import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadi/app/actions/ajout_panneau.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/core/ui/empty_state.dart';
import 'package:kadi/core/ui/error_snackbar.dart';
import 'package:kadi/core/ui/quantity_field.dart';
import 'package:kadi/core/undo/undo.dart';
import 'package:kadi/core/undo/undo_snackbar.dart';
import 'package:kadi/features/catalogue/data/catalogue_repository.dart';
import 'package:kadi/features/catalogue/state/catalogue_providers.dart';
import 'package:material_ui/material_ui.dart';

import '../data/liste_repository.dart';
import '../state/liste_providers.dart';
import 'add_sheet_rows.dart';
import 'rayon_header.dart';

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

/// Panneau + : Champ de recherche focalisé, puis les fréquents groupés par
/// rayon dans l'ordre du parcours, ou les résultats dès qu'une recherche est
/// saisie. Un tap ajoute l'article, ou le retire s'il est déjà dans la liste
/// (avec Annuler). Reste ouvert après un tap pour enchaîner.
///
/// Sans correspondance exacte, « Créer « … » » termine les résultats : il
/// crée l'article et l'ajoute (R8). La ligne du dernier ajout se déplie :
/// Champ quantité (unité par défaut de l'article, absent sans unité) et
/// Choix de rayon (R3, R9). La quantité s'écrit à la validation du clavier,
/// au repli (autre ajout, retrait de l'article) et à la fermeture, une seule
/// fois et seulement si la saisie a changé.
class AddSheet extends ConsumerStatefulWidget {
  const AddSheet({super.key, this.pendingUndo, this.listMessenger});

  /// Reçoit le dernier Annuler du panneau tant que son snackbar est ouvert.
  final PanelUndo? pendingUndo;

  /// Messager de la Liste : erreur d'une écriture faite à la fermeture.
  final ScaffoldMessengerState? listMessenger;

  @override
  ConsumerState<AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends ConsumerState<AddSheet> {
  final _controller = TextEditingController();
  List<CatalogueArticle> _lastResults = const [];

  /// Articles dont l'écriture est en cours : un second tap est ignoré.
  final _pending = <String>{};

  /// Une création est en cours : un second tap sur « Créer » est ignoré.
  bool _creating = false;

  /// Articles créés dans ce panneau : leur Choix de rayon change aussi le
  /// rayon de l'article, même après un retrait et un nouvel ajout.
  final _created = <String>{};

  /// Messager propre au panneau.
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  // Lu une fois : l'écriture de fermeture se fait aussi dans dispose.
  late final ListeRepository _liste;

  /// Dernier ajout, dont la ligne est dépliée ; `null` : tout est replié.
  ArticleAjoute? _deplie;
  final _quantityController = TextEditingController();

  /// Le Champ quantité a été saisi depuis le dernier ajout.
  bool _quantityEdited = false;

  /// Dernière quantité écrite pour la ligne dépliée (`null` : sans).
  int? _quantityWritten;

  /// Rayon de la ligne dépliée, entouré dans le Choix de rayon.
  Rayon _rayonDeplie = Rayon.divers;

  /// Le panneau se ferme : une erreur s'affiche sur la Liste.
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _liste = ref.read(listeRepositoryProvider);
  }

  @override
  void dispose() {
    // Fermeture sans passer par le pop (rare) : la quantité est écrite.
    _closing = true;
    _commitQuantity();
    _controller.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  /// Snackbar [message] dans le panneau, ou sur la Liste s'il se ferme.
  void _showMessage(String message) {
    final panel = _messengerKey.currentState;
    final messenger = !_closing && panel != null && panel.mounted
        ? panel
        : widget.listMessenger;
    if (messenger == null) return;
    showErrorSnackBar(messenger, message);
  }

  /// Écrit la quantité saisie pour la ligne dépliée, si le champ a été
  /// saisi et qu'elle diffère de la dernière écrite. Le futur se termine
  /// une fois l'écriture faite (ou échouée).
  Future<void> _commitQuantity() async {
    final deplie = _deplie;
    final unit = deplie?.article.unit;
    if (deplie == null || unit == null || !_quantityEdited) return;
    final value = quantityFromFieldText(_quantityController.text, unit);
    final previous = _quantityWritten;
    if (value == previous) return;
    _quantityWritten = value;
    await _liste.setAddedQuantity(deplie.contributionId, value).catchError((
      Object _,
    ) {
      // Un nouvel essai reste possible (validation ou fermeture).
      if (identical(_deplie, deplie) && _quantityWritten == value) {
        _quantityWritten = previous;
      }
      _showMessage(StringsFr.modificationImpossible);
    });
  }

  /// Replie la ligne dépliée, après avoir écrit sa quantité ; le futur se
  /// termine une fois la quantité écrite.
  Future<void> _fold() {
    final write = _commitQuantity();
    if (_deplie != null) setState(() => _deplie = null);
    return write;
  }

  /// Déplie la ligne de [ajout], qui vient d'être écrit.
  void _unfold(ArticleAjoute ajout) {
    if (!mounted) return;
    setState(() {
      _deplie = ajout;
      _quantityController.clear();
      _quantityEdited = false;
      _quantityWritten = null;
      // La ligne vient de copier le rayon de l'article (AD-15).
      _rayonDeplie = ajout.article.rayon;
    });
  }

  Future<void> _selectRayon(Rayon rayon) async {
    final deplie = _deplie;
    if (deplie == null || rayon == _rayonDeplie) return;
    final previous = _rayonDeplie;
    setState(() => _rayonDeplie = rayon);
    try {
      await ref
          .read(placerLigneAjouteeProvider)
          .call(
            deplie.lineId,
            deplie.article.id,
            rayon,
            articleCree: deplie.articleCree,
          );
    } catch (_) {
      if (mounted && identical(_deplie, deplie) && _rayonDeplie == rayon) {
        setState(() => _rayonDeplie = previous);
      }
      _showMessage(StringsFr.modificationImpossible);
    }
  }

  /// « Créer « … » » : crée l'article de nom [name] et l'ajoute, puis
  /// déplie sa ligne ; la saisie reste.
  Future<void> _create(String name) async {
    if (_creating) return;
    _creating = true;
    _fold();
    try {
      final ajout = await ref.read(creerEtAjouterProvider).call(name);
      if (ajout.articleCree) _created.add(ajout.article.id);
      _unfold(ajout);
    } catch (_) {
      _showMessage(StringsFr.ajoutImpossible);
    } finally {
      _creating = false;
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
    _fold();
    try {
      final added = await _liste.addArticle(article.id);
      _unfold(
        ArticleAjoute(
          article: article,
          lineId: added.lineId,
          contributionId: added.contributionId,
          articleCree: _created.contains(article.id),
        ),
      );
    } catch (_) {
      // Le panneau a pu se fermer pendant l'écriture.
      showErrorSnackBar(messenger, StringsFr.ajoutImpossible);
    }
  }

  Future<void> _remove(BuildContext context, CatalogueArticle article) async {
    final messenger = ScaffoldMessenger.of(context);
    final repository = _liste;
    final undo = ref.read(undoProvider);
    // Un retrait replie la ligne dépliée ; sa quantité est écrite d'abord,
    // pour qu'Annuler la rende et que l'écriture ne vide pas l'emplacement
    // Annuler de ce retrait (AD-10).
    await _fold();
    final List<UndoRow> rows;
    try {
      rows = await repository.removeArticle(article.id);
    } catch (_) {
      showErrorSnackBar(messenger, StringsFr.suppressionImpossible);
      return;
    }
    if (rows.isEmpty) return;
    final entry = undo.record(rows);
    final message = StringsFr.retireDeLaListe(article.name);
    // Gardé pour la Liste si le panneau se ferme avant la fin du snackbar.
    final pending = widget.pendingUndo
      ?..entry = entry
      ..message = message;
    if (!context.mounted) return;
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
    // « Créer » attend les résultats de cette saisie : jamais proposé sur
    // des résultats périmés.
    final showCreate =
        fresh != null && !CatalogueRepository.hasExactMatch(fresh, query);
    final groups = searching ? null : ref.watch(frequentGroupsProvider).value;
    final inList = ref.watch(inListProvider).value ?? const <String>{};

    // La ligne de [article], dépliée sous elle si c'est le dernier ajout.
    Widget withEditor(CatalogueArticle article, Widget row) {
      final deplie = _deplie;
      final unfolded =
          deplie != null &&
          deplie.article.id == article.id &&
          inList.contains(article.id);
      return KeyedSubtree(
        key: ValueKey(article.id),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            row,
            if (unfolded)
              AddedLineEditor(
                unit: deplie.article.unit,
                quantityController: _quantityController,
                onQuantityChanged: (_) => _quantityEdited = true,
                onQuantitySubmitted: (_) {
                  _quantityEdited = true;
                  _commitQuantity();
                },
                rayon: _rayonDeplie,
                onRayonSelected: _selectRayon,
              ),
          ],
        ),
      );
    }

    // Contenu sous le Champ de recherche ; [context] est sous le messager du
    // panneau.
    Widget content(BuildContext context) {
      if (searching) {
        return ListView.builder(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.only(bottom: KadiSpacing.s4),
          itemCount: results.length + (showCreate ? 1 : 0),
          itemBuilder: (_, i) {
            if (i == results.length) {
              final name = query.trim();
              return CreateArticleRow(
                key: const ValueKey(CreateArticleRow),
                name: name,
                onTap: () => _create(name),
              );
            }
            final article = results[i];
            return withEditor(
              article,
              SearchResultRow(
                article: article,
                inList: inList.contains(article.id),
                onTap: () => _toggle(context, article),
              ),
            );
          },
        );
      }
      return switch (groups) {
        null => const SizedBox.shrink(),
        [] => const EmptyState(message: StringsFr.pasDeFrequents),
        _ => ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.only(bottom: KadiSpacing.s4),
          children: [
            for (final group in groups) ...[
              RayonHeader(rayon: group.rayon),
              for (final article in group.articles)
                withEditor(
                  article,
                  FrequentRow(
                    article: article,
                    inList: inList.contains(article.id),
                    onTap: () => _toggle(context, article),
                  ),
                ),
            ],
          ],
        ),
      };
    }

    // Messager et Scaffold propres au panneau : la feuille vit sur le
    // navigateur racine, au-dessus du Scaffold de la Liste, dont les
    // snackbars resteraient sous la barrière. Le Scaffold laisse la place au
    // clavier ; le fond reste celui de la feuille. À la fermeture, la
    // quantité en cours est écrite.
    return PopScope<Object?>(
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) return;
        _closing = true;
        _commitQuantity();
      },
      child: ScaffoldMessenger(
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
                      textInputAction: TextInputAction.search,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: StringsFr.rechercherUnArticle,
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: StringsFr.effacerLaRecherche,
                                icon: const Icon(Icons.close),
                                onPressed: () => setState(_controller.clear),
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: KadiSpacing.s2),
                Expanded(child: content(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
