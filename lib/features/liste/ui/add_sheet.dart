import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadi/app/actions/ajout_panneau.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/core/ui/empty_state.dart';
import 'package:kadi/core/ui/error_snackbar.dart';
import 'package:kadi/core/undo/undo.dart';
import 'package:kadi/core/undo/undo_snackbar.dart';
import 'package:kadi/features/catalogue/data/catalogue_repository.dart';
import 'package:kadi/features/catalogue/state/catalogue_providers.dart';
import 'package:material_ui/material_ui.dart';

import '../data/liste_repository.dart';
import '../state/liste_providers.dart';
import 'add_sheet_rows.dart';
import 'item_edit_sheet.dart';

/// Dernier Annuler montré dans le Panneau +, repris par la Liste quand le
/// panneau se ferme avant la fin de son snackbar (AD-10).
class PanelUndo {
  UndoEntry? entry;
  String message = '';
}

/// Ouvre le Panneau + sur la Liste.
///
/// [context] est sous le messager de la Liste : un Annuler encore possible
/// à la fermeture du panneau y est remontré ; sinon l'emplacement est vidé.
Future<void> showAddSheet(BuildContext context) async {
  final undo = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(undoProvider);
  final pending = PanelUndo();
  final messenger = ScaffoldMessenger.maybeOf(context);
  await showModalBottomSheet<void>(
    context: context,
    // La barrière couvre toute l'app, Barre de navigation comprise.
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.9,
      child: AddSheet(pendingUndo: pending, listMessenger: messenger),
    ),
  );
  final entry = pending.entry;
  if (entry == null) return;
  if (context.mounted && undo.canUndo(entry)) {
    showUndoSnackBar(context, pending.message, entry);
  } else {
    undo.clear(entry);
  }
}

/// Panneau + : Champ d'ajout focalisé, puis le titre « Ajouts fréquents » et
/// les fréquents en liste plate dans l'ordre du parcours, sans En-tête de
/// rayon, ou les résultats dès qu'un texte est saisi. Un tap ajoute
/// l'article, ou le retire s'il est déjà dans la liste (avec Annuler). Reste
/// ouvert après un ajout pour enchaîner.
///
/// Entrée ajoute le texte tapé (R25) : l'article de ce nom, sinon un article
/// hors catalogue (Divers, sans unité) ; déjà dans la liste, rien ne change.
/// Le champ se vide, le clavier reste ouvert et la Ligne saisie (le dernier
/// article d'Entrée) s'affiche sous le champ tant qu'il est dans la liste.
/// Sans résultat, une seule ligne « Ajouter « … » » fait comme Entrée.
///
/// Rien ne se déplie après un ajout : dans la liste, une ligne (fréquent,
/// résultat ou Ligne saisie) montre un crayon à gauche de sa coche, qui
/// ouvre la Feuille d'édition empilée sur le panneau (R14, AD-13) ; le
/// panneau reste ouvert dessous et son messager montre les erreurs et
/// l'Annuler de « Supprimer ».
class AddSheet extends ConsumerStatefulWidget {
  const AddSheet({super.key, this.pendingUndo, this.listMessenger});

  /// Reçoit le dernier Annuler du panneau tant que son snackbar est ouvert.
  final PanelUndo? pendingUndo;

  /// Messager de la Liste : erreur d'une écriture finie après la
  /// fermeture.
  final ScaffoldMessengerState? listMessenger;

  @override
  ConsumerState<AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends ConsumerState<AddSheet> {
  final _controller = TextEditingController();
  List<CatalogueArticle> _lastResults = const [];

  /// Articles dont l'écriture est en cours : un second tap est ignoré.
  final _pending = <String>{};

  /// Un ajout par Entrée est en cours : une seconde Entrée est ignorée.
  bool _submitting = false;

  /// Ligne saisie : le dernier article ajouté par Entrée, affiché sous le
  /// champ tant qu'il est dans la liste.
  CatalogueArticle? _saisie;

  /// Messager propre au panneau.
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  /// Une Feuille d'édition s'ouvre ou est ouverte : un second crayon est
  /// ignoré.
  bool _editing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Snackbar [message] dans le panneau, ou sur la Liste s'il est fermé.
  void _showMessage(String message) {
    final panel = _messengerKey.currentState;
    final messenger = panel != null && panel.mounted
        ? panel
        : widget.listMessenger;
    if (messenger == null) return;
    showErrorSnackBar(messenger, message);
  }

  /// Entrée ou « Ajouter « … » » : ajoute le texte tapé (R25), sauf s'il
  /// est déjà dans la liste, puis vide le champ et montre la Ligne saisie.
  /// Un texte vide ne fait rien ; un échec garde la saisie.
  Future<void> _addTyped() async {
    final text = _controller.text;
    if (text.trim().isEmpty || _submitting) return;
    _submitting = true;
    try {
      final result = await ref.read(ajouterTexteProvider).call(text);
      if (!mounted) return;
      setState(() {
        _saisie = result.article;
        // Une frappe pendant l'écriture est gardée.
        if (_controller.text == text) _controller.clear();
      });
    } catch (_) {
      _showMessage(StringsFr.ajoutImpossible);
    } finally {
      _submitting = false;
    }
  }

  /// Ajoute [article], ou le retire s'il est dans la liste (AD-4), avec le
  /// snackbar Annuler (AD-10).
  ///
  /// [context] est sous le messager du panneau : ses snackbars s'affichent
  /// dans le panneau, au-dessus de la barrière.
  Future<void> _toggle(BuildContext context, CatalogueArticle article) async {
    // État « dans la liste » pas encore connu : le tap est ignoré.
    final inListIds = ref.read(inListProvider).value;
    if (inListIds == null || !_pending.add(article.id)) return;
    try {
      if (inListIds.contains(article.id)) {
        await _remove(context, article);
      } else {
        await _add(context, article);
      }
    } finally {
      _pending.remove(article.id);
    }
  }

  Future<void> _add(BuildContext context, CatalogueArticle article) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(listeRepositoryProvider).addArticle(article.id);
    } catch (_) {
      // Le panneau a pu se fermer pendant l'écriture.
      showErrorSnackBar(messenger, StringsFr.ajoutImpossible);
    }
  }

  Future<void> _remove(BuildContext context, CatalogueArticle article) async {
    final messenger = ScaffoldMessenger.of(context);
    final List<UndoRow> rows;
    try {
      rows = await ref.read(listeRepositoryProvider).removeArticle(article.id);
    } catch (_) {
      showErrorSnackBar(messenger, StringsFr.suppressionImpossible);
      return;
    }
    if (!context.mounted) return;
    _showUndo(context, rows, StringsFr.retireDeLaListe(article.name));
  }

  /// Crayon de [article] : ouvre la Feuille d'édition de sa plus ancienne
  /// ligne non cochée, empilée sur le panneau ; « Supprimer » y retire la
  /// ligne avec Annuler (AD-10).
  ///
  /// [context] est sous le messager du panneau : les erreurs de la feuille
  /// et l'Annuler s'y affichent (AD-13).
  Future<void> _edit(BuildContext context, CatalogueArticle article) async {
    if (_editing) return;
    _editing = true;
    try {
      final repository = ref.read(listeRepositoryProvider);
      final ListeItem? item;
      try {
        item = await repository.firstUnchecked(article.id);
      } catch (_) {
        if (context.mounted) {
          showErrorSnackBar(
            ScaffoldMessenger.of(context),
            StringsFr.modificationImpossible,
          );
        }
        return;
      }
      if (item == null || !context.mounted) return;
      final result = await showItemEditSheet(context, item);
      if (result != ItemEditResult.delete || !context.mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      final List<UndoRow> rows;
      try {
        rows = await repository.removeLine(item.lineId);
      } catch (_) {
        showErrorSnackBar(messenger, StringsFr.suppressionImpossible);
        return;
      }
      if (!context.mounted) return;
      _showUndo(context, rows, StringsFr.retireDeLaListe(item.name));
    } finally {
      _editing = false;
    }
  }

  /// Snackbar Annuler de [rows] dans le panneau (AD-10), gardé pour la
  /// Liste si le panneau se ferme avant sa fin. Rien sans ligne écrite.
  void _showUndo(BuildContext context, List<UndoRow> rows, String message) {
    if (rows.isEmpty) return;
    final entry = ref.read(undoProvider).record(rows);
    final pending = widget.pendingUndo
      ?..entry = entry
      ..message = message;
    showUndoSnackBar(context, message, entry).closed.then((_) {
      // Fermé normalement, panneau ouvert : plus rien à reprendre.
      if (pending != null && identical(pending.entry, entry)) {
        pending.entry = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text;
    final searching = query.trim().isNotEmpty;
    // Garder les derniers résultats tant que la nouvelle saisie n'a pas
    // encore reçu sa première valeur, pour éviter un clignotement à chaque
    // lettre.
    final fresh = searching
        ? ref.watch(articleSearchProvider(query)).value
        : null;
    final results = searching
        ? fresh ?? _lastResults
        : const <CatalogueArticle>[];
    _lastResults = results;
    // « Ajouter « … » » attend les résultats de cette saisie : jamais
    // proposé sur des résultats périmés.
    final showAddTyped = fresh != null && fresh.isEmpty;
    final frequents = searching
        ? null
        : ref.watch(frequentsInRouteProvider).value;
    final inList = ref.watch(inListProvider).value ?? const <String>{};
    final saisie = _saisie;

    // Contenu sous le Champ d'ajout ; [context] est sous le messager du
    // panneau.
    Widget content(BuildContext context) {
      if (searching) {
        return ListView.builder(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.only(bottom: KadiSpacing.s4),
          itemCount: results.length + (showAddTyped ? 1 : 0),
          itemBuilder: (_, i) {
            if (i == results.length) {
              return AddTypedRow(
                key: const ValueKey(AddTypedRow),
                name: query.trim(),
                onTap: _addTyped,
              );
            }
            final article = results[i];
            return SearchResultRow(
              key: ValueKey(article.id),
              article: article,
              inList: inList.contains(article.id),
              onTap: () => _toggle(context, article),
              onEdit: () => _edit(context, article),
            );
          },
        );
      }
      return switch (frequents) {
        null => const SizedBox.shrink(),
        [] => const EmptyState(message: StringsFr.pasDeFrequents),
        _ => ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.only(bottom: KadiSpacing.s4),
          children: [
            const FrequentsTitle(),
            for (final article in frequents)
              FrequentRow(
                key: ValueKey(article.id),
                article: article,
                inList: inList.contains(article.id),
                onTap: () => _toggle(context, article),
                onEdit: () => _edit(context, article),
              ),
          ],
        ),
      };
    }

    // Messager et Scaffold propres au panneau : la feuille vit sur le
    // navigateur racine, au-dessus du Scaffold de la Liste, dont les
    // snackbars resteraient sous la barrière. Le Scaffold laisse la place au
    // clavier ; le fond reste celui de la feuille.
    return ScaffoldMessenger(
      key: _messengerKey,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Builder(
          builder: (context) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: KadiSpacing.margin,
                ),
                child: SizedBox(
                  height: KadiSpacing.touchTarget,
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _addTyped(),
                    // Le clavier reste ouvert après Entrée.
                    onEditingComplete: () {},
                    decoration: InputDecoration(
                      hintText: StringsFr.ajouterUnArticle,
                      prefixIcon: const Icon(Icons.add),
                      suffixIcon: query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: StringsFr.effacerLeTexte,
                              icon: const Icon(Icons.close),
                              onPressed: () => setState(_controller.clear),
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: KadiSpacing.s2),
              if (saisie != null && inList.contains(saisie.id))
                FrequentRow(
                  key: const ValueKey('saisie'),
                  article: saisie,
                  inList: true,
                  onTap: () => _toggle(context, saisie),
                  onEdit: () => _edit(context, saisie),
                ),
              Expanded(child: content(context)),
            ],
          ),
        ),
      ),
    );
  }
}
