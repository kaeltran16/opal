@Tags(['scenario'])
library;

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/analysis/area_state.dart';
import 'package:opal/controllers/areas_controller.dart';
import 'package:opal/models/models.dart';
import 'package:opal/screens/areas/areas_screen.dart';
import 'package:opal/theme/theme.dart';
import 'package:opal/widgets/day_scene.dart';
import 'package:opal/widgets/glass_tab_bar.dart';
import 'package:opal/widgets/state_colors.dart';

import '../support/today_fixture.dart';
import 'scenario_harness.dart';

const _caption = 'Dot is today. Band is where you usually are by this hour.';
const _fullHistory = 14;
const _shortHistory = 5;

/// Hand spends on top of the receipt's 5.75, for $30 and $70 spent today.
const _spendWatch = 24.25;
const _spendCare = 64.25;
const _spendOver = 74.25;

/// 18:00, late enough that no routine done yet is worth watching.
final _evening = Clock.fixed(DateTime(2026, 9, 28, 18));

/// A routine with no steps yet.
const _stepless = RitualRoutine(
  id: 'stretch',
  name: 'Stretch break',
  time: '3:00 PM',
  tone: RitualTone.midday,
  icon: 'leaf.fill',
  blurb: 'Loosen up',
);

String _theme(bool dark) => dark ? 'dark' : 'light';

Finder _onAreas(Finder matching) =>
    find.descendant(of: find.byType(AreasScreen), matching: matching);

Finder get _tabDot => find.byKey(glassTabDotKey('areas'));

Finder _card(String title) => find.bySemanticsLabel(RegExp('^$title([:,]|\$)'));

/// Boots [day] and opens the Areas tab.
Future<void> _boot(WidgetTester tester, bool dark, TodayDay day) async {
  await bootToday(tester, dark: dark, day: day);
  await tester.tap(find.descendant(
      of: find.byType(GlassTabBar), matching: find.bySemanticsLabel(RegExp('^Areas'))));
  await tester.pumpAndSettle();
  expect(find.byType(AreasScreen), findsOneWidget);
}

/// The tab's dot: absent for null, else in [state]'s arc colour.
void _expectTabDot(WidgetTester tester, AreaState? state) {
  if (state == null) {
    expect(_tabDot, findsNothing);
    return;
  }
  expect(_tabDot, findsOneWidget);
  final box = tester.widget<DecoratedBox>(_tabDot);
  expect(
    (box.decoration as BoxDecoration).color,
    tester.element(_tabDot).colors.arcFor(state),
  );
}

/// How many cards draw today's dot and how many their usual band.
void _expectBars(int dots, int bands) {
  expect(_onAreas(find.byKey(const ValueKey('todayDot'))), findsNWidgets(dots));
  expect(_onAreas(find.byKey(const ValueKey('usualBand'))), findsNWidgets(bands));
}

void main() {
  scenarioTest('areas tab', (tester, dark) async {
    await _boot(
      tester,
      dark,
      const TodayDay(spent: _spendWatch, meal: true, mood: true, historyDays: _fullHistory),
    );

    expect(_onAreas(find.byType(DayScene)), findsOneWidget);
    expect(_onAreas(find.text('2 of 3 on track')), findsOneWidget);
    expect(_onAreas(find.text('Money is worth a look.')), findsOneWidget);
    expect(_onAreas(find.text('\$30')), findsOneWidget);
    expect(_onAreas(find.text('left of \$60')), findsOneWidget);
    expect(_onAreas(find.text(AreaState.watch.word)), findsOneWidget);
    _expectTabDot(tester, AreaState.watch);
    _expectBars(3, 3);
    await shot(tester, 'areas_tab_${_theme(dark)}');
  });

  scenarioTest('areas all on track', (tester, dark) async {
    await _boot(
      tester,
      dark,
      const TodayDay(meal: true, mood: true, historyDays: _fullHistory),
    );

    expect(_onAreas(find.text('3 of 3 on track')), findsOneWidget);
    expect(_onAreas(find.text('Everything is on track.')), findsOneWidget);
    expect(_onAreas(find.text('\$54.25')), findsOneWidget);
    _expectTabDot(tester, null);
    _expectBars(3, 3);
    await shot(tester, 'areas_all_on_track_${_theme(dark)}');
  });

  scenarioTest('areas needs care', at: _evening, (tester, dark) async {
    await _boot(
      tester,
      dark,
      const TodayDay(spent: _spendCare, meal: true, mood: true, historyDays: _fullHistory),
    );

    expect(_onAreas(find.text('1 of 3 on track')), findsOneWidget);
    expect(_onAreas(find.text('Money and routines are worth a look.')), findsOneWidget);
    expect(_onAreas(find.text('\$10')), findsOneWidget);
    expect(_onAreas(find.text('over \$60')), findsOneWidget);
    _expectTabDot(tester, AreaState.care);
    _expectBars(3, 3);
    await shot(tester, 'areas_needs_care_${_theme(dark)}');
  });

  // routines exist but none has a step, with a step logged before they lost
  // theirs: the card counts steps, not routines, and none done.
  scenarioTest('areas routines no steps', (tester, dark) async {
    await _boot(
      tester,
      dark,
      const TodayDay(routines: [_stepless], legacyRitual: true, meal: true, mood: true),
    );

    expect(find.bySemanticsLabel('Routines, 0 steps in your routines. Open Routines'),
        findsOneWidget);
    expect(_onAreas(find.text('0 steps in your routines')), findsOneWidget);
    expect(_onAreas(find.textContaining('routines set up')), findsNothing);
    expect(_onAreas(find.textContaining('of 0')), findsNothing);
    await shot(tester, 'areas_routines_no_steps_${_theme(dark)}');
  });

  scenarioTest('areas short history', (tester, dark) async {
    await _boot(
      tester,
      dark,
      const TodayDay(meal: true, mood: true, historyDays: _shortHistory),
    );

    expect(_onAreas(find.text('3 of 3 on track')), findsOneWidget);
    _expectTabDot(tester, null);
    _expectBars(3, 0);
    await shot(tester, 'areas_short_history_${_theme(dark)}');
  });

  scenarioTest('areas scrolled', (tester, dark) async {
    await _boot(
      tester,
      dark,
      const TodayDay(spent: _spendWatch, meal: true, mood: true, historyDays: _fullHistory),
    );
    await tester.drag(_onAreas(find.byType(Scrollable)).first, const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(_onAreas(find.text('Also tracked')).hitTestable(), findsOneWidget);
    for (final title in ['Money', 'Nutrition', 'Sleep', 'Mood']) {
      expect(_card(title).hitTestable(), findsOneWidget, reason: title);
    }
    expect(_onAreas(find.text(_caption)).hitTestable(), findsOneWidget);
    _expectTabDot(tester, AreaState.watch);
    _expectBars(3, 3);
    await shot(tester, 'areas_scrolled_${_theme(dark)}');
  });

  scenarioTest('areas money no budget', (tester, dark) async {
    await _boot(
      tester,
      dark,
      const TodayDay(
        goals: Goals(dailyBudget: 0, dailyMoveKcal: 500),
        meal: true,
        mood: true,
        historyDays: _fullHistory,
      ),
    );

    expect(_card('Money'), findsOneWidget);
    expect(_onAreas(find.text('\$5.75')), findsOneWidget);
    expect(_onAreas(find.text('spent today')), findsOneWidget);
    _expectTabDot(tester, null);
    // nutrition and mood keep their bars; money has none.
    _expectBars(2, 2);
    await shot(tester, 'areas_money_no_budget_${_theme(dark)}');
  });

  scenarioTest('areas money over budget', (tester, dark) async {
    await _boot(
      tester,
      dark,
      const TodayDay(spent: _spendOver, meal: true, mood: true, historyDays: _fullHistory),
    );

    expect(_onAreas(find.text('\$20')), findsOneWidget);
    expect(_onAreas(find.text('over \$60')), findsOneWidget);
    expect(_onAreas(find.text(AreaState.care.word)), findsOneWidget);
    expect(_onAreas(find.text('Money is worth a look.')), findsOneWidget);
    _expectTabDot(tester, AreaState.care);
    _expectBars(3, 3);
    // over budget, nothing is left: the dot sits at the bar's start, on it.
    final moneyDot = find.descendant(
        of: _card('Money'), matching: find.byKey(const ValueKey('todayDot')));
    expect(tester.getTopLeft(moneyDot).dx, closeTo(tester.getTopLeft(_card('Money')).dx, 1));
    await shot(tester, 'areas_money_over_budget_${_theme(dark)}');
  });

  scenarioTest('areas mood no check-in', (tester, dark) async {
    await _boot(
      tester,
      dark,
      const TodayDay(meal: true, historyDays: _fullHistory),
    );

    expect(find.bySemanticsLabel('Mood: No check-in yet today. Open Mood'), findsOneWidget);
    expect(_onAreas(find.text('No check-in yet today')), findsOneWidget);
    _expectTabDot(tester, null);
    _expectBars(2, 2);
    await shot(tester, 'areas_mood_no_checkin_${_theme(dark)}');
  });

  scenarioTest('areas loading', (tester, dark) async {
    final never = StreamController<AreasSummary>();
    addTearDown(never.close);
    await bootToday(tester, dark: dark, overrides: [
      areasSummaryProvider.overrideWith((ref) => never.stream),
    ]);
    await tester.tap(find.descendant(
        of: find.byType(GlassTabBar), matching: find.bySemanticsLabel('Areas')));
    await tester.pumpAndSettle();

    expect(_onAreas(find.text('Areas')), findsOneWidget);
    expect(_onAreas(find.text('…')), findsOneWidget);
    _expectTabDot(tester, null);
    await shot(tester, 'areas_loading_${_theme(dark)}');
  });

  scenarioTest('areas error', (tester, dark) async {
    await bootToday(tester, dark: dark, overrides: [
      areasSummaryProvider.overrideWith((ref) => Stream.error(StateError('no database'))),
    ]);
    await tester.tap(find.descendant(
        of: find.byType(GlassTabBar), matching: find.bySemanticsLabel('Areas')));
    await tester.pumpAndSettle();

    expect(_onAreas(find.text('Areas')), findsOneWidget);
    expect(_onAreas(find.text("Couldn't load your areas.")), findsOneWidget);
    _expectTabDot(tester, null);
    await shot(tester, 'areas_error_${_theme(dark)}');
  });
}
