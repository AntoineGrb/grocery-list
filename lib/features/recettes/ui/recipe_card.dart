import 'package:kadi/core/pictos/picto.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../data/recettes_repository.dart';

/// Carte recette (DESIGN `recipe-card`) : visuel de repli (Picto de
/// l'ingrédient principal, 44 dp, sur `surface`) et nom en `title-medium`,
/// sur `surface-container`. Sélectionnée : bordure 2 dp et pastille de 26 dp
/// en `on-surface` avec une coche `surface`, en haut à gauche ; jamais
/// d'argile.
///
/// Le nom n'est jamais tronqué : la carte grandit avec la police système.
/// Annoncée « Chili con carne, sélectionnée » ou « …, non sélectionnée ».
class RecipeCard extends StatelessWidget {
  const RecipeCard({super.key, required this.card, required this.onTap});

  final RecipeCardItem card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const radius = BorderRadius.all(Radius.circular(KadiRadius.md));

    final content = Material(
      color: scheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: card.selected
            ? BorderSide(color: scheme.onSurface, width: 2)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ColoredBox(
              color: scheme.surface,
              child: SizedBox(
                height: KadiSpacing.recipeVisualHeight,
                child: Center(
                  child: Picto(
                    pictoKey: card.pictoKey,
                    rayon: card.rayon,
                    size: KadiSpacing.recipePicto,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: KadiSpacing.recipeCaptionMinHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KadiSpacing.s3,
                    vertical: KadiSpacing.s2,
                  ),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      card.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Semantics(
      button: true,
      label: StringsFr.recetteSelectionnee(card.name, selected: card.selected),
      onTap: onTap,
      excludeSemantics: true,
      // Les contraintes de la rangée passent telles quelles à la carte : deux
      // cartes d'une rangée ont la même hauteur.
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          content,
          if (card.selected)
            Positioned(
              top: KadiSpacing.s2,
              left: KadiSpacing.s2,
              child: IgnorePointer(
                child: Container(
                  width: KadiSpacing.recipeMark,
                  height: KadiSpacing.recipeMark,
                  decoration: BoxDecoration(
                    color: scheme.onSurface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: scheme.surface,
                      width: 2,
                      strokeAlign: BorderSide.strokeAlignOutside,
                    ),
                  ),
                  child: Icon(Icons.check, size: 18, color: scheme.surface),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
