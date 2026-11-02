import 'package:material_ui/material_ui.dart';

import '../theme/kadi_tokens.dart';

/// Coche ronde de 24 dp au lieu des 18 dp de la case M3.
const _checkScale = KadiSpacing.picto / Checkbox.width;

/// Coche ronde de la Ligne d'article et de la Ligne de Revue : case M3 en
/// cercle de 24 dp à l'accent [accent], dans une cible de 48 dp. Un tap
/// appelle [onChanged].
class RoundCheck extends StatelessWidget {
  const RoundCheck({
    super.key,
    required this.value,
    required this.onChanged,
    required this.accent,
  });

  final bool value;
  final VoidCallback onChanged;

  /// Accent du rayon de la ligne : contour, fond coché et halo.
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: KadiSpacing.touchTarget,
      child: Transform.scale(
        scale: _checkScale,
        child: Checkbox(
          value: value,
          onChanged: (_) => onChanged(),
          shape: const CircleBorder(),
          activeColor: accent,
          checkColor: Theme.of(context).colorScheme.surface,
          // Tailles d'avant l'échelle : contour de 2 dp, halo de 48 dp, à
          // l'accent du rayon et jamais en argile (C6).
          side: BorderSide(color: accent, width: 2 / _checkScale),
          splashRadius: KadiSpacing.touchTarget / 2 / _checkScale,
          overlayColor: WidgetStatePropertyAll(accent.withValues(alpha: 0.12)),
        ),
      ),
    );
  }
}
