import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:opal/controllers/post_workout_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/seed/seeder.dart';
import 'package:opal/models/models.dart';
import 'package:opal/screens/workout/post_workout_screen.dart';
import 'package:opal/services/pal/mock_pal_service.dart';
import 'package:opal/theme/app_colors.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Pure math — muscle-volume aggregation over completed sets only.
  // ---------------------------------------------------------------------------
  test('buildMuscleVolumes sums done-set volume per muscle, highest first', () {
    const catalog = [
      Exercise(id: 'bench', name: 'Bench', group: 'Push', muscle: 'Chest', icon: 'x'),
      Exercise(id: 'ohp', name: 'OHP', group: 'Push', muscle: 'Shoulders', icon: 'x'),
    ];
    final workout = Workout(
      id: 'w',
      name: 'Push',
      startedAt: DateTime(2026, 6, 10),
      sets: const [
        SetLog(id: '1', exerciseId: 'bench', weightKg: 100, reps: 5, done: true), // 500
        SetLog(id: '2', exerciseId: 'bench', weightKg: 100, reps: 5, done: true), // 500
        SetLog(id: '3', exerciseId: 'ohp', weightKg: 50, reps: 5, done: true), //   250
        SetLog(id: '4', exerciseId: 'bench', weightKg: 999, reps: 9), // not done -> ignored
        SetLog(id: '5', exerciseId: 'unknown', weightKg: 20, reps: 5, done: true), // Other
      ],
    );

    final m = buildMuscleVolumes(workout, catalog);
    expect(m.map((e) => e.muscle).toList(), ['Chest', 'Shoulders', 'Other']);
    expect(m.first.volumeKg, 1000); // two bench sets
    expect(m[1].volumeKg, 250);
    expect(m.last.muscle, 'Other'); // exercise absent from catalog
  });

  test('postWorkoutNote pluralizes the set count', () async {
    final pal = MockPalService(latency: Duration.zero);
    Workout w(List<SetLog> sets) =>
        Workout(id: 'w', name: 'x', startedAt: DateTime(2026, 6, 10), sets: sets);

    final one = await pal.postWorkoutNote(w(const [
      SetLog(id: '1', exerciseId: 'bench', weightKg: 60, reps: 8, done: true),
    ]));
    expect(one, contains('1 set in the bank'));

    final two = await pal.postWorkoutNote(w(const [
      SetLog(id: '1', exerciseId: 'bench', weightKg: 60, reps: 8, done: true),
      SetLog(id: '2', exerciseId: 'bench', weightKg: 60, reps: 8, done: true),
    ]));
    expect(two, contains('2 sets in the bank'));
  });

  // ---------------------------------------------------------------------------
  // Save (SF-5) — persists the workout (done sets only) + a linked move Entry.
  // ---------------------------------------------------------------------------
  test('save() writes the workout and a linked move entry; drops unlogged sets',
      () async {
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    await Seeder(db).seedIfNeeded(); // set_logs.exercise_id FK needs the catalog
    addTearDown(db.close);

    final container = ProviderContainer(
      overrides: [loopDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    // hold the autoDispose controller alive across the awaited save.
    container.listen(postWorkoutControllerProvider, (_, _) {});

    final workout = Workout(
      id: 'active',
      routineId: 'r1',
      name: 'U14 Save Test', // unique so it's findable amongst seed workouts
      startedAt: DateTime(2026, 6, 10, 9),
      endedAt: DateTime(2026, 6, 10, 10),
      sets: const [
        SetLog(id: 'a', exerciseId: 'bench', weightKg: 80, reps: 5, done: true, isPR: true),
        SetLog(id: 'b', exerciseId: 'bench', weightKg: 80, reps: 5, done: true),
        SetLog(id: 'c', exerciseId: 'bench', weightKg: 80, reps: 5), // not logged
      ],
    );

    final workoutRepo = container.read(workoutRepositoryProvider);
    final before = (await workoutRepo.watchWorkouts().first).length;

    await container.read(postWorkoutControllerProvider.notifier).save(workout);
    expect(container.read(postWorkoutControllerProvider), SaveState.saved);

    final all = await workoutRepo.watchWorkouts().first;
    expect(all.length, before + 1); // exactly one workout added
    final saved = all.firstWhere((w) => w.name == 'U14 Save Test');
    expect(saved.id, isNot('active')); // fresh uuid assigned
    expect(saved.sets.length, 2); // only the two completed sets
    expect(saved.totalVolumeKg, 800);
    expect(saved.prCount, 1);

    final entries = await container.read(entryRepositoryProvider).getAll();
    final mine = entries.where((e) => e.workoutId == saved.id).toList();
    expect(mine.length, 1);
    expect(mine.first.type, EntryType.move);
    expect(mine.first.source, EntrySource.manual);
    expect(mine.first.duration, 60); // one hour
  });

  test('save() is idempotent — a second call does not double-write', () async {
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    await Seeder(db).seedIfNeeded(); // set_logs.exercise_id FK needs the catalog
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [loopDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    container.listen(postWorkoutControllerProvider, (_, _) {});

    final workout = Workout(
      id: 'active',
      name: 'U14 Idem Test',
      startedAt: DateTime(2026, 6, 10, 9),
      endedAt: DateTime(2026, 6, 10, 9, 30),
      sets: const [
        SetLog(id: 'a', exerciseId: 'bench', weightKg: 60, reps: 8, done: true),
      ],
    );
    final workoutRepo = container.read(workoutRepositoryProvider);
    final before = (await workoutRepo.watchWorkouts().first).length;

    final notifier = container.read(postWorkoutControllerProvider.notifier);
    await notifier.save(workout);
    await notifier.save(workout); // latched at saved -> no-op

    final all = await workoutRepo.watchWorkouts().first;
    expect(all.length, before + 1); // only one added despite two save calls
  });

  // ---------------------------------------------------------------------------
  // Widget — celebration hero, set chips, and the save action render.
  // ---------------------------------------------------------------------------
  testWidgets('PostWorkoutScreen renders hero, set chip, and save button',
      (tester) async {
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    await Seeder(db).seedIfNeeded();
    addTearDown(db.close);

    final workout = Workout(
      id: 'active',
      name: 'Push Day A',
      startedAt: DateTime(2026, 6, 10, 9),
      endedAt: DateTime(2026, 6, 10, 10),
      sets: const [
        SetLog(id: 'a', exerciseId: 'bench', weightKg: 80, reps: 5, done: true, isPR: true),
      ],
    );

    final colors = AppColors.light(AppAccent.blue);
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (c, s) => PostWorkoutScreen(workout: workout)),
        GoRoute(path: '/move', builder: (c, s) => const SizedBox()),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [loopDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(useMaterial3: true, extensions: [colors]),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nice session.'), findsOneWidget);
    expect(find.text('COMPLETE'), findsOneWidget);
    // the standalone PERSONAL RECORD card surfaces the PR set.
    expect(find.text('PERSONAL RECORD'), findsOneWidget);
    expect(find.text('Save to timeline'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);

    // Hero stats: singular labels for a 1-set / 1-PR session, and volume in kg
    // (400 < 1 tonne) so it matches the per-muscle/per-exercise row units.
    expect(find.text('SET'), findsOneWidget);
    expect(find.text('PR'), findsOneWidget);
    expect(find.text('400'), findsOneWidget);

    // The per-exercise set bar chart sits below the fold — scroll it in.
    await tester.scrollUntilVisible(find.text('80×5'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('80×5'), findsOneWidget); // the logged set bar label

    // unmount, then drain the autoDispose drift stream provider's cleanup timer
    // (and any in-flight Pal-note latency timer) before the teardown invariant.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('PostWorkoutScreen hero shows seconds for a sub-minute session',
      (tester) async {
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    await Seeder(db).seedIfNeeded();
    addTearDown(db.close);

    final workout = Workout(
      id: 'active',
      name: 'Quick set',
      startedAt: DateTime(2026, 6, 10, 9, 0, 0),
      endedAt: DateTime(2026, 6, 10, 9, 0, 40), // 40 seconds
      sets: const [
        SetLog(id: 'a', exerciseId: 'bench', weightKg: 80, reps: 5, done: true),
      ],
    );

    final colors = AppColors.light(AppAccent.blue);
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (c, s) => PostWorkoutScreen(workout: workout)),
        GoRoute(path: '/move', builder: (c, s) => const SizedBox()),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [loopDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(useMaterial3: true, extensions: [colors]),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 40s reads as "40 sec", never "0 min".
    expect(find.text('40'), findsOneWidget);
    expect(find.text('sec'), findsOneWidget);
    expect(find.text('min'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
