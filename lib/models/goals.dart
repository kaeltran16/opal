/// The user's daily targets across the three trackers.
///
/// Mirrors the handoff's `@Model class Goals`. There is a single Goals record;
/// it has no id in the handoff sketch, so none is modelled here. Defaults match
/// the handoff ($85 budget, 60min move, 5 rituals).
class Goals {
  const Goals({
    this.dailyBudget = 85.0,
    this.dailyMoveMinutes = 60,
    this.dailyRitualTarget = 5,
  });

  final double dailyBudget;
  final int dailyMoveMinutes;
  final int dailyRitualTarget;

  Goals copyWith({
    double? dailyBudget,
    int? dailyMoveMinutes,
    int? dailyRitualTarget,
  }) {
    return Goals(
      dailyBudget: dailyBudget ?? this.dailyBudget,
      dailyMoveMinutes: dailyMoveMinutes ?? this.dailyMoveMinutes,
      dailyRitualTarget: dailyRitualTarget ?? this.dailyRitualTarget,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Goals &&
          other.dailyBudget == dailyBudget &&
          other.dailyMoveMinutes == dailyMoveMinutes &&
          other.dailyRitualTarget == dailyRitualTarget;

  @override
  int get hashCode =>
      Object.hash(dailyBudget, dailyMoveMinutes, dailyRitualTarget);

  @override
  String toString() =>
      'Goals(budget: $dailyBudget, move: ${dailyMoveMinutes}min, rituals: $dailyRitualTarget)';
}
