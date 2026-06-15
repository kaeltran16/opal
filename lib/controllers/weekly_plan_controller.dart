import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/models.dart';
import 'providers.dart';

part 'weekly_plan_controller.g.dart';

/// One day in the [weeklyPlanController] schedule (handoff screen 24).
///
/// A derived 7-day view joining the persisted schedule (`weekday -> routineId`)
/// to the referenced [Routine] and this week's [Workout]s. [colorKey] is a
/// tracker token ('move'|'rituals'|'money'|'accent') or the 'rest' pseudo-color;
/// the screen maps 'rest' → `c.ink3` and everything else through `c.forType`
/// (with 'accent' falling through to `c.accent`).
@immutable
class WeekPlanDay {
  const WeekPlanDay({
    required this.day,
    required this.date,
    required this.type,
    this.routine,
    this.est,
    required this.colorKey,
    required this.icon,
    this.done = false,
    this.today = false,
    this.muscles = const [],
  });

  /// Three-letter weekday, e.g. "Mon".
  final String day;

  /// Day-of-month, e.g. 21.
  final int date;

  /// Workout type label, e.g. "Push" / "Legs" / "Rest".
  final String type;

  /// Routine name, null on rest days.
  final String? routine;

  /// Estimated minutes, null on rest days.
  final int? est;

  /// 'move' | 'rituals' | 'money' | 'accent' | 'rest'.
  final String colorKey;

  /// SF Symbol for the type icon tile.
  final String icon;

  /// Completed workout (or rested) for the day.
  final bool done;

  /// The current day — drives the spotlight + schedule row accent.
  final bool today;

  /// Target muscle groups, empty on rest days.
  final List<String> muscles;

  bool get isRest => type == 'Rest';
}

/// The full week's derived schedule + its summary counts. All math lives here so
/// the screen is dumb (mirrors [MonthlyStats]).
@immutable
class WeeklyPlan {
  const WeeklyPlan({required this.days});

  final List<WeekPlanDay> days;

  /// Completed non-rest workouts.
  int get doneCount => days.where((d) => d.done && !d.isRest).length;

  /// Total scheduled non-rest workouts.
  int get totalCount => days.where((d) => !d.isRest).length;

  /// Sum of estimated minutes across the week.
  int get totalMinutes => days.fold(0, (sum, d) => sum + (d.est ?? 0));

  WeekPlanDay? get today {
    for (final d in days) {
      if (d.today) return d;
    }
    return null;
  }
}

const _dayAbbrev = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Per-weekday accent token (1=Mon..7=Sun) cycling the three tracker hues plus
/// the accent, so the strip keeps its visual variety without a stored field.
const _colorByWeekday = <int, String>{
  1: 'move',
  2: 'rituals',
  3: 'rest',
  4: 'money',
  5: 'move',
  6: 'accent',
  7: 'rest',
};

/// Builds the derived [WeeklyPlan] by joining the persisted [schedule] to its
/// [routines] (looked up by id) and deriving completion from this week's
/// [workouts]. Pure so the join/derive logic is unit-testable; [now] is the
/// anchor for "this week" and "today".
///
/// For each weekday (Mon..Sun): an assignment with a resolvable routine yields a
/// workout day (type/muscles derived from the routine's exercises via
/// [exercisesById], est from `Routine.estMin`); anything else is a Rest day.
/// `done` is true when a workout for that routine started within the current
/// week (Mon 00:00 .. next Mon 00:00).
WeeklyPlan buildWeeklyPlan({
  required List<WeeklyPlanAssignment> schedule,
  required List<Routine> routines,
  required Map<String, Exercise> exercisesById,
  required List<Workout> workouts,
  required DateTime now,
}) {
  final todayMidnight = DateTime(now.year, now.month, now.day);
  // Monday of the current week (DateTime.weekday: Mon=1..Sun=7).
  final monday = todayMidnight.subtract(Duration(days: now.weekday - 1));
  final nextMonday = monday.add(const Duration(days: 7));

  final routineById = {for (final r in routines) r.id: r};
  final scheduleByWeekday = {for (final a in schedule) a.weekday: a};

  // Routine ids with a workout started in the current week.
  final doneRoutineIds = <String>{};
  for (final w in workouts) {
    final id = w.routineId;
    if (id == null) continue;
    if (!w.startedAt.isBefore(monday) && w.startedAt.isBefore(nextMonday)) {
      doneRoutineIds.add(id);
    }
  }

  final days = <WeekPlanDay>[];
  for (var offset = 0; offset < 7; offset++) {
    final date = monday.add(Duration(days: offset));
    final isToday = date == todayMidnight;
    final weekday = offset + 1; // 1=Mon..7=Sun
    final colorKey = _colorByWeekday[weekday]!;

    final routineId = scheduleByWeekday[weekday]?.routineId;
    final routine = routineId == null ? null : routineById[routineId];

    if (routine == null) {
      days.add(WeekPlanDay(
        day: _dayAbbrev[offset],
        date: date.day,
        type: 'Rest',
        colorKey: 'rest',
        icon: 'moon.stars.fill',
        today: isToday,
      ));
      continue;
    }

    final isCardio = routine.tag == RoutineTag.cardio;
    days.add(WeekPlanDay(
      day: _dayAbbrev[offset],
      date: date.day,
      type: _typeLabel(routine, exercisesById),
      routine: routine.name,
      est: routine.estMin,
      colorKey: colorKey,
      icon: isCardio ? 'figure.run' : 'dumbbell.fill',
      done: doneRoutineIds.contains(routine.id),
      today: isToday,
      muscles: _muscles(routine, exercisesById),
    ));
  }

  return WeeklyPlan(days: days);
}

/// Short type label derived from the routine's exercises: the most common
/// exercise `group` (e.g. "Push" / "Pull" / "Legs" / "Cardio"). Falls back to
/// the routine name when no exercises resolve.
String _typeLabel(Routine routine, Map<String, Exercise> exercisesById) {
  final counts = <String, int>{};
  for (final slot in routine.orderedExercises) {
    final group = exercisesById[slot.exerciseId]?.group;
    if (group == null) continue;
    counts[group] = (counts[group] ?? 0) + 1;
  }
  if (counts.isEmpty) return routine.name;
  return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
}

/// Distinct target muscles across the routine's exercises, in slot order.
List<String> _muscles(Routine routine, Map<String, Exercise> exercisesById) {
  final seen = <String>{};
  final result = <String>[];
  for (final slot in routine.orderedExercises) {
    final muscle = exercisesById[slot.exerciseId]?.muscle;
    if (muscle == null || !seen.add(muscle)) continue;
    result.add(muscle);
  }
  return result;
}

/// Streams the derived [WeeklyPlan], anchored to the current week. Re-emits when
/// the persisted schedule changes; each tick re-reads routines, the exercise
/// catalog, and workout history so completion/derivation stay current.
@riverpod
Stream<WeeklyPlan> weeklyPlanController(Ref ref) async* {
  final scheduleRepo = ref.watch(weeklyPlanRepositoryProvider);
  // Await routines/exercises/workouts via `.future` (not re-read) so completing
  // a workout — or editing a routine — refreshes the plan's completion state,
  // not just a schedule edit.
  final routines = await ref.watch(workoutRoutinesStreamProvider.future);
  final exercises = await ref.watch(exercisesProvider.future);
  final workouts = await ref.watch(workoutsStreamProvider.future);

  await for (final schedule in scheduleRepo.watchSchedule()) {
    yield buildWeeklyPlan(
      schedule: schedule,
      routines: routines,
      exercisesById: {for (final e in exercises) e.id: e},
      workouts: workouts,
      now: DateTime.now(),
    );
  }
}
