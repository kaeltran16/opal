import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../analysis/area_state.dart';
import '../theme/theme.dart';
import 'state_colors.dart';

const int _days = 7;
const List<String> _letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
const double _chartHeight = 64;
const double _minBar = 2;
const double _goalLine = 1;
const double _dash = 3;
const double _dashGap = 3;

/// A week of daily values against a goal, Monday first. A null value is a day
/// with nothing recorded, which includes the days still to come. A day's [off]
/// state colours its bar; null while it is on track.
class WeekBars extends StatelessWidget {
  const WeekBars({
    super.key,
    required this.values,
    required this.off,
    required this.todayIndex,
    required this.goal,
    required this.semanticLabel,
  });

  final List<double?> values;
  final List<AreaState?> off;
  final int todayIndex;
  final double goal;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    assert(values.length == _days && off.length == _days);
    final c = context.colors;
    final top = values.nonNulls.fold(goal, math.max);
    double height(double? v) => v == null || top <= 0
        ? _minBar
        : math.max(_minBar, (v / top * _chartHeight).roundToDouble());
    Color fill(int i) {
      if (values[i] == null) return c.track;
      if (i == todayIndex) return c.ink;
      final state = off[i];
      return state == null ? c.ink3 : c.arcFor(state);
    }

    return Semantics(
      image: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: _chartHeight,
              child: Stack(
                children: [
                  if (goal > 0)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: height(goal) - _goalLine,
                      height: _goalLine,
                      child: CustomPaint(painter: _DashedLinePainter(c.ink3)),
                    ),
                  // fills the chart so the bars stand on its floor, where the
                  // goal line is measured from.
                  Positioned.fill(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      spacing: Spacing.sm,
                      children: [
                        for (var i = 0; i < _days; i++)
                          Expanded(
                            child: SizedBox(
                              height: height(values[i]),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: fill(i),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(Radii.xs),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.md),
            Row(
              spacing: Spacing.sm,
              children: [
                for (var i = 0; i < _days; i++)
                  Expanded(
                    child: Text(
                      _letters[i],
                      textAlign: TextAlign.center,
                      style: AppType.caption.copyWith(
                        color: i == todayIndex ? c.ink : c.ink3,
                        fontWeight: i == todayIndex ? FontWeight.w600 : null,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  _DashedLinePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.height;
    final y = size.height / 2;
    for (var x = 0.0; x < size.width; x += _dash + _dashGap) {
      canvas.drawLine(Offset(x, y), Offset(math.min(x + _dash, size.width), y), paint);
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter old) => old.color != color;
}
