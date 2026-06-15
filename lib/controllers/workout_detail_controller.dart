import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/models.dart';
import '../util/dates.dart';
import 'providers.dart';

part 'workout_detail_controller.g.dart';

/// Number of trailing ISO weeks the volume bar chart spans.
const int _volumeWeeks = 8;

/// One exercise's resolved name + its ordered sets within the session.
@immutable
class ExerciseSets {
  const ExerciseSets({required this.name, required this.sets});

  /// Catalog display name, or the raw exerciseId when the catalog lacks it.
  final String name;

  /// The session's sets for this exercise, in stored order.
  final List<SetLog> sets;
}

/// One bar of the 8-week volume trend: the week's Monday and its total volume
/// in kilograms (0 for a week with no completed workouts).
@immutable
class WeekVolume {
  const WeekVolume({required this.weekStart, required this.volumeKg});

  final DateTime weekStart;
  final double volumeKg;
}

/// The fully-computed Workout Detail view model. All derivation (per-exercise
/// grouping, name resolution, 8-week bucketing) lives here so the screen is
/// dumb and this is unit-testable.
@immutable
class WorkoutDetailState {
  const WorkoutDetailState({
    required this.workout,
    required this.exercises,
    required this.weeklyVolume,
  });

  final Workout workout;

  /// Per-exercise groups in first-seen set order.
  final List<ExerciseSets> exercises;

  /// Trailing [_volumeWeeks] weekly volume buckets, oldest first.
  final List<WeekVolume> weeklyVolume;
}

/// Buckets the completed-set volume of [workouts] into the trailing
/// [_volumeWeeks] ISO weeks ending with the week of [now]. Weeks with no
/// workout stay at 0. Extracted so it can be tested directly.
List<WeekVolume> buildWeeklyVolume(List<Workout> workouts, DateTime now) {
  final thisWeek = startOfWeek(now);
  final weeks = <DateTime, double>{
    for (var i = _volumeWeeks - 1; i >= 0; i--)
      thisWeek.subtract(Duration(days: 7 * i)): 0.0,
  };
  final oldest = thisWeek.subtract(const Duration(days: 7 * (_volumeWeeks - 1)));
  for (final w in workouts) {
    final ws = startOfWeek(w.startedAt);
    if (ws.isBefore(oldest) || ws.isAfter(thisWeek)) continue;
    weeks[ws] = (weeks[ws] ?? 0) + w.totalVolumeKg;
  }
  return [
    for (final e in weeks.entries) WeekVolume(weekStart: e.key, volumeKg: e.value),
  ];
}

/// Groups [workout]'s sets by exerciseId (first-seen order), resolving each
/// name against [catalog]. Extracted for direct testing.
List<ExerciseSets> buildExerciseGroups(
  Workout workout,
  List<Exercise> catalog,
) {
  final names = {for (final e in catalog) e.id: e.name};
  final order = <String>[];
  final grouped = <String, List<SetLog>>{};
  for (final s in workout.sets) {
    final list = grouped.putIfAbsent(s.exerciseId, () {
      order.add(s.exerciseId);
      return <SetLog>[];
    });
    list.add(s);
  }
  return [
    for (final id in order)
      ExerciseSets(name: names[id] ?? id, sets: grouped[id]!),
  ];
}

/// Streams the [WorkoutDetailState] for [workoutId]: the session aggregate, its
/// per-exercise set groups (names resolved via the catalog), and the trailing
/// 8-week volume buckets computed from all workouts. Re-emits when the workout
/// store changes.
@riverpod
Stream<WorkoutDetailState> workoutDetail(Ref ref, String workoutId) async* {
  final repo = ref.watch(workoutRepositoryProvider);
  final catalog = await ref.watch(exercisesProvider.future);

  await for (final all in repo.watchWorkouts()) {
    final matches = all.where((w) => w.id == workoutId);
    if (matches.isEmpty) {
      throw StateError('Workout $workoutId not found');
    }
    final workout = matches.first;
    yield WorkoutDetailState(
      workout: workout,
      exercises: buildExerciseGroups(workout, catalog),
      weeklyVolume: buildWeeklyVolume(all, DateTime.now()),
    );
  }
}

/// The Pal post-workout note for [workoutId], with a loading state. Separate
/// from [workoutDetailProvider] so the note can spin independently of the
/// (reactive) stats.
@riverpod
Future<String> workoutNote(Ref ref, String workoutId) async {
  final repo = ref.watch(workoutRepositoryProvider);
  final pal = ref.watch(palServiceProvider);
  final workout = await repo.getById(workoutId);
  if (workout == null) throw StateError('Workout $workoutId not found');
  return pal.postWorkoutNote(workout);
}
