import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadi/core/pictos/picto.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_colors.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/core/ui/empty_state.dart';
import 'package:kadi/core/undo/undo.dart';
import 'package:kadi/core/undo/undo_snackbar.dart';
import 'package:kadi/features/catalogue/data/catalogue_repository.dart';
import 'package:kadi/features/catalogue/state/catalogue_providers.dart';
import 'package:material_ui/material_ui.dart';

import '../state/liste_providers.dart';
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
  await showModalBottomSheet<void>(
    context: context,
    // La barrière couvre toute l'app, Barre de navigation comprise.
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.9,
      child: AddSheet(pendingUndo: pending),
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
class AddSheet extends ConsumerStatefulWidget {
  const AddSheet({super.key, this.pendingUndo});

  /// Reçoit le dernier Annuler du panneau tant que son snackbar est ouvert.
  final PanelUndo? pendingUndo;

  @override
  ConsumerState<AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends ConsumerState<AddSheet> {
  final _controller = TextEditingController();
  List<CatalogueArticle> _lastResults = const [];

  /// Articles dont l'écriture est en cours : un second tap est ignoré.
  final _pending = <String>{};

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
      if (messenger.mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text(StringsFr.ajoutImpossible)),
        );
      }
    }
  }

  Future<void> _remove(BuildContext context, CatalogueArticle article) async {
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(listeRepositoryProvider);
    final undo = ref.read(undoProvider);
    final List<UndoRow> rows;
    try {
      rows = await repository.removeArticle(article.id);
    } catch (_) {
      if (messenger.mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text(StringsFr.suppressionImpossible)),
        );
      }
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
    final results = searching
        ? ref.watch(articleSearchProvider(query)).value ?? _lastResults
        : const <CatalogueArticle>[];
    _lastResults = results;
    final groups = searching ? null : ref.watch(frequentGroupsProvider).value;
    final inList = ref.watch(inListProvider).value ?? const <String>{};

    // Contenu sous le Champ de recherche ; [context] est sous le messager du
    // panneau.
    Widget content(BuildContext context) {
      if (searching) {
        return ListView.builder(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          itemCount: results.length,
          itemBuilder: (_, i) => SearchResultRow(
            key: ValueKey(results[i].id),
            article: results[i],
            inList: inList.contains(results[i].id),
            onTap: () => _toggle(context, results[i]),
          ),
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
                FrequentRow(
                  key: ValueKey(article.id),
                  article: article,
                  inList: inList.contains(article.id),
                  onTap: () => _toggle(context, article),
                ),
            ],
          ],
        ),
      };
    }

    // Messager et Scaffold propres au panneau : la feuille vit sur le
    // navigateur racine, au-dessus du Scaffold de la Liste, dont les
    // snackbars resteraient sous la barrière. Le Scaffold laisse la place au
    // clavier ; le fond reste celui de la feuille.
    return ScaffoldMessenger(
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
    );
  }
}

/// Indicateur d'état à droite d'une ligne du Panneau + : coche à l'accent du
/// rayon dans la liste, signe + en `on-surface-variant` hors liste.
class InListIndicator extends StatelessWidget {
  const InListIndicator({super.key, required this.rayon, required this.inList});

  final Rayon rayon;
  final bool inList;

  @override
  Widget build(BuildContext context) {
    return inList
        ? Icon(Icons.check, color: KadiColors.of(context).rayon(rayon).accent)
        : Icon(
            Icons.add,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          );
  }
}

/// Ligne de fréquent : Picto, nom et indicateur d'état. Annoncée « Lait »
/// hors liste, « Lait, dans la liste » dans la liste.
class FrequentRow extends StatelessWidget {
  const FrequentRow({
    super.key,
    required this.article,
    required this.inList,
    required this.onTap,
  });

  final CatalogueArticle article;
  final bool inList;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: inList
          ? '${article.name}, ${StringsFr.dansLaListe}'
          : article.name,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: KadiSpacing.rowMinHeight,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: KadiSpacing.margin,
              vertical: KadiSpacing.s2,
            ),
            child: Row(
              children: [
                Picto(pictoKey: article.pictoKey, rayon: article.rayon),
                const SizedBox(width: KadiSpacing.s4),
                Expanded(
                  child: Text(
                    article.name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: KadiSpacing.s3),
                InListIndicator(rayon: article.rayon, inList: inList),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ligne de résultat : Picto, nom, rayon et indicateur d'état. Annoncée
/// « Lait, Crèmerie », avec « dans la liste » s'il y est.
class SearchResultRow extends StatelessWidget {
  const SearchResultRow({
    super.key,
    required this.article,
    required this.onTap,
    this.inList = false,
  });

  final CatalogueArticle article;
  final bool inList;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Semantics(
      button: true,
      label: [
        article.name,
        article.rayon.spokenLabel,
        if (inList) StringsFr.dansLaListe,
      ].join(', '),
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: KadiSpacing.rowMinHeight,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: KadiSpacing.margin,
              vertical: KadiSpacing.s2,
            ),
            child: Row(
              children: [
                Picto(pictoKey: article.pictoKey, rayon: article.rayon),
                const SizedBox(width: KadiSpacing.s4),
                Expanded(
                  child: Text(
                    article.name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: KadiSpacing.s3),
                Text(
                  article.rayon.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: KadiSpacing.s3),
                InListIndicator(rayon: article.rayon, inList: inList),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
