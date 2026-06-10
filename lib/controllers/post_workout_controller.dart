import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/models.dart';
import 'providers.dart';

part 'post_workout_controller.g.dart';

/// One muscle's share of a session's completed-set volume, for the
/// muscles-worked pills + stacked bar on the post-workout summary (screen 10).
@immutable
class MuscleVolume {
  const MuscleVolume({required this.muscle, required this.volumeKg});

  /// Primary muscle label, e.g. "Chest" (from [Exercise.muscle]).
  final String muscle;

  /// Summed `weight × reps` of this muscle's completed sets.
  final double volumeKg;
}

/// Aggregates [workout]'s completed-set volume by the primary muscle of each
/// exercise (resolved via [catalog]), highest volume first. Not-done sets are
/// ignored — the summary reflects what was actually logged. Sets whose exercise
/// is absent from the catalog fall back to an "Other" bucket. Pure, so it is
/// unit-testable.
List<MuscleVolume> buildMuscleVolumes(Workout workout, List<Exercise> catalog) {
  final muscleOf = {for (final e in catalog) e.id: e.muscle};
  final byMuscle = <String, double>{};
  for (final s in workout.sets) {
    if (!s.done) continue;
    final muscle = muscleOf[s.exerciseId] ?? 'Other';
    byMuscle[muscle] = (byMuscle[muscle] ?? 0) + s.volumeKg;
  }
  final result = [
    for (final e in byMuscle.entries)
      MuscleVolume(muscle: e.key, volumeKg: e.value),
  ]..sort((a, b) => b.volumeKg.compareTo(a.volumeKg));
  return result;
}

/// Builds the linked move [Entry] for a saved [workout] (SF-5): a timeline entry
/// of type `move`, `source: manual`, carrying [workoutId] so U10's recent list
/// and U15's detail resolve back to the session. Empty id → repo assigns a UUID.
Entry moveEntryForWorkout(Workout workout, String workoutId) => Entry(
      id: '',
      timestamp: workout.endedAt ?? workout.startedAt,
      type: EntryType.move,
      title: workout.name,
      detail: '${workout.completedSetCount} sets · '
          '${workout.totalVolumeKg.round()} kg',
      duration: workout.duration?.inMinutes,
      source: EntrySource.manual,
      workoutId: workoutId,
    );

/// The Pal post-workout note for an *unsaved* [workout]. Separate from
/// [workoutNoteProvider] (which loads by id from the repo) because the summary
/// shows before the workout is persisted; it spins independently of the stats.
@riverpod
Future<String> postWorkoutNote(Ref ref, Workout workout) =>
    ref.watch(palServiceProvider).postWorkoutNote(workout);

/// Lifecycle of the "Save to timeline" action on the summary screen.
enum SaveState { idle, saving, saved }

/// Owns the one-shot save of a finished session (screen 10). [save] writes the
/// [Workout] and its linked move [Entry] (plan SF-5) in repository order, then
/// latches [SaveState.saved] so the button can't double-write. Only completed
/// sets are persisted — planned-but-unlogged sets are dropped, and stored sets
/// get fresh ids so re-running the same routine never collides on a set id.
@riverpod
class PostWorkoutController extends _$PostWorkoutController {
  @override
  SaveState build() => SaveState.idle;

  Future<void> save(Workout workout) async {
    if (state != SaveState.idle) return;
    state = SaveState.saving;
    try {
      final workoutRepo = ref.read(workoutRepositoryProvider);
      final entryRepo = ref.read(entryRepositoryProvider);

      final doneSets = [
        for (final s in workout.sets)
          if (s.done) s.copyWith(id: ''),
      ];
      final toSave = workout.copyWith(id: '', sets: doneSets);

      final workoutId = await workoutRepo.insert(toSave);
      await entryRepo.insert(moveEntryForWorkout(workout, workoutId));
      state = SaveState.saved;
    } catch (_) {
      // reset so the user can retry; the screen surfaces the failure.
      state = SaveState.idle;
      rethrow;
    }
  }
}
