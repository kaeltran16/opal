import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import '../theme/theme.dart';

/// A single-arc progress ring: a faint track circle with a colored arc that
/// fills clockwise from 12 o'clock by [progress] (clamped to one full turn).
/// An optional [child] is centered inside. Static — no animation.
class SpendRing extends StatelessWidget {
  const SpendRing({
    super.key,
    required this.progress,
    required this.color,
    this.trackColor,
    this.over = false,
    this.size = 64,
    this.stroke = 7,
    this.child,
  });

  /// 0..1+ spend fraction; the arc fills up to one full turn (clamped at 1.0).
  final double progress;

  /// Arc color when on budget.
  final Color color;

  /// Track (unfilled) color; defaults to [color] at 13% opacity.
  final Color? trackColor;

  /// When true the arc uses the theme's red (over budget).
  final bool over;

  final double size;
  final double stroke;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _SpendRingPainter(
              progress: progress,
              color: over ? c.red : color,
              trackColor: trackColor ?? color.withValues(alpha: 0.13),
              stroke: stroke,
            ),
          ),
          ?child,
        ],
      ),
    );
  }
}

class _SpendRingPainter extends CustomPainter {
  _SpendRingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.stroke,
  });

  final double progress;
  final Color color;
  final Color trackColor;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - stroke / 2;
    if (r <= 0) return;

    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = trackColor,
    );

    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    if (sweep > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_SpendRingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.stroke != stroke;
}
