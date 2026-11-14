import 'dart:io';
import 'dart:math' as math;

import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_colors.dart';
import 'package:kadi/core/theme/kadi_theme.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../data/recettes_models.dart';
import 'recipe_photo_image.dart';

/// Tuile de recette de la vue grille de Recettes : fond rayé à la pastille
/// du rayon de l'ingrédient principal, un grand disque à son accent posé
/// dans un coin, le nom en bas à gauche et le bouton rond de sélection en
/// bas à droite. Une photo remplace le fond, assombrie en bas pour le nom.
///
/// Un tap sur la tuile ouvre la Fiche recette ([onOpen]) ; le bouton
/// sélectionne ou désélectionne la recette pour la semaine ([onToggle]).
class RecipeTile extends StatelessWidget {
  const RecipeTile({
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
    final scheme = Theme.of(context).colorScheme;
    final rayon = card.ingredientCount == 0 ? null : card.rayon;
    final colors = rayon == null ? null : KadiColors.of(context).rayon(rayon);
    final background = colors?.pastille ?? scheme.surfaceContainerHigh;
    final accent = colors?.accent ?? scheme.outlineVariant;
    final pattern = _Pattern(
      background: background,
      accent: accent,
      corner: _corner(card.recipeId),
    );
    final radius = BorderRadius.circular(KadiRadius.card);

    // TalkBack : la tuile est lue « Modifier … » et ouvre la fiche ; le
    // bouton de sélection reste un nœud à part.
    return Semantics(
      container: true,
      button: true,
      label:
          '${StringsFr.modifierRecette(card.name)}, '
          '${StringsFr.nIngredients(card.ingredientCount)}',
      onTap: onOpen,
      child: ClipRRect(
        borderRadius: radius,
        child: Material(
          color: background,
          child: InkWell(
            onTap: onOpen,
            excludeFromSemantics: true,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final hasPhoto = photo != null;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    if (hasPhoto) ...[
                      RecipePhotoImage(
                        file: photo!,
                        height: constraints.maxHeight,
                        fallback: pattern,
                      ),
                      // Dégradé du bas : le nom reste lisible sur la photo.
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: [0.45, 1],
                            colors: [Color(0x00000000), Color(0x99000000)],
                          ),
                        ),
                      ),
                    ] else
                      pattern,
                    Positioned(
                      left: KadiSpacing.s3,
                      // Place pour le bouton rond à droite.
                      right: KadiSpacing.touchTarget,
                      bottom: KadiSpacing.s3,
                      child: ExcludeSemantics(
                        child: Text(
                          card.name,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: KadiText.tileName.copyWith(
                            color: hasPhoto ? Colors.white : scheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: _RoundSelectButton(
                        name: card.name,
                        selected: card.selected,
                        onTap: onToggle,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Coin du disque, stable pour une recette : les tuiles voisines varient.
  static Alignment _corner(String recipeId) {
    var hash = 0;
    for (final unit in recipeId.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    const corners = [
      Alignment.bottomRight,
      Alignment.bottomLeft,
      Alignment.topRight,
      Alignment.topLeft,
    ];
    return corners[hash % corners.length];
  }
}

/// Fond de la tuile sans photo : rayures en biais et grand disque.
class _Pattern extends StatelessWidget {
  const _Pattern({
    required this.background,
    required this.accent,
    required this.corner,
  });

  final Color background;
  final Color accent;
  final Alignment corner;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      painter: _PatternPainter(
        background: background,
        accent: accent,
        corner: corner,
      ),
      child: const SizedBox.expand(),
    ),
  );
}

class _PatternPainter extends CustomPainter {
  const _PatternPainter({
    required this.background,
    required this.accent,
    required this.corner,
  });

  final Color background;
  final Color accent;
  final Alignment corner;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);

    // Rayures à 45°, accent très léger.
    final stripe = Paint()
      ..color = accent.withValues(alpha: 0.14)
      ..strokeWidth = 7;
    const gap = 18.0;
    final span = size.width + size.height;
    for (var x = -size.height; x < span; x += gap) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        stripe,
      );
    }

    // Disque : centré un peu à l'intérieur du coin, il déborde de la tuile.
    final diameter = math.min(size.width, size.height) * 0.6;
    final inset = diameter * 0.15;
    final center = Offset(
      corner.x > 0 ? size.width - inset : inset,
      corner.y > 0 ? size.height - inset : inset,
    );
    canvas.drawCircle(center, diameter / 2, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(_PatternPainter old) =>
      old.background != background ||
      old.accent != accent ||
      old.corner != corner;
}

/// Bouton rond de sélection de la tuile : « + » sur fond `surface`, ou
/// « ✓ » à l'encre (C6 : jamais d'argile pour un état). Rond de 32 dp dans
/// une cible de 48.
class _RoundSelectButton extends StatelessWidget {
  const _RoundSelectButton({
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
        child: SizedBox.square(
          dimension: KadiSpacing.touchTarget,
          child: Center(
            child: AnimatedContainer(
              key: const Key('recipe-tile-select-button'),
              duration: duration,
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: selected ? scheme.onSurface : scheme.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                selected ? Icons.check : Icons.add,
                size: 20,
                color: selected ? scheme.surface : scheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
