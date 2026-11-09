import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/core/ui/rayon_pastille.dart';
import 'package:material_ui/material_ui.dart';

/// En-tête de rayon : pastille (point + nom) et, à droite, le nombre
/// d'articles restants ([count], V2 2e). Non interactif, annoncé comme titre
/// par son nom, suivi du nombre.
class RayonHeader extends StatelessWidget {
  const RayonHeader({super.key, required this.rayon, this.count});

  final Rayon rayon;

  /// Articles restants du rayon ; nul : pas de compteur.
  final int? count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = this.count;
    return Semantics(
      header: true,
      label: count == null ? rayon.spokenLabel : '${rayon.spokenLabel}, $count',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          KadiSpacing.margin,
          14,
          KadiSpacing.margin,
          2,
        ),
        // Flexible : en très grande police, le nom passe à la ligne dans la
        // pastille au lieu de déborder.
        child: Row(
          children: [
            Flexible(child: RayonPastille(rayon: rayon)),
            if (count != null) ...[
              const Spacer(),
              Text(
                '$count',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
