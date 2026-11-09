import 'package:go_router/go_router.dart';
import 'package:kadi/core/pictos/picto.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/router/app_router.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_colors.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/core/ui/picto_disc.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:kadi/features/catalogue/data/catalogue_repository.dart';
import 'package:material_ui/material_ui.dart';

import '../data/liste_repository.dart';
import 'quantity_tag.dart';

/// Poignée fine du Panneau + : le glissement se joue sur toute la feuille, et
/// TalkBack ferme par la barrière ; elle n'est donc pas lue.
class PanelHandle extends StatelessWidget {
  const PanelHandle({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExcludeSemantics(
      child: SizedBox(
        height: KadiSpacing.panelHandleHeight,
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.bottomSheetTheme.dragHandleColor,
              borderRadius: const BorderRadius.all(
                Radius.circular(KadiRadius.full),
              ),
            ),
            child: const SizedBox(
              width: KadiSpacing.panelHandleWidth,
              height: KadiSpacing.panelHandleThickness,
            ),
          ),
        ),
      ),
    );
  }
}

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

/// Titre de la section des fréquents du Panneau + : « Ajouts fréquents »,
/// annoncé comme titre, et un bouton « Gérer » à droite, lu « Gérer les ajouts
/// fréquents », qui ferme le panneau puis pousse Paramètres › Fréquents ; au
/// retour, la Liste est affichée, panneau fermé. Un tap sur le titre ferme
/// le clavier, pour voir les fréquents.
class FrequentsTitle extends StatelessWidget {
  const FrequentsTitle({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      // Le texte du bouton s'aligne sur la fin des indicateurs des lignes.
      padding: const EdgeInsetsDirectional.only(
        start: KadiSpacing.margin + KadiSpacing.s1,
        end: KadiSpacing.margin - KadiSpacing.s3,
        top: KadiSpacing.s3,
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: KadiSpacing.touchTarget,
                ),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Semantics(
                    header: true,
                    label: StringsFr.ajoutsFrequents,
                    excludeSemantics: true,
                    child: Text(
                      StringsFr.ajoutsFrequents,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              // Le panneau est la feuille du dessus, sur le navigateur racine :
              // il se ferme, puis l'écran est poussé au-dessus de la Liste.
              final router = GoRouter.of(context);
              Navigator.pop(context);
              router.push(AppRoutes.frequents);
            },
            style: TextButton.styleFrom(
              foregroundColor: scheme.onSurfaceVariant,
              padding: const EdgeInsets.symmetric(horizontal: KadiSpacing.s3),
              minimumSize: const Size(
                KadiSpacing.touchTarget,
                KadiSpacing.touchTarget,
              ),
            ),
            child: const Text(
              StringsFr.gerer,
              semanticsLabel: StringsFr.gererLesAjoutsFrequents,
            ),
          ),
        ],
      ),
    );
  }
}

/// Indicateur d'état à droite d'une ligne du Panneau + : coche ronde pleine à
/// l'accent du rayon dans la liste, signe + en `on-surface-variant` hors liste.
class InListIndicator extends StatelessWidget {
  const InListIndicator({super.key, required this.rayon, required this.inList});

  final Rayon rayon;
  final bool inList;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return inList
        ? Container(
            width: KadiSpacing.picto,
            height: KadiSpacing.picto,
            decoration: BoxDecoration(
              color: KadiColors.of(context).rayon(rayon).accent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check,
              color: scheme.surface,
              size: KadiSpacing.s4,
            ),
          )
        : Icon(Icons.add, color: scheme.onSurfaceVariant);
  }
}

/// Ligne du Panneau + : Picto, nom et indicateur d'état ; dans la liste, le tag
/// quantité de [line] à gauche de la coche.
///
/// La ligne est un bouton lu [label] ; le tag, cible de 48 dp, est un bouton à
/// part, lu « Quantité de Lait, 500 g ».
class _PanelRow extends StatelessWidget {
  const _PanelRow({
    required this.article,
    required this.label,
    required this.inList,
    required this.onTap,
    this.line,
    this.onQuantityTap,
  });

  final CatalogueArticle article;
  final String label;
  final bool inList;
  final VoidCallback onTap;
  final ListeItem? line;
  final ValueChanged<ListeItem>? onQuantityTap;

  Widget _lineTag(ListeItem line, ValueChanged<ListeItem> onQuantityTap) {
    final value = formatQuantity(line.quantity, line.unit);
    return PanelQuantityTag(
      value: value,
      emptyLabel: StringsFr.qte,
      semanticLabel: StringsFr.quantiteDe(article.name, value),
      onTap: () => onQuantityTap(line),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final line = this.line;
    final onQuantityTap = this.onQuantityTap;

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
                  child: PictoDisc(
                    pictoKey: article.pictoKey,
                    rayon: article.rayon,
                  ),
                ),
                const SizedBox(width: KadiSpacing.s3),
                Expanded(
                  child: ExcludeSemantics(
                    child: Padding(
                      // Le tag fait 48 dp : la ligne garde sa hauteur.
                      padding: const EdgeInsets.symmetric(
                        vertical: KadiSpacing.s1,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            article.name,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              height: 20 / 16,
                              color: scheme.onSurface,
                            ),
                          ),
                          Text(
                            article.rayon.label,
                            style: theme.textTheme.bodySmall?.copyWith(
                              height: 16 / 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (inList && line != null && onQuantityTap != null)
                  // Sa largeur seule, jusqu'à la limite : le nom garde le reste.
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: KadiSpacing.tagMaxWidth,
                    ),
                    child: _lineTag(line, onQuantityTap),
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

/// Ligne de résultat du Panneau + : disque picto, nom et rayon dessous,
/// indicateur d'état ; dans la liste, le tag quantité de [line].
/// Annoncée « Lait, Crèmerie », avec « dans la liste » s'il y est.
class SearchResultRow extends StatelessWidget {
  const SearchResultRow({
    super.key,
    required this.article,
    required this.onTap,
    this.inList = false,
    this.line,
    this.onQuantityTap,
  });

  final CatalogueArticle article;
  final bool inList;
  final VoidCallback onTap;

  /// Plus ancienne ligne non cochée de l'article.
  final ListeItem? line;

  /// Tag quantité, montré seulement dans la liste.
  final ValueChanged<ListeItem>? onQuantityTap;

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
    line: line,
    onQuantityTap: onQuantityTap,
  );
}

/// Pastille de fréquent (V2 2g) : 36 dp, rayon plein ; picto à l'accent du
/// rayon, nom, puis + ; dans la liste, fond encre, texte et picto `surface`
/// et ✓. Un tap l'ajoute, ou la retire avec Annuler si elle y est.
/// Annoncée « Lait », ou « Lait, dans la liste ».
class FrequentChip extends StatelessWidget {
  const FrequentChip({
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
    final scheme = theme.colorScheme;
    final foreground = inList ? scheme.surface : scheme.onSurface;
    final accent = KadiColors.of(context).rayon(article.rayon).accent;
    const shape = StadiumBorder();
    return Semantics(
      container: true,
      button: true,
      label: inList
          ? '${article.name}, ${StringsFr.dansLaListe}'
          : article.name,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: onTap,
        // Pastille de 36 dp dans une cible de 48.
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Material(
            color: inList ? scheme.onSurface : scheme.surface,
            shape: shape,
            child: InkWell(
              onTap: onTap,
              excludeFromSemantics: true,
              customBorder: shape,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 36),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        PictoResolver.iconFor(article.pictoKey, article.rayon),
                        size: 18,
                        color: inList ? scheme.surface : accent,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          article.name,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: foreground,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        inList ? Icons.check : Icons.add,
                        size: 16,
                        color: foreground.withValues(alpha: 0.7),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
