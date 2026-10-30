import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/core/ui/rayon_pastille.dart';
import 'package:material_ui/material_ui.dart';

/// En-tête de rayon : pastille (point + nom), sans compteur. Non
/// interactif, annoncé comme titre par son seul nom : « Crèmerie ».
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
          KadiSpacing.s4,
          KadiSpacing.margin,
          KadiSpacing.s1,
        ),
        child: Row(children: [RayonPastille(rayon: rayon)]),
      ),
    );
  }
}
