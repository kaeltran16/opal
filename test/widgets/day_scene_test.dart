import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/theme/theme.dart';
import 'package:opal/widgets/day_scene.dart';

const _hostLabel = 'host';
const _designWidth = 390.0;
const _designHeight = 382.0;
const _crossFade = Duration(milliseconds: 700);

// one instance across pumps, or AnimatedTheme lerps and the reduce motion
// test sees a running animation that isn't the scene's.
final _theme = ThemeData(useMaterial3: true, extensions: [AppColors.dark()]);

Widget _app(DayPhase phase, {bool disableAnimations = false}) {
  return MaterialApp(
    theme: _theme,
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(disableAnimations: disableAnimations),
        child: Align(
          alignment: Alignment.topCenter,
          child: Semantics(
            container: true,
            label: _hostLabel,
            child: DayScene(phase: phase),
          ),
        ),
      ),
    ),
  );
}

final _paints = find.descendant(
  of: find.byType(DayScene),
  matching: find.byType(CustomPaint),
);

void main() {
  group('phaseFor', () {
    DayPhase at(int hour, int minute) =>
        phaseFor(DateTime(2026, 10, 4, hour, minute));

    test('is morning before 12:00', () {
      expect(at(0, 0), DayPhase.morning);
      expect(at(11, 59), DayPhase.morning);
    });

    test('is afternoon from 12:00 until 18:00', () {
      expect(at(12, 0), DayPhase.afternoon);
      expect(at(17, 59), DayPhase.afternoon);
    });

    test('is evening from 18:00', () {
      expect(at(18, 0), DayPhase.evening);
      expect(at(23, 59), DayPhase.evening);
    });
  });

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('paints every phase at width $width', (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      for (final phase in DayPhase.values) {
        await tester.pumpWidget(_app(phase, disableAnimations: true));

        expect(tester.takeException(), isNull);
        final size = tester.getSize(find.byType(DayScene));
        expect(size.width, width);
        expect(
          size.height,
          closeTo(width * _designHeight / _designWidth, 0.01),
        );
      }
    });
  }

  testWidgets('contributes no semantics nodes', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(DayPhase.morning));

    final host = tester.getSemantics(find.bySemanticsLabel(_hostLabel));
    expect(host.label, _hostLabel);
    expect(host.hasChildren, isFalse);
    handle.dispose();
  });

  testWidgets('a phase change cross-fades over 700 ms', (tester) async {
    await tester.pumpWidget(_app(DayPhase.morning));
    await tester.pumpWidget(_app(DayPhase.afternoon));
    await tester.pump();

    expect(_paints, findsNWidgets(2));
    expect(tester.hasRunningAnimations, isTrue);

    await tester.pump(_crossFade - const Duration(milliseconds: 1));
    expect(_paints, findsNWidgets(2));

    await tester.pumpAndSettle();
    expect(_paints, findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('reduce motion swaps the phase in one frame', (tester) async {
    await tester.pumpWidget(_app(DayPhase.morning, disableAnimations: true));
    await tester.pumpWidget(_app(DayPhase.afternoon, disableAnimations: true));

    expect(_paints, findsOneWidget);
    expect(
      tester.widget<CustomPaint>(_paints).key,
      const ValueKey(DayPhase.afternoon),
    );
    expect(tester.hasRunningAnimations, isFalse);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
