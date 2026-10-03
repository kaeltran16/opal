import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/analysis/area_state.dart';
import 'package:opal/app.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/controllers/today_controller.dart';
import 'package:opal/data/seed/seed_data.dart';
import 'package:opal/models/models.dart';
import 'package:opal/screens/detail/detail_screen.dart';
import 'package:opal/screens/mood/mood_screen.dart';
import 'package:opal/screens/nutrition/nutrition_screen.dart';
import 'package:opal/screens/pal/pal_composer_screen.dart';
import 'package:opal/screens/reflect/evening_close_out_screen.dart';
import 'package:opal/screens/rituals/routine_player_screen.dart';
import 'package:opal/screens/sleep/sleep_screen.dart';
import 'package:opal/screens/today/today_logic.dart';
import 'package:opal/screens/today/today_screen.dart';
import 'package:opal/screens/workout/start_workout_screen.dart';
import 'package:opal/theme/theme.dart';
import 'package:opal/widgets/app_icon.dart';
import 'package:opal/widgets/shortcut_ring.dart';

import 'support/flush_provider_timers.dart';
import 'support/golden_harness.dart' show appRouter;
import 'support/today_fixture.dart';

final _monday = Clock.fixed(DateTime(2026, 9, 28, 9, 30));

const _longTitle = 'Stretch the hips and shoulders before the long desk session';
const _otherLongTitle = 'Walk around the block and refill the water bottle again';

/// Boots Today under the fixed Monday clock on a surface tall enough that
/// every row is on screen.
Future<void> _boot(
  WidgetTester tester, {
  TodayDay day = const TodayDay(),
  TodayPal? pal,
}) async {
  tester.view.physicalSize = const Size(390, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await bootToday(tester, day: day, pal: pal);
}

Finder _onToday(Finder matching) =>
    find.descendant(of: find.byType(TodayScreen), matching: matching);

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(LoopApp)));

AppColors _colors(WidgetTester tester) => tester.element(find.byType(TodayScreen)).colors;

/// The timeline row titled [title].
Finder _row(String title) =>
    find.ancestor(of: _onToday(find.text(title)), matching: find.byType(Row)).first;

double _rowIconLeft(WidgetTester tester, String title) => tester
    .getTopLeft(find.descendant(of: _row(title), matching: find.byType(AppIcon)))
    .dx;

/// The Routines ring with nothing to complete: empty, On track, neutral ink.
void _expectNoRoutinesRing(WidgetTester tester) {
  expect(find.bySemanticsLabel('Routines: none today. On track'), findsOneWidget);
  final ring = find.byType(ShortcutRing).last;
  final widget = tester.widget<ShortcutRing>(ring);
  expect(widget.fraction, 0);
  expect(widget.state, AreaState.good);
  final word = tester.widget<Text>(
      find.descendant(of: ring, matching: find.text(AreaState.good.word)));
  expect(word.style!.color, _colors(tester).ink3);
}

/// Runs [body] under the Monday clock and flushes the app's timers after it.
void _todayTest(String name, Future<void> Function(WidgetTester tester) body) {
  testWidgets(name, (tester) async {
    await withClock(_monday, () async {
      await body(tester);
      await flushProviderTimers(tester);
    });
  });
}

void main() {
  _todayTest('the header shows the date line and a hidden Today heading, with no profile button',
      (tester) async {
    await _boot(tester);

    expect(find.text('MON 28 SEP · 9:30 AM'), findsOneWidget);
    expect(
      _onToday(find.byWidgetPredicate((w) =>
          w is Semantics && w.properties.header == true && w.properties.label == 'Today')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Profile and settings'), findsNothing);
    expect(find.bySemanticsLabel('Search'), findsNothing);
  });

  _todayTest('the three rings carry the glance labels and open their area page',
      (tester) async {
    await _boot(tester);
    final currency = _container(tester).read(appSettingsControllerProvider).currency;
    final glances = areaGlances(
      const GlanceNumbers(
        spent: 5.75,
        budget: 60,
        moveKcal: 310,
        moveGoal: 500,
        routinesDone: 0,
        routinesTotal: 3,
      ),
      currency,
      clock.now(),
    );

    expect(find.byType(ShortcutRing), findsNWidgets(3));
    for (final glance in glances) {
      expect(find.bySemanticsLabel(glance.semantics), findsOneWidget);

      await tester.tap(find.bySemanticsLabel(glance.semantics));
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate((w) => w is DetailScreen && w.tracker == glance.tracker),
        findsOneWidget,
      );

      appRouter(tester).pop();
      await tester.pumpAndSettle();
      // nothing expanded in place: the card is the one Today booted with.
      expect(find.byType(DetailScreen), findsNothing);
      expect(_onToday(find.text('Morning')), findsOneWidget);
      expect(_onToday(find.text('Now')), findsOneWidget);
    }
  });

  _todayTest('the lead is Pal\'s headline when there is one', (tester) async {
    await _boot(tester, pal: TodayPal(headline: 'Steady start.', proposals: const []));

    expect(find.text('Steady start.'), findsOneWidget);
    expect(find.text('Ease into the day'), findsNothing);
  });

  _todayTest('with Pal offline Today still renders, led by the current item\'s sentence',
      (tester) async {
    await _boot(tester, pal: TodayPal(offline: true));

    // the morning routine's own blurb.
    expect(find.text('Ease into the day'), findsOneWidget);
    expect(find.byType(ShortcutRing), findsNWidgets(3));
    expect(_onToday(find.text('Morning')), findsOneWidget);
    expect(_onToday(find.text('Midday reset')), findsOneWidget);
    expect(find.byKey(todayRailKey), findsOneWidget);
    expect(find.textContaining("Couldn't load today"), findsNothing);
  });

  _todayTest('an item with no sentence leads with its title', (tester) async {
    await _boot(tester,
        day: const TodayDay(routines: [], workout: false), pal: TodayPal(offline: true));

    expect(_onToday(find.text('Mood check-in')), findsNWidgets(2));
  });

  _todayTest('the card shows the first open item; skip, Undo and the count follow',
      (tester) async {
    await _boot(
      tester,
      day: const TodayDay(routines: []),
      pal: TodayPal(proposals: [proposal('a', 'Rent auto-pays')]),
    );

    expect(_onToday(find.text('Rent auto-pays')), findsOneWidget);
    expect(find.text('0 of 4 done'), findsOneWidget);
    // the receipt row has its own Undo, labelled with its title.
    expect(find.bySemanticsLabel('Undo'), findsNothing);

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(_onToday(find.text('Rent auto-pays')), findsNothing);
    expect(find.text('Now · 55 min'), findsOneWidget);
    // a skip is not counted as done.
    expect(find.text('0 of 4 done'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Undo'));
    await tester.pumpAndSettle();
    expect(_onToday(find.text('Rent auto-pays')), findsOneWidget);

    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(_onToday(find.text('Rent auto-pays')), findsNothing);
    expect(find.text('1 of 4 done'), findsOneWidget);
  });

  group('the primary pill opens the flow for', () {
    _todayTest('a routine', (tester) async {
      await _boot(tester);

      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      expect(find.byType(RoutinePlayerScreen), findsOneWidget);
    });

    _todayTest('the workout', (tester) async {
      await _boot(tester, day: const TodayDay(routines: []));

      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      expect(find.byType(StartWorkoutScreen), findsOneWidget);
    });

    _todayTest('the mood check-in', (tester) async {
      await _boot(tester, day: const TodayDay(routines: [], workout: false));

      await tester.tap(find.text('Check in'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
    });

    _todayTest('a meal', (tester) async {
      await _boot(tester, day: const TodayDay(routines: [], workout: false, mood: true));

      // the card's title and its pill read the same.
      await tester.tap(_onToday(find.text('Log a meal')).last);
      await tester.pumpAndSettle();
      expect(find.byType(PalComposerSheet), findsOneWidget);
    });

    _todayTest('the close-out', (tester) async {
      await _boot(tester);

      await tester.tap(find.bySemanticsLabel('Close-out, at 9:30 PM. Do this next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      expect(find.byType(EveningCloseOutScreen), findsOneWidget);
    });
  });

  _todayTest('tapping a later row makes it the card', (tester) async {
    await _boot(tester);
    expect(find.text('At 1:00 PM'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Midday reset, at 1:00 PM. Do this next'));
    await tester.pumpAndSettle();

    expect(find.text('At 1:00 PM'), findsOneWidget);
    expect(find.bySemanticsLabel('Midday reset, at 1:00 PM. Do this next'), findsNothing);
    expect(find.bySemanticsLabel('Morning, at 7:00 AM. Do this next'), findsOneWidget);
  });

  _todayTest('a receipt row\'s Undo deletes the entry, even one already gone',
      (tester) async {
    await _boot(tester);
    final repo = _container(tester).read(entryRepositoryProvider);
    // the insert only completes once fake time advances, so don't await it
    // before pumping.
    final inserted = repo.insert(Entry(
      id: 'e-blue',
      timestamp: DateTime(2026, 9, 28, 8),
      type: EntryType.money,
      title: 'Blue Bottle',
      amount: -4.5,
      source: EntrySource.email,
    ));
    await tester.pumpAndSettle();
    await inserted;

    expect(find.textContaining('Logged $receiptTitle, '), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Undo $receiptTitle'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Undo $receiptTitle'), findsNothing);
    final all = repo.getAll();
    await tester.pumpAndSettle();
    expect((await all).any((e) => e.id == receiptId), isFalse);

    // deleted elsewhere first: Undo must not throw, and the row goes away.
    final gone = repo.deleteById('e-blue');
    await tester.tap(find.bySemanticsLabel('Undo Blue Bottle'));
    await tester.pumpAndSettle();
    await gone;
    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel('Undo Blue Bottle'), findsNothing);
  });

  _todayTest('the sleep, mood and meal done rows open their screens', (tester) async {
    await _boot(tester, day: const TodayDay(mood: true, meal: true));

    await tester.tap(_onToday(find.text('Sleep')));
    await tester.pumpAndSettle();
    expect(find.byType(SleepScreen), findsOneWidget);
    appRouter(tester).pop();
    await tester.pumpAndSettle();

    await tester.tap(_onToday(find.text('Mood check-in')));
    await tester.pumpAndSettle();
    expect(find.byType(MoodScreen), findsOneWidget);
    appRouter(tester).pop();
    await tester.pumpAndSettle();

    await tester.tap(_onToday(find.text(mealTitle)));
    await tester.pumpAndSettle();
    expect(find.byType(NutritionScreen), findsOneWidget);
  });

  _todayTest('a done routine row opens the Routines page', (tester) async {
    await _boot(tester, day: const TodayDay(firstRoutineDone: true));

    await tester.tap(_onToday(find.text('Morning')));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate((w) => w is DetailScreen && w.tracker.name == 'rituals'),
      findsOneWidget,
    );
  });

  _todayTest('an empty day ends on the all-done card with no buttons and no rail',
      (tester) async {
    await _boot(tester, day: const TodayDay.empty());

    // with nothing set up, the mood check-in and a meal are all that is asked.
    expect(find.text('0 of 2 done'), findsOneWidget);
    await tester.tap(find.text('Not today'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not today'));
    await tester.pumpAndSettle();

    expect(find.text('All done'), findsOneWidget);
    expect(find.text("That's the day"), findsOneWidget);
    expect(find.text('Nothing is left. Rest up.'), findsOneWidget);
    expect(find.text('Not today'), findsNothing);
    expect(find.byKey(todayRailKey), findsNothing);
    expect(tester.takeException(), isNull);
  });

  _todayTest('with no goals the rings are empty, neutral and On track', (tester) async {
    await _boot(tester, day: const TodayDay.empty());
    final c = _colors(tester);

    final rings = tester.widgetList<ShortcutRing>(find.byType(ShortcutRing)).toList();
    expect(rings, hasLength(3));
    for (final ring in rings) {
      expect(ring.fraction, 0);
      expect(ring.state, AreaState.good);
    }
    final words = tester.widgetList<Text>(_onToday(find.text('On track'))).toList();
    expect(words, hasLength(3));
    for (final word in words) {
      expect(word.style!.color, c.ink3);
    }
    expect(tester.takeException(), isNull);
  });

  for (final (hour, minute, time) in const [(12, 0, '12:00'), (21, 30, '21:30')]) {
    testWidgets(
        'with no routines and the default goals the Routines ring is On track at $time',
        (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 9, 28, hour, minute)), () async {
        await _boot(tester, day: const TodayDay(goals: Goals(), routines: []));

        _expectNoRoutinesRing(tester);
        await flushProviderTimers(tester);
      });
    });
  }

  _todayTest('with no routines, stray ritual step entries leave the ring empty and On track',
      (tester) async {
    await _boot(tester, day: const TodayDay(goals: Goals(), routines: []));
    // the insert only completes once fake time advances, so don't await it
    // before pumping.
    final inserted = _container(tester).read(entryRepositoryProvider).insert(Entry(
          id: 'stray-step',
          timestamp: DateTime(2026, 9, 28, 8),
          type: EntryType.rituals,
          title: 'Stretch',
          ritualId: 'step-of-a-deleted-routine',
          source: EntrySource.manual,
        ));
    await tester.pumpAndSettle();
    await inserted;

    _expectNoRoutinesRing(tester);
  });

  _todayTest('with three routines and one complete the ring reads 1 of 3', (tester) async {
    await _boot(tester, day: const TodayDay(firstRoutineDone: true));
    final routines = areaGlances(
      const GlanceNumbers(
        spent: 5.75,
        budget: 60,
        moveKcal: 310,
        moveGoal: 500,
        routinesDone: 1,
        routinesTotal: 3,
      ),
      _container(tester).read(appSettingsControllerProvider).currency,
      clock.now(),
    ).last;

    expect(routines.value, '1 of 3');
    expect(find.bySemanticsLabel(routines.semantics), findsOneWidget);
    final ring = tester.widgetList<ShortcutRing>(find.byType(ShortcutRing)).last;
    expect(ring.value, routines.value);
    expect(ring.fraction, routines.fraction);
    expect(ring.state, routines.state);
  });

  _todayTest('a done row with no time leaves the time column empty, at the same width',
      (tester) async {
    await _boot(tester, day: const TodayDay(meal: true));

    expect(find.descendant(of: _row('Sleep'), matching: find.text('Any')), findsNothing);
    // an open untimed row still says so, and a timed done row keeps its clock.
    expect(find.descendant(of: _row('Mood check-in'), matching: find.text('Any')),
        findsOneWidget);
    expect(find.descendant(of: _row(mealTitle), matching: find.text('6:40 AM')),
        findsOneWidget);
    expect(_rowIconLeft(tester, 'Sleep'), _rowIconLeft(tester, mealTitle));
  });

  testWidgets('a 60 character routine title at text scale 1.3 does not overflow',
      (tester) async {
    await withClock(_monday, () async {
      expect(_longTitle.length, greaterThanOrEqualTo(59));
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final seeded = SeedData.ritualRoutines();

      await bootToday(
        tester,
        strictLayout: true,
        day: TodayDay(routines: [
          seeded[0].copyWith(name: _longTitle),
          seeded[1].copyWith(name: _otherLongTitle),
        ]),
      );

      // the card wraps its title; the timeline row ellipsises.
      expect(_onToday(find.text(_longTitle)), findsOneWidget);
      expect(_onToday(find.text(_otherLongTitle)), findsOneWidget);
      expect(tester.takeException(), isNull);
      await flushProviderTimers(tester);
    });
  });

  _todayTest('pulling Today down refetches the brief', (tester) async {
    final pal = TodayPal(headline: 'Steady start.', proposals: const []);
    await _boot(tester, pal: pal);
    final before = pal.insightsCalls;
    // the indicator arms at a share of the viewport, which a 400 pt pull
    // never reaches on the tall layout surface; pull on a phone instead.
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();

    await tester.fling(find.byType(TodayScreen), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(pal.insightsCalls, before + 1);
  });

  _todayTest('returning to the app refetches the brief', (tester) async {
    final pal = TodayPal(headline: 'Steady start.', proposals: const []);
    await _boot(tester, pal: pal);
    final before = pal.insightsCalls;

    // AppLifecycleListener asserts every transition, so walk the real sequence.
    for (final state in const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(pal.insightsCalls, before + 1);
  });

  _todayTest('the date line is the only uppercase text', (tester) async {
    await _boot(
      tester,
      day: const TodayDay(mood: true, meal: true, spent: 80),
      pal: TodayPal(proposals: [proposal('a', 'Rent auto-pays')]),
    );

    final shouting = tester
        .widgetList<Text>(_onToday(find.byType(Text)))
        .map((t) => t.data!)
        .where(RegExp(r'[A-Z]{3,}').hasMatch);
    expect(shouting, ['MON 28 SEP · 9:30 AM']);
  });

  _todayTest('Today reads no area colour: rings, icons and text are neutral or a state colour',
      (tester) async {
    // over budget, a goal met and a routine done, so every state colour shows.
    await _boot(
      tester,
      day: const TodayDay(mood: true, meal: true, spent: 80, moveKcal: 520, firstRoutineDone: true),
      pal: TodayPal(proposals: [proposal('a', 'Rent auto-pays')]),
    );
    final c = _colors(tester);
    final area = {
      c.money, c.moneyTint, c.moneyInk,
      c.move, c.moveTint, c.moveInk,
      c.rituals, c.ritualsTint, c.ritualsInk,
      c.nutrition, c.nutritionTint, c.nutritionInk,
      c.sleep, c.sleepTint, c.sleepInk,
      c.mood, c.moodTint, c.moodInk,
    };

    for (final ring in tester.widgetList<CustomPaint>(find.descendant(
        of: find.byType(ShortcutRing), matching: find.byType(CustomPaint)))) {
      final painter = ring.painter as dynamic;
      if (painter == null) continue;
      expect(painter.track, c.track);
      expect([c.ink, c.watch, c.care], contains(painter.arc));
    }
    for (final icon in tester.widgetList<AppIcon>(find.descendant(
        of: find.byType(ShortcutRing), matching: find.byType(AppIcon)))) {
      expect([c.ink, c.bg], contains(icon.color));
    }

    final used = <Color?>{
      for (final icon in tester.widgetList<AppIcon>(_onToday(find.byType(AppIcon)))) icon.color,
      for (final text in tester.widgetList<Text>(_onToday(find.byType(Text)))) text.style?.color,
      for (final box in tester.widgetList<Container>(_onToday(find.byType(Container))))
        if (box.decoration case final BoxDecoration d) d.color,
    };
    expect(used.intersection(area), isEmpty);
  });

  _todayTest('while today is loading it shows the ellipsis', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final never = StreamController<TodayState>();
    addTearDown(never.close);

    await bootToday(tester,
        overrides: [todayStateProvider.overrideWith((ref) => never.stream)]);

    expect(_onToday(find.text('…')), findsOneWidget);
    expect(find.byType(ShortcutRing), findsNothing);
  });

  _todayTest('when today fails to load it says so', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await bootToday(tester, overrides: [
      todayStateProvider.overrideWith((ref) => Stream.error(StateError('no database'))),
    ]);

    expect(find.text("Couldn't load today. Try again in a moment."), findsOneWidget);
    expect(find.byType(ShortcutRing), findsNothing);
  });
}
