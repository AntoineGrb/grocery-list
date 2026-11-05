import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/core/ui/empty_state.dart';
import 'package:kadi/core/ui/error_snackbar.dart';
import 'package:kadi/core/ui/rayon_picker.dart';
import 'package:kadi/core/undo/undo.dart';
import 'package:kadi/core/undo/undo_snackbar.dart';
import 'package:kadi/features/catalogue/data/catalogue_repository.dart';
import 'package:kadi/features/catalogue/state/catalogue_providers.dart';
import 'package:material_ui/material_ui.dart';

import 'article_lines.dart';

/// Paramètres › Fréquents (R16), poussé par la ligne « Fréquents » des
/// Paramètres et par « Gérer » du Panneau +.
///
/// Champ vide : les fréquents actifs dans l'ordre du parcours, comme les
/// Ajouts fréquents du panneau ([frequentsInRouteProvider]). Chaque Ligne de
/// fréquent (Picto, nom, rayon) ouvre au tap le Choix de rayon, qui change
/// le rayon par défaut de l'article et passe le fréquent en dernier de son
/// nouveau rayon ; son icône de retrait le retire, avec Annuler (AD-10).
/// Sans fréquent : un message d'état vide.
///
/// Avec un texte : les articles du catalogue, chacun avec un + (tap : ajouté
/// en dernier de son rayon, champ vidé) ou une coche s'il est déjà fréquent
/// (tap sans effet) ; sans article de ce nom exact, « Créer « … » » en tête
/// crée l'article au catalogue (Divers, sans unité) et son fréquent.
///
/// L'app n'ajoute jamais de fréquent d'elle-même ; aucun réordonnancement
/// manuel (C10). Une écriture qui échoue montre un snackbar d'erreur.
class FrequentsScreen extends ConsumerStatefulWidget {
  const FrequentsScreen({super.key});

  @override
  ConsumerState<FrequentsScreen> createState() => _FrequentsScreenState();
}

class _FrequentsScreenState extends ConsumerState<FrequentsScreen> {
  final _controller = TextEditingController();

  /// Derniers résultats affichés, gardés tant que la saisie n'a pas les
  /// siens.
  List<CatalogueArticle> _lastResults = const [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Écrit [write] par le repository `catalogue` ; un échec montre
  /// « Fréquent impossible à enregistrer. ». Rend `false` sur un échec.
  Future<bool> _write(
    Future<void> Function(CatalogueRepository repository) write,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await write(ref.read(catalogueRepositoryProvider));
      return true;
    } catch (_) {
      showErrorSnackBar(messenger, StringsFr.frequentImpossible);
      return false;
    }
  }

  /// Ajoute [article] (ou, sans article, crée [name]) aux fréquents, puis
  /// vide le champ.
  Future<void> _add({CatalogueArticle? article, String? name}) async {
    final ok = await _write(
      (r) => article != null
          ? r.addFrequent(article.id)
          : r.createFrequentArticle(name!),
    );
    if (ok && mounted) setState(_controller.clear);
  }

  /// Retire [article] des fréquents et montre le snackbar Annuler, qui le
  /// remet à sa place.
  Future<void> _remove(CatalogueArticle article) async {
    final messenger = ScaffoldMessenger.of(context);
    final List<UndoRow> rows;
    try {
      rows = await ref
          .read(catalogueRepositoryProvider)
          .removeFrequent(article.id);
    } catch (_) {
      showErrorSnackBar(messenger, StringsFr.frequentImpossible);
      return;
    }
    if (rows.isEmpty) return;
    final entry = ref.read(undoProvider).record(rows);
    if (mounted) {
      showUndoSnackBar(
        context,
        StringsFr.retireDesFrequents(article.name),
        entry,
      );
    }
  }

  /// Choix de rayon de [article] : un autre rayon change le rayon par
  /// défaut de l'article (nom et unité actuels) et passe son fréquent en
  /// dernier, par le seul chemin de la Fiche article (AD-17).
  Future<void> _chooseRayon(CatalogueArticle article) async {
    final rayon = await showFrequentRayonSheet(context, article);
    if (rayon == null || rayon == article.rayon || !mounted) return;
    await _write(
      (r) => r.updateArticle(
        article.id,
        name: article.name,
        rayon: rayon,
        unit: article.unit,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text;
    final searching = query.trim().isNotEmpty;

    final Widget content;
    if (searching) {
      final fresh = ref.watch(articleSearchProvider(query)).value;
      final results = fresh ?? _lastResults;
      _lastResults = results;
      final frequentIds = {
        for (final f in ref.watch(frequentsProvider).value ?? const []) f.id,
      };
      // « Créer « … » » attend les résultats de cette saisie.
      final showCreate = fresh != null && !hasExactName(fresh, query);
      final name = CatalogueRepository.cleanName(query);
      content = ArticleList(
        articles: results,
        header: showCreate
            ? CreateArticleLine(
                key: const ValueKey(CreateArticleLine),
                name: name,
                onTap: () => _add(name: name),
              )
            : null,
        lineOf: (article) => FrequentResultLine(
          key: ValueKey(article.id),
          article: article,
          frequent: frequentIds.contains(article.id),
          onAdd: () => _add(article: article),
        ),
      );
    } else {
      final frequents = ref.watch(frequentsInRouteProvider).value;
      content = switch (frequents) {
        null => const SizedBox.shrink(),
        [] => const EmptyState(message: StringsFr.pasEncoreDeFrequents),
        _ => ArticleList(
          articles: frequents,
          lineOf: (article) => FrequentLine(
            key: ValueKey(article.id),
            article: article,
            onTap: () => _chooseRayon(article),
            onRemove: () => _remove(article),
          ),
        ),
      };
    }

    return Scaffold(
      appBar: AppBar(title: const Text(StringsFr.frequentsTitre)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CatalogueSearchField(
            controller: _controller,
            hint: StringsFr.ajouterUnFrequent,
            onChanged: () => setState(() {}),
          ),
          Expanded(child: content),
        ],
      ),
    );
  }
}

/// Ligne de fréquent de Paramètres › Fréquents : Picto, nom, nom du rayon
/// et, à droite, l'icône de retrait (cible de 48 dp, lue « Retirer Lait des
/// fréquents »). La ligne est un bouton lu « Lait, Crèmerie », qui ouvre le
/// Choix de rayon.
class FrequentLine extends StatelessWidget {
  const FrequentLine({
    super.key,
    required this.article,
    required this.onTap,
    required this.onRemove,
  });

  final CatalogueArticle article;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => ArticleLine(
    article: article,
    onTap: onTap,
    trailing: IconButton(
      tooltip: StringsFr.retirerDesFrequents(article.name),
      icon: const Icon(Icons.remove_circle_outline),
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      constraints: const BoxConstraints(
        minWidth: KadiSpacing.touchTarget,
        minHeight: KadiSpacing.touchTarget,
      ),
      onPressed: onRemove,
    ),
  );
}

/// Ligne de résultat de Paramètres › Fréquents : Picto, nom, rayon et, à
/// droite, un + si l'article n'est pas encore fréquent (la ligne est alors
/// un bouton lu « Piles, Divers », qui l'ajoute) ou une coche s'il l'est
/// (tap sans effet, lue « Lait, déjà dans les fréquents »).
class FrequentResultLine extends StatelessWidget {
  const FrequentResultLine({
    super.key,
    required this.article,
    required this.frequent,
    required this.onAdd,
  });

  final CatalogueArticle article;

  /// L'article est déjà un fréquent actif.
  final bool frequent;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final variant = Theme.of(context).colorScheme.onSurfaceVariant;
    return ArticleLine(
      article: article,
      onTap: frequent ? null : onAdd,
      label: frequent ? StringsFr.dejaFrequent(article.name) : null,
      onTapHint: frequent ? null : StringsFr.ajouterAuxFrequents,
      trailing: ExcludeSemantics(
        child: SizedBox.square(
          dimension: KadiSpacing.touchTarget,
          child: Icon(frequent ? Icons.check : Icons.add, color: variant),
        ),
      ),
    );
  }
}

/// Ouvre le Choix de rayon de [article] dans une feuille modale du
/// navigateur racine (AD-13) ; rend le rayon touché, ou `null` si la
/// feuille est fermée sans choix.
Future<Rayon?> showFrequentRayonSheet(
  BuildContext context,
  CatalogueArticle article,
) => showModalBottomSheet<Rayon>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => FrequentRayonSheet(article: article),
);

/// Feuille du Choix de rayon d'un fréquent : Picto et nom de l'article (lu
/// comme titre), « Rayon par défaut » et le Choix de rayon, son rayon
/// actuel entouré. Toucher un rayon ferme la feuille avec ce rayon.
class FrequentRayonSheet extends StatelessWidget {
  const FrequentRayonSheet({super.key, required this.article});

  final CatalogueArticle article;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        KadiSpacing.margin,
        0,
        KadiSpacing.margin,
        KadiSpacing.s5,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ArticleSheetTitle(
            pictoKey: article.pictoKey,
            rayon: article.rayon,
            title: article.name,
          ),
          const SizedBox(height: KadiSpacing.s4),
          Text(
            StringsFr.rayonParDefaut,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: KadiSpacing.s2),
          RayonPicker(
            selected: article.rayon,
            onSelected: (rayon) => Navigator.pop(context, rayon),
          ),
        ],
      ),
    );
  }
}
