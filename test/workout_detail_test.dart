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
import 'package:opal/data/repositories/workout_repository.dart';
import 'package:opal/data/seed/seeder.dart';
import 'package:opal/models/models.dart';
import 'package:opal/screens/workout/workout_detail_screen.dart';
import 'package:opal/theme/app_colors.dart';

import 'support/semantics_blocks.dart';

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
  // Widget — the seeded push session (1,933 kg, one PR set on bench).
  // ---------------------------------------------------------------------------
  group('WorkoutDetailScreen', () {
    late LoopDatabase db;

    setUp(() async {
      db = LoopDatabase.forTesting(NativeDatabase.memory());
      await Seeder(db).seedIfNeeded();
    });

    tearDown(() async => db.close());

    testWidgets('leads with the volume in display type and keeps the chart',
        (tester) async {
      await _pumpDetail(tester, db);

      expect(find.text('Push Day A'), findsOneWidget);
      final volume = tester.widget<Text>(find.text('1,933'));
      expect(volume.style?.fontSize, 64);
      expect(volume.style?.fontWeight, FontWeight.w300);
      expect(find.text('kg lifted'), findsOneWidget);
      expect(find.text('New best · Barbell Bench Press, 92.5 kg'), findsOneWidget);
      expect(find.text('Records'), findsOneWidget);
      expect(find.byType(BarChart), findsOneWidget);

      await _unmount(tester);
    });

    testWidgets('a PR set shows New best in its set table', (tester) async {
      await _pumpDetail(tester, db);

      await tester.scrollUntilVisible(
        find.text('New best'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('New best'), findsOneWidget);
      expect(find.text('92.5 kg × 5'), findsOneWidget);
      expect(tester.widget<Text>(find.text('New best')).style?.color,
          AppColors.light().thrivingInk);

      await _unmount(tester);
    });

    testWidgets('a screen reader reaches each heading and set row on its own',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpDetail(tester, db);
      await tester.scrollUntilVisible(find.text('85 kg × 5'), 200,
          scrollable: find.byType(Scrollable).first);

      expectOwnSemanticsNodes(tester, [
        'Volume over 8 weeks',
        'Exercises',
        'Barbell Bench Press',
        '80 kg × 5',
        '85 kg × 5',
      ]);

      semantics.dispose();
      await _unmount(tester);
    });

    testWidgets('Cancel in the delete confirm keeps the workout', (tester) async {
      await _pumpDetail(tester, db);

      await _openDeleteConfirm(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Delete workout?'), findsNothing);
      expect(await _stillThere(tester, db), isTrue);

      await _unmount(tester);
    });

    testWidgets('More options deletes the workout after the confirm',
        (tester) async {
      await _pumpDetail(tester, db);

      await _openDeleteConfirm(tester);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(await _stillThere(tester, db), isFalse);
      expect(find.text(_home), findsOneWidget);

      await _unmount(tester);
    });
  });
}

const _workoutId = 'seed-workout-today-push';
const _home = 'home';

/// Pumps the detail screen as a route pushed over [_home], so it can pop.
Future<void> _pumpDetail(WidgetTester tester, LoopDatabase db) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final router = GoRouter(
    initialLocation: '/w',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Text(_home),
        routes: [
          GoRoute(
            path: 'w',
            builder: (context, state) =>
                const WorkoutDetailScreen(workoutId: _workoutId),
          ),
        ],
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
        theme: ThemeData(useMaterial3: true, extensions: [AppColors.light()]),
        routerConfig: router,
      ),
    ),
  );
  // let the detail stream and the mock pal note's latency resolve.
  await tester.pumpAndSettle();
}

Future<void> _openDeleteConfirm(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel('More options'));
  await tester.pumpAndSettle();
  expect(find.text('Delete workout'), findsOneWidget);

  await tester.tap(find.text('Delete workout'));
  await tester.pumpAndSettle();
  expect(find.text('Delete workout?'), findsOneWidget);
}

Future<bool> _stillThere(WidgetTester tester, LoopDatabase db) async {
  final workout = await tester
      .runAsync(() => WorkoutRepository(db).getById(_workoutId));
  return workout != null;
}

/// Unmounts and flushes drift's zero-duration stream cleanup timer so the
/// teardown timer check passes.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(Duration.zero);
}
