import 'entry.dart';
import 'enums.dart';
import 'ritual_routine.dart';

/// The user's daily targets across the three trackers.
///
/// Mirrors the handoff's `@Model class Goals`. There is a single Goals record;
/// it has no id in the handoff sketch, so none is modelled here. Defaults match
/// the handoff ($85 budget, 500 kcal move, 5 rituals).
class Goals {
  const Goals({
    this.dailyBudget = 85.0,
    this.dailyMoveKcal = 500,
    this.dailyRitualTarget = 5,
  });

  final double dailyBudget;
  final int dailyMoveKcal;
  final int dailyRitualTarget;

  Goals copyWith({
    double? dailyBudget,
    int? dailyMoveKcal,
    int? dailyRitualTarget,
  }) {
    return Goals(
      dailyBudget: dailyBudget ?? this.dailyBudget,
      dailyMoveKcal: dailyMoveKcal ?? this.dailyMoveKcal,
      dailyRitualTarget: dailyRitualTarget ?? this.dailyRitualTarget,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Goals &&
          other.dailyBudget == dailyBudget &&
          other.dailyMoveKcal == dailyMoveKcal &&
          other.dailyRitualTarget == dailyRitualTarget;

  @override
  int get hashCode =>
      Object.hash(dailyBudget, dailyMoveKcal, dailyRitualTarget);

  @override
  String toString() =>
      'Goals(budget: $dailyBudget, move: ${dailyMoveKcal}kcal, rituals: $dailyRitualTarget)';
}

/// Whether [r] is done: it has steps and every step id is in [doneStepIds].
/// A routine with no steps is set up but not tracked, so it is never done.
bool isRoutineComplete(RitualRoutine r, Set<String> doneStepIds) =>
    r.steps.isNotEmpty && r.steps.every((s) => doneStepIds.contains(s.id));

/// The routines that count toward a target: those with at least one step, in
/// their given order.
List<RitualRoutine> trackedRoutines(List<RitualRoutine> routines) =>
    [for (final r in routines) if (r.steps.isNotEmpty) r];

/// Effective daily ritual target: the count of [trackedRoutines] when the user
/// has any routines, else the stored [Goals.dailyRitualTarget] fallback. The
/// daily ring, detail hero, period reviews, and Pal context all size the ritual
/// goal this way so targets track the routines that actually exist (a fixed 5
/// was unreachable when only 3 routines are seeded). Routines that all lack
/// steps give 0: there is nothing to complete, so the fallback does not apply.
int effectiveDailyRitualTarget(List<RitualRoutine> routines, Goals goals) =>
    routines.isEmpty ? goals.dailyRitualTarget : trackedRoutines(routines).length;

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Completed routines, the single source of truth for "routines done". A
/// routine counts only when [isRoutineComplete] holds for the step ids logged
/// as ritual [Entry]s (`ritualId == step.id`). When [day] is given, only entries
/// logged that calendar day count — so a routine is complete only if all its
/// steps were kept on the same day.
///
/// Recap, the period reviews ([completedRoutinesInPeriod]), and Pal context read
/// this so their counts can't drift (the bug where Recap showed 3/3 by counting
/// step *entries* while Today showed 0/3). Today (`today_controller`) and the
/// Rituals tab (`rituals_controller`) read their own step-completion state but
/// share [isRoutineComplete], so all three agree on what done means.
int completedRoutines(
  Iterable<Entry> entries,
  List<RitualRoutine> routines, {
  DateTime? day,
}) {
  final done = <String>{};
  for (final e in entries) {
    if (e.type != EntryType.rituals || e.ritualId == null) continue;
    if (day != null && !_sameDay(e.timestamp, day)) continue;
    done.add(e.ritualId!);
  }
  return routines.where((r) => isRoutineComplete(r, done)).length;
}

/// Completed routines summed per calendar day across [days] days from [start].
/// Per-day (not "all steps done somewhere in the window") so the numerator
/// stays on the same scale as a period target of `daily target * days` — a
/// routine half-done Monday and half-done Friday completes on neither day.
int completedRoutinesInPeriod(
  Iterable<Entry> entries,
  List<RitualRoutine> routines, {
  required DateTime start,
  required int days,
}) {
  final list = entries is List<Entry> ? entries : entries.toList();
  var total = 0;
  for (var i = 0; i < days; i++) {
    final day = DateTime(start.year, start.month, start.day + i);
    total += completedRoutines(list, routines, day: day);
  }
  return total;
}
