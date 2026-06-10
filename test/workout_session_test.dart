import 'package:flutter_test/flutter_test.dart';
import 'package:loop/controllers/workout_session.dart';
import 'package:loop/models/models.dart';

/// Two-exercise routine: bench (3 sets @ 50×6), row (2 sets @ 40×8), rest 90s.
Routine _routine() => Routine(
      id: 'r1',
      name: 'Push Day A',
      tag: RoutineTag.upper,
      restSeconds: 90,
      exercises: const [
        RoutineExercise(
          id: 're-bench',
          exerciseId: 'bench',
          order: 0,
          targetSets: 3,
          targetReps: 6,
          targetWeightKg: 50,
        ),
        RoutineExercise(
          id: 're-row',
          exerciseId: 'row',
          order: 1,
          targetSets: 2,
          targetReps: 8,
          targetWeightKg: 40,
        ),
      ],
    );

/// Catalog with a historical bench PR of 55×5 = 275 volume.
List<Exercise> _catalog() => const [
      Exercise(
        id: 'bench',
        name: 'Bench Press',
        group: 'Push',
        muscle: 'Chest',
        icon: 'figure.strengthtraining.traditional',
        pr: ExercisePR(weightKg: 55, reps: 5),
      ),
      Exercise(
        id: 'row',
        name: 'Barbell Row',
        group: 'Pull',
        muscle: 'Back',
        icon: 'figure.rower',
      ),
    ];

WorkoutSession _session() => WorkoutSession(
      routine: _routine(),
      exercises: _catalog(),
      startedAt: DateTime(2026, 6, 10, 8),
    );

void main() {
  group('seeding', () {
    test('seeds target sets per exercise with prefilled target values', () {
      final s = _session();
      // 3 bench + 2 row = 5 sets, none done.
      expect(s.sets.length, 5);
      expect(s.sets.where((x) => x.done), isEmpty);

      final bench = s.sets.where((x) => x.exerciseId == 'bench').toList();
      expect(bench.length, 3);
      expect(bench.first.weightKg, 50);
      expect(bench.first.reps, 6);

      expect(s.currentExerciseIndex, 0);
      expect(s.currentSetIndex, 0);
      expect(s.isResting, isFalse);
    });
  });

  group('logCurrentSet advances and starts rest (behavior 1)', () {
    test('completing the current set advances the cursor and starts rest', () {
      final s = _session();
      expect(s.currentSet?.exerciseId, 'bench');

      s.logCurrentSet(weightKg: 50, reps: 6);

      // first bench set is now done...
      final firstBench = s.sets.firstWhere((x) => x.id == 're-bench-set-0');
      expect(firstBench.done, isTrue);
      expect(firstBench.weightKg, 50);
      expect(firstBench.reps, 6);

      // ...cursor moved to the second bench set...
      expect(s.currentExerciseIndex, 0);
      expect(s.currentSetIndex, 1);

      // ...and the rest timer is running at the routine's rest length.
      expect(s.restRemaining, 90);
      expect(s.isResting, isTrue);
    });

    test('advances across exercise boundary to the next exercise', () {
      final s = _session();
      s.logCurrentSet(weightKg: 50, reps: 6); // bench 1
      s.logCurrentSet(weightKg: 50, reps: 6); // bench 2
      s.logCurrentSet(weightKg: 50, reps: 6); // bench 3 -> rolls to row

      expect(s.currentExerciseIndex, 1);
      expect(s.currentSetIndex, 0);
      expect(s.currentSet?.exerciseId, 'row');
    });

    test('logging when complete is a no-op', () {
      final s = _session();
      for (var i = 0; i < 5; i++) {
        s.logCurrentSet(weightKg: 50, reps: 6);
      }
      expect(s.isComplete, isTrue);
      expect(s.currentSet, isNull);

      s.logCurrentSet(weightKg: 999, reps: 9); // ignored
      expect(s.sets.where((x) => x.weightKg == 999), isEmpty);
    });
  });

  group('rest timer tick (behavior 2)', () {
    test('tick counts down to 0 and stops, never going negative', () {
      final s = _session();
      s.logCurrentSet(weightKg: 50, reps: 6);
      expect(s.restRemaining, 90);

      for (var i = 0; i < 90; i++) {
        s.tick();
      }
      expect(s.restRemaining, 0);
      expect(s.isResting, isFalse);

      // extra ticks stay clamped, never negative, still stopped.
      s.tick();
      expect(s.restRemaining, 0);
      expect(s.isResting, isFalse);
    });

    test('skipRest and addRestTime manipulate the timer', () {
      final s = _session();
      s.logCurrentSet(weightKg: 50, reps: 6);

      s.addRestTime(30);
      expect(s.restRemaining, 120);
      expect(s.isResting, isTrue);

      s.skipRest();
      expect(s.restRemaining, 0);
      expect(s.isResting, isFalse);
    });
  });

  group('PR detection (behavior 3)', () {
    test('a heavier-than-history set is flagged isPR, a lighter one is not', () {
      final s = _session();
      // history bench PR = 55×5 = 275. 60×6 = 360 > 275 -> PR.
      s.logCurrentSet(weightKg: 60, reps: 6);
      final prSet = s.sets.firstWhere((x) => x.id == 're-bench-set-0');
      expect(prSet.isPR, isTrue);

      // 50×6 = 300 > new session best 360? no -> not a PR.
      s.logCurrentSet(weightKg: 50, reps: 6);
      final secondSet = s.sets.firstWhere((x) => x.id == 're-bench-set-1');
      expect(secondSet.isPR, isFalse);
    });

    test('without history, the first positive-volume set is a PR', () {
      final s = _session();
      // row has no historical PR; first row set beats baseline 0.
      s.logCurrentSet(weightKg: 50, reps: 6); // bench
      s.logCurrentSet(weightKg: 50, reps: 6); // bench
      s.logCurrentSet(weightKg: 50, reps: 6); // bench -> now on row
      s.logCurrentSet(weightKg: 40, reps: 8); // row 1: 320 > 0
      final rowSet = s.sets.firstWhere((x) => x.id == 're-row-set-0');
      expect(rowSet.isPR, isTrue);
    });
  });

  group('finish (behavior 4)', () {
    test('builds a Workout with correct totalVolumeKg and prCount', () {
      final s = _session();
      s.logCurrentSet(weightKg: 60, reps: 6); // 360, PR
      s.logCurrentSet(weightKg: 50, reps: 6); // 300, not PR

      final w = s.finish(endedAt: DateTime(2026, 6, 10, 9));

      expect(w.endedAt, DateTime(2026, 6, 10, 9));
      expect(w.completedSetCount, 2);
      // only done sets count: 360 + 300 = 660.
      expect(w.totalVolumeKg, 660);
      expect(w.prCount, 1);
      expect(w.name, 'Push Day A');
      expect(w.routineId, 'r1');
    });
  });

  group('addSet (behavior 5)', () {
    test('adds a loggable set to the current exercise', () {
      final s = _session();
      final before = s.sets.where((x) => x.exerciseId == 'bench').length;

      final added = s.addSet();
      final after = s.sets.where((x) => x.exerciseId == 'bench').length;

      expect(after, before + 1);
      expect(added.exerciseId, 'bench');
      expect(added.done, isFalse);
      // copies the last set's target values.
      expect(added.weightKg, 50);
      expect(added.reps, 6);

      // the appended set is reachable by the cursor: log through to it.
      s.logCurrentSet(weightKg: 50, reps: 6); // set 0
      s.logCurrentSet(weightKg: 50, reps: 6); // set 1
      s.logCurrentSet(weightKg: 50, reps: 6); // set 2
      expect(s.currentSet?.id, added.id); // the new 4th bench set is active
      s.logCurrentSet(weightKg: 52, reps: 5);
      expect(s.sets.firstWhere((x) => x.id == added.id).done, isTrue);
    });
  });
}
