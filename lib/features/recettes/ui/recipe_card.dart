import 'dart:io';

import 'package:kadi/core/pictos/picto.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../data/recettes_repository.dart';
import 'recipe_photo_image.dart';

/// Carte recette (DESIGN `recipe-card`) : la photo, recadrée sur toute la
/// zone visuelle, ou à défaut (sans photo, fichier absent ou illisible) le
/// visuel de repli (Picto de l'ingrédient principal, 44 dp, sur `surface`) ;
/// nom en `title-medium`, sur `surface-container`. Sélectionnée : bordure
/// 2 dp et pastille de 26 dp en `on-surface` avec une coche `surface`, en
/// haut à gauche ; jamais d'argile.
///
/// Le nom n'est jamais tronqué : la carte grandit avec la police système.
/// Annoncée « Chili con carne, sélectionnée » ou « …, non sélectionnée ».
///
/// Icône « modifier » discrète en haut à droite du visuel, cible de 48 dp,
/// lue « Modifier Chili con carne » : elle ouvre la Fiche recette ([onEdit])
/// sans changer la sélection ; un tap ailleurs sur la carte sélectionne.
class RecipeCard extends StatelessWidget {
  const RecipeCard({
    super.key,
    required this.card,
    required this.onTap,
    required this.onEdit,
    this.photo,
  });

  final RecipeCardItem card;

  /// Fichier de la photo de la recette, nul sans photo (ou tant que le
  /// dossier des photos n'est pas lu).
  final File? photo;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const radius = BorderRadius.all(Radius.circular(KadiRadius.md));
    final fallback = Center(
      child: Picto(
        pictoKey: card.pictoKey,
        rayon: card.rayon,
        size: KadiSpacing.recipePicto,
      ),
    );
    final photo = this.photo;

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
                child: photo == null
                    ? fallback
                    : RecipePhotoImage(
                        file: photo,
                        height: KadiSpacing.recipeVisualHeight,
                        fallback: fallback,
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

    // Les contraintes de la rangée passent telles quelles à la carte : deux
    // cartes d'une rangée ont la même hauteur.
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Semantics(
          container: true,
          button: true,
          label: StringsFr.recetteSelectionnee(
            card.name,
            selected: card.selected,
          ),
          onTap: onTap,
          excludeSemantics: true,
          child: content,
        ),
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
        // Icône « modifier » : en haut à droite du visuel, 48 dp, lue à
        // part ; elle ouvre la fiche sans toucher à la sélection. Sur une
        // photo, une pastille `surface` la garde lisible.
        PositionedDirectional(
          top: 0,
          end: 0,
          child: IconButton(
            tooltip: StringsFr.modifierRecette(card.name),
            style: IconButton.styleFrom(
              minimumSize: const Size.square(KadiSpacing.touchTarget),
              backgroundColor: photo == null
                  ? null
                  : scheme.surface.withValues(alpha: 0.8),
            ),
            onPressed: onEdit,
            icon: Icon(Icons.edit_outlined, color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
