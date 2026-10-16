import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart' show debugPrint;
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

/// What the user did with today's plan: Today's card and timeline, and You's
/// Pal suggests, settle the same proposals here, so one approved or put off
/// on either screen is gone from both.
///
/// Approving a proposal performs it through the repositories, and Undo
/// reverses it the same way. Each settles or pops only after its write, so a
/// failed write leaves the plan as it was and throws for the screen to say so.
///
/// Kept alive so it outlives either screen. The settled map is saved for the
/// day, so a relaunch keeps the day's put-offs; the undo history is not, as
/// the toast that offers it is gone after a relaunch anyway.
@Riverpod(keepAlive: true)
class PlanSessionController extends _$PlanSessionController {
  @override
  PlanSession build() => _load(startOfDay(clock.now()));

  void putOff(PlanItem item) =>
      _apply(state.settle(item.id, done: false, label: 'Put off until tomorrow: ${item.title}'));

  /// Performs [item]'s proposal, then settles it as done.
  Future<void> approve(PlanItem item) async {
    final p = item.proposal;
    final (label, change) = switch (p) {
      PalProposal(addsRitual: true, ritual: final r?) => await _addStep(r.routineId, r.step),
      PalProposal(reschedulesWorkout: true, slot: final s?) => await _setSlot(s.weekday, s.routineId),
      _ => throw StateError('nothing to perform for ${item.id} (action ${p?.action})'),
    };
    _apply(state.settle(item.id, done: true, label: label, change: change));
  }

  void bringBack(PlanItem item) =>
      _apply(state.bringBack(item.id, label: '${item.title} is back on today'));

  /// Reverses the last change's write, then reopens its item once that is
  /// saved, so a failed write or save leaves the change for the toast to retry.
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
    if (!identical(state.lastStep, last)) return;
    final next = state.undo();
    await _save(next);
    state = next;
  }

  void dismissNotice() => state = state.dismissNotice();

  /// Starts the new day's session when [now] is past the session's day, for an
  /// app left open across midnight.
  void syncDay(DateTime now) {
    final day = startOfDay(now);
    if (day != state.day) state = _load(day);
  }

  PlanSession _load(DateTime day) =>
      PlanSession(day: day, settled: ref.read(settingsRepositoryProvider).planSettled(day));

  void _apply(PlanSession next) {
    state = next;
    // _save logs the failure; the change still shows for this session.
    _save(next).ignore();
  }

  Future<void> _save(PlanSession session) async {
    try {
      await ref.read(settingsRepositoryProvider).setPlanSettled(session.day, session.settled);
    } catch (e) {
      debugPrint("plan session: couldn't save the plan for ${session.day}: $e");
      rethrow;
    }
  }

  Future<(String, PlanChange)> _addStep(String routineId, String title) async {
    final repo = ref.read(ritualRepositoryProvider);
    final routine = await _ritual(routineId);
    if (routine == null) throw StateError('no ritual routine $routineId');
    final step = RitualStep(id: const Uuid().v4(), title: title, note: '', icon: _addedStepIcon);
    await repo.upsertRoutine(routine.copyWith(steps: [...routine.steps, step]));
    return ('Added $title to ${routine.name}', AddedRitualStep(routineId, step.id));
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
    final tomorrow = clock.now().add(const Duration(days: 1)).weekday;
    final when = weekday == tomorrow ? 'tomorrow' : kWeekdays[weekday - 1];
    return ('Planned ${routine.name} for $when', SetPlanSlot(weekday, prior));
  }
}
