@Tags(['scenario'])
library;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/theme/theme.dart';
import 'package:opal/widgets/day_scene.dart';

import 'scenario_harness.dart';

const _crossFade = Duration(milliseconds: 700);

final _beforeNoon = DateTime(2026, 9, 28, 11, 59);
final _afterNoon = DateTime(2026, 9, 28, 12, 1);

const _phaseTimes = {
  DayPhase.morning: 9,
  DayPhase.afternoon: 14,
  DayPhase.evening: 19,
};

// the scenario clock reads this, so a step can move the time mid-test.
late DateTime _now;
final _clock = Clock(() => _now);

final _paints = find.descendant(
  of: find.byType(DayScene),
  matching: find.byType(CustomPaint),
);

// one instance per theme across pumps, or AnimatedTheme lerps and the phase
// change steps see an animation that isn't the scene's.
final _themes = {
  for (final dark in [false, true])
    dark: ThemeData(
      useMaterial3: true,
      extensions: [dark ? AppColors.dark() : AppColors.light()],
    ),
};

/// The scene over `bg`, following the clock the way Today does.
Widget _app({required bool dark, bool disableAnimations = false}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: _themes[dark],
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(disableAnimations: disableAnimations),
        child: ColoredBox(
          color: context.colors.bg,
          child: Align(
            alignment: Alignment.topCenter,
            child: DayScene(phase: phaseFor(clock.now())),
          ),
        ),
      ),
    ),
  );
}

DayPhase _shownPhase(WidgetTester tester) =>
    tester.widget<DayScene>(find.byType(DayScene)).phase;

void main() {
  for (final MapEntry(key: phase, value: hour) in _phaseTimes.entries) {
    scenarioTest('scene ${phase.name}', at: _clock, (tester, dark) async {
      _now = DateTime(2026, 9, 28, hour);
      await tester.pumpWidget(_app(dark: dark));

      expect(_shownPhase(tester), phase);
      expect(_paints, findsOneWidget);
      await shot(tester, 'scene_${phase.name}_${dark ? 'dark' : 'light'}');
    });
  }

  scenarioTest('scene phase change', at: _clock, (tester, dark) async {
    _now = _beforeNoon;
    await tester.pumpWidget(_app(dark: dark));
    expect(_shownPhase(tester), DayPhase.morning);

    _now = _afterNoon;
    await tester.pumpWidget(_app(dark: dark));
    await tester.pump();
    expect(_paints, findsNWidgets(2));
    await tester.pump(_crossFade - const Duration(milliseconds: 1));
    expect(_paints, findsNWidgets(2));
    await tester.pumpAndSettle();

    expect(_shownPhase(tester), DayPhase.afternoon);
    expect(_paints, findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
    await shot(tester, 'scene_phase_change_${dark ? 'dark' : 'light'}');
  });

  scenarioTest('scene phase change, reduced motion', at: _clock, (
    tester,
    dark,
  ) async {
    _now = _beforeNoon;
    await tester.pumpWidget(_app(dark: dark, disableAnimations: true));
    expect(_shownPhase(tester), DayPhase.morning);

    _now = _afterNoon;
    await tester.pumpWidget(_app(dark: dark, disableAnimations: true));

    expect(_shownPhase(tester), DayPhase.afternoon);
    expect(_paints, findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await shot(
      tester,
      'scene_phase_change_reduced_motion_${dark ? 'dark' : 'light'}',
    );
  });
}
