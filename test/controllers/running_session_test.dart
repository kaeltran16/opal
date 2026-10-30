import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/controllers/providers.dart';
import 'package:opal/controllers/workout_session_controller.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/seed/seeder.dart';
import 'package:opal/services/services.dart';

const _routineId = 'seed-routine-push-a';

class _SilentHaptics implements HapticsService {
  @override
  void light() {}
  @override
  void medium() {}
  @override
  void success() {}
}

/// Lets scheduled provider disposal and post-build microtasks run.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late LoopDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = LoopDatabase.forTesting(NativeDatabase.memory());
    await Seeder(db).seedIfNeeded();
    container = ProviderContainer(overrides: [
      loopDatabaseProvider.overrideWithValue(db),
      hapticsServiceProvider.overrideWithValue(_SilentHaptics()),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  final session = workoutSessionControllerProvider(_routineId);

  test('the session survives its listener going away, logged sets intact',
      () async {
    final sub = container.listen(session, (_, _) {});
    final first = await container.read(session.future);
    final set = first.currentSet!;
    container
        .read(session.notifier)
        .logCurrentSet(weightKg: set.weightKg, reps: set.reps);

    sub.close(); // minimise: the screen stops watching
    await _settle();

    final after = container.read(session);
    expect(after.hasValue, isTrue);
    expect(after.requireValue.sets.where((s) => s.done).length, 1);
    expect(after.requireValue.activeWorkout.startedAt,
        first.activeWorkout.startedAt);
  });

  test('finish() clears the running session and a re-read starts fresh',
      () async {
    final sub = container.listen(session, (_, _) {});
    final first = await container.read(session.future);
    final set = first.currentSet!;
    final notifier = container.read(session.notifier);
    notifier.logCurrentSet(weightKg: set.weightKg, reps: set.reps);
    await _settle();
    expect(container.read(runningSessionProvider), _routineId);

    final workout = await notifier.finish();
    expect(workout.endedAt, isNotNull);
    expect(workout.sets.where((s) => s.done).length, 1);
    expect(container.read(runningSessionProvider), isNull);

    sub.close(); // the session screen leaves for the summary
    await _settle();

    final fresh = await container.read(session.future);
    expect(fresh.sets.where((s) => s.done), isEmpty);
    expect(fresh.activeWorkout.endedAt, isNull);
  });

  test('building the controller for routine X marks X as running', () async {
    expect(container.read(runningSessionProvider), isNull);

    final sub = container.listen(session, (_, _) {});
    await container.read(session.future);
    await _settle();

    expect(container.read(runningSessionProvider), _routineId);
    sub.close();
  });

  test('RunningSession start and clear', () {
    final running = container.read(runningSessionProvider.notifier);
    running.start('a');
    expect(container.read(runningSessionProvider), 'a');
    running.clear();
    expect(container.read(runningSessionProvider), isNull);
  });
}
