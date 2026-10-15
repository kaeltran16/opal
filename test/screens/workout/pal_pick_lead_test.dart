import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/controllers/move_controller.dart';
import 'package:opal/controllers/start_workout_controller.dart';
import 'package:opal/controllers/weekly_plan_controller.dart';
import 'package:opal/controllers/workout_session_controller.dart';
import 'package:opal/models/models.dart';
import 'package:opal/screens/workout/pal_pick_lead.dart';
import 'package:opal/services/pal/pal_service.dart';
import 'package:opal/theme/theme.dart';

const _rationale = 'Legs have rested four days. Squats feel best after a rest.';
const _canvasSample = 'Push today. You lift heavier before 6.';
const _suggestion = WorkoutSuggestion(
  title: 'Leg Day',
  rationale: _rationale,
  routineId: 'r-legs',
  estimatedMinutes: 50,
  focus: 'Legs',
);

class _FakePick extends PalPickController {
  _FakePick(this.result);

  final Future<WorkoutSuggestion> Function() result;
  int anotherCalls = 0;

  @override
  Future<WorkoutSuggestion> build() => result();

  @override
  Future<void> another() async => anotherCalls++;
}

class _Running extends RunningSession {
  _Running(this.id);
  final String? id;

  @override
  String? build() => id;
}

class _FakeSession extends WorkoutSessionController {
  @override
  Future<ActiveSessionState> build(String routineId) async => _session();
}

ActiveSessionState _session() {
  const bench = Exercise(
    id: 'bench',
    name: 'Bench press',
    group: 'Push',
    muscle: 'Chest',
    icon: 'dumbbell',
  );
  return ActiveSessionState(
    activeWorkout: Workout(
      id: 'active',
      routineId: 'r-push',
      name: 'Push Day A',
      startedAt: DateTime.now(),
      sets: const [
        SetLog(id: 's0', exerciseId: 'bench', weightKg: 60, reps: 8, done: true),
        SetLog(id: 's1', exerciseId: 'bench', weightKg: 60, reps: 8, done: true),
        SetLog(id: 's2', exerciseId: 'bench', weightKg: 60, reps: 8),
      ],
    ),
    currentExerciseIndex: 0,
    currentSetIndex: 2,
    currentSet: null,
    restRemaining: 0,
    isResting: false,
    isComplete: false,
    exerciseIds: const ['bench'],
    catalog: const {'bench': bench},
  );
}

MoveState _move({bool doneToday = false}) => MoveState(
  moveKcal: 0,
  recentSessions: [
    if (doneToday)
      RecentSession(
        workout: Workout(id: 'w1', name: 'Push Day A', startedAt: DateTime.now()),
        relativeDate: 'Today',
        isCardio: false,
      ),
  ],
  otherActivity: const [],
  routineCount: 3,
  weekDays: const [],
  weekWorkouts: doneToday ? 1 : 0,
  weekVolumeKg: 0,
  weekMinutes: 0,
  weekPrCount: 0,
  weekGoal: 3,
);

/// Mon..Sun with today on Wednesday; [planned] maps a weekday index to a routine.
WeeklyPlan _plan(Map<int, String> planned) => WeeklyPlan(
  days: [
    for (var i = 0; i < 7; i++)
      planned[i] == null
          ? WeekPlanDay(
              day: 'D$i',
              date: i + 1,
              type: 'Rest',
              colorKey: 'rest',
              icon: 'moon',
              today: i == 2,
            )
          : WeekPlanDay(
              day: 'D$i',
              date: i + 1,
              type: 'Pull',
              routine: planned[i],
              colorKey: 'move',
              icon: 'dumbbell',
              today: i == 2,
            ),
  ],
);

Future<_FakePick> _pump(
  WidgetTester tester, {
  Future<WorkoutSuggestion> Function()? pick,
  String? running,
  bool doneToday = false,
  Map<int, String> planned = const {},
  bool onPicker = false,
}) async {
  final fake = _FakePick(pick ?? () async => _suggestion);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        palPickControllerProvider.overrideWith(() => fake),
        runningSessionProvider.overrideWith(() => _Running(running)),
        workoutSessionControllerProvider.overrideWith(_FakeSession.new),
        moveStateProvider.overrideWith((ref) => Stream.value(_move(doneToday: doneToday))),
        weeklyPlanControllerProvider.overrideWith((ref) => Stream.value(_plan(planned))),
        startWorkoutProvider.overrideWith(
          (ref) => Stream.value(const StartWorkoutState(strength: [], cardio: [])),
        ),
      ],
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [AppColors.light()]),
        home: Scaffold(body: PalPickLead(onPicker: onPicker)),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return fake;
}

/// Unmounts so the in-progress clock's timer is cancelled.
Future<void> _unmount(WidgetTester tester) => tester.pumpWidget(const SizedBox());

void main() {
  testWidgets("Pal's line is the suggestion's rationale, not the canvas sample", (tester) async {
    await _pump(tester);

    expect(find.text(_rationale), findsOneWidget);
    expect(find.text(_canvasSample), findsNothing);
    expect(find.text("Pal's pick for today"), findsOneWidget);
    expect(find.text('Leg Day'), findsOneWidget);
    expect(find.text('50 min · Legs'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
  });

  testWidgets('Pick another asks the controller for another pick', (tester) async {
    final fake = await _pump(tester);

    await tester.tap(find.bySemanticsLabel('Pick another'));
    await tester.pump();

    expect(fake.anotherCalls, 1);
  });

  testWidgets('while loading, the line is a muted Thinking… and there is no card', (tester) async {
    final never = Completer<WorkoutSuggestion>();
    await _pump(tester, pick: () => never.future);

    final line = tester.widget<Text>(find.text('Thinking…'));
    expect(line.style!.color, AppColors.light().ink3);
    expect(find.text('Start'), findsNothing);
    expect(find.text('Pick another'), findsNothing);
  });

  testWidgets('on error, the tab offers Start workout and Try again', (tester) async {
    final fake = await _pump(tester, pick: () => Future.error(StateError('offline')));

    expect(find.text("Pal couldn't pick one just now."), findsOneWidget);
    expect(find.text('Pick a routine'), findsOneWidget);
    expect(find.text('Start workout'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Try again'));
    await tester.pump();
    expect(fake.anotherCalls, 1);
  });

  testWidgets('on error, the picker points at the list with Try again only', (tester) async {
    await _pump(tester, pick: () => Future.error(StateError('offline')), onPicker: true);

    expect(find.text("Pal couldn't pick one just now."), findsOneWidget);
    expect(find.text('Pick a routine below'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Start workout'), findsNothing);
  });

  testWidgets('a running session shows In progress and Resume', (tester) async {
    await _pump(tester, running: 'r-push');

    expect(find.text('In progress'), findsOneWidget);
    expect(find.text('2 sets in, 1 to go.'), findsOneWidget);
    expect(find.text('Push Day A'), findsOneWidget);
    expect(find.textContaining('Bench press'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);
    expect(find.text('Pick another'), findsNothing);
    await _unmount(tester);
  });

  testWidgets('settled: names the next planned routine and its day', (tester) async {
    await _pump(tester, doneToday: true, planned: {1: 'Push Day A', 4: 'Pull Day A'});

    expect(find.text('Push Day A is done. Pull Day A is next, on Friday.'), findsOneWidget);
    expect(find.text('Start'), findsNothing);
    expect(find.text('Pick another'), findsNothing);
  });

  testWidgets('settled skips a next slot that is the routine just done', (tester) async {
    await _pump(tester, doneToday: true, planned: {4: 'Push Day A', 5: 'Pull Day A'});

    expect(find.text('Push Day A is done. Pull Day A is next, on Saturday.'), findsOneWidget);
  });

  testWidgets('settled with only the same routine later ends after is done.', (tester) async {
    await _pump(tester, doneToday: true, planned: {4: 'Push Day A'});

    expect(find.text('Push Day A is done.'), findsOneWidget);
  });

  testWidgets('settled with nothing planned later ends after is done.', (tester) async {
    await _pump(tester, doneToday: true, planned: {0: 'Legs'});

    expect(find.text('Push Day A is done.'), findsOneWidget);
    expect(find.text('Start'), findsNothing);
  });

  testWidgets('the picker reads the settled day too, with no second pick', (tester) async {
    await _pump(tester, doneToday: true, onPicker: true, planned: {4: 'Pull Day A'});

    expect(find.text('Push Day A is done. Pull Day A is next, on Friday.'), findsOneWidget);
    expect(find.text(_rationale), findsNothing);
  });

  testWidgets('in progress takes precedence over settled', (tester) async {
    await _pump(tester, running: 'r-push', doneToday: true, planned: {4: 'Pull Day A'});

    expect(find.text('In progress'), findsOneWidget);
    expect(find.textContaining('is done.'), findsNothing);
    await _unmount(tester);
  });
}
