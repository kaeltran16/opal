import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/models.dart';
import 'providers.dart';

part 'rituals_controller.g.dart';

/// The Rituals view model: the three time-of-day [RitualRoutine]s plus the set
/// of completed step indices per routine for today. Completion is derived from
/// today's ritual-type [Entry] rows (each step completion is one entry, keyed
/// by `Entry.ritualId == step.id`), so the Today rituals ring and the Rituals
/// tab/player always agree. The screen is dumb — all math lives here.
class RitualsState {
  const RitualsState({
    required this.routines,
    required this.progress,
    this.entryIdByStepId = const {},
  });

  /// Today's routines, display-ordered.
  final List<RitualRoutine> routines;

  /// `routineId -> {completed step indices}` for today.
  final Map<String, Set<int>> progress;

  /// `stepId -> entryId`, so toggling a step off deletes the exact row without
  /// re-querying the stream.
  final Map<String, String> entryIdByStepId;

  Set<int> doneFor(String routineId) => progress[routineId] ?? const {};

  int doneCount(String routineId) => doneFor(routineId).length;

  bool isStepDone(String routineId, int index) =>
      doneFor(routineId).contains(index);

  /// A routine is complete when every step is checked (empty routines never).
  bool isComplete(RitualRoutine r) =>
      r.steps.isNotEmpty && doneCount(r.id) >= r.steps.length;

  /// Steps remaining in [r].
  int stepsLeft(RitualRoutine r) =>
      (r.steps.length - doneCount(r.id)).clamp(0, r.steps.length);

  int get totalSteps => routines.fold(0, (s, r) => s + r.steps.length);

  int get doneSteps => routines.fold(0, (s, r) => s + doneCount(r.id));

  /// The first routine with an incomplete step — the up-next hero target.
  /// Null when everything is done.
  RitualRoutine? get upNext {
    for (final r in routines) {
      if (doneCount(r.id) < r.steps.length) return r;
    }
    return null;
  }

  /// Index of the first incomplete step in [r] (or `steps.length` if complete).
  int firstIncompleteStep(RitualRoutine r) {
    for (var i = 0; i < r.steps.length; i++) {
      if (!isStepDone(r.id, i)) return i;
    }
    return r.steps.length;
  }
}

/// Streams the Rituals view model and owns the step toggle / complete actions.
@riverpod
class RitualsController extends _$RitualsController {
  @override
  Stream<RitualsState> build() async* {
    final ritualRepo = ref.watch(ritualRepositoryProvider);
    final entryRepo = ref.watch(entryRepositoryProvider);

    // Re-emit whenever today's entries change; re-read routines each tick
    // (small list, cheap) so builder edits show up immediately.
    await for (final entries in entryRepo.watchToday()) {
      final routines = await ritualRepo.getAll();

      // stepId -> (routineId, stepIndex).
      final lookup = <String, (String, int)>{};
      for (final r in routines) {
        for (var i = 0; i < r.steps.length; i++) {
          lookup[r.steps[i].id] = (r.id, i);
        }
      }

      final progress = <String, Set<int>>{};
      final entryIdByStepId = <String, String>{};
      for (final e in entries) {
        if (e.type == EntryType.rituals && e.ritualId != null) {
          final loc = lookup[e.ritualId!];
          if (loc != null) {
            (progress[loc.$1] ??= <int>{}).add(loc.$2);
            entryIdByStepId[e.ritualId!] = e.id;
          }
        }
      }

      yield RitualsState(
        routines: routines,
        progress: progress,
        entryIdByStepId: entryIdByStepId,
      );
    }
  }

  /// Toggles step [stepIndex] of [routine] for today: writes a ritual [Entry]
  /// (so the Today rituals ring updates) + a light haptic when newly done;
  /// deletes today's matching entry when already done.
  Future<void> toggleStep(RitualRoutine routine, int stepIndex) async {
    if (stepIndex < 0 || stepIndex >= routine.steps.length) return;
    final step = routine.steps[stepIndex];
    final entryRepo = ref.read(entryRepositoryProvider);
    final existingEntryId = state.value?.entryIdByStepId[step.id];

    if (existingEntryId != null) {
      await entryRepo.deleteById(existingEntryId);
      return;
    }
    await _logStep(routine, step);
  }

  /// Marks step [stepIndex] done if not already (the guided player's "Mark
  /// done" — never un-checks). No-op when already complete.
  Future<void> completeStep(RitualRoutine routine, int stepIndex) async {
    if (stepIndex < 0 || stepIndex >= routine.steps.length) return;
    final step = routine.steps[stepIndex];
    if (state.value?.entryIdByStepId.containsKey(step.id) ?? false) return;
    await _logStep(routine, step);
  }

  Future<void> _logStep(RitualRoutine routine, RitualStep step) async {
    await ref.read(entryRepositoryProvider).insert(
          Entry(
            id: '',
            timestamp: DateTime.now(),
            type: EntryType.rituals,
            title: step.title,
            detail: routine.name,
            ritualId: step.id,
            source: EntrySource.manual,
          ),
        );
    await ref.read(hapticsServiceProvider).light();
  }
}
