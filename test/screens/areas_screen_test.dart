import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:opal/analysis/area.dart';
import 'package:opal/analysis/area_state.dart';
import 'package:opal/controllers/areas_controller.dart';
import 'package:opal/models/models.dart';
import 'package:opal/screens/areas/areas_screen.dart';
import 'package:opal/screens/shell/loop_shell.dart';
import 'package:opal/screens/today/today_logic.dart';
import 'package:opal/util/format.dart';
import 'package:opal/widgets/activity_rings.dart';
import 'package:opal/widgets/day_scene.dart';
import 'package:opal/widgets/glass_tab_bar.dart';

import '../scenario/scenario_harness.dart' show loadScenarioFonts;
import '../support/flush_provider_timers.dart';
import '../support/today_fixture.dart';

// thursday 1 october 2026, half way through the waking day
final _now = DateTime(2026, 10, 1, 14, 30);

DateTime _at(int daysAgo, int hour, {int minute = 0}) =>
    DateTime(_now.year, _now.month, _now.day - daysAgo, hour, minute);

var _nextId = 0;

/// Today's numbers at [_now] and [historyDays] prior days of spends, meals and
/// check-ins, each logged before this hour.
AreasSummary _summary({
  double spent = 20,
  double budget = 60,
  int moveKcal = 300,
  int routinesDone = 2,
  int historyDays = 14,
  bool checkinToday = true,
}) {
  final days = [for (var d = 1; d <= historyDays; d++) d];
  return buildAreasSummary(
    today: GlanceNumbers(
      spent: spent,
      budget: budget,
      moveKcal: moveKcal,
      moveGoal: 500,
      routinesDone: routinesDone,
      routinesTotal: 4,
    ),
    entries: [
      for (final d in days)
        Entry(
          id: 'e${_nextId++}',
          timestamp: _at(d, 12),
          type: EntryType.money,
          title: 'Lunch',
          amount: -(10.0 + d),
          source: EntrySource.manual,
        ),
    ],
    meals: [
      for (final d in [0, ...days])
        NutritionMeal(
          id: 'm${_nextId++}',
          timestamp: _at(d, 12),
          slot: 'Lunch',
          name: 'Bowl',
          source: NutritionSource.home,
          icon: 'fork.knife',
          confidence: NutritionConfidence.med,
          cal: IntRange(600 + d * 10, 600 + d * 10),
          macros: macrosFromCal(IntRange(600 + d * 10, 600 + d * 10)),
        ),
    ],
    checkins: [
      for (final d in [if (checkinToday) 0, ...days])
        MoodCheckin(
          id: 'c${_nextId++}',
          timestamp: _at(d, 9, minute: 15),
          pleasantness: 0.5 + d / 100,
          source: EntrySource.manual,
        ),
    ],
    currency: Currency.usd,
    now: _now,
  );
}

Override _with(AreasSummary s) => areasSummaryProvider.overrideWith((ref) => Stream.value(s));

Finder _areasTab() => find.descendant(
    of: find.byType(GlassTabBar), matching: find.bySemanticsLabel(RegExp('^Areas')));

Finder _onAreas(Finder matching) =>
    find.descendant(of: find.byType(AreasScreen), matching: matching);

String _path(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(LoopShell)))
        .routerDelegate
        .currentConfiguration
        .uri
        .path;

/// Boots the app on a surface tall enough that the whole tab is built, and
/// opens Areas over [summary].
Future<void> _boot(
  WidgetTester tester, {
  AreasSummary? summary,
  Override? override,
  Size size = const Size(390, 2400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await bootToday(tester, overrides: [override ?? _with(summary ?? _summary())]);
  await tester.tap(_areasTab());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the header counts the ruled areas on track', (tester) async {
    await _boot(tester, summary: _summary(moveKcal: 100));

    expect(_onAreas(find.text('Areas')), findsOneWidget);
    expect(_onAreas(find.text('2 of 3 on track')), findsOneWidget);

    await flushProviderTimers(tester);
  });

  testWidgets('the rings read as one daily goals node over Move and Routines', (tester) async {
    await _boot(tester);

    expect(
      find.bySemanticsLabel('Daily goals: Move 300 of 500 kcal, Routines 2 of 4 done'),
      findsOneWidget,
    );
    final rings = tester.widget<ActivityRings>(find.byType(ActivityRings));
    expect(rings.rings.map((r) => r.fraction), [300 / 500, 2 / 4]);
    expect(rings.size, 152);
    expect(rings.strokeWidth, 16);
    expect(rings.radii, [68, 48]);

    await flushProviderTimers(tester);
  });

  testWidgets('a legend shows its state word only when not on track', (tester) async {
    await _boot(tester, summary: _summary(moveKcal: 100));

    expect(
      find.bySemanticsLabel('Move, 100 of 500 kcal, Worth watching. Open Move'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Routines, 2 of 4 done. Open Routines'), findsOneWidget);
    expect(_onAreas(find.text('100 of 500 kcal')), findsOneWidget);
    expect(_onAreas(find.text('Worth watching')), findsOneWidget);
    // routines is on track, and so is money on its card.
    expect(_onAreas(find.text('On track')), findsOneWidget);

    await flushProviderTimers(tester);
  });

  for (final (name, summary, line) in [
    ('no area', _summary(), 'Everything is on track.'),
    ('one area', _summary(spent: 50), 'Money is worth a look.'),
    ('two areas', _summary(spent: 50, moveKcal: 100), 'Money and move are worth a look.'),
  ]) {
    testWidgets("Pal's line with $name off", (tester) async {
      await _boot(tester, summary: summary);

      expect(_onAreas(find.text(line)), findsOneWidget);

      await flushProviderTimers(tester);
    });
  }

  testWidgets('Also tracked shows Money, Nutrition, Sleep and Mood', (tester) async {
    final s = _summary(spent: 50);
    await _boot(tester, summary: s);

    expect(_onAreas(find.text('Also tracked')), findsOneWidget);
    for (final area in [Area.money, Area.nutrition, Area.sleep, Area.mood]) {
      expect(find.bySemanticsLabel(s.of(area).semanticLabel), findsOneWidget,
          reason: area.title);
    }
    final money = s.of(Area.money);
    expect(_onAreas(find.text(money.number!)), findsOneWidget);
    expect(_onAreas(find.text(money.unit)), findsOneWidget);
    expect(_onAreas(find.text(AreaState.watch.word)), findsOneWidget);
    expect(_onAreas(find.text(s.of(Area.nutrition).number!)), findsOneWidget);
    expect(_onAreas(find.text('kcal eaten so far')), findsOneWidget);
    expect(_onAreas(find.text('No sleep data yet')), findsOneWidget);
    expect(_onAreas(find.text(s.of(Area.mood).number!)), findsOneWidget);
    expect(_onAreas(find.text('at 9:15 AM')), findsOneWidget);
    // money, nutrition and mood carry a bar; sleep does not.
    expect(_onAreas(find.byKey(const ValueKey('todayDot'))), findsNWidgets(3));
    expect(_onAreas(find.byKey(const ValueKey('usualBand'))), findsNWidgets(3));
    expect(
      _onAreas(find.text('Dot is today. Band is where you usually are by this hour.')),
      findsOneWidget,
    );

    await flushProviderTimers(tester);
  });

  testWidgets('with short history the cards leave out the band', (tester) async {
    await _boot(tester, summary: _summary(historyDays: 6));

    expect(_onAreas(find.byKey(const ValueKey('todayDot'))), findsNWidgets(3));
    expect(_onAreas(find.byKey(const ValueKey('usualBand'))), findsNothing);

    await flushProviderTimers(tester);
  });

  testWidgets('mood with no check-in today has no number and no bar', (tester) async {
    await _boot(tester, summary: _summary(checkinToday: false));

    expect(find.bySemanticsLabel('Mood: No check-in yet today. Open Mood'), findsOneWidget);
    expect(_onAreas(find.text('No check-in yet today')), findsOneWidget);
    expect(_onAreas(find.byKey(const ValueKey('todayDot'))), findsNWidgets(2));

    await flushProviderTimers(tester);
  });

  testWidgets('money with no budget reads spent today, with no bar', (tester) async {
    await _boot(tester, summary: _summary(budget: 0));

    expect(_onAreas(find.text('spent today')), findsOneWidget);
    expect(_onAreas(find.byKey(const ValueKey('todayDot'))), findsNWidgets(2));

    await flushProviderTimers(tester);
  });

  testWidgets('each legend row and card opens its area page', (tester) async {
    await _boot(tester);

    for (final area in Area.values) {
      await tester.tap(find.bySemanticsLabel(RegExp('^${area.title}[:,]')));
      await tester.pumpAndSettle();
      expect(_path(tester), '/areas/${area.name}', reason: area.title);

      await tester.tap(_areasTab());
      await tester.pumpAndSettle();
      expect(_path(tester), '/areas');
    }

    await flushProviderTimers(tester);
  });

  testWidgets('the time-of-day scene sits behind the tab', (tester) async {
    await _boot(tester);

    expect(_onAreas(find.byType(DayScene)), findsOneWidget);

    await flushProviderTimers(tester);
  });

  testWidgets('loading shows the header with a quiet ellipsis', (tester) async {
    final pending = StreamController<AreasSummary>();
    addTearDown(pending.close);
    await _boot(
      tester,
      override: areasSummaryProvider.overrideWith((ref) => pending.stream),
    );

    expect(_onAreas(find.text('Areas')), findsOneWidget);
    expect(_onAreas(find.text('…')), findsOneWidget);
    expect(_onAreas(find.byType(DayScene)), findsOneWidget);

    await flushProviderTimers(tester);
  });

  testWidgets('an error says so', (tester) async {
    await _boot(
      tester,
      override: areasSummaryProvider.overrideWith((ref) => Stream.error(Exception('db'))),
    );

    expect(_onAreas(find.text('Areas')), findsOneWidget);
    expect(_onAreas(find.text("Couldn't load your areas.")), findsOneWidget);

    await flushProviderTimers(tester);
  });

  // last in the file: real fonts stay registered for the rest of the process,
  // and widths only mean something in them, not in ahem's square glyphs.
  group('on a phone in real fonts', () {
    setUpAll(loadScenarioFonts);

    for (final (name, summary) in [
      ('Routines', _summary(routinesDone: 0)),
      ('Move', _summary(moveKcal: 100)),
    ]) {
      testWidgets('$name at Worth watching shows its legend word in full', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 1.0;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await _boot(tester, summary: summary, size: const Size(390, 844));

        expect(find.bySemanticsLabel(RegExp('^$name, .*, Worth watching\\. ')), findsOneWidget);
        final word = tester.renderObject<RenderParagraph>(_onAreas(find.text('Worth watching')));
        expect(word.didExceedMaxLines, isFalse);
        expect(word.size.width, moreOrLessEquals(word.getMaxIntrinsicWidth(double.infinity)));

        await flushProviderTimers(tester);
      });
    }
  });
}
