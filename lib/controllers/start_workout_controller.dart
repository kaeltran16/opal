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
  const StartWorkoutState({required this.strength, required this.cardio});

  /// Non-cardio routines (Upper/Lower/Full/Custom) — the 2-col grid.
  final List<Routine> strength;

  /// Cardio-tagged routines — the wider rows.
  final List<Routine> cardio;

  /// First strength routine, used as the Pal-pick fallback target when a
  /// suggestion has no [WorkoutSuggestion.routineId]. Null if none exist.
  Routine? get firstStrength => strength.isEmpty ? null : strength.first;
}

/// Streams the [StartWorkoutState] — re-emits when routines change. Splits on
/// [RoutineTag.cardio]: cardio rows vs. everything else (strength grid).
@riverpod
Stream<StartWorkoutState> startWorkout(Ref ref) {
  final repo = ref.watch(routineRepositoryProvider);
  return repo.watchRoutines().map((routines) {
    final strength = <Routine>[];
    final cardio = <Routine>[];
    for (final r in routines) {
      (r.tag == RoutineTag.cardio ? cardio : strength).add(r);
    }
    return StartWorkoutState(strength: strength, cardio: cardio);
  });
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
