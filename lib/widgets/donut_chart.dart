import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../controllers/insights_money_controller.dart';
import '../theme/theme.dart';

/// A category-share donut: consecutive thick-stroke arcs (one per category,
/// sweep ∝ fraction) starting at 12 o'clock — the faithful equivalent of the
/// design's CSS conic-gradient ring. [center] is overlaid in the hole.
class CategoryDonut extends StatelessWidget {
  const CategoryDonut({
    super.key,
    required this.categories,
    required this.center,
    this.size = 132,
    this.stroke = 18,
  });

  final List<CategoryInsight> categories;
  final Widget center;
  final double size;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final segments = [
      for (final cat in categories)
        (color: c.forType(cat.colorToken), fraction: cat.fraction),
    ];
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: DonutPainter(
              segments: segments,
              stroke: stroke,
              trackColor: c.fill,
            ),
          ),
          center,
        ],
      ),
    );
  }
}

/// Draws consecutive arc segments around a ring. Each segment sweeps
/// `fraction * 2π` clockwise from -π/2 (12 o'clock), butted end-to-end.
class DonutPainter extends CustomPainter {
  DonutPainter({
    required this.segments,
    required this.stroke,
    required this.trackColor,
  });

  final List<({Color color, double fraction})> segments;
  final double stroke;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - stroke / 2;
    if (r <= 0) return;
    final rect = Rect.fromCircle(center: center, radius: r);

    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = trackColor,
    );

    var start = -math.pi / 2;
    for (final seg in segments) {
      final sweep = seg.fraction.clamp(0.0, 1.0) * 2 * math.pi;
      if (sweep <= 0) continue;
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = seg.color,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(DonutPainter old) =>
      old.stroke != stroke ||
      old.trackColor != trackColor ||
      !_sameSegments(old.segments, segments);

  static bool _sameSegments(
    List<({Color color, double fraction})> a,
    List<({Color color, double fraction})> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].color != b[i].color || a[i].fraction != b[i].fraction) {
        return false;
      }
    }
    return true;
  }
}
