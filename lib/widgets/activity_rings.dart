import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import '../theme/app_colors.dart';

/// Apple-Health-style nested rings: money (outer), move (middle), rituals (inner).
/// Values are 0..1+ progress fractions; each ring fills clockwise from 12 o'clock.
class ActivityRings extends StatelessWidget {
  const ActivityRings({
    super.key,
    required this.values,
    this.size = 118,
    this.strokeWidth = 14,
    this.gap = 2,
  });

  final List<double> values; // [money, move, rituals]
  final double size;
  final double strokeWidth;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingsPainter(
          values: values,
          colors: [c.money, c.move, c.rituals],
          strokeWidth: strokeWidth,
          gap: gap,
        ),
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  _RingsPainter({
    required this.values,
    required this.colors,
    required this.strokeWidth,
    required this.gap,
  });

  final List<double> values;
  final List<Color> colors;
  final double strokeWidth;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (var i = 0; i < values.length; i++) {
      final r = size.width / 2 - strokeWidth / 2 - i * (strokeWidth + gap);
      if (r <= 0) continue;
      final rect = Rect.fromCircle(center: center, radius: r);

      // Track.
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..color = colors[i].withValues(alpha: 0.20),
      );

      // Progress arc, clockwise from top.
      final sweep = 2 * math.pi * values[i].clamp(0.0, 1.0);
      if (sweep > 0) {
        canvas.drawArc(
          rect,
          -math.pi / 2,
          sweep,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth
            ..strokeCap = StrokeCap.round
            ..color = colors[i],
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) =>
      old.values != values || old.colors != colors;
}
