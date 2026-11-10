import 'package:material_ui/material_ui.dart';

import '../strings/strings_fr.dart';
import '../theme/kadi_tokens.dart';

/// Éclair des fréquents (Paramètres › Articles) : vide par défaut, plein à
/// l'encre quand l'article est un fréquent (C6 : jamais d'argile pour un
/// état). Bouton bascule de 48 dp, lu « Fréquent » coché ou non.
class FrequentBolt extends StatelessWidget {
  const FrequentBolt({
    super.key,
    required this.name,
    required this.frequent,
    required this.onTap,
  });

  /// Nom de l'article, pour TalkBack.
  final String name;
  final bool frequent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      button: true,
      toggled: frequent,
      label: StringsFr.frequentDe(name),
      excludeSemantics: true,
      onTap: onTap,
      child: InkResponse(
        onTap: onTap,
        radius: KadiSpacing.touchTarget / 2,
        child: SizedBox.square(
          dimension: KadiSpacing.touchTarget,
          child: Center(
            child: CustomPaint(
              size: const Size.square(22),
              painter: BoltPainter(
                color: frequent ? scheme.onSurface : scheme.onSurfaceVariant,
                filled: frequent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Éclair dessiné dans son carré : plein ([filled]) ou en contour de 1,6.
class BoltPainter extends CustomPainter {
  const BoltPainter({required this.color, required this.filled});

  final Color color;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width / 24;
    final h = size.height / 24;
    final path = Path()
      ..moveTo(13.5 * w, 2 * h)
      ..lineTo(4.5 * w, 13.5 * h)
      ..lineTo(11 * w, 13.5 * h)
      ..lineTo(10 * w, 22 * h)
      ..lineTo(19.5 * w, 10 * h)
      ..lineTo(13 * w, 10 * h)
      ..close();
    final paint = Paint()
      ..color = color
      ..isAntiAlias = true
      ..strokeJoin = StrokeJoin.round
      ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = 1.6 * w;
    canvas.drawPath(path, paint);
    if (filled) {
      canvas.drawPath(
        path,
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6 * w,
      );
    }
  }

  @override
  bool shouldRepaint(BoltPainter old) =>
      old.color != color || old.filled != filled;
}
