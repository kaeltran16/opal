import 'package:clock/clock.dart';
import 'package:drift/native.dart';
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

import 'golden_harness.dart' show ignoreOverflowErrors;

const receiptTitle = 'Verve Coffee';
const receiptId = 'receipt-verve';
const mealTitle = 'Oats & banana';
const workoutRoutineId = 'seed-routine-push-a';

/// A Pal whose day headline and proposals the test picks. [offline] makes
/// both the brief and the agenda throw.
class TodayPal extends MockPalService {
  TodayPal({this.headline, this.proposals, this.offline = false})
      : super(latency: Duration.zero, seed: 0);

  final String? headline;
  final List<PalProposal>? proposals;
  final bool offline;
  int insightsCalls = 0;

  @override
  Future<PalInsights> insights(InsightRange range) async {
    if (range == InsightRange.day) insightsCalls++;
    if (offline) throw Exception('offline');
    if (range == InsightRange.day && headline != null) {
      return PalInsights(headline: headline);
    }
    return super.insights(range);
  }

  @override
  Future<PalAgenda> agenda() async {
    if (offline) throw Exception('offline');
    final p = proposals;
    return p == null ? super.agenda() : PalAgenda(proposals: p);
  }
}

PalProposal proposal(String id, String title, {String? action}) => PalProposal(
      id: id,
      tag: 'Money',
      colorToken: 'money',
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
        firstRoutineDone = false;

  final Goals goals;

  /// Null means the three seed routines.
  final List<RitualRoutine>? routines;
  final bool workout;

  /// Spent by hand, on top of the receipt's 5.75.
  final double spent;
  final int moveKcal;
  final bool receipt, sleep, mood, meal, firstRoutineDone;

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
  }
}

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

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        loopDatabaseProvider.overrideWithValue(db),
        palServiceProvider.overrideWithValue(pal ?? TodayPal(proposals: const [])),
        ...overrides,
      ],
      child: const LoopApp(),
    ),
  );
  await tester.pumpAndSettle();
}
