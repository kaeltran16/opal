import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/services.dart';
import 'nutrition_controller.dart';
import 'providers.dart';

/// What one auto-applied action needs in order to be reversed: the id of the
/// entry, routine or meal it created, or for a goal change the goal action that
/// puts back the value it replaced. One per action, so a turn that did several
/// things can undo each on its own.
class AppliedAction {
  const AppliedAction({this.entryId, this.routineId, this.mealId, this.priorGoal});

  final String? entryId;
  final String? routineId;
  final String? mealId;
  final SetGoalAction? priorGoal;
}

/// Applies the mutations Pal returned from a chat turn — logging entries,
/// changing goals, and building routines — and returns one [AppliedAction] per
/// action, in order, to undo them. Shared by every chat surface so "log it" /
/// "build me a routine" behave identically wherever the user types.
///
/// Routine creation follows "AI decides, then call the API": the model only
/// emits the goal, and the client calls [PalService.generateRoutine] with its
/// local exercise catalog before persisting — so the catalog never rides along
/// on every /chat request.
Future<List<AppliedAction>> applyPalActions(Ref ref, List<PalAction> actions) async {
  final applied = <AppliedAction>[];
  try {
    for (final action in actions) {
      applied.add(await _apply(ref, action));
    }
  } catch (_) {
    // partial application leaves orphaned, un-undoable mutations — roll back
    // what already landed, newest first so goal values unwind in order.
    for (final a in applied.reversed) {
      await reversePalAction(ref, a);
    }
    rethrow;
  }
  return applied;
}

/// Reverses one applied action: deletes what it created, or puts back the goal
/// value it replaced (only that goal, so other changes since are kept).
Future<void> reversePalAction(Ref ref, AppliedAction a) async {
  if (a.entryId != null) await ref.read(entryRepositoryProvider).deleteById(a.entryId!);
  if (a.routineId != null) {
    await ref.read(routineRepositoryProvider).deleteById(a.routineId!);
  }
  if (a.mealId != null) await ref.read(nutritionRepositoryProvider).deleteById(a.mealId!);
  if (a.priorGoal != null) {
    final goals = ref.read(goalsRepositoryProvider);
    await goals.upsert(_applyGoal(await goals.get(), a.priorGoal!));
  }
}

Future<AppliedAction> _apply(Ref ref, PalAction action) async {
  switch (action) {
    case LogEntryAction():
      return AppliedAction(
          entryId: await ref.read(entryRepositoryProvider).insert(_entryFor(action)));
    case SetGoalAction():
      final goals = ref.read(goalsRepositoryProvider);
      final before = await goals.get();
      await goals.upsert(_applyGoal(before, action));
      return AppliedAction(
          priorGoal: SetGoalAction(target: action.target, value: _goalValue(before, action.target)));
    case CreateRoutineAction():
      final catalog = ref.read(exercisesProvider).asData?.value ?? const [];
      final draft = await ref.read(palServiceProvider).generateRoutine(action.goal, catalog);
      return AppliedAction(
          routineId: await ref
              .read(routineRepositoryProvider)
              .insert(routineFromDraft(draft, name: action.name)));
    case LogMealAction():
      final est =
          MealEstimate(name: action.name, cal: action.cal, confidence: action.confidence);
      final slot = mealSlotFor(action);
      return AppliedAction(
          mealId: await ref.read(nutritionRepositoryProvider).insert(
                NutritionMeal(
                  id: '',
                  timestamp: clock.now(),
                  slot: slot,
                  name: action.name,
                  source: NutritionSource.manual,
                  icon: NutritionSource.manual.icon,
                  confidence: est.confidence,
                  cal: est.cal,
                  macros: est.macros,
                ),
              ));
  }
}

/// The slot a chat-logged meal lands in: Pal's, else the one for the time of day.
String mealSlotFor(LogMealAction a) {
  final slot = a.slot?.trim() ?? '';
  return slot.isNotEmpty ? slot : NutritionController.slotForHour(clock.now().hour);
}

Entry _entryFor(LogEntryAction a) => Entry(
      id: '',
      timestamp: clock.now(),
      type: a.type,
      title: a.title,
      amount: a.type == EntryType.money ? a.amount : null,
      duration: a.type == EntryType.move ? a.durationMinutes : null,
      calories: a.type == EntryType.move ? a.calories : null,
      category: a.category,
      note: a.note,
      source: EntrySource.nlParsed,
    );

Goals _applyGoal(Goals g, SetGoalAction a) => switch (a.target) {
      GoalTarget.dailyBudget => g.copyWith(dailyBudget: a.value.toDouble()),
      GoalTarget.dailyMoveKcal => g.copyWith(dailyMoveKcal: a.value.round()),
      GoalTarget.dailyRitualTarget => g.copyWith(dailyRitualTarget: a.value.round()),
    };

num _goalValue(Goals g, GoalTarget t) => switch (t) {
      GoalTarget.dailyBudget => g.dailyBudget,
      GoalTarget.dailyMoveKcal => g.dailyMoveKcal,
      GoalTarget.dailyRitualTarget => g.dailyRitualTarget,
    };

/// Folds a generated draft into a persistable [Routine]. Each slot takes its set
/// count from the generated sets and its targets, set minutes included, from
/// the first set (the editor stores one target per slot); the routine keeps
/// Pal's time estimate. Empty ids let the repo mint UUIDs. An optional
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
    estMin: draft.estimatedMinutes,
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
    targetDurationMin: first?.durationMinutes,
  );
}
