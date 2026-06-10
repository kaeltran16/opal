import 'package:drift/native.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/controllers/workout_detail_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/seed/seeder.dart';
import 'package:opal/models/models.dart';
import 'package:opal/screens/workout/workout_detail_screen.dart';
import 'package:opal/theme/app_colors.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Pure math — 8-week bucketing and per-exercise grouping.
  // ---------------------------------------------------------------------------
  test('buildWeeklyVolume buckets completed volume into trailing 8 weeks', () {
    final now = DateTime(2026, 6, 10); // a Wednesday
    SetLog set(double kg, int reps) =>
        SetLog(id: 's', exerciseId: 'bench', weightKg: kg, reps: reps, done: true);

    final thisWeekWorkout = Workout(
      id: 'a',
      name: 'A',
      startedAt: now,
      endedAt: now,
      sets: [set(100, 5)], // 500 kg
    );
    final fourWeeksAgo = Workout(
      id: 'b',
      name: 'B',
      startedAt: now.subtract(const Duration(days: 28)),
      endedAt: now,
      sets: [set(100, 10)], // 1000 kg
    );
    // Outside the 8-week window (should be ignored).
    final old = Workout(
      id: 'c',
      name: 'C',
      startedAt: now.subtract(const Duration(days: 70)),
      endedAt: now,
      sets: [set(999, 9)],
    );

    final buckets =
        buildWeeklyVolume([thisWeekWorkout, fourWeeksAgo, old], now);

    expect(buckets.length, 8);
    expect(buckets.last.volumeKg, 500); // current week
    expect(buckets[3].volumeKg, 1000); // 4 weeks back (index 3 of 0..7)
    // Total only counts in-window workouts.
    expect(buckets.fold<double>(0, (s, b) => s + b.volumeKg), 1500);
  });

  test('buildExerciseGroups groups sets by exercise in first-seen order', () {
    final workout = Workout(
      id: 'w',
      name: 'W',
      startedAt: DateTime(2026, 6, 10),
      sets: const [
        SetLog(id: '1', exerciseId: 'bench', weightKg: 80, reps: 5, done: true),
        SetLog(id: '2', exerciseId: 'ohp', weightKg: 50, reps: 6, done: true),
        SetLog(id: '3', exerciseId: 'bench', weightKg: 85, reps: 5, done: true),
      ],
    );
    const catalog = [
      Exercise(
          id: 'bench', name: 'Bench', group: 'Push', muscle: 'Chest', icon: 'x'),
      Exercise(
          id: 'ohp', name: 'OHP', group: 'Push', muscle: 'Shoulders', icon: 'x'),
    ];

    final groups = buildExerciseGroups(workout, catalog);
    expect(groups.map((g) => g.name).toList(), ['Bench', 'OHP']);
    expect(groups.first.sets.length, 2); // both bench sets
    expect(groups.last.sets.length, 1);
  });

  // ---------------------------------------------------------------------------
  // Widget — renders name, summary, exercise rows, and the fl_chart BarChart.
  // ---------------------------------------------------------------------------
  testWidgets(
      'WorkoutDetailScreen renders the seeded push session + volume chart',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    await Seeder(db).seedIfNeeded();
    addTearDown(db.close);

    final colors = AppColors.light(AppAccent.blue);
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const WorkoutDetailScreen(
            workoutId: 'seed-workout-today-push',
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          loopDatabaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(useMaterial3: true, extensions: [colors]),
          routerConfig: router,
        ),
      ),
    );
    // Let the controller stream + Pal note future resolve.
    await tester.pumpAndSettle();

    // Workout title.
    expect(find.text('Push Day A'), findsOneWidget);

    // Summary PR tile is present, and the seed push workout has exactly 1 PR —
    // surfaced as a single "PR" badge in the set tables.
    expect(find.text('PRS'), findsOneWidget); // 'PRs' label, uppercased
    expect(find.text('PR'), findsOneWidget); // exactly one PR-flagged set

    // Per-exercise row for Bench (seed name: "Barbell Bench Press").
    expect(find.text('Barbell Bench Press'), findsOneWidget);

    // The fl_chart bar chart is present.
    expect(find.byType(BarChart), findsOneWidget);

    // Unmount and flush: disposing the autoDispose drift stream provider makes
    // drift schedule a zero-duration cleanup timer (StreamQueryStore
    // .markAsClosed); pump once so it fires before teardown's timer check.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  });
}
