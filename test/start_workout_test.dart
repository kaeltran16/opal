import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/controllers/providers.dart';
import 'package:opal/controllers/workout_session_controller.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/seed/seeder.dart';
import 'package:opal/models/models.dart';
import 'package:opal/screens/workout/start_workout_screen.dart';
import 'package:opal/services/services.dart';
import 'package:opal/theme/app_colors.dart';

import 'support/flush_provider_timers.dart';

const _phone = Size(390, 844);
const _pushId = 'seed-routine-push-a';

/// Records the routineId the session was opened with. The target body itself
/// is inert.
class _Recorder {
  String? openedRoutineId;
}

class _Running extends RunningSession {
  _Running(this.id);
  final String id;

  @override
  String? build() => id;
}

/// A running session without the engine, so the lead's In progress card
/// renders without writing to the database.
class _FakeSession extends WorkoutSessionController {
  @override
  Future<ActiveSessionState> build(String routineId) async => ActiveSessionState(
        activeWorkout: Workout(
          id: 'active',
          routineId: routineId,
          name: 'Push Day A',
          startedAt: DateTime.now(),
          sets: const [SetLog(id: 's0', exerciseId: 'bench', weightKg: 60, reps: 8)],
        ),
        currentExerciseIndex: 0,
        currentSetIndex: 0,
        currentSet: null,
        restRemaining: 0,
        isResting: false,
        isComplete: false,
        exerciseIds: const ['bench'],
        catalog: const {},
      );
}

/// Mounts [StartWorkoutScreen] over the seeded routines (4 strength, 1 cardio)
/// in a minimal GoRouter + ProviderScope harness with a fast Pal.
Future<_Recorder> _pump(
  WidgetTester tester, {
  Size size = _phone,
  double textScale = 1,
  String? running,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final db = LoopDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  // drift writes need uncontrolled async.
  await tester.runAsync(() => Seeder(db).seedIfNeeded());

  final recorder = _Recorder();
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const StartWorkoutScreen()),
      GoRoute(
        path: '/session/:routineId',
        name: 'activeSession',
        builder: (_, state) {
          recorder.openedRoutineId = state.pathParameters['routineId'];
          return const SizedBox();
        },
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        loopDatabaseProvider.overrideWithValue(db),
        palServiceProvider.overrideWithValue(
            MockPalService(latency: const Duration(milliseconds: 1), seed: 1)),
        if (running != null) ...[
          runningSessionProvider.overrideWith(() => _Running(running)),
          workoutSessionControllerProvider.overrideWith(_FakeSession.new),
        ],
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, extensions: [AppColors.light()]),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return recorder;
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200,
      scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

void main() {
  for (final scale in [1.0, 1.3]) {
    testWidgets('at 390 wide and text scale $scale nothing overflows',
        (tester) async {
      // any RenderFlex overflow is reported as an exception and fails here.
      await _pump(tester, textScale: scale);
      expect(tester.takeException(), isNull);

      // scroll to the end so every row is laid out.
      await _scrollTo(tester, find.text('Exercise library'));
      expect(tester.takeException(), isNull);

      await flushProviderTimers(tester);
    });
  }

  testWidgets('lists the routines by kind and opens one on tap',
      (tester) async {
    final recorder = await _pump(tester);

    expect(find.text('Start workout'), findsWidgets);
    expect(find.text('Pick a routine'), findsOneWidget);
    expect(find.text("Pal's pick for today"), findsOneWidget);
    expect(find.text('Strength'), findsOneWidget);
    expect(find.text('Pull Day A'), findsOneWidget);

    await _scrollTo(tester, find.text('Treadmill Intervals'));
    expect(find.text('Cardio'), findsOneWidget);
    // the detail line carries the stats and the first exercise names.
    expect(find.textContaining(RegExp(r'^\d+ exercises · \d+ min · ')),
        findsWidgets);

    await _scrollTo(tester, find.text('Leg Day'));
    await tester.tap(find.text('Leg Day'));
    await tester.pumpAndSettle();
    expect(recorder.openedRoutineId, 'seed-routine-legs');

    await flushProviderTimers(tester);
  });

  testWidgets('the tool rows are there and Freestyle session is gone',
      (tester) async {
    await _pump(tester);
    await _scrollTo(tester, find.text('Exercise library'));

    expect(find.text('Generate with Pal'), findsOneWidget);
    expect(find.text('New routine'), findsOneWidget);
    expect(find.text('Freestyle session'), findsNothing);

    await flushProviderTimers(tester);
  });

  testWidgets('with another routine running, a routine opens the running one',
      (tester) async {
    final recorder = await _pump(tester, running: _pushId);
    expect(find.text('In progress'), findsOneWidget);

    await _scrollTo(tester, find.text('Leg Day'));
    await tester.tap(find.text('Leg Day'));
    await tester.pumpAndSettle();
    expect(recorder.openedRoutineId, _pushId);

    await flushProviderTimers(tester);
  });

  testWidgets('a long-press on a routine asks to delete it', (tester) async {
    await _pump(tester);

    await tester.longPress(find.text('Pull Day A'));
    await tester.pumpAndSettle();
    expect(find.text('Delete routine?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Delete routine?'), findsNothing);
    expect(find.text('Pull Day A'), findsOneWidget);

    await flushProviderTimers(tester);
  });
}
