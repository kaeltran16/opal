import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart' show SizedBox;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/app.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/repositories/repositories.dart';
import 'package:opal/data/seed/seed_data.dart';
import 'package:opal/data/seed/seeder.dart';
import 'package:opal/models/models.dart';
import 'package:opal/services/pal/mock_pal_service.dart';
import 'package:opal/services/pal/pal_service.dart';
import 'package:opal/util/dates.dart';

import 'golden_harness.dart' show NoHaptics, ignoreOverflowErrors;

const receiptTitle = 'Verve Coffee';
const receiptId = 'receipt-verve';
const mealTitle = 'Oats & banana';
const workoutRoutineId = 'seed-routine-push-a';
const legacyRitualId = 'legacy-step';

/// A Pal whose proposals and lines the test picks. [offline] makes insights
/// and the agenda throw; a test can flip it after boot and refresh to fail a
/// fetch that succeeded before.
class TodayPal extends MockPalService {
  TodayPal({this.proposals, this.linesByTitle, this.offline = false})
      : super(latency: Duration.zero, seed: 0);

  final List<PalProposal>? proposals;

  /// A line for each received fact whose title has an entry.
  final Map<String, String>? linesByTitle;

  /// Each agenda call's plan, in call order.
  final List<List<PlanFact>> plans = [];
  bool offline;

  /// How often the day's summary was asked for; Today never asks.
  int insightsCalls = 0;

  @override
  Future<PalInsights> insights(InsightRange range) async {
    if (range == InsightRange.day) insightsCalls++;
    if (offline) throw Exception('offline');
    return super.insights(range);
  }

  @override
  Future<PalAgenda> agenda({List<PlanFact> plan = const []}) async {
    plans.add(plan);
    if (offline) throw Exception('offline');
    final byTitle = linesByTitle;
    final lines = {
      for (final f in plan) f.key: ?byTitle?[f.title],
    };
    final p = proposals;
    if (p == null) {
      final base = await super.agenda(plan: plan);
      return PalAgenda(
        proposals: base.proposals,
        autopilot: base.autopilot,
        streakDays: base.streakDays,
        lines: lines,
      );
    }
    return PalAgenda(proposals: p, lines: lines);
  }
}

/// A proposal for [colorToken]'s area, money by default.
PalProposal proposal(String id, String title, {String? action, String colorToken = 'money'}) =>
    PalProposal(
      id: id,
      tag: colorToken,
      colorToken: colorToken,
      icon: 'dollarsign.circle.fill',
      title: title,
      body: 'Body for $title.',
      approveLabel: 'Got it',
      approveIcon: 'checkmark',
      doneLabel: '$title done',
      action: action,
    );

/// The day Today's tests start from, written to a fresh database before the
/// app boots. Everything is logged early in the morning so it is in the past
/// at any clock a test pins.
class TodayDay {
  const TodayDay({
    this.goals = const Goals(dailyBudget: 60, dailyMoveKcal: 500),
    this.routines,
    this.workout = true,
    this.spent = 0,
    this.moveKcal = 310,
    this.receipt = true,
    this.sleep = true,
    this.mood = false,
    this.meal = false,
    this.firstRoutineDone = false,
    this.legacyRitual = false,
    this.historyDays = 0,
  });

  /// Nothing set up and nothing logged.
  const TodayDay.empty()
      : goals = const Goals(dailyBudget: 0, dailyMoveKcal: 0, dailyRitualTarget: 0),
        routines = const [],
        workout = false,
        spent = 0,
        moveKcal = 0,
        receipt = false,
        sleep = false,
        mood = false,
        meal = false,
        firstRoutineDone = false,
        legacyRitual = false,
        historyDays = 0;

  final Goals goals;

  /// Null means the three seed routines.
  final List<RitualRoutine>? routines;
  final bool workout;

  /// Spent by hand, on top of the receipt's 5.75.
  final double spent;
  final int moveKcal;
  final bool receipt, sleep, mood, meal, firstRoutineDone;

  /// A ritual step logged today whose step no longer exists in any routine.
  final bool legacyRitual;

  /// Earlier days, each with a spend, a meal and a check-in in the morning, so
  /// the Areas cards draw where the user usually is by this hour.
  final int historyDays;

  Future<void> write(LoopDatabase db) async {
    final today = startOfDay(clock.now());
    DateTime at(int hour, int minute) => today.add(Duration(hours: hour, minutes: minute));
    final entries = EntryRepository(db);
    final rituals = routines ?? SeedData.ritualRoutines();

    await GoalsRepository(db).upsert(goals);
    for (final r in rituals) {
      await RitualRepository(db).upsertRoutine(r);
    }
    if (workout) {
      for (final r in SeedData.routines()) {
        await RoutineRepository(db).insert(r);
      }
      await WeeklyPlanRepository(db).upsert(today.weekday, workoutRoutineId);
    }
    if (receipt) {
      await entries.insert(Entry(
        id: receiptId,
        timestamp: at(6, 45),
        type: EntryType.money,
        title: receiptTitle,
        amount: -5.75,
        source: EntrySource.email,
      ));
    }
    if (spent > 0) {
      await entries.insert(Entry(
        id: 'spend-groceries',
        timestamp: at(6, 30),
        type: EntryType.money,
        title: 'Groceries',
        amount: -spent,
        source: EntrySource.manual,
      ));
    }
    if (moveKcal > 0) {
      await entries.insert(Entry(
        id: 'move-run',
        timestamp: at(6, 10),
        type: EntryType.move,
        title: 'Morning run',
        calories: moveKcal,
        source: EntrySource.manual,
      ));
    }
    if (firstRoutineDone) {
      for (final s in rituals.first.steps) {
        await entries.insert(Entry(
          id: 'done-${s.id}',
          timestamp: at(6, 55),
          type: EntryType.rituals,
          title: s.title,
          ritualId: s.id,
          source: EntrySource.manual,
        ));
      }
    }
    if (legacyRitual) {
      await entries.insert(Entry(
        id: legacyRitualId,
        timestamp: at(6, 55),
        type: EntryType.rituals,
        title: 'Old step',
        ritualId: legacyRitualId,
        source: EntrySource.manual,
      ));
    }
    if (sleep) {
      await SleepRepository(db)
          .insert(SeedData.sleepNights().first.copyWith(id: 'night-today', night: today));
    }
    if (mood) {
      await MoodRepository(db).insert(MoodCheckin(
        id: 'checkin-today',
        timestamp: at(6, 50),
        pleasantness: 0.7,
        source: EntrySource.manual,
      ));
    }
    if (meal) {
      await NutritionRepository(db).insert(SeedData.nutritionMeals()
          .first
          .copyWith(id: 'meal-today', name: mealTitle, timestamp: at(6, 40)));
    }
    await _writeHistory(db, today);
  }

  Future<void> _writeHistory(LoopDatabase db, DateTime today) async {
    final meals = SeedData.nutritionMeals();
    for (var d = 1; d <= historyDays; d++) {
      // calendar arithmetic, so a dst change keeps each day's morning
      DateTime at(int hour, int minute) =>
          DateTime(today.year, today.month, today.day - d, hour, minute);
      // the values vary by day so each usual band has some width.
      await EntryRepository(db).insert(Entry(
        id: 'history-spend-$d',
        timestamp: at(8, 15),
        type: EntryType.money,
        title: 'Coffee and pastry',
        amount: -(4.0 + d),
        source: EntrySource.manual,
      ));
      await NutritionRepository(db).insert(
          meals[d % 2].copyWith(id: 'history-meal-$d', timestamp: at(7, 30)));
      await MoodRepository(db).insert(MoodCheckin(
        id: 'history-checkin-$d',
        timestamp: at(8, 0),
        pleasantness: 0.4 + (d % 5) / 10,
        source: EntrySource.manual,
      ));
    }
  }
}

SharedPreferences? _lastPrefs;
LoopDatabase? _lastDb;

/// Boots the app on Today with [day] in the database. [strictLayout] leaves
/// overflow errors fatal, for tests that assert there are none.
Future<void> bootToday(
  WidgetTester tester, {
  TodayDay day = const TodayDay(),
  bool dark = false,
  MockPalService? pal,
  List<Override> overrides = const [],
  bool strictLayout = false,
}) async {
  if (!strictLayout) ignoreOverflowErrors();
  SharedPreferences.setMockInitialValues({
    'settings.onboardingComplete': true,
    'settings.brightness': dark ? 'dark' : 'light',
  });
  final prefs = await SharedPreferences.getInstance();
  final db = LoopDatabase.forTesting(NativeDatabase.memory());
  await Seeder(db).seedReferenceData();
  await day.write(db);
  addTearDown(db.close);
  _lastPrefs = prefs;
  _lastDb = db;

  await _pumpApp(tester, prefs, db, pal, overrides);
}

/// Closes the app and boots a fresh one on the same preferences and database
/// as the last [bootToday], as a relaunch does.
Future<void> relaunchToday(
  WidgetTester tester, {
  MockPalService? pal,
  List<Override> overrides = const [],
}) async {
  final prefs = _lastPrefs, db = _lastDb;
  if (prefs == null || db == null) throw StateError('relaunchToday needs a bootToday first');
  await tester.pumpWidget(const SizedBox());
  await _pumpApp(tester, prefs, db, pal, overrides);
}

Future<void> _pumpApp(
  WidgetTester tester,
  SharedPreferences prefs,
  LoopDatabase db,
  MockPalService? pal,
  List<Override> overrides,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        loopDatabaseProvider.overrideWithValue(db),
        palServiceProvider.overrideWithValue(pal ?? TodayPal(proposals: const [])),
        hapticsServiceProvider.overrideWithValue(const NoHaptics()),
        ...overrides,
      ],
      child: const LoopApp(),
    ),
  );
  await tester.pumpAndSettle();
}
