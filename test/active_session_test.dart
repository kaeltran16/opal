import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:opal/controllers/providers.dart';
import 'package:opal/controllers/workout_session_controller.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/seed/seeder.dart';
import 'package:opal/screens/workout/active_session_screen.dart';
import 'package:opal/services/services.dart';
import 'package:opal/theme/app_colors.dart';
import 'package:opal/widgets/press_scale.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _routineId = 'seed-routine-push-a';
const _timedRoutineId = 'seed-routine-treadmill-int';

/// Records haptic calls so the wiring (medium @10s, success @0s) is observable.
class _SpyHaptics implements HapticsService {
  int lightCount = 0;
  int mediumCount = 0;
  int successCount = 0;
  @override
  void light() => lightCount++;
  @override
  void medium() => mediumCount++;
  @override
  void success() => successCount++;
}

/// Mounts [ActiveSessionScreen] pushed over a stub home inside a minimal
/// GoRouter (so minimise pops and Finish reaches the `postWorkout` stub),
/// with the seeded in-memory DB. Returns the container to read the session.
Future<ProviderContainer> _pump(
  WidgetTester tester,
  LoopDatabase db,
  SharedPreferences prefs,
  HapticsService haptics, {
  Size size = const Size(800, 2400),
  double textScale = 1,
  String routineId = _routineId,
}) async {
  // tall by default so the whole screen lays out without culling.
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const Scaffold(body: Text('Home'))),
      GoRoute(
        path: '/session/:routineId',
        name: 'activeSession',
        builder: (context, state) => ActiveSessionScreen(
          routineId: state.pathParameters['routineId']!,
        ),
      ),
      GoRoute(
        path: '/post',
        name: 'postWorkout',
        builder: (context, state) => const Scaffold(body: Text('Summary')),
      ),
    ],
  );

  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    loopDatabaseProvider.overrideWithValue(db),
    hapticsServiceProvider.overrideWithValue(haptics),
  ]);
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, extensions: [AppColors.light()]),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        routerConfig: router,
      ),
    ),
  );
  router.push('/session/$routineId');
  await tester.pumpAndSettle();
  return container;
}

ActiveSessionState _session(ProviderContainer container, [String routineId = _routineId]) =>
    container.read(workoutSessionControllerProvider(routineId)).requireValue;

Future<void> _tapLabel(WidgetTester tester, String label, {int times = 1}) async {
  for (var i = 0; i < times; i++) {
    await tester.tap(find.bySemanticsLabel(label));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

/// Cancels the controller's periodic rest timer so no timer outlives the test.
Future<void> _endRest(WidgetTester tester) async {
  await tester.tap(find.text('Skip rest'));
  await tester.pumpAndSettle();
}

/// Finishing releases the rest timer the last set started.
Future<void> _summary(WidgetTester tester) async {
  await tester.tap(find.text('See your summary'));
  await tester.pumpAndSettle();
}

void main() {
  late LoopDatabase db;
  late SharedPreferences prefs;
  late _SpyHaptics haptics;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = LoopDatabase.forTesting(NativeDatabase.memory());
    await Seeder(db).seedIfNeeded();
    haptics = _SpyHaptics();
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('renders the first exercise of the seeded Push Day A routine',
      (tester) async {
    await _pump(tester, db, prefs, haptics);

    expect(find.text('Push Day A'), findsOneWidget);
    expect(find.text('Chest · Barbell'), findsOneWidget);
    expect(find.text('Barbell Bench Press'), findsOneWidget);
    expect(find.text('Exercise 1 of 5'), findsOneWidget);
    expect(find.text('0 of 16 sets'), findsOneWidget);
    expect(find.text('Set 1 of 4'), findsOneWidget);
    expect(find.text('Best 92.5 kg × 5'), findsOneWidget);
    expect(find.text('Complete set'), findsOneWidget);
    expect(find.text('Rest'), findsNothing);
    expect(find.bySemanticsLabel(RegExp(r'^Elapsed \d')), findsOneWidget);
  });

  testWidgets('a timed session steps minutes and distance, not weight and reps',
      (tester) async {
    final container = await _pump(tester, db, prefs, haptics, routineId: _timedRoutineId);

    expect(find.text('Minutes'), findsOneWidget);
    expect(find.text('Distance'), findsOneWidget);
    expect(find.text('Weight'), findsNothing);
    expect(find.text('Reps'), findsNothing);
    expect(find.textContaining('kg'), findsNothing);
    expect(find.textContaining('Best'), findsNothing);

    await _tapLabel(tester, 'Fewer minutes', times: 9);
    await _tapLabel(tester, 'Fewer distance', times: 18);
    expect(find.text('21 min · 3.2 km'), findsOneWidget); // the current row follows the steppers
    await tester.tap(find.text('Complete set'));
    await tester.pumpAndSettle();

    final first = _session(container, _timedRoutineId).sets.first;
    expect(first.done, isTrue);
    expect(first.minutes, 21);
    expect(first.distanceKm, 3.2);
    expect(find.text('21 min · 3.2 km'), findsOneWidget);
    await _summary(tester);
  });

  testWidgets('distance at 0 reads No distance and logs null', (tester) async {
    final container = await _pump(tester, db, prefs, haptics, routineId: _timedRoutineId);

    await _tapLabel(tester, 'Fewer distance', times: 60);
    expect(find.text('No distance'), findsOneWidget);
    await _tapLabel(tester, 'Fewer minutes', times: 40);
    expect(find.text('1 min'), findsNWidgets(2)); // minutes floor at 1: stepper and row
    await tester.tap(find.text('Complete set'));
    await tester.pumpAndSettle();

    final first = _session(container, _timedRoutineId).sets.first;
    expect(first.minutes, 1);
    expect(first.distanceKm, isNull);
    await _summary(tester);
  });

  testWidgets('More weight then Complete set logs the target plus 2.5 kg',
      (tester) async {
    final container = await _pump(tester, db, prefs, haptics);

    await _tapLabel(tester, 'More weight');
    expect(find.text('92.5 kg × 5'), findsOneWidget); // the current row follows the stepper
    await tester.tap(find.text('Complete set'));
    await tester.pumpAndSettle();

    final first = _session(container).sets.first;
    expect(first.done, isTrue);
    expect(first.weightKg, 92.5);
    expect(first.reps, 5);
    // a non-PR set fires the light cue (success is reserved for PRs).
    expect(haptics.lightCount, greaterThan(0));
    await _endRest(tester);
  });

  testWidgets('Less weight floors at 0 and Fewer reps at 1', (tester) async {
    final container = await _pump(tester, db, prefs, haptics);

    // 90 kg is 36 steps; tap past it.
    await _tapLabel(tester, 'Less weight', times: 40);
    await _tapLabel(tester, 'Fewer reps', times: 8);
    expect(find.text('0 kg × 1'), findsOneWidget);

    await tester.tap(find.text('Complete set'));
    await tester.pumpAndSettle();
    final first = _session(container).sets.first;
    expect(first.weightKg, 0);
    expect(first.reps, 1);
    await _endRest(tester);
  });

  testWidgets('the ahead line shows only when the weight beats the best',
      (tester) async {
    await _pump(tester, db, prefs, haptics);

    expect(find.textContaining('Ahead of your best by'), findsNothing); // 90 < 92.5
    await _tapLabel(tester, 'More weight');
    expect(find.textContaining('Ahead of your best by'), findsNothing); // equal is not ahead
    await _tapLabel(tester, 'More weight');
    expect(find.text('Ahead of your best by 2.5 kg'), findsOneWidget);
    await _tapLabel(tester, 'Less weight');
    expect(find.textContaining('Ahead of your best by'), findsNothing);
  });

  testWidgets('resting offers +30 s and Skip rest, each driving the controller',
      (tester) async {
    final container = await _pump(tester, db, prefs, haptics);

    await tester.tap(find.text('Complete set'));
    await tester.pumpAndSettle();

    expect(find.text('Rest'), findsOneWidget);
    expect(find.text('Complete set'), findsNothing);
    expect(find.text('+30 s'), findsOneWidget);
    expect(find.text('Next: set 2 · 90 kg × 5'), findsOneWidget);
    final before = _session(container).restRemaining;
    expect(find.text('2:00'), findsOneWidget);

    await _tapLabel(tester, 'Add 30 seconds rest');
    expect(_session(container).restRemaining, before + 30);
    expect(find.text('2:30'), findsOneWidget);

    await _endRest(tester);
    expect(_session(container).isResting, isFalse);
    expect(find.text('Complete set'), findsOneWidget);
  });

  testWidgets('Skip exercise moves to the next exercise', (tester) async {
    final container = await _pump(tester, db, prefs, haptics);

    await tester.tap(find.text('Skip exercise'));
    await tester.pumpAndSettle();

    expect(_session(container).currentExerciseIndex, 1);
    expect(find.text('Overhead Press'), findsOneWidget);
    expect(find.text('Barbell Bench Press'), findsNothing);
    expect(find.text('Exercise 2 of 5'), findsOneWidget);
  });

  testWidgets('logging the last set shows All sets logged and See your summary finishes',
      (tester) async {
    final container = await _pump(tester, db, prefs, haptics);

    // skip to the last exercise: Skip exercise is gone once there is no next.
    while (find.text('Skip exercise').evaluate().isNotEmpty) {
      await tester.tap(find.text('Skip exercise'));
      await tester.pumpAndSettle();
    }
    while (find.text('Complete set').evaluate().isNotEmpty) {
      await tester.tap(find.text('Complete set'));
      await tester.pumpAndSettle();
      if (find.text('Skip rest').evaluate().isNotEmpty) await _endRest(tester);
    }

    expect(_session(container).isComplete, isTrue);
    expect(find.text('All sets logged'), findsOneWidget);
    expect(find.text('3 of 3 sets'), findsNWidgets(2)); // the progress line and the card
    expect(find.text('Add set'), findsNothing);

    await tester.tap(find.text('See your summary'));
    await tester.pumpAndSettle();
    expect(find.text('Summary'), findsOneWidget);
    expect(container.read(runningSessionProvider), isNull);
  });

  testWidgets('Finish opens a sheet; Keep going closes it and Finish summarises',
      (tester) async {
    await _pump(tester, db, prefs, haptics);

    await tester.tap(find.bySemanticsLabel('Finish'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Finish workout?'), findsOneWidget);
    expect(
      find.text('0 of 16 sets logged. This ends the session and shows your summary.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Keep going'));
    await tester.pumpAndSettle();
    expect(find.text('Finish workout?'), findsNothing);
    expect(find.text('Barbell Bench Press'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Finish'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(BottomSheet), matching: find.text('Finish')));
    await tester.pumpAndSettle();
    expect(find.text('Summary'), findsOneWidget);
  });

  testWidgets('minimise pops and the session keeps running', (tester) async {
    final container = await _pump(tester, db, prefs, haptics);

    await _tapLabel(tester, 'Minimise, the session keeps running');

    expect(find.text('Home'), findsOneWidget);
    expect(find.byType(ActiveSessionScreen), findsNothing);
    expect(container.read(runningSessionProvider), _routineId);
  });

  testWidgets('390 wide at text scale 1.3 has no overflow', (tester) async {
    await _pump(tester, db, prefs, haptics,
        size: const Size(390, 2400), textScale: 1.3);
    expect(tester.takeException(), isNull);

    // the heaviest the steppers get in practice, then the rest state.
    await _tapLabel(tester, 'More weight', times: 8);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Complete set'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Rest'), findsOneWidget);
    await _endRest(tester);
  });

  // the ahem test font draws Best and Skip exercise wider than half a 390 row,
  // so they would reach its end either way; the wide default shows the gap.
  testWidgets('Best sits at its row end', (tester) async {
    await _pump(tester, db, prefs, haptics);

    final best = find.text('Best 92.5 kg × 5');
    final row = find.ancestor(of: best, matching: find.byType(Row)).first;
    expect(tester.getTopRight(best).dx, moreOrLessEquals(tester.getRect(row).right, epsilon: 0.5));
  });

  testWidgets('Add set sits at the action row start and Skip exercise at its end', (tester) async {
    await _pump(tester, db, prefs, haptics);

    Finder target(String label) =>
        find.ancestor(of: find.text(label), matching: find.byType(PressScale)).first;
    final skip = target('Skip exercise');
    final row = tester.getRect(find.ancestor(of: skip, matching: find.byType(Row)).first);
    expect(tester.getRect(skip).right, moreOrLessEquals(row.right, epsilon: 0.5));
    expect(tester.getRect(target('Add set')).left, moreOrLessEquals(row.left, epsilon: 0.5));
    expect(tester.getSize(skip).height, greaterThanOrEqualTo(44));
  });

  testWidgets('390 wide at text scale 1.3 with long titles has no overflow', (tester) async {
    const long = 'Upper body push with a long accessory finisher block';
    await (db.update(db.routines)..where((r) => r.id.equals(_routineId)))
        .write(const RoutinesCompanion(name: Value(long)));
    await (db.update(db.exercises)..where((e) => e.name.equals('Barbell Bench Press')))
        .write(const ExercisesCompanion(name: Value('Paused barbell bench press with a long name')));
    await _pump(tester, db, prefs, haptics, size: const Size(390, 844), textScale: 1.3);

    expect(tester.takeException(), isNull);
    expect(find.text('Best 92.5 kg × 5'), findsOneWidget);
  });
}
