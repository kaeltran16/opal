import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/widgets/activity_rings.dart';

const _outer = Color(0xFF30D158);
const _inner = Color(0xFFBF5AF2);
const _size = 152.0;
const _stroke = 16.0;
const _radii = [68.0, 48.0];
const _center = Offset(_size / 2, _size / 2);

Widget _rings(List<double> fractions, {bool reduceMotion = false}) => MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: ActivityRings(
            rings: [
              ActivityRing(fraction: fractions[0], color: _outer),
              ActivityRing(fraction: fractions[1], color: _inner),
            ],
            size: _size,
            strokeWidth: _stroke,
            radii: _radii,
          ),
        ),
      ),
    );

Finder get _paint =>
    find.descendant(of: find.byType(ActivityRings), matching: find.byType(CustomPaint));

Rect _rect(int i) => Rect.fromCircle(center: _center, radius: _radii[i]);

void main() {
  testWidgets('each arc draws its fraction from 12 o\'clock over its track', (tester) async {
    await tester.pumpWidget(_rings([0.5, 0.25]));
    await tester.pumpAndSettle();

    expect(
      _paint,
      paints
        ..circle(x: _center.dx, y: _center.dy, radius: _radii[0],
            color: _outer.withValues(alpha: 0.2), strokeWidth: _stroke)
        ..arc(rect: _rect(0), startAngle: -math.pi / 2, sweepAngle: math.pi,
            color: _outer, strokeWidth: _stroke, strokeCap: StrokeCap.round)
        ..circle(radius: _radii[1], color: _inner.withValues(alpha: 0.2))
        ..arc(rect: _rect(1), startAngle: -math.pi / 2, sweepAngle: math.pi / 2,
            color: _inner),
    );
  });

  testWidgets('a fraction past the goal is capped at one turn', (tester) async {
    await tester.pumpWidget(_rings([1.4, 1.0]));
    await tester.pumpAndSettle();

    expect(
      _paint,
      paints
        ..circle(radius: _radii[0])
        ..arc(rect: _rect(0), sweepAngle: 2 * math.pi, color: _outer)
        ..circle(radius: _radii[1])
        ..arc(rect: _rect(1), sweepAngle: 2 * math.pi, color: _inner),
    );
  });

  testWidgets('an empty ring draws only its track', (tester) async {
    await tester.pumpWidget(_rings([0, 0.5]));
    await tester.pumpAndSettle();

    expect(
      _paint,
      paints
        ..circle(radius: _radii[0])
        ..circle(radius: _radii[1])
        ..arc(rect: _rect(1), sweepAngle: math.pi),
    );
    expect(_paint, isNot(paints..arc(rect: _rect(0))));
  });

  testWidgets('the rings ease in from empty', (tester) async {
    await tester.pumpWidget(_rings([1, 1]));

    // the first frame has not filled yet.
    expect(_paint, isNot(paints..arc(color: _outer)));

    await tester.pumpAndSettle();
    expect(_paint, paints..arc(color: _outer, sweepAngle: 2 * math.pi));
  });

  testWidgets('with reduce motion the rings draw their values at once', (tester) async {
    await tester.pumpWidget(_rings([1, 0.5], reduceMotion: true));

    expect(
      _paint,
      paints
        ..arc(rect: _rect(0), sweepAngle: 2 * math.pi)
        ..arc(rect: _rect(1), sweepAngle: math.pi),
    );
  });

  testWidgets('a new value tweens from the shown one', (tester) async {
    await tester.pumpWidget(_rings([0.5, 0.5]));
    await tester.pumpAndSettle();

    await tester.pumpWidget(_rings([1, 0.5]));
    // just after the change the outer ring is still near half a turn.
    await tester.pump(const Duration(milliseconds: 16));
    expect(_paint, isNot(paints..arc(rect: _rect(0), sweepAngle: 2 * math.pi)));

    await tester.pumpAndSettle();
    expect(_paint, paints..arc(rect: _rect(0), sweepAngle: 2 * math.pi));
  });
}
