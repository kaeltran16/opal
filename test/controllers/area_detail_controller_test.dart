import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/analysis/area_state.dart';
import 'package:opal/controllers/area_detail_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/controllers/rituals_controller.dart';
import 'package:opal/controllers/spending_controller.dart';
import 'package:opal/controllers/weekly_plan_controller.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/repositories/repositories.dart';
import 'package:opal/models/models.dart';
import 'package:opal/util/format.dart';

// Thursday 1 October 2026, half way through the waking day. The week starts
// Monday 28 September, so Mon..Wed are past and Fri..Sun are still to come.
final _now = DateTime(2026, 10, 1, 14, 30);

/// [hour]:00 on the day [daysAgo] days before [_now].
DateTime _at(int daysAgo, [int hour = 9]) =>
    DateTime(_now.year, _now.month, _now.day - daysAgo, hour);

var _nextId = 0;

Entry _spend(double amount, String category, {int daysAgo = 0}) => Entry(
      id: 'e${_nextId++}',
      timestamp: _at(daysAgo),
      type: EntryType.money,
      title: category,
      amount: -amount,
      category: category,
      source: EntrySource.manual,
    );

Entry _burn(int kcal, {int daysAgo = 0}) => Entry(
      id: 'e${_nextId++}',
      timestamp: _at(daysAgo),
      type: EntryType.move,
      title: 'Run',
      calories: kcal,
      source: EntrySource.health,
    );

Entry _step(String stepId, {int daysAgo = 0}) => Entry(
      id: 'e${_nextId++}',
      timestamp: _at(daysAgo),
      type: EntryType.rituals,
      title: stepId,
      ritualId: stepId,
      source: EntrySource.manual,
    );

RitualRoutine _routine(String id, String name, String time, int steps) =>
    RitualRoutine(
      id: id,
      name: name,
      time: time,
      tone: RitualTone.morning,
      icon: 'sun.max.fill',
      blurb: '',
      steps: [
        for (var i = 0; i < steps; i++)
          RitualStep(id: '$id-step-$i', title: 'Step $i', note: '', icon: 'checkmark'),
      ],
    );

final _routines = [
  _routine('morning', 'Morning', '7:00 AM', 2),
  _routine('midday', 'Midday', '12:30 PM', 1),
  _routine('evening', 'Evening', '9:00 PM', 5),
  _routine('night', 'Night', '10:30 PM', 1),
];

List<Entry> _allSteps(RitualRoutine r, {int daysAgo = 0}) =>
    [for (final s in r.steps) _step(s.id, daysAgo: daysAgo)];

const _pushDay = WeekPlanDay(
  day: 'Thu',
  date: 1,
  type: 'Push',
  routine: 'Push Day A',
  est: 45,
  colorKey: 'move',
  icon: 'dumbbell.fill',
  today: true,
);

AreaDetail _build(
  DetailTracker tracker,
  List<Entry> entries, {
  Goals goals = const Goals(dailyBudget: 60, dailyMoveKcal: 500),
  List<RitualRoutine> routines = const [],
  RitualsState? rituals,
  WeekPlanDay? workout,
  DateTime? now,
}) =>
    buildAreaDetail(
      tracker: tracker,
      entries: entries,
      goals: goals,
      routines: routines,
      rituals: rituals,
      workout: workout,
      currency: Currency.usd,
      now: now ?? _now,
    );

String _usd(num v) => formatCurrency(v, Currency.usd);

void _expectFinite(AreaDetail d) {
  expect(d.goal.isFinite, isTrue);
  for (final c in d.contributors) {
    expect(c.fraction.isFinite, isTrue, reason: c.label);
    expect(c.fraction, inInclusiveRange(0, 1), reason: c.label);
  }
  for (final b in d.week) {
    expect(b.value?.isFinite ?? true, isTrue, reason: b.day);
  }
}

void main() {
  group('money', () {
    final today = [
      _spend(20, 'Food'),
      _spend(12, 'Groceries'),
      _spend(4, 'Transit'),
      _spend(2, 'Fun'),
    ];

    test('under budget on pace', () {
      final d = _build(DetailTracker.money, today);

      expect(d.hero, _usd(22));
      expect(d.unit, 'left of ${_usd(60)} today');
      expect(d.state, AreaState.good);
      expect(d.palLine, '${_usd(22)} left for today.');
      expect(d.goal, 60);
      expect(d.goalLabel, '${_usd(60)} daily budget');

      expect(d.contributors.map((c) => c.label),
          ['Spent today', 'Food', 'Groceries', 'Transit']);
      expect(d.contributors.map((c) => c.value),
          ['${_usd(38)} of ${_usd(60)}', _usd(20), _usd(12), _usd(4)]);
      expect(d.contributors[0].fraction, closeTo(38 / 60, 1e-9));
      expect(d.contributors[1].fraction, closeTo(20 / 38, 1e-9));
      expect(d.contributors.any((c) => c.off), isFalse);
      expect(d.days.single.entries, hasLength(4));
    });

    test('ahead of the day\'s pace is worth watching', () {
      final d = _build(DetailTracker.money, today,
          now: DateTime(2026, 10, 1, 9));

      expect(d.state, AreaState.watch);
      expect(d.palLine, '${_usd(22)} left, and the day is not over.');
    });

    test('over budget shows the overage, never a negative', () {
      final d = _build(DetailTracker.money, [...today, _spend(27, 'Food')]);

      expect(d.hero, _usd(5));
      expect(d.unit, 'over ${_usd(60)} today');
      expect(d.state, AreaState.care);
      expect(d.palLine, '${_usd(5)} over budget. Hold spending for today.');
      expect(d.contributors.first.off, isTrue);
      expect(d.contributors.first.fraction, 1);
      expect(d.contributors.first.value, '${_usd(65)} of ${_usd(60)}');
    });

    test('no budget reads as a plain amount', () {
      final d = _build(
        DetailTracker.money,
        [...today, _spend(90, 'Food', daysAgo: 1)],
        goals: const Goals(dailyBudget: 0),
      );

      expect(d.hero, _usd(38));
      expect(d.unit, 'spent today');
      expect(d.state, AreaState.good);
      expect(d.palLine, '${_usd(38)} spent today.');
      expect(d.contributors.first.value, _usd(38));
      expect(d.contributors.first.fraction, 0);
      expect(d.goal, 0);
      expect(d.goalLabel, '');
      expect(d.weekNote, 'Every day on track');
      _expectFinite(d);
    });

    test('week runs Monday first and only past days can be off', () {
      final d = _build(DetailTracker.money, [
        _spend(48, 'Food', daysAgo: 3),
        _spend(61, 'Food', daysAgo: 2),
        _spend(35, 'Food', daysAgo: 1),
        _spend(65, 'Food'),
      ]);

      expect(d.week.map((b) => b.day), ['M', 'T', 'W', 'T', 'F', 'S', 'S']);
      expect(d.week.map((b) => b.value), [48, 61, 35, 65, null, null, null]);
      expect(d.week.map((b) => b.today),
          [false, false, false, true, false, false, false]);
      // today is over budget too, but the day is not finished
      expect(d.week.map((b) => b.off),
          [false, true, false, false, false, false, false]);
      expect(d.weekNote, '1 day over budget');
    });

    test('last week does not leak into this week', () {
      final d = _build(DetailTracker.money, [_spend(500, 'Rent', daysAgo: 4)]);

      expect(d.week.map((b) => b.value), [0, 0, 0, 0, null, null, null]);
      expect(d.weekNote, 'Every day on track');
    });
  });

  group('move', () {
    test('under goal with a workout planned', () {
      final d = _build(
        DetailTracker.move,
        [
          _burn(310),
          _burn(520, daysAgo: 3),
          _burn(380, daysAgo: 2),
          _burn(200, daysAgo: 1),
        ],
        workout: _pushDay,
      );

      expect(d.hero, '310');
      expect(d.unit, 'of 500 kcal burned');
      expect(d.state, AreaState.good);
      expect(d.palLine, '190 kcal to go. Push Day A is planned today.');
      expect(d.goal, 500);
      expect(d.goalLabel, '500 kcal goal');

      expect(d.contributors.map((c) => c.label), ['Burned', 'Push Day A']);
      expect(d.contributors.map((c) => c.value),
          ['310 of 500 kcal', '45 min planned']);
      expect(d.contributors[0].fraction, closeTo(310 / 500, 1e-9));
      expect(d.contributors[1].fraction, 0);

      expect(d.week.map((b) => b.value), [520, 380, 200, 310, null, null, null]);
      expect(d.week.map((b) => b.off),
          [false, true, true, false, false, false, false]);
      expect(d.weekNote, '2 days under goal');
    });

    test('a finished workout reads Done and drops out of the Pal line', () {
      final d = _build(
        DetailTracker.move,
        [_burn(310)],
        workout: const WeekPlanDay(
          day: 'Thu',
          date: 1,
          type: 'Push',
          routine: 'Push Day A',
          est: 45,
          colorKey: 'move',
          icon: 'dumbbell.fill',
          done: true,
          today: true,
        ),
      );

      expect(d.palLine, '190 kcal to go.');
      expect(d.contributors[1].value, 'Done');
      expect(d.contributors[1].fraction, 1);
    });

    test('a rest day adds no contributor', () {
      final d = _build(
        DetailTracker.move,
        [_burn(310)],
        workout: const WeekPlanDay(
          day: 'Thu',
          date: 1,
          type: 'Rest',
          colorKey: 'rest',
          icon: 'moon.stars.fill',
          today: true,
        ),
      );

      expect(d.contributors.map((c) => c.label), ['Burned']);
      expect(d.palLine, '190 kcal to go.');
    });

    test('goal met', () {
      final d = _build(DetailTracker.move, [_burn(520)], workout: _pushDay);

      expect(d.state, AreaState.thriving);
      expect(d.palLine, 'Goal met.');
      expect(d.contributors.first.fraction, 1);
    });

    test('no goal reads as a plain amount', () {
      final d = _build(
        DetailTracker.move,
        [_burn(310), _burn(40, daysAgo: 1)],
        goals: const Goals(dailyMoveKcal: 0),
      );

      expect(d.hero, '310');
      expect(d.unit, 'kcal burned');
      expect(d.state, AreaState.good);
      expect(d.palLine, '310 kcal burned today.');
      expect(d.contributors.first.value, '310 kcal');
      expect(d.contributors.first.fraction, 0);
      expect(d.goal, 0);
      expect(d.goalLabel, '');
      expect(d.weekNote, 'Every day on track');
      _expectFinite(d);
    });
  });

  group('routines', () {
    final morning = _routines[0];
    final midday = _routines[1];
    final evening = _routines[2];
    final night = _routines[3];

    test('two of four done', () {
      final d = _build(
        DetailTracker.rituals,
        [
          ..._allSteps(morning),
          ..._allSteps(midday),
          _step(evening.steps[0].id),
          _step(evening.steps[1].id),
        ],
        routines: _routines,
        rituals: RitualsState(routines: _routines, progress: const {
          'morning': {0, 1},
          'midday': {0},
          'evening': {0, 1},
        }),
      );

      expect(d.hero, '2');
      expect(d.unit, 'of 4 routines done');
      expect(d.state, AreaState.good);
      expect(d.palLine, '2 left. Evening is at 9:00 PM.');
      expect(d.goal, 4);
      expect(d.goalLabel, 'all 4 routines');

      expect(d.contributors.map((c) => c.label),
          ['Morning', 'Midday', 'Evening', 'Night']);
      expect(d.contributors.map((c) => c.value),
          ['2 of 2 steps', '1 of 1 steps', '2 of 5 steps', '0 of 1 steps']);
      expect(d.contributors.map((c) => c.fraction), [1, 1, closeTo(0.4, 1e-9), 0]);
    });

    test('a routine counts for a day only when every step was logged that day',
        () {
      final d = _build(
        DetailTracker.rituals,
        [
          // Monday: everything.
          for (final r in _routines) ..._allSteps(r, daysAgo: 3),
          // Tuesday: two whole routines and half of Morning.
          ..._allSteps(midday, daysAgo: 2),
          ..._allSteps(night, daysAgo: 2),
          _step(morning.steps[0].id, daysAgo: 2),
          // Wednesday: the other half of Morning, so it completes on neither day.
          _step(morning.steps[1].id, daysAgo: 1),
          // Today.
          ..._allSteps(midday),
        ],
        routines: _routines,
        rituals: RitualsState(routines: _routines, progress: const {
          'midday': {0},
        }),
      );

      expect(d.week.map((b) => b.value), [4, 2, 0, 1, null, null, null]);
      expect(d.week.map((b) => b.off),
          [false, true, true, false, false, false, false]);
      expect(d.weekNote, '2 days missed');
    });

    test('all done', () {
      final d = _build(
        DetailTracker.rituals,
        [for (final r in _routines) ..._allSteps(r)],
        routines: _routines,
        rituals: RitualsState(routines: _routines, progress: const {
          'morning': {0, 1},
          'midday': {0},
          'evening': {0, 1, 2, 3, 4},
          'night': {0},
        }),
      );

      expect(d.hero, '4');
      expect(d.state, AreaState.thriving);
      expect(d.palLine, 'All 4 done.');
    });

    test('none set up', () {
      final d = _build(
        DetailTracker.rituals,
        // stray ritual entries from routines that no longer exist
        [_step('gone-step-0'), _step('gone-step-0', daysAgo: 1)],
        rituals: const RitualsState(routines: [], progress: {}),
      );

      expect(d.hero, '0');
      expect(d.unit, 'routines set up');
      expect(d.state, AreaState.good);
      expect(d.palLine, 'No routines set up yet.');
      expect(d.contributors, isEmpty);
      expect(d.goal, 0);
      expect(d.goalLabel, '');
      expect(d.weekNote, 'Every day on track');
      _expectFinite(d);
    });
  });

  test('the provider re-emits after an entry is inserted', () async {
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await GoalsRepository(db).upsert(const Goals(dailyBudget: 60));

    final container = ProviderContainer(overrides: [
      loopDatabaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ]);
    addTearDown(container.dispose);

    final provider = areaDetailProvider(DetailTracker.money);
    final spent = Completer<AreaDetail>();
    container.listen(provider, (_, next) {
      final d = next.value;
      if (d != null && d.hero == _usd(22) && !spent.isCompleted) {
        spent.complete(d);
      }
    });

    final first = await container.read(provider.future);
    expect(first.hero, _usd(60));

    await EntryRepository(db).insert(Entry(
      id: 'p1',
      timestamp: DateTime.now(),
      type: EntryType.money,
      title: 'Lunch',
      amount: -38,
      category: 'Food',
      source: EntrySource.manual,
    ));

    final after = await spent.future.timeout(const Duration(seconds: 5));
    expect(after.unit, 'left of ${_usd(60)} today');
    expect(after.contributors.map((c) => c.label), ['Spent today', 'Food']);
  });
}
