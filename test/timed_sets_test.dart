import 'package:flutter_test/flutter_test.dart';
import 'package:opal/controllers/post_workout_controller.dart';
import 'package:opal/models/models.dart';

/// Timed sets (cardio and holds) log minutes and optional km; every aggregate
/// reads them through the [SetLog]/[Workout] getters so they never count as
/// 0 kg of volume.
void main() {
  SetLog timed(String ex, int minutes, {double? km, bool done = true}) => SetLog(
      id: 't',
      exerciseId: ex,
      weightKg: 0,
      reps: 0,
      minutes: minutes,
      distanceKm: km,
      done: done);

  SetLog weighted(String ex, double kg, int reps, {bool pr = false}) => SetLog(
      id: 'w', exerciseId: ex, weightKg: kg, reps: reps, done: true, isPR: pr);

  Workout workout(List<SetLog> sets) => Workout(
        id: 'w1',
        name: 'Treadmill Intervals',
        startedAt: DateTime(2026, 10, 15, 7),
        endedAt: DateTime(2026, 10, 15, 7, 30),
        sets: sets,
      );

  const catalog = [
    Exercise(
        id: 'bench', name: 'Bench', group: 'Push', muscle: 'Chest', icon: 'x'),
    Exercise(
        id: 'treadmill',
        name: 'Treadmill Run',
        group: 'Cardio',
        muscle: 'Cardio',
        icon: 'x',
        timed: true),
    Exercise(
        id: 'plank',
        name: 'Plank',
        group: 'Core',
        muscle: 'Core',
        icon: 'x',
        timed: true),
  ];

  test('a timed set is timed and adds no volume', () {
    // even if stale weight/reps were stored, the rule wins over the numbers
    final s = timed('treadmill', 20, km: 3.2).copyWith(weightKg: 50, reps: 5);
    expect(s.isTimed, isTrue);
    expect(s.volumeKg, 0);
    expect(weighted('bench', 50, 5).isTimed, isFalse);
  });

  test('a timed-only session totals minutes and km and is a timed session', () {
    final w = workout([
      timed('treadmill', 20, km: 3.2),
      timed('treadmill', 10, km: 1.5),
      timed('treadmill', 5, done: false),
    ]);
    expect(w.totalMinutes, 30);
    expect(w.totalKm, closeTo(4.7, 1e-9));
    expect(w.isTimedSession, isTrue);
    expect(w.totalVolumeKg, 0);
    expect(w.prCount, 0);
  });

  test('a mixed session is not a timed session and counts only weighted volume',
      () {
    final w = workout([
      weighted('bench', 100, 5, pr: true),
      timed('plank', 1).copyWith(isPR: true),
    ]);
    expect(w.isTimedSession, isFalse);
    expect(w.totalVolumeKg, 500);
    expect(w.totalMinutes, 1);
    expect(w.totalKm, 0);
    // a timed set never counts as a record
    expect(w.prCount, 1);
  });

  test('an empty session is not a timed session', () {
    final w = workout([timed('treadmill', 20, done: false)]);
    expect(w.isTimedSession, isFalse);
    expect(w.totalMinutes, 0);
    expect(w.totalKm, 0);
  });

  test('buildMuscleVolumes has no Cardio entry for a treadmill-only session',
      () {
    final w = workout([timed('treadmill', 20, km: 3.2)]);
    expect(buildMuscleVolumes(w, catalog), isEmpty);
  });

  test('buildMuscleVolumes counts the weighted sets of a mixed session', () {
    final w = workout([weighted('bench', 100, 5), timed('plank', 1)]);
    final volumes = buildMuscleVolumes(w, catalog);
    expect(volumes.map((m) => m.muscle), ['Chest']);
  });

  test('buildPrHighlight skips a timed set flagged as a record', () {
    final w = workout([timed('plank', 1).copyWith(isPR: true)]);
    expect(buildPrHighlight(w, catalog), isNull);
  });

  test('moveEntryForWorkout gives a treadmill session minutes and km', () {
    final entry =
        moveEntryForWorkout(workout([timed('treadmill', 20, km: 3.2)]), 'id');
    expect(entry.detail, '20 min · 3.2 km');
    expect(entry.distance, 3.2);
  });

  test('moveEntryForWorkout drops a trailing .0 and omits absent distance', () {
    expect(
      moveEntryForWorkout(workout([timed('treadmill', 20, km: 3)]), 'id')
          .detail,
      '20 min · 3 km',
    );
    final noKm = moveEntryForWorkout(workout([timed('plank', 2)]), 'id');
    expect(noKm.detail, '2 min');
    expect(noKm.distance, isNull);
  });

  test('moveEntryForWorkout keeps sets and kg for a weighted session', () {
    final entry = moveEntryForWorkout(
        workout([weighted('bench', 100, 5), timed('plank', 1)]), 'id');
    expect(entry.detail, '2 sets · 500 kg');
  });
}
