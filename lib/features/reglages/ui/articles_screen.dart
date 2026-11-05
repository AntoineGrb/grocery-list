import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
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
    final offset = showCreate ? 1 : 0;

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
            child: ListView.builder(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.only(bottom: KadiSpacing.s4),
              itemCount: results.length + offset,
              itemBuilder: (context, i) {
                if (showCreate && i == 0) {
                  final name = CatalogueRepository.cleanName(query);
                  return CreateArticleLine(
                    key: const ValueKey(CreateArticleLine),
                    name: name,
                    onTap: () => showArticleSheet(context, name: name),
                  );
                }
                final article = results[i - offset];
                return ArticleLine(
                  key: ValueKey(article.id),
                  article: article,
                  onTap: () => showArticleSheet(context, article: article),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
