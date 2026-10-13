import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
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
import 'package:opal/widgets/nav_bar.dart' show NavIconButton;

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
  // Widget — the summary, the note states, saving and the no-session fallback.
  // ---------------------------------------------------------------------------
  Workout prWorkout({DateTime? endedAt}) => Workout(
        id: 'active',
        name: 'Push Day A',
        startedAt: DateTime(2026, 6, 10, 9),
        endedAt: endedAt ?? DateTime(2026, 6, 10, 10),
        sets: const [
          SetLog(id: 'a', exerciseId: 'bench', weightKg: 80, reps: 5, done: true, isPR: true),
          SetLog(id: 'b', exerciseId: 'bench', weightKg: 80, reps: 5),
        ],
      );

  Future<void> pumpSummary(
    WidgetTester tester,
    Workout? workout, {
    List<Override> overrides = const [],
  }) async {
    // a phone width, tall enough that the whole summary lays out unculled.
    tester.view.physicalSize = const Size(390, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    await Seeder(db).seedIfNeeded();
    addTearDown(db.close);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (c, s) => PostWorkoutScreen(workout: workout)),
        GoRoute(path: '/move', builder: (c, s) => const Text('Move tab')),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [loopDatabaseProvider.overrideWithValue(db), ...overrides],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(useMaterial3: true, extensions: [AppColors.light()]),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // unmount, then drain the autoDispose drift stream provider's cleanup timer
  // (and any in-flight Pal-note latency timer) before the teardown invariant.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('PostWorkoutScreen renders the note, volume, best and sections',
      (tester) async {
    final w = prWorkout();
    await pumpSummary(tester, w, overrides: [
      postWorkoutNoteProvider(w).overrideWith((ref) async => 'A new best on bench.'),
    ]);

    expect(find.text('Done · Push Day A'), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is NavIconButton && w.semanticLabel == 'Back to Workout'),
      findsOneWidget,
    );
    expect(find.text('A new best on bench.'), findsOneWidget);
    expect(find.text('400'), findsOneWidget);
    expect(find.text('kg lifted'), findsOneWidget);
    expect(find.text('New best · Barbell Bench Press, 80 kg'), findsOneWidget);
    expect(find.text('1 of 2', findRichText: true), findsOneWidget);
    expect(find.text('Records'), findsOneWidget);
    expect(find.text('Muscles worked'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('By exercise'), findsOneWidget);
    expect(find.text('1 × 80 kg'), findsOneWidget);
    expect(find.text('Ahead'), findsOneWidget);
    expect(find.text('Save to timeline'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);

    await tester.tap(find.byType(NavIconButton));
    await tester.pumpAndSettle();
    expect(find.text('Move tab'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('PostWorkoutScreen shows seconds for a sub-minute session',
      (tester) async {
    final w = prWorkout(endedAt: DateTime(2026, 6, 10, 9, 0, 40));
    await pumpSummary(tester, w, overrides: [
      postWorkoutNoteProvider(w).overrideWith((ref) async => 'Quick one.'),
    ]);

    // 40s reads as "40 sec", never "0 min".
    expect(find.text('40 sec', findRichText: true), findsOneWidget);
    expect(find.text('0 min', findRichText: true), findsNothing);

    await unmount(tester);
  });

  testWidgets('the note reads muted while Pal is reading and when it fails',
      (tester) async {
    final w = prWorkout();
    final pending = Completer<String>();
    await pumpSummary(tester, w, overrides: [
      postWorkoutNoteProvider(w).overrideWith((ref) => pending.future),
    ]);
    final ink3 = AppColors.light().ink3;

    final reading = tester.widget<Text>(find.text('Pal is reading your session…'));
    expect(reading.style?.color, ink3);
    await unmount(tester);

    await pumpSummary(tester, w, overrides: [
      postWorkoutNoteProvider(w).overrideWith((ref) async => throw StateError('offline')),
    ]);
    final failed = tester.widget<Text>(find.text("Pal couldn't write a note just now."));
    expect(failed.style?.color, ink3);
    await unmount(tester);
  });

  testWidgets('Save shows Saving… then returns to the Move tab', (tester) async {
    final w = prWorkout();
    final gate = Completer<void>();
    await pumpSummary(tester, w, overrides: [
      postWorkoutNoteProvider(w).overrideWith((ref) async => 'Note.'),
      postWorkoutControllerProvider.overrideWith(() => _GatedSave(gate)),
    ]);

    await tester.tap(find.text('Save to timeline'));
    await tester.pump();
    expect(find.text('Saving…'), findsOneWidget);
    expect(find.text('Save to timeline'), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Move tab'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('no workout shows the no-session state with Back to Workout',
      (tester) async {
    await pumpSummary(tester, null);

    expect(find.text('No active session'), findsOneWidget);
    expect(find.text('Your last summary is no longer available.'), findsOneWidget);
    await tester.tap(find.text('Back to Workout'));
    await tester.pumpAndSettle();
    expect(find.text('Move tab'), findsOneWidget);

    await unmount(tester);
  });
}

/// Holds the save in flight until [gate] completes, so `Saving…` is visible.
class _GatedSave extends PostWorkoutController {
  _GatedSave(this.gate);

  final Completer<void> gate;

  @override
  Future<void> save(Workout workout) async {
    state = SaveState.saving;
    await gate.future;
    state = SaveState.saved;
  }
}
