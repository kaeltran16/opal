import 'dart:async';

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/analysis/area.dart';
import 'package:opal/analysis/area_state.dart';
import 'package:opal/controllers/area_detail_controller.dart' show buildNutritionDetail;
import 'package:opal/controllers/areas_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/repositories/repositories.dart';
import 'package:opal/models/models.dart';
import 'package:opal/screens/today/today_logic.dart';
import 'package:opal/util/format.dart';

// thursday 1 october 2026, half way through the waking day
final _now = DateTime(2026, 10, 1, 14, 30);

/// [hour]:[minute] on the day [daysAgo] days before [now].
DateTime _at(int daysAgo, int hour, {int minute = 0, DateTime? now}) {
  final n = now ?? _now;
  return DateTime(n.year, n.month, n.day - daysAgo, hour, minute);
}

var _nextId = 0;

Entry _spend(double amount, DateTime at) => Entry(
  id: 'e${_nextId++}',
  timestamp: at,
  type: EntryType.money,
  title: 'Lunch',
  amount: -amount,
  category: 'Food',
  source: EntrySource.manual,
);

NutritionMeal _meal(int kcal, DateTime at) => NutritionMeal(
  id: 'm${_nextId++}',
  timestamp: at,
  slot: 'Lunch',
  name: 'Bowl',
  source: NutritionSource.home,
  icon: 'fork.knife',
  confidence: NutritionConfidence.med,
  cal: IntRange(kcal, kcal),
  macros: macrosFromCal(IntRange(kcal, kcal)),
);

MoodCheckin _checkin(double pleasantness, DateTime at) => MoodCheckin(
  id: 'c${_nextId++}',
  timestamp: at,
  pleasantness: pleasantness,
  source: EntrySource.manual,
);

GlanceNumbers _numbers({
  double spent = 20,
  double budget = 60,
  int moveKcal = 300,
  int moveGoal = 500,
  int routinesDone = 2,
  int routinesTotal = 4,
  bool hasRoutines = true,
}) => GlanceNumbers(
  spent: spent,
  budget: budget,
  moveKcal: moveKcal,
  moveGoal: moveGoal,
  routinesDone: routinesDone,
  routinesTotal: routinesTotal,
  hasRoutines: hasRoutines,
);

AreasSummary _build({
  GlanceNumbers? today,
  List<Entry> entries = const [],
  List<NutritionMeal> meals = const [],
  List<MoodCheckin> checkins = const [],
  List<SleepNight> nights = const [],
  DateTime? now,
}) => buildAreasSummary(
  today: today ?? _numbers(),
  entries: entries,
  meals: meals,
  checkins: checkins,
  nights: nights,
  currency: Currency.usd,
  now: now ?? _now,
);

String _usd(num v) => formatCurrency(v, Currency.usd);

void _expectBand(UsualBand? band, double low, double high) {
  expect(band, isNotNull);
  expect(band!.low, closeTo(low, 1e-9));
  expect(band.high, closeTo(high, 1e-9));
}

void main() {
  group('count, line and dot', () {
    test('nothing off', () {
      final s = _build();

      expect(s.areas.map((a) => a.area), Area.values);
      expect(s.onTrack, 3);
      expect(s.off, isEmpty);
      expect(s.countLabel, '3 of 3 on track');
      expect(s.palLine, 'Everything is on track.');
      expect(s.tabDot, isNull);
      expect(s.tabSemanticLabel, 'Areas');
    });

    test('one area worth watching', () {
      // $50 of $60 by mid-day runs a third ahead of the day
      final s = _build(today: _numbers(spent: 50));

      expect(s.of(Area.money).state, AreaState.watch);
      expect(s.countLabel, '2 of 3 on track');
      expect(s.palLine, 'Money is worth a look.');
      expect(s.tabDot, AreaState.watch);
      expect(s.tabSemanticLabel, 'Areas, money worth watching');
      expect(
        s.of(Area.money).semanticLabel,
        'Money: ${_usd(10)} left of ${_usd(60)}. Worth watching. Open Money',
      );
    });

    test('care with watch shows the care dot and a two-area line', () {
      final s = _build(today: _numbers(spent: 70, moveKcal: 100));

      expect(s.off.map((a) => a.area), [Area.money, Area.move]);
      expect(s.countLabel, '1 of 3 on track');
      expect(s.palLine, 'Money and move are worth a look.');
      expect(s.tabDot, AreaState.care);
      expect(
        s.tabSemanticLabel,
        'Areas, money needs care, move worth watching',
      );
    });

    test('three areas off', () {
      final s = _build(
        today: _numbers(spent: 50, moveKcal: 100, routinesDone: 0),
      );

      expect(s.countLabel, '0 of 3 on track');
      expect(s.palLine, 'Money, move and routines are worth a look.');
      expect(s.tabDot, AreaState.watch);
    });

    test('ahead counts as on track', () {
      final s = _build(today: _numbers(moveKcal: 600, routinesDone: 4));

      expect(s.of(Area.move).state, AreaState.thriving);
      expect(s.of(Area.move).progress, closeTo(1.2, 1e-9));
      expect(s.of(Area.routines).state, AreaState.thriving);
      expect(s.countLabel, '3 of 3 on track');
    });

    test('no budget, goal or routines reads all on track', () {
      final s = _build(
        today: _numbers(
          spent: 12,
          budget: 0,
          moveKcal: 250,
          moveGoal: 0,
          routinesDone: 0,
          routinesTotal: 0,
          hasRoutines: false,
        ),
      );

      expect(s.countLabel, '3 of 3 on track');
      expect(s.tabDot, isNull);
      expect(s.palLine, 'Everything is on track.');
      for (final area in [Area.money, Area.move, Area.routines]) {
        expect(s.of(area).state, AreaState.good, reason: area.title);
      }
      final move = s.of(Area.move);
      expect('${move.number} ${move.unit}', '250 kcal');
      expect(move.progress, 0);
      final routines = s.of(Area.routines);
      expect('${routines.number} ${routines.unit}', '0 routines set up');
      expect(routines.progress, 0);
    });

    test('routines with no steps read as steps, not routines', () {
      final routines = _build(
        today: _numbers(routinesDone: 0, routinesTotal: 0),
      ).of(Area.routines);

      expect('${routines.number} ${routines.unit}', '0 steps in your routines');
      expect(routines.state, AreaState.good);
      expect(routines.progress, 0);
    });
  });

  group('legend values', () {
    test('move and routines against their goals', () {
      final s = _build();

      final move = s.of(Area.move);
      expect('${move.number} ${move.unit}', '300 of 500 kcal');
      expect(move.progress, closeTo(0.6, 1e-9));
      expect(move.usual, isNull);
      final routines = s.of(Area.routines);
      expect('${routines.number} ${routines.unit}', '2 of 4 done');
      expect(routines.progress, 0.5);
      expect(routines.usual, isNull);
      expect(
        routines.semanticLabel,
        'Routines: 2 of 4 done. On track. Open Routines',
      );
    });
  });

  group('money', () {
    test('under budget', () {
      final money = _build().of(Area.money);

      expect(money.number, _usd(40));
      expect(money.unit, 'left of ${_usd(60)}');
      expect(money.progress, closeTo(40 / 60, 1e-9));
    });

    test('over budget puts the dot at 0', () {
      final money = _build(today: _numbers(spent: 75)).of(Area.money);

      expect(money.state, AreaState.care);
      expect(money.number, _usd(15));
      expect(money.unit, 'over ${_usd(60)}');
      expect(money.progress, 0);
    });

    test('no budget shows spent today with no bar', () {
      final money = _build(
        today: _numbers(spent: 12, budget: 0),
        entries: [for (var d = 1; d <= 14; d++) _spend(10, _at(d, 9))],
      ).of(Area.money);

      expect(money.state, AreaState.good);
      expect(money.number, _usd(12));
      expect(money.unit, 'spent today');
      expect(money.progress, isNull);
      expect(money.usual, isNull);
      expect(
        money.semanticLabel,
        'Money: ${_usd(12)} spent today. On track. Open Money',
      );
    });
  });

  group('usual band', () {
    test('quartiles of the 14 prior days at this hour', () {
      final s = _build(
        entries: [
          // $1..$14 by 9:00, and a later spend that this hour has not reached
          for (var d = 1; d <= 14; d++) ...[
            _spend(d.toDouble(), _at(d, 9)),
            _spend(30, _at(d, 20)),
          ],
          // older than the window
          _spend(59, _at(15, 9)),
        ],
        meals: [
          for (var d = 1; d <= 14; d++) ...[
            _meal(100 * d, _at(d, 9)),
            _meal(1000, _at(d, 20)),
          ],
          _meal(700, _at(0, 8)),
        ],
      );

      // left shares (59..46)/60: rank 3.25 is 49.25, rank 9.75 is 55.75
      _expectBand(s.of(Area.money).usual, 49.25 / 60, 55.75 / 60);
      // kcal 100..1400 scaled to the largest, 1400: 425 and 1075
      final nutrition = s.of(Area.nutrition);
      _expectBand(nutrition.usual, 425 / 1400, 1075 / 1400);
      expect(nutrition.progress, closeTo(700 / 1400, 1e-9));
    });

    test('no band under 7 days of history', () {
      final s = _build(
        entries: [for (var d = 1; d <= 6; d++) _spend(10, _at(d, 9))],
        meals: [for (var d = 1; d <= 6; d++) _meal(500, _at(d, 9))],
        checkins: [
          _checkin(0.5, _at(0, 9)),
          for (var d = 1; d <= 6; d++) _checkin(0.5, _at(d, 9)),
        ],
      );

      expect(s.of(Area.money).usual, isNull);
      expect(s.of(Area.money).progress, isNotNull);
      expect(s.of(Area.nutrition).usual, isNull);
      expect(s.of(Area.nutrition).progress, isNotNull);
      expect(s.of(Area.mood).usual, isNull);
    });

    test('early morning reads days with data at the same early hour', () {
      final early = DateTime(2026, 10, 1, 6);
      final s = _build(
        now: early,
        today: _numbers(spent: 0),
        entries: [
          for (var d = 1; d <= 14; d++) _spend(20, _at(d, 12, now: early)),
        ],
        meals: [
          for (var d = 1; d <= 14; d++) _meal(600, _at(d, 12, now: early)),
          for (var d = 1; d <= 7; d++) _meal(300, _at(d, 5, now: early)),
        ],
      );

      // nothing spent by 6:00 on any day, so all left
      _expectBand(s.of(Area.money).usual, 1, 1);
      // seven days at 0 kcal by 6:00 and seven at 300, scaled to 300
      final nutrition = s.of(Area.nutrition);
      _expectBand(nutrition.usual, 0, 1);
      expect(nutrition.number, '0');
      expect(nutrition.progress, 0);
    });

    test('mood reads each day\'s latest check-in by this hour', () {
      final s = _build(
        checkins: [
          _checkin(0.5, _at(0, 9)),
          for (var d = 1; d <= 7; d++) ...[
            _checkin(0.1, _at(d, 8)),
            _checkin(d / 10, _at(d, 10)),
            _checkin(1, _at(d, 20)),
          ],
          // a day whose only check-in is later than this hour has no value yet
          for (var d = 8; d <= 14; d++) _checkin(1, _at(d, 20)),
        ],
      );

      // 0.1..0.7: rank 1.5 is 0.25, rank 4.5 is 0.55
      _expectBand(s.of(Area.mood).usual, 0.25, 0.55);
    });
  });

  group('vitals', () {
    test('nutrition kcal today with a thousands separator', () {
      final nutrition = _build(
        meals: [
          _meal(640, _at(0, 8)),
          _meal(600, _at(0, 12, minute: 30)),
          _meal(2000, _at(1, 9)),
        ],
      ).of(Area.nutrition);

      expect(nutrition.state, isNull);
      expect(nutrition.number, '1,240');
      expect(nutrition.unit, 'kcal eaten today');
      expect(
        nutrition.semanticLabel,
        'Nutrition: 1,240 kcal eaten today. Open Nutrition',
      );
    });

    test('nutrition counts today\'s meals the way the Nutrition page does', () {
      // a meal logged for later today is today's, on both screens
      final meals = [_meal(640, _at(0, 8)), _meal(580, _at(0, 19, minute: 10))];
      final nutrition = _build(meals: meals).of(Area.nutrition);

      expect(nutrition.number, '1,220');
      expect(nutrition.number, buildNutritionDetail(meals, _now).hero);
      expect(nutrition.unit, buildNutritionDetail(meals, _now).unit);
    });

    test('mood with a check-in today shows the latest word and time', () {
      final mood = _build(
        checkins: [
          _checkin(0.2, _at(0, 9, minute: 15)),
          _checkin(5 / 6, _at(0, 13, minute: 5)),
        ],
      ).of(Area.mood);

      expect(mood.state, isNull);
      expect(mood.number, 'Pleasant');
      expect(mood.unit, 'at 1:05 PM');
      expect(mood.progress, closeTo(5 / 6, 1e-9));
      expect(mood.semanticLabel, 'Mood: Pleasant at 1:05 PM. Open Mood');
    });

    test('mood with no check-in today has no number and no bar', () {
      final mood = _build(
        checkins: [for (var d = 1; d <= 14; d++) _checkin(0.5, _at(d, 9))],
      ).of(Area.mood);

      expect(mood.number, isNull);
      expect(mood.unit, 'No check-in yet today');
      expect(mood.progress, isNull);
      expect(mood.usual, isNull);
      expect(mood.semanticLabel, 'Mood: No check-in yet today. Open Mood');
    });

    test('sleep reads last night from the stored nights', () {
      SleepNight night(int daysBefore, int asleep) => SleepNight(
            id: 'n$daysBefore',
            night: DateTime(_now.year, _now.month, _now.day - daysBefore),
            asleepMinutes: asleep,
            inBedMinutes: asleep + 20,
            bedtime: '23:00',
            wake: '7:00',
            deepMinutes: 60,
            remMinutes: 90,
            coreMinutes: 250,
            awakeMinutes: 20,
            wakes: 1,
            source: EntrySource.health,
          );

      // the night that began yesterday counts toward today.
      final last = _build(nights: [night(2, 400), night(1, 432)]).of(Area.sleep);
      expect(last.number, '7h 12m');
      expect(last.unit, 'asleep last night');

      final stale = _build(nights: [night(3, 400)]).of(Area.sleep);
      expect(stale.number, isNull);
      expect(stale.unit, 'No night synced for last night');
    });

    test('sleep has no data yet', () {
      final sleep = _build().of(Area.sleep);

      expect(sleep.state, isNull);
      expect(sleep.number, isNull);
      expect(sleep.unit, 'No sleep data yet');
      expect(sleep.progress, isNull);
      expect(sleep.usual, isNull);
      expect(sleep.semanticLabel, 'Sleep: No sleep data yet. Open Sleep');
    });
  });

  test(
    'a routine with no steps leaves the routines target',
    () => withClock(Clock.fixed(DateTime(2026, 10, 1, 9, 30)), () async {
      final db = LoopDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final rituals = RitualRepository(db);
      const full = RitualRoutine(
        id: 'full',
        name: 'Full',
        time: '7:00 AM',
        tone: RitualTone.morning,
        icon: 'sunrise.fill',
        blurb: '',
        steps: [
          RitualStep(id: 'full-0', title: 'Water', note: '', icon: 'drop.fill'),
        ],
      );
      await rituals.upsertRoutine(full);
      await rituals.upsertRoutine(
        full.copyWith(id: 'empty', name: 'Empty', order: 1, steps: const []),
      );
      await EntryRepository(db).insert(
        Entry(
          id: 'e-full-0',
          timestamp: clock.now(),
          type: EntryType.rituals,
          title: 'Water',
          ritualId: 'full-0',
          source: EntrySource.manual,
        ),
      );

      final container = ProviderContainer(
        overrides: [
          loopDatabaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);
      container.listen(areasSummaryProvider, (_, _) {});

      final s = await container.read(areasSummaryProvider.future);
      final routines = s.of(Area.routines);
      expect('${routines.number} ${routines.unit}', '1 of 1 done');
      expect(routines.progress, 1);
    }),
  );

  // pinned to the morning: on the real clock Move at 0 kcal reads Worth
  // watching later in the day, and the count would follow the wall time.
  test(
    'the provider re-emits after a meal is logged',
    () => withClock(Clock.fixed(DateTime(2026, 10, 1, 9, 30)), () async {
      final db = LoopDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await GoalsRepository(db).upsert(const Goals(dailyBudget: 60));

      final container = ProviderContainer(
        overrides: [
          loopDatabaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final logged = Completer<AreasSummary>();
      container.listen(areasSummaryProvider, (_, next) {
        final s = next.value;
        if (s != null &&
            s.of(Area.nutrition).number == '500' &&
            !logged.isCompleted) {
          logged.complete(s);
        }
      });

      final first = await container.read(areasSummaryProvider.future);
      expect(first.of(Area.nutrition).number, '0');
      expect(first.of(Area.money).number, _usd(60));

      await NutritionRepository(db).insert(_meal(500, clock.now()));

      final after = await logged.future.timeout(const Duration(seconds: 5));
      expect(after.countLabel, '3 of 3 on track');
    }),
  );
}
