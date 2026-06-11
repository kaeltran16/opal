import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/models.dart';
import '../services/pal/pal_service.dart';
import 'providers.dart';

part 'start_workout_controller.g.dart';

/// The routine picker view model: the seeded/saved routines split into the
/// Strength grid and the Cardio rows. Derived from [RoutineRepository] so the
/// screen is dumb and this split is unit-testable.
@immutable
class StartWorkoutState {
  const StartWorkoutState({
    required this.strength,
    required this.cardio,
    this.lastDone = const {},
  });

  /// Non-cardio routines (Upper/Lower/Full/Custom) — the 2-col grid.
  final List<Routine> strength;

  /// Cardio-tagged routines — the wider rows.
  final List<Routine> cardio;

  /// When each routine was last performed, keyed by routine id — derived from
  /// the most recent matching [Workout.startedAt]. Absent when never done.
  final Map<String, DateTime> lastDone;

  /// First strength routine, used as the Pal-pick fallback target when a
  /// suggestion has no [WorkoutSuggestion.routineId]. Null if none exist.
  Routine? get firstStrength => strength.isEmpty ? null : strength.first;

  /// Whole-day count since a routine was last done, or null if never.
  int? daysSinceLastDone(String routineId) {
    final at = lastDone[routineId];
    if (at == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final then = DateTime(at.year, at.month, at.day);
    return today.difference(then).inDays;
  }
}

/// Streams the [StartWorkoutState] — re-emits when routines or workout history
/// change. Splits on [RoutineTag.cardio]: cardio rows vs. everything else
/// (strength grid). `lastDone` is derived from the newest matching workout per
/// routine id (not stored), so it can never drift from real history.
///
/// Drives off the live workouts stream (so "last done" stays current) and
/// re-reads routines each tick — matching `moveState`'s pattern over the same
/// small tables.
@riverpod
Stream<StartWorkoutState> startWorkout(Ref ref) async* {
  final routineRepo = ref.watch(routineRepositoryProvider);
  final workoutRepo = ref.watch(workoutRepositoryProvider);

  await for (final workouts in workoutRepo.watchWorkouts()) {
    final routines = await routineRepo.getAll();

    final lastDone = <String, DateTime>{};
    for (final w in workouts) {
      final id = w.routineId;
      if (id == null) continue;
      final prev = lastDone[id];
      if (prev == null || w.startedAt.isAfter(prev)) {
        lastDone[id] = w.startedAt;
      }
    }

    final strength = <Routine>[];
    final cardio = <Routine>[];
    for (final r in routines) {
      (r.tag == RoutineTag.cardio ? cardio : strength).add(r);
    }

    yield StartWorkoutState(
      strength: strength,
      cardio: cardio,
      lastDone: lastDone,
    );
  }
}

/// Drives the "Pal's pick" card: holds the current [WorkoutSuggestion] with a
/// loading state and re-requests a different pick on [another]. Mirrors the
/// monthly-review narrative controller (mock-service call + regenerate).
@riverpod
class PalPickController extends _$PalPickController {
  @override
  Future<WorkoutSuggestion> build() {
    final pal = ref.watch(palServiceProvider);
    return pal.suggestWorkout();
  }

  /// Asks Pal for a different pick than the last, showing the loading state
  /// while the new suggestion is fetched (so the card can spin).
  Future<void> another() async {
    final pal = ref.read(palServiceProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => pal.suggestWorkout(another: true));
  }
}
