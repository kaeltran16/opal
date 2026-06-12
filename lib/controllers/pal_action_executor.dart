import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/services.dart';
import 'providers.dart';

/// What a chat turn's auto-applied actions need in order to be reversed: the ids
/// of entries and routines it created, and the goals snapshot from before it
/// changed them.
class AppliedActions {
  const AppliedActions({
    this.entryIds = const [],
    this.routineIds = const [],
    this.priorGoals,
  });

  final List<String> entryIds;
  final List<String> routineIds;
  final Goals? priorGoals;

  bool get isEmpty =>
      entryIds.isEmpty && routineIds.isEmpty && priorGoals == null;
}

/// Applies the mutations Pal returned from a chat turn — logging entries,
/// changing goals, and building routines — and returns the data needed to undo
/// them. Shared by every chat surface so "log it" / "build me a routine" behave
/// identically wherever the user types.
///
/// Routine creation follows "AI decides, then call the API": the model only
/// emits the goal, and the client calls [PalService.generateRoutine] with its
/// local exercise catalog before persisting — so the catalog never rides along
/// on every /chat request.
Future<AppliedActions> applyPalActions(Ref ref, List<PalAction> actions) async {
  final entries = ref.read(entryRepositoryProvider);
  final goalsRepo = ref.read(goalsRepositoryProvider);
  final entryIds = <String>[];
  final routineIds = <String>[];
  Goals? working;
  Goals? priorGoals;

  try {
    for (final action in actions) {
      switch (action) {
        case LogEntryAction():
          entryIds.add(await entries.insert(_entryFor(action)));
        case SetGoalAction():
          working ??= await goalsRepo.get();
          priorGoals ??= working;
          working = _applyGoal(working, action);
          await goalsRepo.save(working);
        case CreateRoutineAction():
          final catalog = ref.read(exercisesProvider).asData?.value ?? const [];
          final draft =
              await ref.read(palServiceProvider).generateRoutine(action.goal, catalog);
          final id = await ref
              .read(routineRepositoryProvider)
              .insert(routineFromDraft(draft, name: action.name));
          routineIds.add(id);
      }
    }
  } catch (_) {
    // partial application leaves orphaned, un-undoable mutations — roll back
    // what already landed (same reversal the undo path uses), then rethrow.
    for (final id in entryIds) {
      await entries.deleteById(id);
    }
    final routines = ref.read(routineRepositoryProvider);
    for (final id in routineIds) {
      await routines.deleteById(id);
    }
    if (priorGoals != null) await goalsRepo.save(priorGoals);
    rethrow;
  }
  return AppliedActions(
    entryIds: entryIds,
    routineIds: routineIds,
    priorGoals: priorGoals,
  );
}

Entry _entryFor(LogEntryAction a) => Entry(
      id: '',
      timestamp: DateTime.now(),
      type: a.type,
      title: a.title,
      amount: a.type == EntryType.money ? a.amount : null,
      duration: a.type == EntryType.move ? a.durationMinutes : null,
      category: a.category,
      note: a.note,
      source: EntrySource.nlParsed,
    );

Goals _applyGoal(Goals g, SetGoalAction a) => switch (a.target) {
      GoalTarget.dailyBudget => g.copyWith(dailyBudget: a.value.toDouble()),
      GoalTarget.dailyMoveMinutes => g.copyWith(dailyMoveMinutes: a.value.round()),
      GoalTarget.dailyRitualTarget => g.copyWith(dailyRitualTarget: a.value.round()),
    };

/// Folds a generated draft into a persistable [Routine]. Each slot takes its set
/// count from the generated sets and its targets from the first set (the editor
/// stores one target per slot). Empty ids let the repo mint UUIDs. An optional
/// [name] override lets the chat caller name the routine.
Routine routineFromDraft(GeneratedRoutineDraft draft, {String? name}) {
  final exercises = <RoutineExercise>[
    for (var i = 0; i < draft.exercises.length; i++)
      _slotFrom(draft.exercises[i], i),
  ];
  return Routine(
    id: '',
    name: (name == null || name.trim().isEmpty) ? draft.name : name.trim(),
    tag: draft.tag,
    exercises: exercises,
  );
}

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
