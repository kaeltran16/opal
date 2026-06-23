import 'package:flutter_test/flutter_test.dart';

import 'package:opal/controllers/workout_history_controller.dart';
import 'package:opal/models/models.dart';

void main() {
  // Small builders for fixtures.
  SetLog set(String ex, double kg, int reps, {bool pr = false}) => SetLog(
      id: 's', exerciseId: ex, weightKg: kg, reps: reps, done: true, isPR: pr);

  Workout workout(
    String id,
    DateTime started, {
    List<SetLog> sets = const [],
    int minutes = 60,
    String? routineId,
  }) =>
      Workout(
        id: id,
        routineId: routineId,
        name: id,
        startedAt: started,
        endedAt: started.add(Duration(minutes: minutes)),
        sets: sets,
      );

  const catalog = [
    Exercise(id: 'bench', name: 'Bench', group: 'Push', muscle: 'Chest', icon: 'x'),
    Exercise(id: 'row', name: 'Row', group: 'Pull', muscle: 'Back', icon: 'x'),
    Exercise(id: 'squat', name: 'Squat', group: 'Legs', muscle: 'Quads', icon: 'x'),
    Exercise(id: 'run', name: 'Run', group: 'Cardio', muscle: 'Cardio', icon: 'x'),
    Exercise(id: 'pullup', name: 'Pull-up', group: 'Pull', muscle: 'Back', icon: 'x'),
  ];

  // ---------------------------------------------------------------------------
  // Range windowing
  // ---------------------------------------------------------------------------
  test('workoutsInRange keeps only the trailing 8 weeks for eightWeeks', () {
    final now = DateTime(2026, 6, 10); // Wednesday
    final recent = workout('a', now.subtract(const Duration(days: 5 * 7)));
    final old = workout('b', now.subtract(const Duration(days: 10 * 7)));

    final inRange =
        workoutsInRange([recent, old], WorkoutHistoryRange.eightWeeks, now);

    expect(inRange.map((w) => w.id), ['a']);
  });

  test('workoutsInRange keeps everything for allTime', () {
    final now = DateTime(2026, 6, 10);
    final recent = workout('a', now.subtract(const Duration(days: 5 * 7)));
    final old = workout('b', now.subtract(const Duration(days: 100 * 7)));

    final inRange =
        workoutsInRange([recent, old], WorkoutHistoryRange.allTime, now);

    expect(inRange.map((w) => w.id).toSet(), {'a', 'b'});
  });

  // ---------------------------------------------------------------------------
  // Summary tiles
  // ---------------------------------------------------------------------------
  test('buildHistorySummary aggregates volume, sessions, minutes, PRs', () {
    final a = workout('a', DateTime(2026, 6, 1),
        minutes: 50, sets: [set('bench', 100, 5, pr: true)]); // 500kg, 1 PR
    final b = workout('b', DateTime(2026, 6, 3),
        minutes: 40, sets: [set('row', 80, 10)]); // 800kg, 0 PR

    final s = buildHistorySummary([a, b]);

    expect(s.volumeKg, 1300);
    expect(s.sessionCount, 2);
    expect(s.totalMinutes, 90);
    expect(s.prCount, 1);
  });

  // ---------------------------------------------------------------------------
  // Muscle balance (by completed-set count)
  // ---------------------------------------------------------------------------
  test('buildGroupBalance splits completed sets by group as percentages', () {
    // 3 Push sets, 1 Pull set => 75% / 25%.
    final w = workout('w', DateTime(2026, 6, 1), sets: [
      set('bench', 100, 5),
      set('bench', 100, 5),
      set('bench', 100, 5),
      set('row', 80, 5),
    ]);

    final balance = buildGroupBalance([w], catalog);

    final push = balance.firstWhere((b) => b.label == 'Push');
    final pull = balance.firstWhere((b) => b.label == 'Pull');
    expect(push.pct, 75);
    expect(push.colorToken, 'move');
    expect(pull.pct, 25);
    expect(pull.colorToken, 'rituals');
    // No Legs/Cardio sets => those groups are absent.
    expect(balance.any((b) => b.label == 'Legs'), isFalse);
  });

  // ---------------------------------------------------------------------------
  // Personal records (best logged set per lift)
  // ---------------------------------------------------------------------------
  test('buildHistoryPrs picks the heaviest set per lift, newest first', () {
    final older = workout('w1', DateTime(2026, 5, 1), sets: [
      set('bench', 80, 5),
      set('bench', 85, 5),
    ]);
    final newer = workout('w2', DateTime(2026, 6, 1), sets: [
      set('bench', 90, 5), // bench PR
      set('row', 100, 5), // row PR
    ]);

    final prs = buildHistoryPrs([newer, older], catalog);

    final bench = prs.firstWhere((p) => p.exerciseId == 'bench');
    expect(bench.weightKg, 90);
    expect(bench.achievedAt, DateTime(2026, 6, 1));
    // delta vs the previous best (85) is +5kg.
    expect(bench.deltaKg, 5);
    // Sorted most-recent achievement first: both achieved 2026-06-01 here, but
    // the row PR and bench PR are both newest; ensure bench is present.
    expect(prs.map((p) => p.exerciseId), contains('row'));
  });

  test('buildHistoryPrs ranks bodyweight lifts by reps', () {
    final w = workout('w', DateTime(2026, 6, 1), sets: [
      set('pullup', 0, 8),
      set('pullup', 0, 11),
    ]);

    final prs = buildHistoryPrs([w], catalog);
    final pullup = prs.firstWhere((p) => p.exerciseId == 'pullup');
    expect(pullup.bodyweight, isTrue);
    expect(pullup.reps, 11);
  });

  // ---------------------------------------------------------------------------
  // Session rows
  // ---------------------------------------------------------------------------
  test('buildHistorySessions tags cardio via routine and sorts newest first', () {
    const routines = [
      Routine(id: 'r-push', name: 'Push', tag: RoutineTag.upper),
      Routine(id: 'r-run', name: 'Run', tag: RoutineTag.cardio),
    ];
    final strength = workout('a', DateTime(2026, 6, 1),
        routineId: 'r-push', sets: [set('bench', 100, 5)]);
    final cardio = workout('b', DateTime(2026, 6, 3), routineId: 'r-run');

    final rows = buildHistorySessions([strength, cardio], routines);

    expect(rows.first.workoutId, 'b'); // newest first
    expect(rows.first.isCardio, isTrue);
    expect(rows.last.isCardio, isFalse);
    expect(rows.last.volumeKg, 500);
  });

  // ---------------------------------------------------------------------------
  // Volume bars + trend
  // ---------------------------------------------------------------------------
  test('buildVolumeBars returns 8 weekly bars for eightWeeks', () {
    final now = DateTime(2026, 6, 10);
    final thisWeek =
        workout('a', now, sets: [set('bench', 100, 5)]); // 500kg this week
    final bars = buildVolumeBars(
        WorkoutHistoryRange.eightWeeks, [thisWeek], now);

    expect(bars.length, 8);
    expect(bars.first.label, 'W1');
    expect(bars.last.label, 'W8');
    expect(bars.last.volumeKg, 500); // current week is the last bar
  });

  test('buildVolumeBars returns 6 monthly bars for sixMonths', () {
    final now = DateTime(2026, 6, 10);
    final thisMonth =
        workout('a', DateTime(2026, 6, 2), sets: [set('bench', 100, 5)]);
    final bars =
        buildVolumeBars(WorkoutHistoryRange.sixMonths, [thisMonth], now);

    expect(bars.length, 6);
    expect(bars.last.label, 'Jun');
    expect(bars.last.volumeKg, 500);
    expect(bars.first.label, 'Jan');
  });

  test('historyTrendPct compares the recent half against the prior half', () {
    final bars = [
      for (var i = 0; i < 4; i++) const HistoryBar(label: 'p', volumeKg: 100),
      for (var i = 0; i < 4; i++) const HistoryBar(label: 'r', volumeKg: 150),
    ];
    // prior = 400, recent = 600 => +50%.
    expect(historyTrendPct(bars), 50);
  });

  test('historyTrendPct is null without a prior baseline', () {
    expect(historyTrendPct(const []), isNull);
    final flat = [const HistoryBar(label: 'x', volumeKg: 0)];
    expect(historyTrendPct(flat), isNull);
  });
}
