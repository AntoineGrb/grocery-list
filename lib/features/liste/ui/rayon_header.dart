import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/core/ui/rayon_pastille.dart';
import 'package:material_ui/material_ui.dart';

/// En-tête de rayon : pastille (point + nom). Non interactif, annoncé comme
/// titre par son nom.
class RayonHeader extends StatelessWidget {
  const RayonHeader({super.key, required this.rayon});

  final Rayon rayon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: rayon.spokenLabel,
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
        child: Row(children: [Flexible(child: RayonPastille(rayon: rayon))]),
      ),
    );
  }
}
