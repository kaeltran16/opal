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
