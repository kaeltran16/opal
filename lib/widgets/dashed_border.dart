import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

/// A rounded box with a dashed border, painted via [CustomPaint] (Flutter has
/// no built-in dashed border). Optionally fills the interior with [fillColor].
class DottedBorderBox extends StatelessWidget {
  const DottedBorderBox({
    super.key,
    required this.child,
    required this.color,
    this.fillColor,
    this.strokeWidth = 1,
    this.radius = Radii.md,
  });

  final Widget child;

  /// Dashed stroke color.
  final Color color;

  /// Optional solid fill painted behind the dashed stroke.
  final Color? fillColor;
  final double strokeWidth;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: color,
        fillColor: fillColor,
        strokeWidth: strokeWidth,
        radius: radius,
      ),
      child: child,
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({
    required this.color,
    required this.fillColor,
    required this.strokeWidth,
    required this.radius,
  });

  final Color color;
  final Color? fillColor;
  final double strokeWidth;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    final fill = fillColor;
    if (fill != null) {
      canvas.drawRRect(rrect, Paint()..color = fill);
    }

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    final path = Path()..addRRect(rrect);

    const dash = 5.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dash),
          paint,
        );
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color ||
      old.fillColor != fillColor ||
      old.strokeWidth != strokeWidth ||
      old.radius != radius;
}
