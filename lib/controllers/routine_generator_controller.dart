import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/models.dart';
import '../services/pal/pal_service.dart';
import 'providers.dart';

part 'routine_generator_controller.g.dart';

/// View-model union for the Routine Generator. The screen renders the hero +
/// prompt + quick-picks for [idle], a spinner for [loading], the red error card
/// for [error], and the gradient preview for [result].
@immutable
sealed class RoutineGeneratorState {
  const RoutineGeneratorState();
}

/// Nothing generated yet — show the pitch, prompt input, and quick-picks.
class RoutineGeneratorIdle extends RoutineGeneratorState {
  const RoutineGeneratorIdle();
}

/// Pal is building the routine — show the centered spinner pill.
class RoutineGeneratorLoading extends RoutineGeneratorState {
  const RoutineGeneratorLoading();
}

/// Generation failed — show the red-tinted card with [message].
class RoutineGeneratorError extends RoutineGeneratorState {
  const RoutineGeneratorError(this.message);
  final String message;
}

/// A routine was generated — show the preview built from [draft], with names
/// resolved against [catalog].
class RoutineGeneratorResult extends RoutineGeneratorState {
  const RoutineGeneratorResult({required this.draft, required this.catalog});

  final GeneratedRoutineDraft draft;
  final List<Exercise> catalog;

  /// Catalog entry for a generated slot's [exerciseId], or null if missing.
  Exercise? exerciseFor(String exerciseId) {
    for (final e in catalog) {
      if (e.id == exerciseId) return e;
    }
    return null;
  }
}

/// Drives the Routine Generator (Handoff #2). Holds the exercise catalog (the
/// `available` list passed to Pal and the source for resolving names/icons in
/// the preview), and a [RoutineGeneratorState] union the screen renders.
///
/// [generate] calls the [PalService.generateRoutine] seam (mirrors the
/// Pal-pick loading pattern). [save] persists the previewed draft as a real
/// [Routine] via [RoutineRepository.insert] — the same create path the Routine
/// Editor uses — assigning empty ids so the repo mints UUIDs.
@riverpod
class RoutineGeneratorController extends _$RoutineGeneratorController {
  List<Exercise> _catalog = const [];

  @override
  RoutineGeneratorState build() {
    // Resolve the catalog once; the screen also reads exercisesProvider, so this
    // is the parsed/loaded list when available, empty until then.
    _catalog = ref.watch(exercisesProvider).asData?.value ?? const [];
    return const RoutineGeneratorIdle();
  }

  /// Asks Pal to build a routine for [goal], showing the loading state while the
  /// draft is fetched. Empty/whitespace goals are ignored. On success the state
  /// becomes a [RoutineGeneratorResult]; on failure a [RoutineGeneratorError].
  Future<void> generate(String goal) async {
    final ask = goal.trim();
    if (ask.isEmpty) return;

    state = const RoutineGeneratorLoading();
    try {
      final pal = ref.read(palServiceProvider);
      final draft = await pal.generateRoutine(ask, _catalog);
      state = RoutineGeneratorResult(draft: draft, catalog: _catalog);
    } catch (e) {
      state = const RoutineGeneratorError(
        'Could not generate routine. Try again?',
      );
    }
  }

  /// Clears the preview/error back to [RoutineGeneratorIdle] ("Try again").
  void reset() => state = const RoutineGeneratorIdle();

  /// Persists the previewed draft as a new [Routine]. Builds [RoutineExercise]
  /// slots from the generated exercises (sets count + first set's targets),
  /// assigning empty ids so the repo mints UUIDs, then inserts via the same
  /// repo method the Routine Editor's create path uses. No-op unless a result
  /// is showing.
  Future<void> save() async {
    final current = state;
    if (current is! RoutineGeneratorResult) return;
    final draft = current.draft;

    final exercises = <RoutineExercise>[
      for (var i = 0; i < draft.exercises.length; i++)
        _slotFrom(draft.exercises[i], i),
    ];

    final routine = Routine(
      id: '',
      name: draft.name,
      tag: draft.tag,
      exercises: exercises,
    );

    await ref.read(routineRepositoryProvider).insert(routine);
  }

  /// Folds a generated exercise into a routine slot: set count from the list
  /// length, target reps/weight from the first set (the editor stores a single
  /// target per slot, not per-set).
  RoutineExercise _slotFrom(GeneratedExerciseDraft ex, int order) {
    final first = ex.sets.isEmpty ? null : ex.sets.first;
    return RoutineExercise(
      id: '',
      exerciseId: ex.exerciseId,
      order: order,
      targetSets: ex.sets.isEmpty ? 3 : ex.sets.length,
      targetReps: first?.reps,
      targetWeightKg: first?.weightKg,
    );
  }
}
