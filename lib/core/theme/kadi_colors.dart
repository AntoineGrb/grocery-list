import 'package:material_ui/material_ui.dart';

import '../rayons/rayon.dart';
import 'kadi_tokens.dart';

/// Couleurs d'un rayon : accent (point, case, picto) et fond de pastille.
class RayonColors {
  const RayonColors({required this.accent, required this.pastille});
  final Color accent;
  final Color pastille;
}

/// Couleurs propres à Kadi, hors rôles M3 : rayons et texte coché (AD-12).
class KadiColors extends ThemeExtension<KadiColors> {
  const KadiColors({required this.checked, required this.rayons});

  factory KadiColors.fromPalette(KadiPalette p) => KadiColors(
    checked: p.checked,
    rayons: {
      for (final r in Rayon.values)
        r: RayonColors(
          accent: p.rayonAccents[r]!,
          pastille: p.rayonPastilles[r]!,
        ),
    },
  );

  final Color checked;
  final Map<Rayon, RayonColors> rayons;

  RayonColors rayon(Rayon r) => rayons[r]!;

  static KadiColors of(BuildContext context) =>
      Theme.of(context).extension<KadiColors>()!;

  @override
  KadiColors copyWith({Color? checked, Map<Rayon, RayonColors>? rayons}) =>
      KadiColors(
        checked: checked ?? this.checked,
        rayons: rayons ?? this.rayons,
      );

  @override
  KadiColors lerp(covariant KadiColors? other, double t) {
    if (other == null) return this;
    return KadiColors(
      checked: Color.lerp(checked, other.checked, t)!,
      rayons: {
        for (final r in Rayon.values)
          r: RayonColors(
            accent: Color.lerp(rayon(r).accent, other.rayon(r).accent, t)!,
            pastille: Color.lerp(
              rayon(r).pastille,
              other.rayon(r).pastille,
              t,
            )!,
          ),
      },
    );
  }
}
