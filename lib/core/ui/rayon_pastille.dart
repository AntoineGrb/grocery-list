import 'package:material_ui/material_ui.dart';

import '../rayons/rayon.dart';
import '../theme/kadi_colors.dart';
import '../theme/kadi_tokens.dart';

/// Pastille d'un rayon : point d'accent et nom, sur le fond de pastille du
/// rayon. Rendu commun de l'En-tête de rayon et du Choix de rayon ; une
/// [border] entoure le rayon choisi.
class RayonPastille extends StatelessWidget {
  const RayonPastille({super.key, required this.rayon, this.border});

  final Rayon rayon;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = KadiColors.of(context).rayon(rayon);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.pastille,
        borderRadius: BorderRadius.circular(KadiRadius.full),
        border: border,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: KadiSpacing.s3,
          vertical: KadiSpacing.s1 + 2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: KadiSpacing.rayonDot,
              height: KadiSpacing.rayonDot,
              decoration: BoxDecoration(
                color: colors.accent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: KadiSpacing.s2),
            // En très grande police, le nom passe à la ligne sans déborder.
            Flexible(
              child: Text(
                rayon.label,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
