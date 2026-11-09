import 'dart:ui' show PathMetric;

import 'package:material_ui/material_ui.dart';

/// Bordure pointillée (tag balance, ligne de création d'ingrédient) : Flutter
/// n'en a pas en natif. Rectangle arrondi de [radius], ou cercle si [circle].
class DashedBorder extends StatelessWidget {
  const DashedBorder({
    super.key,
    required this.color,
    required this.child,
    this.radius = 0,
    this.circle = false,
    this.strokeWidth = 1.5,
    this.dash = 3,
    this.gap = 2.5,
  });

  final Color color;
  final Widget child;
  final double radius;
  final bool circle;
  final double strokeWidth;
  final double dash;
  final double gap;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _DashedPainter(
      color: color,
      radius: radius,
      circle: circle,
      strokeWidth: strokeWidth,
      dash: dash,
      gap: gap,
    ),
    child: child,
  );
}

class _DashedPainter extends CustomPainter {
  const _DashedPainter({
    required this.color,
    required this.radius,
    required this.circle,
    required this.strokeWidth,
    required this.dash,
    required this.gap,
  });

  final Color color;
  final double radius;
  final bool circle;
  final double strokeWidth;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(strokeWidth / 2);
    final path = Path();
    if (circle) {
      path.addOval(rect);
    } else {
      path.addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    }
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    for (final PathMetric metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.circle != circle ||
      old.strokeWidth != strokeWidth ||
      old.dash != dash ||
      old.gap != gap;
}
