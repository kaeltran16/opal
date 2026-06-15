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
