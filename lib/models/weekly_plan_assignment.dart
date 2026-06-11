/// One persisted weekly-schedule assignment: a weekday slot pointing at an
/// optional [Routine].
///
/// This is the *stored* shape — only `weekday -> routineId`. The display view
/// (type, est minutes, target muscles, completion) is derived from the
/// referenced routine + this week's workouts in `WeeklyPlanController`, so no
/// routine fields are duplicated here.
class WeeklyPlanAssignment {
  const WeeklyPlanAssignment({required this.weekday, this.routineId});

  /// ISO weekday: 1=Mon .. 7=Sun.
  final int weekday;

  /// FK to [Routine.id]; null = Rest day.
  final String? routineId;

  WeeklyPlanAssignment copyWith({int? weekday, String? routineId}) =>
      WeeklyPlanAssignment(
        weekday: weekday ?? this.weekday,
        routineId: routineId ?? this.routineId,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeeklyPlanAssignment &&
          other.weekday == weekday &&
          other.routineId == routineId;

  @override
  int get hashCode => Object.hash(weekday, routineId);

  @override
  String toString() =>
      'WeeklyPlanAssignment(weekday: $weekday, routineId: $routineId)';
}
