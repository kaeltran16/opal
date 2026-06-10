import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'weekly_plan_controller.g.dart';

/// One day in the [WeeklyPlanController] schedule (handoff screen 24).
///
/// This is a derived 7-day view, not persisted, so the schedule is hardcoded in
/// the controller. [colorKey] is a tracker token ('move'|'rituals'|'money'|
/// 'accent') or the 'rest' pseudo-color; the screen maps 'rest' → `c.ink3` and
/// everything else through `c.forType` (with 'accent' falling through to
/// `c.accent`).
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
  int get totalMinutes =>
      days.fold(0, (sum, d) => sum + (d.est ?? 0));

  WeekPlanDay? get today {
    for (final d in days) {
      if (d.today) return d;
    }
    return null;
  }
}

/// The week schedule, anchored to the CURRENT week. Mon→Sun: completed = 3 of 5
/// workouts, 290 min planned. Dates are derived relative to today so the plan
/// always shows this week; per-day content/status is fixed.
@riverpod
WeeklyPlan weeklyPlanController(Ref ref) {
  final now = DateTime.now();
  final todayMidnight = DateTime(now.year, now.month, now.day);
  // Monday of the current week (DateTime.weekday: Mon=1..Sun=7).
  final monday = todayMidnight.subtract(Duration(days: now.weekday - 1));

  // Per-day content/status keyed by weekday offset (0 = Mon .. 6 = Sun).
  WeekPlanDay dayAt(int offset, WeekPlanDay Function(int date, bool isToday) build) {
    final date = monday.add(Duration(days: offset));
    return build(date.day, date == todayMidnight);
  }

  return WeeklyPlan(days: [
    dayAt(0, (date, isToday) => WeekPlanDay(
          day: 'Mon',
          date: date,
          type: 'Push',
          routine: 'Push Day A',
          est: 55,
          colorKey: 'move',
          icon: 'dumbbell.fill',
          done: true,
          today: isToday,
          muscles: const ['Chest', 'Shoulders', 'Triceps'],
        )),
    dayAt(1, (date, isToday) => WeekPlanDay(
          day: 'Tue',
          date: date,
          type: 'Pull',
          routine: 'Pull Day A',
          est: 58,
          colorKey: 'rituals',
          icon: 'dumbbell.fill',
          done: true,
          today: isToday,
          muscles: const ['Back', 'Biceps'],
        )),
    dayAt(2, (date, isToday) => WeekPlanDay(
          day: 'Wed',
          date: date,
          type: 'Rest',
          colorKey: 'rest',
          icon: 'moon.stars.fill',
          done: true,
          today: isToday,
        )),
    dayAt(3, (date, isToday) => WeekPlanDay(
          day: 'Thu',
          date: date,
          type: 'Legs',
          routine: 'Leg Day',
          est: 62,
          colorKey: 'money',
          icon: 'figure.run',
          today: isToday,
          muscles: const ['Quads', 'Hamstrings', 'Calves'],
        )),
    dayAt(4, (date, isToday) => WeekPlanDay(
          day: 'Fri',
          date: date,
          type: 'Cardio',
          routine: 'Treadmill Intervals',
          est: 30,
          colorKey: 'move',
          icon: 'figure.run',
          today: isToday,
          muscles: const ['Cardio'],
        )),
    dayAt(5, (date, isToday) => WeekPlanDay(
          day: 'Sat',
          date: date,
          type: 'Upper',
          routine: 'Upper Power',
          est: 45,
          colorKey: 'accent',
          icon: 'dumbbell.fill',
          today: isToday,
          muscles: const ['Chest', 'Back'],
        )),
    dayAt(6, (date, isToday) => WeekPlanDay(
          day: 'Sun',
          date: date,
          type: 'Rest',
          colorKey: 'rest',
          icon: 'moon.stars.fill',
          today: isToday,
        )),
  ]);
}
