import 'package:flutter_test/flutter_test.dart';
import 'package:opal/models/models.dart';
import 'package:opal/services/pal/pal_context_builder.dart';
import 'package:opal/services/pal/pal_service.dart' show InsightRange, ReviewRange;

void main() {
  final goals = const Goals(dailyBudget: 60, dailyMoveKcal: 30, dailyRitualTarget: 5);

  Entry money(double amount, {String? category, DateTime? at}) => Entry(
        id: '', timestamp: at ?? DateTime(2026, 6, 10, 8), type: EntryType.money,
        title: category ?? 'Spend', amount: amount, category: category, source: EntrySource.manual,
      );
  Entry move(int kcal, {DateTime? at}) => Entry(
        id: '', timestamp: at ?? DateTime(2026, 6, 10, 9), type: EntryType.move,
        title: 'Walk', duration: 30, calories: kcal, source: EntrySource.manual,
      );
  Entry ritual({DateTime? at}) => Entry(
        id: '', timestamp: at ?? DateTime(2026, 6, 10, 7), type: EntryType.rituals,
        title: 'Meditate', source: EntrySource.manual,
      );

  test('buildChatContext folds today + week numbers', () {
    final ctx = buildChatContext(
      userName: 'Kael',
      goals: goals,
      todayEntries: [money(-12, category: 'Coffee'), move(20), ritual(), ritual(), ritual()],
      weekEntries: [money(-200, category: 'Coffee'), move(140), ritual()],
      moveStreakDays: 11,
    );

    expect(ctx['userName'], 'Kael');
    expect(ctx['dailyBudget'], 60);
    expect(ctx['spentToday'], 12); // absolute value of the expense
    expect(ctx['movedTodayKcal'], 20);
    expect(ctx['ritualsDoneToday'], 3);
    expect(ctx['weekBudget'], 420); // 60 * 7
    expect(ctx['weekRitualGoal'], 35); // 5 * 7
    expect(ctx['moveStreakDays'], 11);
    expect((ctx['todayEntries'] as List).length, 5);
  });

  test('ritual goals derive from routineCount when provided, else fall back', () {
    // routineCount > 0 → targets track the routines (3, 3*7); fallback otherwise.
    final derived = buildChatContext(
      userName: 'Kael',
      goals: goals, // dailyRitualTarget: 5
      todayEntries: const [],
      weekEntries: const [],
      moveStreakDays: 0,
      routineCount: 3,
    );
    expect(derived['ritualGoal'], 3);
    expect(derived['weekRitualGoal'], 21);

    final insights = buildInsightsContext(
      range: InsightRange.week,
      entries: const [],
      goals: goals,
      periodDays: 7,
      streakDays: 0,
      routineCount: 3,
    );
    expect(insights['ritualsTarget'], 21);
  });

  test('buildInsightsContext folds totals, top category, and spend-by-weekday', () {
    // Jun 12 2026 is a Friday (weekday 5); Jun 8 is a Monday (weekday 1).
    final ctx = buildInsightsContext(
      range: InsightRange.week,
      entries: [
        money(-100, category: 'Dining', at: DateTime(2026, 6, 12, 19)), // Fri
        money(-20, category: 'Coffee', at: DateTime(2026, 6, 8, 8)), // Mon
        move(40, at: DateTime(2026, 6, 8, 9)),
        ritual(at: DateTime(2026, 6, 8, 7)),
      ],
      goals: goals,
      periodDays: 7,
      streakDays: 4,
    );

    expect(ctx['range'], 'week');
    expect(ctx['spent'], 120);
    expect(ctx['budget'], 420); // 60 * 7
    expect(ctx['moveKcal'], 40);
    expect(ctx['ritualsKept'], 1);
    expect(ctx['activeDays'], 1); // one distinct move day
    expect(ctx['streakDays'], 4);
    expect(ctx['topCategory'], 'Dining');
    expect(ctx['topCategoryPct'], 83); // 100/120
    final byDay = ctx['spendByWeekday'] as List<double>;
    expect(byDay[0], 20); // Monday
    expect(byDay[4], 100); // Friday
  });

  test('buildReviewContext wires the range, computes ritualsPct, and carries nullable deltas', () {
    final ctx = buildReviewContext(
      range: ReviewRange.week,
      spent: 200,
      spentDeltaPct: -12,
      kcalMoved: 4,
      movedDeltaPct: null,
      activeDays: 5,
      ritualsKept: 28,
      ritualsTarget: 35,
      streakDays: 6,
      topCategory: 'Food',
      topCategoryPct: 34,
    );

    expect(ctx['range'], 'week');
    expect(ctx['spentDeltaPct'], -12);
    expect(ctx['movedDeltaPct'], isNull); // no comparable prior period
    expect(ctx['ritualsPct'], 80); // 28/35
    expect(ctx.containsKey('discoveredPattern'), isFalse);
  });

  test('moveStreakDays counts consecutive move days, anchoring on yesterday', () {
    final now = DateTime(2026, 6, 12, 15); // today has no move entry yet
    final entries = [
      move(30, at: DateTime(2026, 6, 11, 9)), // yesterday
      move(30, at: DateTime(2026, 6, 10, 9)),
      move(30, at: DateTime(2026, 6, 9, 9)),
      // gap on Jun 8 breaks the streak
      move(30, at: DateTime(2026, 6, 7, 9)),
    ];

    expect(moveStreakDays(entries, now: now), 3);
    expect(moveStreakDays(const [], now: now), 0);
  });

  test('ritualStreakDays counts consecutive ritual days, anchoring on yesterday',
      () {
    final now = DateTime(2026, 6, 12, 15); // today has no ritual entry yet
    final entries = [
      ritual(at: DateTime(2026, 6, 11, 7)), // yesterday
      ritual(at: DateTime(2026, 6, 11, 21)), // same day, must not double-count
      ritual(at: DateTime(2026, 6, 10, 7)),
      ritual(at: DateTime(2026, 6, 9, 7)),
      // gap on Jun 8 breaks the streak
      ritual(at: DateTime(2026, 6, 7, 7)),
      // non-ritual entries are ignored
      move(30, at: DateTime(2026, 6, 8, 9)),
    ];

    expect(ritualStreakDays(entries, now: now), 3);
    expect(ritualStreakDays(const [], now: now), 0);
  });

  test('ritualStreakDays includes today when a ritual is logged today', () {
    final now = DateTime(2026, 6, 12, 15);
    final entries = [
      ritual(at: DateTime(2026, 6, 12, 7)), // today
      ritual(at: DateTime(2026, 6, 11, 7)),
    ];

    expect(ritualStreakDays(entries, now: now), 2);
  });

  test('buildSuggestContext resolves set exerciseIds to muscle, then group, then raw id', () {
    final catalog = {
      'bench': const Exercise(
          id: 'bench', name: 'Bench Press', group: 'Push', muscle: 'Chest', icon: 'fig'),
      // empty muscle falls back to the group label
      'sled': const Exercise(
          id: 'sled', name: 'Sled Push', group: 'Legs', muscle: '', icon: 'fig'),
    };
    final workout = Workout(
      id: 'w1', routineId: 'r1', name: 'Push A',
      startedAt: DateTime(2026, 6, 10, 17),
      sets: const [
        SetLog(id: 's1', exerciseId: 'bench', weightKg: 60, reps: 5),
        SetLog(id: 's2', exerciseId: 'sled', weightKg: 80, reps: 10),
        SetLog(id: 's3', exerciseId: 'mystery', weightKg: 20, reps: 10), // unknown → raw id
      ],
    );

    final ctx = buildSuggestContext(
      recentWorkouts: [workout],
      dayOfWeek: 'Wed',
      availableRoutines: const [],
      exercisesById: catalog,
    );

    final muscles = (ctx['recentWorkouts'] as List).single as Map;
    final labels = (muscles['muscles'] as String).split(', ').toSet();
    expect(labels, {'Chest', 'Legs', 'mystery'});
  });

  test('buildPostWorkoutContext reads volume + PRs from the workout', () {
    final workout = Workout(
      id: 'w1', routineId: 'r1', name: 'Push A',
      startedAt: DateTime(2026, 6, 10, 17), endedAt: DateTime(2026, 6, 10, 18),
      sets: const [
        SetLog(id: 's1', exerciseId: 'bench', weightKg: 60, reps: 5, done: true, isPR: true),
        SetLog(id: 's2', exerciseId: 'bench', weightKg: 60, reps: 5, done: true, isPR: false),
      ],
    );

    final ctx = buildPostWorkoutContext(workout: workout, lastSessionVolumeKg: 540, daysAgoLastSession: 4);

    expect(ctx['routineName'], 'Push A');
    expect(ctx['prCount'], 1);
    expect((ctx['prExercises'] as List), contains('bench'));
    expect(ctx['lastSessionVolumeKg'], 540);
    expect(ctx['daysAgoLastSession'], 4);
  });
}
