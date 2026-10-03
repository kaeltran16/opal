@Tags(['scenario'])
library;

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/analysis/area_state.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/controllers/spending_controller.dart' show DetailTracker;
import 'package:opal/controllers/today_controller.dart';
import 'package:opal/data/repositories/repositories.dart';
import 'package:opal/models/models.dart';
import 'package:opal/screens/detail/detail_screen.dart';
import 'package:opal/screens/mood/mood_screen.dart';
import 'package:opal/screens/nutrition/nutrition_screen.dart';
import 'package:opal/screens/pal/pal_composer_screen.dart';
import 'package:opal/screens/reflect/evening_close_out_screen.dart';
import 'package:opal/screens/rituals/routine_player_screen.dart';
import 'package:opal/screens/sleep/sleep_screen.dart';
import 'package:opal/screens/today/today_screen.dart';
import 'package:opal/screens/workout/start_workout_screen.dart';
import 'package:opal/services/pal/pal_service.dart' show PalProposal;
import 'package:opal/theme/theme.dart';
import 'package:opal/widgets/day_scene.dart';
import 'package:opal/widgets/pal_ask_bar.dart';
import 'package:opal/widgets/shortcut_ring.dart';

import '../support/golden_harness.dart' show appRouter;
import '../support/today_fixture.dart';
import 'scenario_harness.dart';

const _headline = 'A steady start. The morning routine is first.';
const _rentTitle = 'Set aside \$40 for rent';

const _rent = PalProposal(
  id: 'hold-rent-40',
  tag: 'Money',
  colorToken: 'money',
  icon: 'dollarsign.circle.fill',
  title: _rentTitle,
  body: 'Rent auto-pays Monday. Holding \$40 today clears it.',
  approveLabel: 'Hold \$40',
  approveIcon: 'checkmark',
  doneLabel: 'Held \$40',
);

const _noGoals = Goals(dailyBudget: 0, dailyMoveKcal: 0, dailyRitualTarget: 0);

TodayPal _pal() => TodayPal(headline: _headline, proposals: const [_rent]);

String _theme(bool dark) => dark ? 'dark' : 'light';

Finder _onToday(Finder matching) =>
    find.descendant(of: find.byType(TodayScreen), matching: matching);

Finder _later(String title, String when) =>
    find.bySemanticsLabel('$title, $when. Do this next');

Finder _areaPage(DetailTracker tracker) =>
    find.byWidgetPredicate((w) => w is DetailScreen && w.tracker == tracker);

/// Scrolls [finder] into view and taps it.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _back(WidgetTester tester) async {
  appRouter(tester).pop();
  await tester.pumpAndSettle();
}

class _FailingDelete extends EntryRepository {
  _FailingDelete(super.db);

  @override
  Future<void> deleteById(String id) => throw StateError('database is locked');
}

void main() {
  const phases = {
    'morning': (7, 10, DayPhase.morning, '7:10 AM'),
    'afternoon': (14, 14, DayPhase.afternoon, '2:14 PM'),
    'evening': (18, 40, DayPhase.evening, '6:40 PM'),
  };
  for (final MapEntry(key: name, value: (hour, minute, phase, time)) in phases.entries) {
    scenarioTest('today $name', at: Clock.fixed(DateTime(2026, 9, 28, hour, minute)),
        (tester, dark) async {
      await bootToday(tester, dark: dark, pal: _pal());

      expect(tester.widget<DayScene>(find.byType(DayScene)).phase, phase);
      expect(find.text('MON 28 SEP · $time'), findsOneWidget);
      expect(find.byType(ShortcutRing), findsNWidgets(3));
      expect(find.text(_headline), findsOneWidget);
      expect(_onToday(find.text('Morning')), findsOneWidget);
      expect(find.byKey(todayRailKey), findsOneWidget);
      await shot(tester, 'today_${name}_${_theme(dark)}');
    });
  }

  scenarioTest('today action card', (tester, dark) async {
    final theme = _theme(dark);
    await bootToday(tester, dark: dark, pal: _pal());
    expect(find.text('0 of 8 done'), findsOneWidget);

    await _tap(tester, _later(_rentTitle, 'any time'));
    await tester.drag(find.byType(TodayScreen), const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(find.text('Hold \$40'), findsOneWidget);
    expect(find.text('Any time'), findsOneWidget);
    await shot(tester, 'today_row_selected_$theme');

    await tester.tap(find.text('Hold \$40'));
    await tester.pumpAndSettle();
    expect(find.text('1 of 8 done'), findsOneWidget);
    expect(find.text(_rentTitle), findsNothing);
    expect(find.bySemanticsLabel('Undo'), findsOneWidget);
    await shot(tester, 'today_after_action_$theme');

    expect(_onToday(find.text('Morning')), findsOneWidget);
    await tester.tap(find.text('Not today'));
    await tester.pumpAndSettle();
    expect(_onToday(find.text('Morning')), findsNothing);
    expect(find.text('1 of 8 done'), findsOneWidget);
    expect(find.bySemanticsLabel('Undo'), findsOneWidget);
    await shot(tester, 'today_after_skip_$theme');

    await tester.tap(find.bySemanticsLabel('Undo'));
    await tester.pumpAndSettle();
    expect(_onToday(find.text('Morning')), findsOneWidget);
    expect(find.text('Now'), findsOneWidget);
    await shot(tester, 'today_after_undo_$theme');
  });

  scenarioTest('today all done', (tester, dark) async {
    await bootToday(tester, dark: dark, day: const TodayDay.empty());

    // nothing is set up, so the mood check-in and a meal are all that is asked.
    await tester.tap(find.text('Not today'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not today'));
    await tester.pumpAndSettle();

    expect(find.text('All done'), findsOneWidget);
    expect(find.text("That's the day"), findsOneWidget);
    expect(find.text('Nothing is left. Rest up.'), findsOneWidget);
    expect(find.text('Not today'), findsNothing);
    expect(find.byKey(todayRailKey), findsNothing);
    await shot(tester, 'today_all_done_${_theme(dark)}');
  });

  scenarioTest('today offline', (tester, dark) async {
    await bootToday(tester, dark: dark, pal: TodayPal(offline: true));

    expect(find.text('Ease into the day'), findsOneWidget);
    expect(find.byType(ShortcutRing), findsNWidgets(3));
    expect(_onToday(find.text('Morning')), findsOneWidget);
    expect(find.byKey(todayRailKey), findsOneWidget);
    expect(find.textContaining("Couldn't load today"), findsNothing);
    await shot(tester, 'today_offline_${_theme(dark)}');
  });

  scenarioTest('today money worth watching', (tester, dark) async {
    await bootToday(tester, dark: dark, pal: _pal(), day: const TodayDay(spent: 32));

    expect(find.bySemanticsLabel(RegExp(r'^Money: .* left to spend\. Worth watching$')),
        findsOneWidget);
    expect(_onToday(find.text(AreaState.watch.word)), findsOneWidget);
    await shot(tester, 'today_watch_${_theme(dark)}');
  });

  scenarioTest('today over budget', (tester, dark) async {
    await bootToday(tester, dark: dark, pal: _pal(), day: const TodayDay(spent: 80));

    expect(find.bySemanticsLabel(RegExp(r'^Money: .* left to spend\. Needs care$')),
        findsOneWidget);
    final money = tester.widgetList<ShortcutRing>(find.byType(ShortcutRing)).first;
    expect(money.fraction, 0);
    expect(money.state, AreaState.care);
    // never a negative amount left.
    expect(money.value, isNot(contains(RegExp('[-−]'))));
    await shot(tester, 'today_over_budget_${_theme(dark)}');
  });

  scenarioTest('today zero goals', (tester, dark) async {
    await bootToday(
      tester,
      dark: dark,
      pal: _pal(),
      day: const TodayDay(goals: _noGoals, routines: [], receipt: false, spent: 38),
    );

    expect(find.bySemanticsLabel(RegExp(r'^Money: .* spent\. On track$')), findsOneWidget);
    expect(find.bySemanticsLabel('Move: 310 kcal burned. On track'), findsOneWidget);
    expect(find.bySemanticsLabel('Routines: none today. On track'), findsOneWidget);
    final ink3 = tester.element(find.byType(TodayScreen)).colors.ink3;
    final words = tester.widgetList<Text>(_onToday(find.text(AreaState.good.word)));
    expect(words, hasLength(3));
    for (final ring in tester.widgetList<ShortcutRing>(find.byType(ShortcutRing))) {
      expect(ring.fraction, 0);
    }
    for (final word in words) {
      expect(word.style!.color, ink3);
    }
    await shot(tester, 'today_zero_goals_${_theme(dark)}');
  });

  scenarioTest('today scrolled to the done rows', (tester, dark) async {
    await bootToday(tester,
        dark: dark, pal: _pal(), day: const TodayDay(mood: true, meal: true));

    final sleep = _onToday(find.text('Sleep'));
    await tester.ensureVisible(sleep);
    await tester.pumpAndSettle();
    expect(sleep.hitTestable(), findsOneWidget);
    expect(_onToday(find.text(mealTitle)).hitTestable(), findsOneWidget);
    expect(find.text('MON 28 SEP · 9:30 AM').hitTestable(), findsNothing);
    await shot(tester, 'today_scrolled_${_theme(dark)}');
  });

  scenarioTest('today error', (tester, dark) async {
    await bootToday(tester, dark: dark, overrides: [
      todayStateProvider.overrideWith((ref) => Stream.error(StateError('no database'))),
    ]);

    expect(find.text("Couldn't load today. Try again in a moment."), findsOneWidget);
    expect(find.byType(ShortcutRing), findsNothing);
    await shot(tester, 'today_error_${_theme(dark)}');
  });

  scenarioTest('today loading', (tester, dark) async {
    final never = StreamController<TodayState>();
    addTearDown(never.close);
    await bootToday(tester,
        dark: dark, overrides: [todayStateProvider.overrideWith((ref) => never.stream)]);

    expect(_onToday(find.text('…')), findsOneWidget);
    expect(find.byType(ShortcutRing), findsNothing);
    await shot(tester, 'today_loading_${_theme(dark)}');
  });

  scenarioTest('today receipt undo', (tester, dark) async {
    await bootToday(tester, dark: dark, pal: _pal());
    expect(find.textContaining('Logged $receiptTitle, '), findsOneWidget);

    await _tap(tester, find.bySemanticsLabel('Undo $receiptTitle'));

    expect(find.textContaining('Logged $receiptTitle'), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    await shot(tester, 'today_receipt_undo_${_theme(dark)}');
  });

  scenarioTest('today receipt undo failed', (tester, dark) async {
    await bootToday(tester, dark: dark, pal: _pal(), overrides: [
      entryRepositoryProvider
          .overrideWith((ref) => _FailingDelete(ref.watch(loopDatabaseProvider))),
    ]);

    await _tap(tester, find.bySemanticsLabel('Undo $receiptTitle'));

    final message = find.text("Couldn't undo. Try again.");
    expect(message, findsOneWidget);
    expect(find.textContaining('Logged $receiptTitle, '), findsOneWidget);
    // above the floating bars, not under them. the SnackBar widget's own box
    // includes its margin, so measure the message.
    expect(
      tester.getBottomLeft(message).dy,
      lessThanOrEqualTo(tester.getTopLeft(find.byType(PalAskBar)).dy),
    );
    await shot(tester, 'today_receipt_undo_failed_${_theme(dark)}');
  });

  scenarioTest('today done rows open their screens', (tester, dark) async {
    final theme = _theme(dark);
    await bootToday(
      tester,
      dark: dark,
      pal: _pal(),
      day: const TodayDay(mood: true, meal: true, firstRoutineDone: true),
    );

    await _tap(tester, _onToday(find.text('Sleep')));
    expect(find.byType(SleepScreen), findsOneWidget);
    await shot(tester, 'today_done_row_sleep_$theme');
    await _back(tester);

    await _tap(tester, _onToday(find.text('Mood check-in')));
    expect(find.byType(MoodScreen), findsOneWidget);
    await shot(tester, 'today_done_row_mood_$theme');
    await _back(tester);

    await _tap(tester, _onToday(find.text('Morning')));
    expect(_areaPage(DetailTracker.rituals), findsOneWidget);
    await shot(tester, 'today_done_row_routine_$theme');
    await _back(tester);

    await _tap(tester, _onToday(find.text(mealTitle)));
    expect(find.byType(NutritionScreen), findsOneWidget);
    await shot(tester, 'today_done_row_meal_$theme');
  });

  // each primary pill, by the kind of item on the card.
  final actions = <String, (TodayDay, Finder Function()?, String, Finder Function())>{
    'routine': (const TodayDay(), null, 'Start', () => find.byType(RoutinePlayerScreen)),
    'workout': (
      const TodayDay(routines: []),
      null,
      'Start',
      () => find.byType(StartWorkoutScreen),
    ),
    'mood': (
      const TodayDay(routines: [], workout: false),
      null,
      'Check in',
      () => find.byType(BottomSheet),
    ),
    'meal': (
      const TodayDay(routines: [], workout: false, mood: true),
      null,
      'Log a meal',
      () => find.byType(PalComposerSheet),
    ),
    'closeout': (
      const TodayDay(),
      () => _later('Close-out', 'at 9:30 PM'),
      'Start',
      () => find.byType(EveningCloseOutScreen),
    ),
  };
  for (final MapEntry(key: kind, value: (day, select, pill, destination)) in actions.entries) {
    scenarioTest('today action $kind', (tester, dark) async {
      await bootToday(tester, dark: dark, day: day);
      if (select != null) await _tap(tester, select());

      // on the meal card the title reads the same as its pill; the pill is last.
      await _tap(tester, _onToday(find.text(pill)).last);

      expect(destination(), findsOneWidget);
      await shot(tester, 'today_action_${kind}_${_theme(dark)}');
    });
  }

  scenarioTest('today pull to refresh', (tester, dark) async {
    final pal = _pal();
    await bootToday(tester, dark: dark, pal: pal);
    final before = pal.insightsCalls;

    await tester.fling(find.byType(TodayScreen), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(pal.insightsCalls, before + 1);
    expect(find.text(_headline), findsOneWidget);
    await shot(tester, 'today_pull_refresh_${_theme(dark)}');
  });
}
