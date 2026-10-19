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
        buildWeeklyTotals([thisWeekWorkout, fourWeeksAgo, old], now);

    expect(buckets.length, 8);
    expect(buckets.last.volumeKg, 500); // current week
    expect(buckets[3].volumeKg, 1000); // 4 weeks back (index 3 of 0..7)
    // Total only counts in-window workouts.
    expect(buckets.fold<double>(0, (s, b) => s + b.volumeKg), 1500);
  });

  test('buildWeeklyTotals also sums the minutes and km of timed sets', () {
    final now = DateTime(2026, 6, 10);
    SetLog timed(int minutes, {double? km}) => SetLog(
        id: 't', exerciseId: 'run', weightKg: 0, reps: 0, done: true, minutes: minutes, distanceKm: km);
    Workout run(String id, DateTime at, List<SetLog> sets) =>
        Workout(id: id, name: id, startedAt: at, endedAt: at, sets: sets);

    final weeks = buildWeeklyTotals([
      run('a', now, [timed(20, km: 3.2), timed(10)]),
      run('b', now.subtract(const Duration(days: 7)), [timed(15, km: 2)]),
    ], now);

    expect(weeks.last.minutes, 30);
    expect(weeks.last.km, closeTo(3.2, 1e-9));
    expect(weeks[6].minutes, 15);
    expect(weeks.last.volumeKg, 0);
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

    testWidgets('a timed session leads with minutes and km, not kg', (tester) async {
      await tester.runAsync(() => WorkoutRepository(db).insert(Workout(
        id: 'timed-run',
        name: 'Treadmill intervals',
        startedAt: DateTime(2026, 6, 10, 9),
        endedAt: DateTime(2026, 6, 10, 9, 20),
        sets: const [
          SetLog(
              id: 'timed-run-1',
              exerciseId: 'treadmill',
              weightKg: 0,
              reps: 0,
              done: true,
              minutes: 20,
              distanceKm: 3.2),
        ],
      )));
      await _pumpDetail(tester, db, workoutId: 'timed-run');
      await tester.pump(_palLatency);

      expect(find.text('20'), findsOneWidget);
      expect(find.textContaining('3.2 km'), findsWidgets);
      expect(find.text('kg lifted'), findsNothing);
      expect(find.textContaining('0 kg'), findsNothing);
      expect(find.text('New best'), findsNothing);
      // the 8-week chart counts minutes, not tonnes.
      expect(find.text('Minutes over 8 weeks'), findsOneWidget);
      expect(find.text('Volume over 8 weeks'), findsNothing);
      expect(find.textContaining(' min over 8 weeks'), findsOneWidget);
      expect(find.textContaining(' t over 8 weeks'), findsNothing);

      await _unmount(tester);
    });

    testWidgets('a mixed session keeps kg lifted and reads a plank row in minutes',
        (tester) async {
      await tester.runAsync(() => WorkoutRepository(db).insert(Workout(
        id: 'mixed',
        name: 'Push plus core',
        startedAt: DateTime(2026, 6, 10, 9),
        endedAt: DateTime(2026, 6, 10, 10),
        sets: const [
          SetLog(id: 'mixed-1', exerciseId: 'bench', weightKg: 80, reps: 5, done: true),
          SetLog(
              id: 'mixed-2',
              exerciseId: 'plank',
              weightKg: 0,
              reps: 0,
              done: true,
              isPR: true,
              minutes: 2),
        ],
      )));
      await _pumpDetail(tester, db, workoutId: 'mixed');
      await tester.pump(_palLatency);

      expect(find.text('400'), findsOneWidget);
      expect(find.text('kg lifted'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('2 min'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('2 min'), findsOneWidget);
      expect(find.text('0 reps'), findsNothing);
      expect(find.text('New best'), findsNothing); // a timed set is never a record

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
// outlasts the mock Pal note's latency, whose timer the stream starts late.
const _palLatency = Duration(seconds: 1);

/// Pumps the detail screen as a route pushed over [_home], so it can pop.
/// The mock Pal's note latency, and a little more.
const _noteLatency = Duration(seconds: 1);

Future<void> _pumpDetail(WidgetTester tester, LoopDatabase db,
    {String workoutId = _workoutId}) async {
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
            builder: (context, state) => WorkoutDetailScreen(workoutId: workoutId),
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
  // a scroll can build the Pal note's section late; let its latency run out.
  await tester.pump(_noteLatency);
  await tester.pumpWidget(const SizedBox());
  await tester.pump(Duration.zero);
}
