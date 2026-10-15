import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../screens/today/day_plan.dart';
import '../services/pal/pal_service.dart';
import '../util/dates.dart';
import 'providers.dart';

part 'plan_session_controller.g.dart';

// an added step's glyph; Pal names the step but not its icon.
const String _addedStepIcon = 'sparkles';

/// What the user did with today's plan this app session: Today's card and
/// timeline, and You's Pal suggests, settle the same proposals here, so one
/// approved or put off on either screen is gone from both.
///
/// Approving a proposal performs it through the repositories, and Undo
/// reverses it the same way. Each settles or pops only after its write, so a
/// failed write leaves the plan as it was and throws for the screen to say so.
///
/// Kept alive so it outlives either screen. Not persisted, as Today's own
/// session never was.
@Riverpod(keepAlive: true)
class PlanSessionController extends _$PlanSessionController {
  @override
  PlanSession build() => const PlanSession();

  /// Performs [item]'s proposal, then settles it as done.
  Future<void> approve(PlanItem item) async {
    final p = item.proposal;
    final (label, change) = switch (p) {
      PalProposal(addsRitual: true, ritual: final r?) => await _addStep(r.routineId, r.step),
      PalProposal(reschedulesWorkout: true, slot: final s?) => await _setSlot(s.weekday, s.routineId),
      _ => throw StateError('nothing to perform for ${item.id} (action ${p?.action})'),
    };
    state = state.settle(item.id, done: true, label: label, change: change);
  }

  /// Puts [item] off for today.
  void skip(PlanItem item) =>
      state = state.settle(item.id, done: false, label: '${item.title} skipped');

  /// Reverses the last step's change, then reopens its item.
  Future<void> undo() async {
    final last = state.lastStep;
    switch (last?.change) {
      case AddedRitualStep(:final routineId, :final stepId):
        await _removeStep(routineId, stepId);
      case SetPlanSlot(:final weekday, :final priorRoutineId):
        await ref.read(weeklyPlanRepositoryProvider).upsert(weekday, priorRoutineId);
      case null:
    }
    // a second tap while this one wrote has popped the step already; popping
    // again would reopen an earlier step without reversing it.
    if (identical(state.lastStep, last)) state = state.undo();
  }

  void select(String id) => state = state.select(id);

  void deselect() => state = state.deselect();

  Future<(String, PlanChange)> _addStep(String routineId, String title) async {
    final repo = ref.read(ritualRepositoryProvider);
    final routine = await _ritual(routineId);
    if (routine == null) throw StateError('no ritual routine $routineId');
    final step = RitualStep(id: const Uuid().v4(), title: title, note: '', icon: _addedStepIcon);
    await repo.upsertRoutine(routine.copyWith(steps: [...routine.steps, step]));
    return ('$title added', AddedRitualStep(routineId, step.id));
  }

  Future<void> _removeStep(String routineId, String stepId) async {
    final routine = await _ritual(routineId);
    // a routine deleted since has taken the step with it.
    if (routine == null) return;
    await ref.read(ritualRepositoryProvider).upsertRoutine(
        routine.copyWith(steps: [...routine.steps.where((s) => s.id != stepId)]));
  }

  Future<RitualRoutine?> _ritual(String id) async =>
      (await ref.read(ritualRepositoryProvider).getAll()).where((r) => r.id == id).firstOrNull;

  Future<(String, PlanChange)> _setSlot(int weekday, String routineId) async {
    final routine = await ref.read(routineRepositoryProvider).getById(routineId);
    if (routine == null) throw StateError('no workout routine $routineId');
    final plan = ref.read(weeklyPlanRepositoryProvider);
    final prior =
        (await plan.getSchedule()).where((a) => a.weekday == weekday).firstOrNull?.routineId;
    await plan.upsert(weekday, routineId);
    return ('${routine.name} on ${kWeekdays[weekday - 1]}', SetPlanSlot(weekday, prior));
  }
}
