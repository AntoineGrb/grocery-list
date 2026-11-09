import 'dart:io';

import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/core/ui/recipe_monogram.dart';
import 'package:material_ui/material_ui.dart';

import '../data/recettes_models.dart';
import 'recipe_photo_image.dart';

/// Ligne de recette de l'écran Recettes (README redesign 2a) : monogramme ou
/// photo, nom et nombre d'ingrédients, puis le bouton de sélection.
///
/// Un tap sur la ligne ouvre la Fiche recette ([onOpen]) ; le bouton
/// sélectionne ou désélectionne la recette pour la semaine ([onToggle]).
class RecipeRow extends StatelessWidget {
  const RecipeRow({
    super.key,
    required this.card,
    required this.onOpen,
    required this.onToggle,
    this.photo,
  });

  final RecipeCardItem card;
  final File? photo;
  final VoidCallback onOpen;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rayon = card.ingredientCount == 0 ? null : card.rayon;
    final monogram = RecipeMonogram(
      name: card.name,
      rayon: rayon,
      photo: photo == null
          ? null
          : RecipePhotoImage(
              file: photo!,
              height: MonogramSize.small.dimension,
              fallback: RecipeMonogram(name: card.name, rayon: rayon),
            ),
    );

    // TalkBack : la ligne est lue « Modifier … » et ouvre la fiche ; le
    // bouton de sélection reste un nœud à part.
    return Semantics(
      container: true,
      button: true,
      label:
          '${StringsFr.modifierRecette(card.name)}, '
          '${StringsFr.nIngredients(card.ingredientCount)}',
      onTap: onOpen,
      child: InkWell(
        onTap: onOpen,
        excludeFromSemantics: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: KadiSpacing.margin,
            vertical: KadiSpacing.s2,
          ),
          child: Row(
            children: [
              monogram,
              const SizedBox(width: 14),
              Expanded(
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.name,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          height: 22 / 16,
                          fontWeight: FontWeight.w500,
                          color: scheme.onSurface,
                        ),
                      ),
                      Text(
                        StringsFr.nIngredients(card.ingredientCount),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 13,
                          height: 18 / 13,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: KadiSpacing.s2),
              // Police système agrandie : au plus 40 % de la largeur, le
              // libellé entier, réduit seulement s'il n'y tient pas.
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.4,
                ),
                child: SelectButton(
                  name: card.name,
                  selected: card.selected,
                  onTap: onToggle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bouton de sélection d'une recette : « + Ajouter » en contour, ou
/// « ✓ Ajoutée » à l'encre (C6 : jamais d'argile pour un état).
class SelectButton extends StatelessWidget {
  const SelectButton({
    super.key,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = selected ? scheme.surface : scheme.onSurface;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: selected
          ? StringsFr.retirerDeLaSemaine(name)
          : StringsFr.ajouterALaSemaine(name),
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // Pilule de 40 dp dans une cible de 48.
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: KadiSpacing.s1),
          child: AnimatedContainer(
            key: const Key('recipe-select-button'),
            duration: duration,
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.fromLTRB(8, 0, 12, 0),
            decoration: BoxDecoration(
              color: selected ? scheme.onSurface : Colors.transparent,
              border: Border.all(
                color: selected ? scheme.onSurface : scheme.outline,
              ),
              borderRadius: BorderRadius.circular(KadiRadius.full),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    selected ? Icons.check : Icons.add,
                    size: 18,
                    color: foreground,
                  ),
                  const SizedBox(width: KadiSpacing.s1),
                  Text(
                    selected ? StringsFr.ajoutee : StringsFr.ajouter,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: foreground,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
