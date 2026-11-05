import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadi/core/pictos/picto.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/features/catalogue/data/catalogue_repository.dart';
import 'package:kadi/features/catalogue/data/normalize_name.dart';
import 'package:kadi/features/catalogue/state/catalogue_providers.dart';
import 'package:material_ui/material_ui.dart';

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

  /// Un article de [results] porte exactement le nom [text] (AD-17).
  static bool _hasExact(List<CatalogueArticle> results, String text) {
    final normalized = normalizeName(text);
    return results.any((article) => normalizeName(article.name) == normalized);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final query = _controller.text;
    final searching = query.trim().isNotEmpty;
    final fresh = searching
        ? ref.watch(articleSearchProvider(query)).value
        : ref.watch(catalogueArticlesProvider).value;
    final results = fresh ?? _lastResults;
    _lastResults = results;
    // « Créer « … » » attend les résultats de cette saisie.
    final showCreate = searching && fresh != null && !_hasExact(fresh, query);
    final offset = showCreate ? 1 : 0;

    final field = Padding(
      padding: const EdgeInsets.fromLTRB(
        KadiSpacing.margin,
        KadiSpacing.s2,
        KadiSpacing.margin,
        KadiSpacing.s2,
      ),
      child: Semantics(
        label: StringsFr.chercherUnArticle,
        child: TextField(
          controller: _controller,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.search,
          style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurface),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            constraints: const BoxConstraints(
              minHeight: KadiSpacing.touchTarget,
            ),
            prefixIcon: const Icon(Icons.search),
            // Lu par le libellé du champ, une seule fois ; entier, sur
            // plusieurs lignes en grande police.
            hint: query.isEmpty
                ? ExcludeSemantics(
                    child: Text(
                      StringsFr.chercherUnArticle,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : null,
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
    );

    return Scaffold(
      appBar: AppBar(title: const Text(StringsFr.articlesTitre)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          field,
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

/// Ligne d'article de Paramètres › Articles : Picto, nom en `body-large` et,
/// dessous, nom du rayon en `body-medium` `on-surface-variant` ; cible de
/// 48 dp au moins, le nom passe à la ligne en grande police. Un bouton lu
/// « Tomates, Fruits et légumes ».
class ArticleLine extends StatelessWidget {
  const ArticleLine({super.key, required this.article, required this.onTap});

  final CatalogueArticle article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      container: true,
      button: true,
      label: '${article.name}, ${article.rayon.spokenLabel}',
      onTap: onTap,
      excludeSemantics: true,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        article.name,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                      Text(
                        article.rayon.label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ligne « Créer « … » » en tête des résultats, quand aucun article du
/// catalogue ne porte exactement le nom tapé : signe + neutre, lue
/// « Créer « Piment » » ; ouvre la Fiche article préremplie.
class CreateArticleLine extends StatelessWidget {
  const CreateArticleLine({super.key, required this.name, required this.onTap});

  /// Le nom nettoyé de la saisie.
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = StringsFr.creerNom(name);
    return Semantics(
      container: true,
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
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
                SizedBox.square(
                  dimension: KadiSpacing.picto,
                  child: Icon(Icons.add, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(width: KadiSpacing.s4),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
