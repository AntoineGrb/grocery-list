import 'package:kadi/core/pictos/picto.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_colors.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
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
/// fréquents ». Il mènera à Paramètres › Fréquents (epic 3) ; d'ici là, il ne
/// fait rien.
class FrequentsTitle extends StatelessWidget {
  const FrequentsTitle({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      // Le texte du bouton s'aligne sur la fin des indicateurs des lignes.
      padding: const EdgeInsetsDirectional.only(
        start: KadiSpacing.margin,
        end: KadiSpacing.margin - KadiSpacing.s3,
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              label: StringsFr.ajoutsFrequents,
              excludeSemantics: true,
              child: Text(
                StringsFr.ajoutsFrequents,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          TextButton(
            // Sans action avant l'epic 3, mais un bouton actif.
            onPressed: () {},
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

/// Facteur de police au-delà duquel le rayon d'une ligne passe sous son nom.
const _inlineMetaMaxTextScale = 1.2;

/// Ligne du Panneau + : Picto, nom, [meta] facultatif et indicateur d'état ;
/// dans la liste, le tag quantité de [line] à gauche de la coche.
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
    this.meta,
  });

  final CatalogueArticle article;
  final String label;
  final bool inList;
  final VoidCallback onTap;
  final ListeItem? line;
  final ValueChanged<ListeItem>? onQuantityTap;
  final String? meta;

  Widget _lineTag(ListeItem line, ValueChanged<ListeItem> onQuantityTap) {
    final value = formatQuantity(line.quantity, line.unit);
    return QuantityTag(
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
    final meta = this.meta;
    // En grande police, tout ne tient plus sur une ligne : le rayon passe sous
    // le nom, et rien ne déborde.
    final large =
        MediaQuery.textScalerOf(context).scale(1) > _inlineMetaMaxTextScale;
    final metaText = meta == null
        ? null
        : Text(
            meta,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          );

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
                      // Le tag fait 48 dp : la ligne garde sa hauteur.
                      padding: const EdgeInsets.symmetric(
                        vertical: KadiSpacing.s2,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            article.name,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: scheme.onSurface,
                            ),
                          ),
                          if (large) ?metaText,
                        ],
                      ),
                    ),
                  ),
                ),
                if (metaText != null && !large) ...[
                  const SizedBox(width: KadiSpacing.s3),
                  ExcludeSemantics(child: metaText),
                ],
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

/// Ligne de fréquent : Picto, nom et indicateur d'état ; dans la liste, le
/// tag quantité de [line]. Annoncée « Lait » hors liste, « Lait, dans la
/// liste » dans la liste.
class FrequentRow extends StatelessWidget {
  const FrequentRow({
    super.key,
    required this.article,
    required this.inList,
    required this.onTap,
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
    label: inList ? '${article.name}, ${StringsFr.dansLaListe}' : article.name,
    inList: inList,
    onTap: onTap,
    line: line,
    onQuantityTap: onQuantityTap,
  );
}

/// Ligne de résultat : Picto, nom, rayon et indicateur d'état ; dans la
/// liste, le tag quantité de [line]. Annoncée « Lait, Crèmerie », avec « dans
/// la liste » s'il y est.
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
    meta: article.rayon.label,
  );
}
