import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/analysis/area.dart';
import 'package:opal/analysis/area_state.dart';
import 'package:opal/controllers/area_detail_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/controllers/rituals_controller.dart';
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
  Area area,
  List<Entry> entries, {
  Goals goals = const Goals(dailyBudget: 60, dailyMoveKcal: 500),
  List<RitualRoutine> routines = const [],
  RitualsState? rituals,
  WeekPlanDay? workout,
  DateTime? now,
}) =>
    buildAreaDetail(
      area: area,
      entries: entries,
      goals: goals,
      routines: routines,
      rituals: rituals,
      workout: workout,
      currency: Currency.usd,
      now: now ?? _now,
    );

NutritionMeal _meal(
  String id,
  int kcal, {
  int daysAgo = 0,
  int hour = 9,
  int protein = 0,
  int carbs = 0,
  int fat = 0,
}) =>
    NutritionMeal(
      id: id,
      timestamp: _at(daysAgo, hour),
      slot: 'Lunch',
      name: id,
      source: NutritionSource.home,
      icon: 'fork.knife',
      confidence: NutritionConfidence.med,
      cal: IntRange(kcal, kcal),
      macros: Macros(
        protein: IntRange(protein, protein),
        carbs: IntRange(carbs, carbs),
        fat: IntRange(fat, fat),
      ),
    );

MoodCheckin _checkin(
  String id,
  double pleasantness, {
  int daysAgo = 0,
  int hour = 9,
  int minute = 0,
}) =>
    MoodCheckin(
      id: id,
      timestamp: _at(daysAgo, hour).add(Duration(minutes: minute)),
      pleasantness: pleasantness,
      source: EntrySource.manual,
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
      final d = _build(Area.money, today);

      expect(d.hero, _usd(22));
      expect(d.unit, 'left of ${_usd(60)} today');
      expect(d.state, AreaState.good);
      expect(d.palLine, "Spending is within the day's pace.");
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
      final d = _build(Area.money, today,
          now: DateTime(2026, 10, 1, 9));

      expect(d.state, AreaState.watch);
      expect(d.palLine, "Spending is ahead of the day's pace.");
    });

    test('almost all of the budget spent before the day ends is worth watching', () {
      final d = _build(Area.money, [...today, _spend(17, 'Food')],
          now: DateTime(2026, 10, 1, 20, 15));

      expect(d.hero, _usd(5));
      expect(d.state, AreaState.watch);
      expect(d.palLine, "Almost all of today's budget is spent.");
    });

    test('over budget shows the overage, never a negative', () {
      final d = _build(Area.money, [...today, _spend(27, 'Food')]);

      expect(d.hero, _usd(5));
      expect(d.unit, 'over ${_usd(60)} today');
      expect(d.state, AreaState.care);
      expect(d.palLine, 'Over budget. Hold spending for the rest of today.');
      expect(d.contributors.first.off, isTrue);
      expect(d.contributors.first.fraction, 1);
      expect(d.contributors.first.value, '${_usd(65)} of ${_usd(60)}');
    });

    test('no budget reads as a plain amount', () {
      final d = _build(
        Area.money,
        [...today, _spend(90, 'Food', daysAgo: 1)],
        goals: const Goals(dailyBudget: 0),
      );

      expect(d.hero, _usd(38));
      expect(d.unit, 'spent today');
      expect(d.state, AreaState.good);
      expect(d.palLine, 'Set a daily budget to see your pace.');
      expect(d.contributors.first.value, _usd(38));
      expect(d.contributors.first.fraction, 0);
      expect(d.goal, 0);
      expect(d.goalLabel, '');
      expect(d.weekNote, 'Every day on track');
      _expectFinite(d);
    });

    test('week runs Monday first and today counts once it is over budget', () {
      final d = _build(Area.money, [
        _spend(48, 'Food', daysAgo: 3),
        _spend(61, 'Food', daysAgo: 2),
        _spend(35, 'Food', daysAgo: 1),
        _spend(65, 'Food'),
      ]);

      expect(d.week.map((b) => b.day), ['M', 'T', 'W', 'T', 'F', 'S', 'S']);
      expect(d.week.map((b) => b.value), [48, 61, 35, 65, null, null, null]);
      expect(d.week.map((b) => b.today),
          [false, false, false, true, false, false, false]);
      // spend only grows, so today over budget stays over
      expect(d.week.map((b) => b.off),
          [false, true, false, true, false, false, false]);
      expect(d.weekNote, '2 days over budget');
    });

    test('today alone over budget is not every day on track', () {
      final d = _build(Area.money, [_spend(65, 'Food')]);

      expect(d.weekNote, '1 day over budget');
    });

    test('last week does not leak into this week', () {
      final d = _build(Area.money, [_spend(500, 'Rent', daysAgo: 4)]);

      expect(d.week.map((b) => b.value), [0, 0, 0, 0, null, null, null]);
      expect(d.weekNote, 'Every day on track');
    });
  });

  group('move', () {
    test('under goal with a workout planned', () {
      final d = _build(
        Area.move,
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
        Area.move,
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
        Area.move,
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
      final d = _build(Area.move, [_burn(520)], workout: _pushDay);

      expect(d.state, AreaState.thriving);
      expect(d.palLine, 'Goal met.');
      expect(d.contributors.first.fraction, 1);
    });

    test('no goal reads as a plain amount', () {
      final d = _build(
        Area.move,
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
        Area.routines,
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

      expect(
        [for (final c in d.contributors) (c.label, c.value, c.fraction)],
        [('Done', '2 of 4', 0.5), ('Evening, 9:00 PM', '5 steps', 0)],
      );
      expect(
        [for (final r in d.routines) (r.id, r.name, r.detail, r.done)],
        [
          ('morning', 'Morning', 'Done', true),
          ('midday', 'Midday', 'Done', true),
          ('evening', 'Evening', '9:00 PM · 5 steps', false),
          ('night', 'Night', '10:30 PM · 1 step', false),
        ],
      );
      expect(d.routines.map((r) => r.semanticLabel), [
        'Morning, done',
        'Midday, done',
        'Evening, at 9:00 PM, 5 steps',
        'Night, at 10:30 PM, 1 step',
      ]);
    });

    test('an empty time and zero steps leave no stray separator', () {
      final untimed = _routine('untimed', 'Untimed', '', 3);
      final empty = _routine('empty', 'Empty', '8:00 AM', 0);
      final d = _build(
        Area.routines,
        const [],
        routines: [untimed, empty],
        rituals: RitualsState(routines: [untimed, empty], progress: const {}),
      );

      expect(d.routines.map((r) => (r.detail, r.done)),
          [('3 steps', false), ('8:00 AM · 0 steps', false)]);
      expect(d.routines.map((r) => r.semanticLabel),
          ['Untimed, 3 steps', 'Empty, at 8:00 AM, 0 steps']);
      // the next open routine has no time, so its label is the name alone.
      expect(
        [for (final c in d.contributors) (c.label, c.value)],
        [('Done', '0 of 1'), ('Untimed', '3 steps')],
      );
      _expectFinite(d);
    });

    test('a routine counts for a day only when every step was logged that day',
        () {
      final d = _build(
        Area.routines,
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
        Area.routines,
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
      // nothing is open, so only Done remains.
      expect(d.contributors.map((c) => (c.label, c.value, c.fraction)),
          [('Done', '4 of 4', 1)]);
      expect(d.routines.every((r) => r.done && r.detail == 'Done'), isTrue);
    });

    test('an empty routine leaves the target and is never next', () {
      final empty = _routine('empty', 'Empty', '6:00 AM', 0);
      final routines = [empty, midday];
      final d = _build(
        Area.routines,
        _allSteps(midday),
        routines: routines,
        rituals: RitualsState(routines: routines, progress: const {
          'midday': {0},
        }),
      );

      expect(d.hero, '1');
      expect(d.unit, 'of 1 routines done');
      expect(d.palLine, 'All 1 done.');
      expect(d.contributors.map((c) => (c.label, c.value, c.fraction)),
          [('Done', '1 of 1', 1)]);
      // the row still lists the empty routine so it can be found and filled.
      expect(d.routines.map((r) => (r.id, r.done)),
          [('empty', false), ('midday', true)]);
      _expectFinite(d);
    });

    test('only empty routines read as no steps yet', () {
      final empty = _routine('empty', 'Empty', '6:00 AM', 0);
      final d = _build(
        Area.routines,
        const [],
        routines: [empty],
        rituals: RitualsState(routines: [empty], progress: const {}),
      );

      expect(d.hero, '0');
      expect(d.unit, 'steps in your routines');
      expect(d.palLine, 'No steps in your routines yet.');
      expect(d.contributors, isEmpty);
      expect(d.routines.map((r) => r.id), ['empty']);
      expect(d.goal, 0);
      _expectFinite(d);
    });

    test('none set up', () {
      final d = _build(
        Area.routines,
        // stray ritual entries from routines that no longer exist
        [_step('gone-step-0'), _step('gone-step-0', daysAgo: 1)],
        rituals: const RitualsState(routines: [], progress: {}),
      );

      expect(d.hero, '0');
      expect(d.unit, 'routines set up');
      expect(d.state, AreaState.good);
      expect(d.palLine, 'No routines set up yet.');
      expect(d.contributors, isEmpty);
      expect(d.routines, isEmpty);
      expect(d.goal, 0);
      expect(d.goalLabel, '');
      expect(d.weekNote, 'Every day on track');
      _expectFinite(d);
    });
  });

  group('nutrition', () {
    // inserted out of order: the page lists them oldest first.
    final lunch = _meal('lunch', 690, hour: 12, protein: 46, carbs: 78, fat: 24);
    final breakfast = _meal('breakfast', 380, hour: 7, protein: 12, carbs: 64, fat: 9);
    final tuesday = _meal('tue', 1200, daysAgo: 2);
    final lastWeek = _meal('last-week', 900, daysAgo: 7);

    test('two meals: hero, macro shares, line, meals and week', () {
      final d = buildNutritionDetail([lunch, breakfast, tuesday, lastWeek], _now);

      expect(d.area, Area.nutrition);
      expect(d.hero, '1,070');
      expect(d.unit, 'kcal eaten today');
      expect(d.state, isNull);
      expect(d.palLine, '2 meals logged today.');
      expect(d.meals.map((m) => m.id), ['breakfast', 'lunch']);
      expect(d.routines, isEmpty);
      expect(d.days, isEmpty);

      // 58 g protein, 142 g carbs, 33 g fat: 232 + 568 + 297 = 1097 kcal.
      expect(
        [for (final c in d.contributors) (c.label, c.value)],
        [('Protein', '58 g'), ('Carbs', '142 g'), ('Fat', '33 g')],
      );
      expect(d.contributors.map((c) => c.fraction), [
        closeTo(232 / 1097, 1e-9),
        closeTo(568 / 1097, 1e-9),
        closeTo(297 / 1097, 1e-9),
      ]);
      expect(d.contributors.any((c) => c.off), isFalse);

      expect(d.week.map((b) => b.value), [0, 1200, 0, 1070, null, null, null]);
      expect(d.week.any((b) => b.off), isFalse);
      expect(d.goal, 0);
      expect(d.goalLabel, '');
      expect(d.weekNote, 'Kcal eaten each day');
      _expectFinite(d);
    });

    test('one meal reads in the singular', () {
      expect(buildNutritionDetail([breakfast], _now).palLine, '1 meal logged today.');
    });

    test('no meals today', () {
      final d = buildNutritionDetail([tuesday], _now);

      expect(d.hero, '0');
      expect(d.unit, 'kcal eaten today');
      expect(d.palLine, 'No meals logged yet today.');
      expect(d.meals, isEmpty);
      expect(
        [for (final c in d.contributors) (c.label, c.value, c.fraction)],
        [('Protein', '0 g', 0), ('Carbs', '0 g', 0), ('Fat', '0 g', 0)],
      );
      expect(d.week.map((b) => b.value), [0, 1200, 0, 0, null, null, null]);
      _expectFinite(d);
    });
  });

  group('mood', () {
    final morning = _checkin('morning', 0.9, hour: 8, minute: 15);
    final afternoon = _checkin('afternoon', 0.5, hour: 13, minute: 5);
    final yesterday = [
      _checkin('y1', 0.2, daysAgo: 1),
      _checkin('y2', 0.6, daysAgo: 1, hour: 20),
    ];

    test('with check-ins today', () {
      final d = buildMoodDetail([afternoon, morning, ...yesterday], _now);

      expect(d.area, Area.mood);
      expect(d.hero, 'Neutral');
      expect(d.unit, 'at 1:05 PM');
      expect(d.state, isNull);
      expect(d.palLine, 'Last check-in at 1:05 PM.');
      expect(
        [for (final c in d.contributors) (c.label, c.value, c.fraction)],
        [('8:15 AM', 'Pleasant', 0.9), ('1:05 PM', 'Neutral', 0.5)],
      );
      expect(d.week.map((b) => b.value),
          [null, null, closeTo(0.4, 1e-9), closeTo(0.7, 1e-9), null, null, null]);
      expect(d.week.any((b) => b.off), isFalse);
      expect(d.goal, 0);
      expect(d.goalLabel, '');
      expect(d.weekNote, 'Average of each day');
      expect(d.days, isEmpty);
      _expectFinite(d);
    });

    test('without a check-in today', () {
      final d = buildMoodDetail(yesterday, _now);

      expect(d.hero, '—');
      expect(d.unit, 'No check-in yet today');
      expect(d.palLine, 'No check-in yet today.');
      expect(d.contributors, isEmpty);
      expect(d.week.map((b) => b.value),
          [null, null, closeTo(0.4, 1e-9), null, null, null, null]);
    });
  });

  test('an area without an entry tracker has no entry-based builder', () {
    for (final area in Area.values.where((a) => a.tracker == null)) {
      expect(() => _build(area, const []), throwsArgumentError, reason: area.name);
    }
  });

  test('the nutrition provider re-emits after a meal is logged', () async {
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final container = ProviderContainer(overrides: [
      loopDatabaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ]);
    addTearDown(container.dispose);

    final provider = areaDetailProvider(Area.nutrition);
    final logged = Completer<AreaDetail>();
    container.listen(provider, (_, next) {
      final d = next.value;
      if (d != null && d.meals.isNotEmpty && !logged.isCompleted) logged.complete(d);
    });

    final first = await container.read(provider.future);
    expect(first.palLine, 'No meals logged yet today.');

    final now = DateTime.now();
    await NutritionRepository(db).insert(_meal('m', 500, hour: 0).copyWith(
        timestamp: DateTime(now.year, now.month, now.day)));

    final after = await logged.future.timeout(const Duration(seconds: 5));
    expect(after.hero, '500');
    expect(after.palLine, '1 meal logged today.');
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

    final provider = areaDetailProvider(Area.money);
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
