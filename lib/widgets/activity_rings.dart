import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import '../theme/app_colors.dart';

/// Apple-Health-style nested rings: money (outer), move (middle), rituals (inner).
/// Values are 0..1+ progress fractions; each ring fills clockwise from 12 o'clock.
///
/// On first appear the rings animate 0 → current over 800ms ease-out, staggered
/// 60ms per ring (handoff "Activity ring animation"). Later value changes snap.
class ActivityRings extends StatefulWidget {
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
  State<ActivityRings> createState() => _ActivityRingsState();
}

class _ActivityRingsState extends State<ActivityRings>
    with SingleTickerProviderStateMixin {
  static const _fill = Duration(milliseconds: 800);
  static const _stagger = Duration(milliseconds: 60);

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    final n = widget.values.length;
    final total = _fill + _stagger * (n > 0 ? n - 1 : 0);
    _controller = AnimationController(vsync: this, duration: total)..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Eased 0..1 progress for ring [i], offset by its stagger window.
  double _fraction(int i, double t) {
    final total = _controller.duration!.inMilliseconds;
    final start = (_stagger.inMilliseconds * i) / total;
    final end = start + _fill.inMilliseconds / total;
    final local = ((t - start) / (end - start)).clamp(0.0, 1.0);
    return Curves.easeOut.transform(local);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pct = [
      for (final v in widget.values) (v.clamp(0.0, 1.0) * 100).round(),
    ];
    final label = pct.length == 3
        ? 'Activity rings: money ${pct[0]}%, move ${pct[1]}%, rituals ${pct[2]}%'
        : 'Activity rings';
    return Semantics(
      label: label,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            final animated = [
              for (var i = 0; i < widget.values.length; i++)
                widget.values[i] * _fraction(i, t),
            ];
            return CustomPaint(
              painter: _RingsPainter(
                values: animated,
                colors: [c.money, c.move, c.rituals],
                strokeWidth: widget.strokeWidth,
                gap: widget.gap,
              ),
            );
          },
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
