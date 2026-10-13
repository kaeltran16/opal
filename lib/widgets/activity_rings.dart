import 'dart:math' as math;
import 'package:flutter/foundation.dart' show immutable, listEquals;
import 'package:flutter/widgets.dart';

/// The track is the ring's own colour at this alpha.
const double _trackAlpha = 0.2;

/// One ring: how far it is filled (0..1+, capped at one turn) and its colour.
@immutable
class ActivityRing {
  const ActivityRing({required this.fraction, required this.color});

  final double fraction;
  final Color color;
}

/// Apple-Health-style nested rings, each filling clockwise from 12 o'clock
/// over a track of its own colour. Ring `i` is drawn at `radii[i]`.
///
/// On first appear the rings animate 0 → current over 800ms ease-out, staggered
/// 60ms per ring (handoff "Activity ring animation"). Later value changes tween
/// from the previously shown value to the new one with the same eased, staggered
/// motion, so logging an entry fills the ring smoothly instead of snapping.
/// With reduce motion on, the rings draw their values at once.
///
/// Draws no semantics: the caller labels the rings with their numbers.
class ActivityRings extends StatefulWidget {
  const ActivityRings({
    super.key,
    required this.rings,
    required this.size,
    required this.strokeWidth,
    required this.radii,
  }) : assert(rings.length == radii.length);

  final List<ActivityRing> rings;
  final double size;
  final double strokeWidth;
  final List<double> radii;

  @override
  State<ActivityRings> createState() => _ActivityRingsState();
}

class _ActivityRingsState extends State<ActivityRings>
    with SingleTickerProviderStateMixin {
  static const _fill = Duration(milliseconds: 800);
  static const _stagger = Duration(milliseconds: 60);

  late final AnimationController _controller;

  // Endpoints of the current tween: the displayed value at the moment the
  // animation (re)started, and the target. Entrance starts from all-zero.
  late List<double> _from;
  late List<double> _to;

  List<double> get _targets => [for (final r in widget.rings) r.fraction];

  Duration _durationFor(int n) => _fill + _stagger * (n > 0 ? n - 1 : 0);

  @override
  void initState() {
    super.initState();
    _to = _targets;
    _from = List<double>.filled(_to.length, 0);
    _controller =
        AnimationController(vsync: this, duration: _durationFor(_to.length))
          ..forward();
  }

  @override
  void didUpdateWidget(ActivityRings old) {
    super.didUpdateWidget(old);
    final targets = _targets;
    if (listEquals(targets, _to)) return;
    // Tween from whatever is on screen right now to the new values, so an
    // in-flight animation hands off without a jump. A changed ring count is
    // a fresh fill.
    final t = _controller.value;
    _from = targets.length == _to.length
        ? [for (var i = 0; i < _to.length; i++) _display(i, t)]
        : List<double>.filled(targets.length, 0);
    _to = targets;
    _controller
      ..duration = _durationFor(_to.length)
      ..forward(from: 0);
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

  /// Currently shown value for ring [i] at controller position [t].
  double _display(int i, double t) =>
      _from[i] + (_to[i] - _from[i]) * _fraction(i, t);

  _RingsPainter _painter(List<double> values) => _RingsPainter(
        values: values,
        colors: [for (final r in widget.rings) r.color],
        radii: widget.radii,
        strokeWidth: widget.strokeWidth,
      );

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return SizedBox.square(
      dimension: widget.size,
      child: still
          ? CustomPaint(painter: _painter(_to))
          : AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = _controller.value;
                return CustomPaint(
                  painter: _painter([for (var i = 0; i < _to.length; i++) _display(i, t)]),
                );
              },
            ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  _RingsPainter({
    required this.values,
    required this.colors,
    required this.radii,
    required this.strokeWidth,
  });

  final List<double> values;
  final List<Color> colors;
  final List<double> radii;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    for (var i = 0; i < values.length; i++) {
      final r = radii[i];
      Paint stroke(Color color) => Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = color;

      canvas.drawCircle(center, r, stroke(colors[i].withValues(alpha: _trackAlpha)));

      // clockwise from 12 o'clock; past the goal the ring stays one full turn.
      final sweep = 2 * math.pi * values[i].clamp(0.0, 1.0);
      if (sweep > 0) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: r),
          -math.pi / 2,
          sweep,
          false,
          stroke(colors[i])..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) =>
      !listEquals(old.values, values) ||
      !listEquals(old.colors, colors) ||
      !listEquals(old.radii, radii) ||
      old.strokeWidth != strokeWidth;
}
