import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/controllers/providers.dart';
import 'package:opal/controllers/watch_workout.dart';
import 'package:opal/controllers/workout_session_controller.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/seed/seeder.dart';
import 'package:opal/models/models.dart' hide Provider;
import 'package:opal/services/services.dart';

const _pushA = 'seed-routine-push-a';
const _treadmill = 'seed-routine-treadmill-int';
const _bench0 = 'seed-rex-push-bench-set-0';
const _bench1 = 'seed-rex-push-bench-set-1';

class _SilentHaptics implements HapticsService {
  @override
  void light() {}
  @override
  void medium() {}
  @override
  void success() {}
}

/// Records what the phone tells the Watch.
class _FakeWatch implements WatchWorkoutService {
  _FakeWatch({this.endStats});

  final WatchWorkoutStats? endStats;
  final started = <bool>[];
  final pushed = <WatchReply>[];
  var ended = 0;

  @override
  Future<void> start({required bool cardio}) async => started.add(cardio);

  @override
  Future<void> push(WatchReply snapshot) async => pushed.add(snapshot);

  @override
  Future<WatchWorkoutStats?> end() async {
    ended++;
    return endStats;
  }
}

void main() {
  late LoopDatabase db;
  late ProviderContainer container;
  late _FakeWatch watch;
  var opened = false;

  Future<void> open(String routineId, {WatchWorkoutStats? endStats}) async {
    watch = _FakeWatch(endStats: endStats);
    opened = true;
    container = ProviderContainer(overrides: [
      loopDatabaseProvider.overrideWithValue(db),
      hapticsServiceProvider.overrideWithValue(_SilentHaptics()),
      watchWorkoutServiceProvider.overrideWithValue(watch),
    ]);
    container.read(runningSessionProvider.notifier).start(routineId);
    container.listen(workoutSessionControllerProvider(routineId), (_, _) {});
    await container.read(workoutSessionControllerProvider(routineId).future);
  }

  Future<WatchReply> send(String command, [Map<String, Object?> extra = const {}]) =>
      container.read(watchWorkoutProvider).handle({
        WatchKeys.type: WatchKeys.workout,
        WatchKeys.command: command,
        ...extra,
      });

  ActiveSessionState session(String routineId) =>
      container.read(workoutSessionControllerProvider(routineId)).requireValue;

  setUp(() async {
    db = LoopDatabase.forTesting(NativeDatabase.memory());
    await Seeder(db).seedIfNeeded();
  });

  tearDown(() async {
    if (opened) container.dispose();
    opened = false;
    await db.close();
  });

  test('starting a session opens the Watch workout and sends the first set', () async {
    await open(_pushA);

    expect(watch.started, [false]);
    final first = watch.pushed.single;
    expect(first[WatchKeys.phase], WatchKeys.phaseSet);
    expect(first[WatchKeys.setId], _bench0);
    expect(first[WatchKeys.exercise], 'Barbell Bench Press');
    expect(first[WatchKeys.setLabel], 'Set 1 of 4');
    expect(first[WatchKeys.planned], '90 kg × 5');
    expect(first[WatchKeys.best], 'Best 92.5 kg × 5');
    expect(first.containsKey(WatchKeys.ahead), isFalse);
    expect(first[WatchKeys.progress], 'Barbell Bench Press · 1 of 4 sets');
    expect(first[WatchKeys.canSkip], isTrue);
  });

  test('a cardio routine starts a cardio Watch workout', () async {
    await open(_treadmill);

    expect(watch.started, [true]);
  });

  test('with no session running the Watch hears there is no workout', () async {
    await open(_pushA);
    container.read(runningSessionProvider.notifier).clear();

    expect(await send(WatchKeys.state), noWorkout);
  });

  test('Complete set logs the planned set and answers with the rest', () async {
    await open(_pushA);

    final reply = await send(WatchKeys.complete, {WatchKeys.setId: _bench0});

    final logged = session(_pushA).sets.first;
    expect(logged.done, isTrue);
    expect(logged.weightKg, 90);
    expect(logged.reps, 5);
    expect(reply[WatchKeys.phase], WatchKeys.phaseRest);
    expect(reply[WatchKeys.setId], _bench1);
    expect(reply[WatchKeys.next], 'Set 2 · 90 kg × 5');
    expect(reply[WatchKeys.restTotal], 120);
    final endsAt = DateTime.fromMillisecondsSinceEpoch(reply[WatchKeys.restEndsAt]! as int);
    expect(endsAt.difference(DateTime.now()).inSeconds, inInclusiveRange(118, 120));
    // the reply is the snapshot the phone pushed
    expect(watch.pushed.last, reply);
  });

  test('a repeated Complete set for a set already logged logs nothing more', () async {
    await open(_pushA);
    await send(WatchKeys.complete, {WatchKeys.setId: _bench0});

    final reply = await send(WatchKeys.complete, {WatchKeys.setId: _bench0});

    expect(session(_pushA).sets.where((s) => s.done), hasLength(1));
    expect(reply[WatchKeys.setId], _bench1);
  });

  test('+30 s and Skip rest act only while resting', () async {
    await open(_pushA);
    await send(WatchKeys.addRest);
    expect(session(_pushA).isResting, isFalse);

    await send(WatchKeys.complete, {WatchKeys.setId: _bench0});
    final longer = await send(WatchKeys.addRest);
    expect(longer[WatchKeys.restTotal], 150);
    expect(session(_pushA).restRemaining, 150);

    final skipped = await send(WatchKeys.skipRest);
    expect(skipped[WatchKeys.phase], WatchKeys.phaseSet);
    expect(session(_pushA).isResting, isFalse);
  });

  test('Add set and Skip exercise apply to the set the Watch showed', () async {
    await open(_pushA);

    final stale = await send(WatchKeys.addSet, {WatchKeys.setId: _bench1});
    expect(stale[WatchKeys.setLabel], 'Set 1 of 4');

    final added = await send(WatchKeys.addSet, {WatchKeys.setId: _bench0});
    expect(added[WatchKeys.setLabel], 'Set 1 of 5');

    final skipped = await send(WatchKeys.skipExercise, {WatchKeys.setId: _bench0});
    expect(skipped[WatchKeys.exercise], isNot('Barbell Bench Press'));
    expect(session(_pushA).currentExerciseIndex, 1);
  });

  test('a planned weight above the best shows the Ahead line instead', () {
    const bench = Exercise(
      id: 'bench',
      name: 'Bench press',
      group: 'Push',
      muscle: 'Chest',
      icon: 'x',
      pr: ExercisePR(weightKg: 62.5, reps: 6),
    );
    final state = ActiveSessionState(
      activeWorkout: Workout(
        id: 'active',
        name: 'Push',
        startedAt: DateTime(2026, 10, 30, 9),
        sets: const [SetLog(id: 's0', exerciseId: 'bench', weightKg: 65, reps: 8)],
      ),
      currentExerciseIndex: 0,
      currentSetIndex: 0,
      currentSet: const SetLog(id: 's0', exerciseId: 'bench', weightKg: 65, reps: 8),
      restRemaining: 0,
      isResting: false,
      isComplete: false,
      exerciseIds: const ['bench'],
      catalog: const {'bench': bench},
    );

    final snapshot = buildWatchSnapshot(state, rev: 1, restSeconds: 90);

    expect(snapshot[WatchKeys.ahead], 'Ahead of your best by 2.5 kg');
    expect(snapshot.containsKey(WatchKeys.best), isFalse);
  });

  test('a timed set logs the Watch distance, or the plan when it measured none', () async {
    await open(_treadmill);
    final setId = session(_treadmill).currentSet!.id;
    final first = watch.pushed.single;
    expect(first[WatchKeys.timed], isTrue);
    expect(first[WatchKeys.planned], '30 min');
    expect(first.containsKey(WatchKeys.best), isFalse);

    await send(WatchKeys.complete, {WatchKeys.setId: setId, WatchKeys.distanceKm: 4.2});

    final logged = session(_treadmill).sets.single;
    expect(logged.minutes, 30);
    expect(logged.distanceKm, 4.2);
  });

  test('a timed set without a Watch distance keeps the planned distance', () async {
    await open(_treadmill);
    final setId = session(_treadmill).currentSet!.id;

    final reply = await send(WatchKeys.complete, {WatchKeys.setId: setId, WatchKeys.distanceKm: 0});

    expect(session(_treadmill).sets.single.distanceKm, 5);
    expect(reply[WatchKeys.phase], WatchKeys.phaseDone);
    expect(reply[WatchKeys.logged], '1 of 1 sets');
  });

  test('Finish on the Watch keeps its numbers and opens the summary', () async {
    await open(_pushA);
    await send(WatchKeys.complete, {WatchKeys.setId: _bench0});
    final finished = container.read(watchWorkoutProvider).finishedOnWatch.first;

    final reply = await send(WatchKeys.finish, {WatchKeys.heartRate: 128.4, WatchKeys.kcal: 412});

    final workout = await finished;
    expect(workout.avgHeartRate, 128);
    expect(workout.activeKcal, 412);
    expect(workout.endedAt, isNotNull);
    expect(reply[WatchKeys.phase], WatchKeys.phaseEnded);
    // the Watch ends its own workout; the phone doesn't ask
    expect(watch.ended, 0);
    expect(container.read(runningSessionProvider), isNull);
  });

  test('Finish on the phone asks the Watch for its numbers', () async {
    await open(_pushA, endStats: const WatchWorkoutStats(heartRate: 131, kcal: 380));

    final workout =
        await container.read(workoutSessionControllerProvider(_pushA).notifier).finish();

    expect(watch.ended, 1);
    expect(workout.avgHeartRate, 131);
    expect(workout.activeKcal, 380);
    expect(watch.pushed.last[WatchKeys.phase], WatchKeys.phaseEnded);
  });

  test('Finish on the phone without the Watch saves no numbers', () async {
    await open(_pushA);

    final workout =
        await container.read(workoutSessionControllerProvider(_pushA).notifier).finish();

    expect(workout.avgHeartRate, isNull);
    expect(workout.activeKcal, isNull);
  });
}
