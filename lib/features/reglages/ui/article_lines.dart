import 'package:kadi/core/pictos/picto.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/features/catalogue/data/catalogue_repository.dart';
import 'package:kadi/features/catalogue/data/normalize_name.dart';
import 'package:material_ui/material_ui.dart';

/// Vrai si un article de [results] porte exactement le nom [text], casse et
/// accents ignorés (AD-17) : « Créer « … » » n'est alors pas proposé.
bool hasExactName(List<CatalogueArticle> results, String text) {
  final normalized = normalizeName(text);
  return results.any((article) => normalizeName(article.name) == normalized);
}

/// Champ de recherche des écrans de Paramètres (DESIGN `search-field`) :
/// loupe à gauche, texte indicatif [hint] (lu comme libellé du champ, une
/// seule fois), × dès qu'il y a du texte, lu « Effacer le texte ».
///
/// [onChanged] est appelé à chaque frappe et après l'effacement : l'écran,
/// qui lit [controller], se reconstruit.
class CatalogueSearchField extends StatelessWidget {
  const CatalogueSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final empty = controller.text.isEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KadiSpacing.margin,
        KadiSpacing.s2,
        KadiSpacing.margin,
        KadiSpacing.s2,
      ),
      child: Semantics(
        label: hint,
        child: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.search,
          style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurface),
          onChanged: (_) => onChanged(),
          decoration: InputDecoration(
            constraints: const BoxConstraints(
              minHeight: KadiSpacing.touchTarget,
            ),
            prefixIcon: const Icon(Icons.search),
            // Lu par le libellé du champ, une seule fois ; entier, sur
            // plusieurs lignes en grande police.
            hint: empty
                ? ExcludeSemantics(
                    child: Text(
                      hint,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : null,
            suffixIcon: empty
                ? null
                : IconButton(
                    tooltip: StringsFr.effacerLeTexte,
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      controller.clear();
                      onChanged();
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

/// Ligne d'article des écrans de Paramètres : Picto, nom en `body-large` et,
/// dessous, nom du rayon en `body-medium` `on-surface-variant` ; cible de
/// 48 dp au moins, le nom passe à la ligne en grande police.
///
/// Lue [label], par défaut « Tomates, Fruits et légumes » ; un bouton si
/// [onTap] est donné, avec l'indication [onTapHint]. [trailing] se place à
/// droite (icône de retrait, + ou coche) : un bouton y garde sa propre
/// lecture.
class ArticleLine extends StatelessWidget {
  const ArticleLine({
    super.key,
    required this.article,
    this.onTap,
    this.label,
    this.onTapHint,
    this.trailing,
  });

  final CatalogueArticle article;
  final VoidCallback? onTap;
  final String? label;
  final String? onTapHint;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final trailing = this.trailing;
    return Semantics(
      container: true,
      button: onTap != null,
      label: label ?? '${article.name}, ${article.rayon.spokenLabel}',
      onTap: onTap,
      onTapHint: onTapHint,
      child: InkWell(
        onTap: onTap,
        excludeFromSemantics: true,
        child: _LineFrame(
          // Le Picto n'a pas de lecture.
          leading: Picto(pictoKey: article.pictoKey, rayon: article.rayon),
          body: ExcludeSemantics(
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
          trailing: trailing,
        ),
      ),
    );
  }
}

/// Ligne « Créer « … » » en tête des résultats, quand aucun article du
/// catalogue ne porte exactement le nom tapé : signe + neutre, lue
/// « Créer « Piment » ».
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
        child: _LineFrame(
          leading: SizedBox.square(
            dimension: KadiSpacing.picto,
            child: Icon(Icons.add, color: scheme.onSurfaceVariant),
          ),
          body: Text(
            label,
            style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurface),
          ),
        ),
      ),
    );
  }
}

/// Cadre commun des lignes de Paramètres › Articles et › Fréquents : cible
/// de 48 dp au moins, marges de l'écran ; [leading] (Picto ou signe),
/// [body] qui prend la place et, s'il est donné, [trailing] à droite.
class _LineFrame extends StatelessWidget {
  const _LineFrame({required this.leading, required this.body, this.trailing});

  final Widget leading;
  final Widget body;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final trailing = this.trailing;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: KadiSpacing.rowMinHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: KadiSpacing.margin,
          vertical: KadiSpacing.s2,
        ),
        child: Row(
          children: [
            leading,
            const SizedBox(width: KadiSpacing.s4),
            Expanded(child: body),
            if (trailing != null) ...[
              const SizedBox(width: KadiSpacing.s2),
              trailing,
            ],
          ],
        ),
      ),
    );
  }
}

/// Liste de Paramètres › Articles et › Fréquents : [header] (la ligne
/// « Créer « … » »), s'il est donné, en tête, puis la ligne [lineOf] de
/// chaque article de [articles]. Glisser la liste ferme le clavier.
class ArticleList extends StatelessWidget {
  const ArticleList({
    super.key,
    required this.articles,
    required this.lineOf,
    this.header,
  });

  final List<CatalogueArticle> articles;
  final Widget Function(CatalogueArticle article) lineOf;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final header = this.header;
    final offset = header == null ? 0 : 1;
    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: KadiSpacing.s4),
      itemCount: articles.length + offset,
      itemBuilder: (context, i) =>
          header != null && i == 0 ? header : lineOf(articles[i - offset]),
    );
  }
}

/// Titre d'une feuille d'article (Fiche article, Choix de rayon d'un
/// fréquent) : le Picto ([pictoKey], [rayon]), affiché sans être modifiable
/// et sans lecture, puis [title] en `title-medium`, lu comme titre.
class ArticleSheetTitle extends StatelessWidget {
  const ArticleSheetTitle({
    super.key,
    required this.pictoKey,
    required this.rayon,
    required this.title,
  });

  final String pictoKey;
  final Rayon rayon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Picto(pictoKey: pictoKey, rayon: rayon),
        const SizedBox(width: KadiSpacing.s4),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
