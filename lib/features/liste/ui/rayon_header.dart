import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/core/ui/rayon_pastille.dart';
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
            RayonPastille(rayon: rayon),
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
