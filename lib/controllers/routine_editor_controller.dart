import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/models.dart';
import 'providers.dart';

part 'routine_editor_controller.g.dart';

/// Rewrites each slot's [RoutineExercise.order] to match its list position, so
/// persistence stores the visual order after adds/removes/reorders. Pure.
List<RoutineExercise> reindex(List<RoutineExercise> exercises) => [
      for (var i = 0; i < exercises.length; i++) exercises[i].copyWith(order: i),
    ];

/// Editor view model: the draft [Routine] under edit plus the exercise catalog
/// (for resolving names in the slot list and feeding the add-exercise picker).
@immutable
class RoutineEditorState {
  const RoutineEditorState({required this.draft, required this.catalog});

  /// The routine being created/edited. Empty id ('') means "new" until saved.
  final Routine draft;

  /// Full exercise catalog, name-ascending.
  final List<Exercise> catalog;

  /// Whether this is editing an existing (persisted) routine.
  bool get isEditing => draft.id.isNotEmpty;

  /// Catalog entry for a slot's exercise, or null if missing.
  Exercise? exerciseFor(String exerciseId) {
    for (final e in catalog) {
      if (e.id == exerciseId) return e;
    }
    return null;
  }

  RoutineEditorState copyWith({Routine? draft}) =>
      RoutineEditorState(draft: draft ?? this.draft, catalog: catalog);
}

/// Drives the Routine Editor (U21b). Loads an existing routine by [routineId]
/// (or a blank draft when null) plus the catalog, then mutates the draft in
/// place through small setters. [save] persists via [RoutineRepository] —
/// `insert` for a new routine, `update` for an existing one — after re-deriving
/// slot order from list position.
@riverpod
class RoutineEditorController extends _$RoutineEditorController {
  @override
  Future<RoutineEditorState> build(String? routineId) async {
    final repo = ref.watch(routineRepositoryProvider);
    final catalog = await repo.getAllExercises();

    final draft = routineId == null
        ? const Routine(id: '', name: '', tag: RoutineTag.upper)
        : await repo.getById(routineId);
    if (draft == null) {
      throw StateError('Routine "$routineId" not found');
    }
    return RoutineEditorState(draft: draft, catalog: catalog);
  }

  RoutineEditorState get _state => state.requireValue;

  void _setDraft(Routine draft) =>
      state = AsyncData(_state.copyWith(draft: draft));

  void setName(String name) => _setDraft(_state.draft.copyWith(name: name));

  void setTag(RoutineTag tag) => _setDraft(_state.draft.copyWith(tag: tag));

  void setRest(int seconds) =>
      _setDraft(_state.draft.copyWith(restSeconds: seconds));

  void toggleWarmup(bool value) =>
      _setDraft(_state.draft.copyWith(warmupReminder: value));

  void toggleAutoProgress(bool value) =>
      _setDraft(_state.draft.copyWith(autoProgress: value));

  /// Appends a slot for [exerciseId] at the end (empty id → repo assigns UUID).
  void addExercise(String exerciseId) {
    final draft = _state.draft;
    final next = [
      ...draft.exercises,
      RoutineExercise(
        id: '',
        exerciseId: exerciseId,
        order: draft.exercises.length,
      ),
    ];
    _setDraft(draft.copyWith(exercises: reindex(next)));
  }

  void removeExercise(String slotId) {
    final draft = _state.draft;
    final next = draft.exercises.where((e) => e.id != slotId).toList();
    _setDraft(draft.copyWith(exercises: reindex(next)));
  }

  void updateExerciseTargets(
    String slotId, {
    int? sets,
    int? reps,
    double? weight,
  }) {
    final draft = _state.draft;
    final next = [
      for (final e in draft.exercises)
        if (e.id == slotId)
          e.copyWith(
            targetSets: sets,
            targetReps: reps,
            targetWeightKg: weight,
          )
        else
          e,
    ];
    _setDraft(draft.copyWith(exercises: next));
  }

  /// Moves a slot from [oldIndex] to [newIndex] and re-derives order. [newIndex]
  /// is the post-removal target supplied by `ReorderableListView.onReorderItem`.
  void reorder(int oldIndex, int newIndex) {
    final draft = _state.draft;
    final next = [...draft.exercises];
    final moved = next.removeAt(oldIndex);
    next.insert(newIndex, moved);
    _setDraft(draft.copyWith(exercises: reindex(next)));
  }

  /// Persists the draft (order re-derived from list position). New routines are
  /// inserted (empty id → repo assigns UUID); existing ones are updated.
  Future<void> save() async {
    final repo = ref.read(routineRepositoryProvider);
    final draft =
        _state.draft.copyWith(exercises: reindex(_state.draft.exercises));
    if (draft.id.isEmpty) {
      await repo.insert(draft);
    } else {
      await repo.update(draft);
    }
  }
}
