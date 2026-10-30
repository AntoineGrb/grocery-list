import 'package:kadi/core/pictos/picto.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_colors.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/features/catalogue/data/catalogue_repository.dart';
import 'package:material_ui/material_ui.dart';

/// Seule ligne des résultats quand la saisie ne trouve rien : signe +
/// neutre et « Ajouter « piles » », qui fait comme Entrée. Un bouton, lu
/// « Ajouter « piles » ».
class AddTypedRow extends StatelessWidget {
  const AddTypedRow({super.key, required this.name, required this.onTap});

  /// La saisie, telle que tapée.
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = StringsFr.ajouterNom(name);

    return Semantics(
      button: true,
      label: label,
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

/// Ligne du Panneau + : Picto, nom, [meta] facultatif et indicateur d'état ;
/// dans la liste, le crayon [onEdit] à gauche de la coche.
///
/// La ligne est un bouton lu [label] ; le crayon, cible de 48 dp, est un
/// bouton à part, lu « Modifier Lait ».
class _PanelRow extends StatelessWidget {
  const _PanelRow({
    required this.article,
    required this.label,
    required this.inList,
    required this.onTap,
    this.onEdit,
    this.meta,
  });

  final CatalogueArticle article;
  final String label;
  final bool inList;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final String? meta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onEdit = this.onEdit;
    final meta = this.meta;

    return Semantics(
      container: true,
      button: true,
      label: label,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        excludeFromSemantics: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: KadiSpacing.rowMinHeight,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: KadiSpacing.margin),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Picto(
                    pictoKey: article.pictoKey,
                    rayon: article.rayon,
                  ),
                ),
                const SizedBox(width: KadiSpacing.s4),
                Expanded(
                  child: ExcludeSemantics(
                    child: Padding(
                      // Le crayon fait 48 dp : la ligne garde sa hauteur.
                      padding: const EdgeInsets.symmetric(
                        vertical: KadiSpacing.s2,
                      ),
                      child: Text(
                        article.name,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
                if (meta != null) ...[
                  const SizedBox(width: KadiSpacing.s3),
                  ExcludeSemantics(
                    child: Text(
                      meta,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
                if (inList && onEdit != null)
                  IconButton(
                    onPressed: onEdit,
                    tooltip: StringsFr.modifierNom(article.name),
                    icon: Icon(
                      Icons.edit_outlined,
                      color: scheme.onSurfaceVariant,
                    ),
                  )
                else
                  const SizedBox(width: KadiSpacing.s3),
                ExcludeSemantics(
                  child: InListIndicator(rayon: article.rayon, inList: inList),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ligne de fréquent : Picto, nom et indicateur d'état ; dans la liste, le
/// crayon [onEdit] ouvre la Feuille d'édition. Annoncée « Lait » hors
/// liste, « Lait, dans la liste » dans la liste. Sert aussi à la Ligne
/// saisie.
class FrequentRow extends StatelessWidget {
  const FrequentRow({
    super.key,
    required this.article,
    required this.inList,
    required this.onTap,
    this.onEdit,
  });

  final CatalogueArticle article;
  final bool inList;
  final VoidCallback onTap;

  /// Crayon, montré seulement dans la liste.
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) => _PanelRow(
    article: article,
    label: inList ? '${article.name}, ${StringsFr.dansLaListe}' : article.name,
    inList: inList,
    onTap: onTap,
    onEdit: onEdit,
  );
}

/// Ligne de résultat : Picto, nom, rayon et indicateur d'état ; dans la
/// liste, le crayon [onEdit]. Annoncée « Lait, Crèmerie », avec « dans la
/// liste » s'il y est.
class SearchResultRow extends StatelessWidget {
  const SearchResultRow({
    super.key,
    required this.article,
    required this.onTap,
    this.inList = false,
    this.onEdit,
  });

  final CatalogueArticle article;
  final bool inList;
  final VoidCallback onTap;

  /// Crayon, montré seulement dans la liste.
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) => _PanelRow(
    article: article,
    label: [
      article.name,
      article.rayon.spokenLabel,
      if (inList) StringsFr.dansLaListe,
    ].join(', '),
    inList: inList,
    onTap: onTap,
    onEdit: onEdit,
    meta: article.rayon.label,
  );
}
