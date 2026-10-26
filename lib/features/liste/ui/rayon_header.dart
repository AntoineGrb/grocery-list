import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_colors.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// En-tête de rayon : pastille (point + nom) et compteur. Non interactif,
/// annoncé comme titre : « Crèmerie, 1 article ».
class RayonHeader extends StatelessWidget {
  const RayonHeader({super.key, required this.rayon, this.count});

  final Rayon rayon;

  /// Compteur à droite ; absent dans le Panneau +.
  final int? count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = KadiColors.of(context).rayon(rayon);
    final count = this.count;
    final spoken = count == null
        ? rayon.spokenLabel
        : '${rayon.spokenLabel}, ${StringsFr.articles(count)}';

    return Semantics(
      header: true,
      label: spoken,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          KadiSpacing.margin,
          KadiSpacing.s4,
          KadiSpacing.margin,
          KadiSpacing.s1,
        ),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.pastille,
                borderRadius: BorderRadius.circular(KadiRadius.full),
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
                    Text(
                      rayon.label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            if (count != null)
              Text(
                '$count',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
