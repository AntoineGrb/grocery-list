import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/ui/error_snackbar.dart';
import 'package:kadi/core/ui/frequent_bolt.dart';
import 'package:kadi/core/undo/undo_snackbar.dart';
import 'package:kadi/features/catalogue/data/catalogue_repository.dart';
import 'package:kadi/features/catalogue/state/catalogue_providers.dart';
import 'package:material_ui/material_ui.dart';

import 'article_lines.dart';
import 'article_sheet.dart';

/// Paramètres › Articles (R18) : Champ de recherche sur les seuls articles
/// du catalogue (AD-17) et leurs Lignes d'article ; un tap ouvre la Fiche
/// article.
///
/// Champ vide : tout le catalogue par ordre alphabétique. Avec un texte : la
/// recherche du catalogue et, si aucun article ne porte exactement ce nom
/// (casse et accents ignorés), une ligne « Créer « … » » en tête, qui ouvre
/// la Fiche article préremplie du nom nettoyé. Les articles hors catalogue
/// n'apparaissent jamais.
///
/// À droite de chaque article, l'éclair des fréquents : vide, un tap en fait
/// un fréquent (ajouté en dernier) et le remplit ; plein, un tap le retire.
/// C'est le seul endroit où l'on gère les fréquents.
class ArticlesScreen extends ConsumerStatefulWidget {
  const ArticlesScreen({super.key});

  @override
  ConsumerState<ArticlesScreen> createState() => _ArticlesScreenState();
}

class _ArticlesScreenState extends ConsumerState<ArticlesScreen> {
  final _controller = TextEditingController();

  /// Derniers résultats affichés, gardés tant que la saisie n'a pas les
  /// siens.
  List<CatalogueArticle> _lastResults = const [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Bascule [article] dans les fréquents ; un échec montre un snackbar.
  Future<void> _toggleFrequent(
    BuildContext context,
    CatalogueArticle article,
    bool frequent,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(catalogueRepositoryProvider);
    try {
      if (frequent) {
        await repository.removeFrequent(article.id);
      } else {
        await repository.addFrequent(article.id);
      }
    } catch (_) {
      showErrorSnackBar(messenger, StringsFr.frequentImpossible);
    }
  }

  /// Ouvre la Fiche de [article] ; supprimé, un snackbar Annuler suit.
  Future<void> _open(BuildContext context, CatalogueArticle article) async {
    final entry = await showArticleSheet(context, article: article);
    if (entry == null || !context.mounted) return;
    showUndoSnackBar(context, StringsFr.articleSupprime(article.name), entry);
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text;
    final searching = query.trim().isNotEmpty;
    final fresh = searching
        ? ref.watch(articleSearchProvider(query)).value
        : ref.watch(catalogueArticlesProvider).value;
    final results = fresh ?? _lastResults;
    _lastResults = results;
    // « Créer « … » » attend les résultats de cette saisie.
    final showCreate =
        searching && fresh != null && !hasExactName(fresh, query);
    final name = CatalogueRepository.cleanName(query);
    final frequentIds = {
      for (final a in ref.watch(frequentsProvider).value ?? const []) a.id,
    };

    return Scaffold(
      appBar: AppBar(title: const Text(StringsFr.articlesTitre)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CatalogueSearchField(
            controller: _controller,
            hint: StringsFr.chercherUnArticle,
            onChanged: () => setState(() {}),
          ),
          Expanded(
            child: ArticleList(
              articles: results,
              header: showCreate
                  ? CreateArticleLine(
                      key: const ValueKey(CreateArticleLine),
                      name: name,
                      onTap: () => showArticleSheet(context, name: name),
                    )
                  : null,
              lineOf: (article) => ArticleLine(
                key: ValueKey(article.id),
                article: article,
                onTap: () => _open(context, article),
                trailing: FrequentBolt(
                  name: article.name,
                  frequent: frequentIds.contains(article.id),
                  onTap: () => _toggleFrequent(
                    context,
                    article,
                    frequentIds.contains(article.id),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
