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

/// Effective daily ritual target: the count of active ritual routines when the
/// user has any, else the stored [Goals.dailyRitualTarget] fallback. The daily
/// ring, detail hero, period reviews, and Pal context all size the ritual goal
/// this way so targets track the routines that actually exist (a fixed 5 was
/// unreachable when only 3 routines are seeded).
int effectiveDailyRitualTarget(int routineCount, Goals goals) =>
    routineCount > 0 ? routineCount : goals.dailyRitualTarget;

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Completed routines, the single source of truth for "routines done". A
/// routine counts only when every one of its steps has a matching ritual
/// [Entry] (`ritualId == step.id`); empty routines never count. When [day] is
/// given, only entries logged that calendar day count — so a routine is
/// complete only if all its steps were kept on the same day.
///
/// Recap, the period reviews ([completedRoutinesInPeriod]), and Pal context read
/// this so their counts can't drift (the bug where Recap showed 3/3 by counting
/// step *entries* while Today showed 0/3). Today (`today_controller`) and the
/// Rituals tab (`rituals_controller`) compute completion independently from
/// their own step-completion state; they agree with this today but do not yet
/// route through it.
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
  return routines
      .where((r) => r.steps.isNotEmpty && r.steps.every((s) => done.contains(s.id)))
      .length;
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
