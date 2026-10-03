import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../analysis/area_state.dart';
import '../models/models.dart';
import '../util/dates.dart';
import '../util/format.dart';
import 'providers.dart';
import 'rituals_controller.dart';
import 'spending_controller.dart';
import 'today_controller.dart';
import 'weekly_plan_controller.dart';

part 'area_detail_controller.g.dart';

/// One row under "What is shaping it" on the area page.
@immutable
class Contributor {
  const Contributor({
    required this.label,
    required this.value,
    required this.fraction,
    this.off = false,
  });

  final String label;
  final String value;

  /// 0..1, for the row's bar.
  final double fraction;

  /// True when this row is what puts the area off track.
  final bool off;
}

/// One day of the area page's week chart.
@immutable
class WeekBar {
  const WeekBar({
    required this.day,
    required this.value,
    this.today = false,
    this.off = false,
  });

  /// Single-letter weekday label.
  final String day;

  /// The day's amount, or null for a day after today.
  final double? value;

  final bool today;

  /// A past day that missed the goal. Today is never off: it is not over yet.
  final bool off;
}

/// The area page view model for one [DetailTracker].
@immutable
class AreaDetail {
  const AreaDetail({
    required this.tracker,
    required this.hero,
    required this.unit,
    required this.state,
    required this.palLine,
    required this.contributors,
    required this.week,
    required this.goal,
    required this.goalLabel,
    required this.weekNote,
    required this.days,
  });

  final DetailTracker tracker;
  final String hero;
  final String unit;
  final AreaState state;
  final String palLine;
  final List<Contributor> contributors;

  /// Seven bars, Monday first.
  final List<WeekBar> week;

  /// The daily goal the week is measured against, 0 when none is set.
  final double goal;

  /// What the goal line stands for, empty when no goal is set.
  final String goalLabel;

  final String weekNote;

  /// Recent entries grouped by day, newest day first.
  final List<DayGroup> days;
}

const int _topCategories = 3;

/// Builds the [AreaDetail] for [tracker]. Pure: [entries] is the full entry
/// history, [now] anchors "today" and the week.
AreaDetail buildAreaDetail({
  required DetailTracker tracker,
  required List<Entry> entries,
  required Goals goals,
  required List<RitualRoutine> routines,
  required RitualsState? rituals,
  required WeekPlanDay? workout,
  required Currency currency,
  required DateTime now,
}) {
  final data =
      buildDetailData(tracker, entries, goals, routines: routines, now: now);
  switch (tracker) {
    case DetailTracker.money:
      return _money(data, currency, now);
    case DetailTracker.move:
      return _move(data, workout, now);
    case DetailTracker.rituals:
      return _routines(data, entries, routines, rituals, now);
  }
}

AreaDetail _money(DetailData data, Currency currency, DateTime now) {
  final spent = data.total;
  final budget = data.target;
  final hasBudget = budget > 0;
  final over = hasBudget && spent > budget;
  final state = moneyState(spent: spent, budget: budget, now: now);
  String fmt(num v) => formatCurrency(v, currency);

  final String hero, unit, palLine;
  if (!hasBudget) {
    hero = fmt(spent);
    unit = 'spent today';
    palLine = '$hero spent today.';
  } else if (over) {
    hero = fmt(spent - budget);
    unit = 'over ${fmt(budget)} today';
    palLine = '$hero over budget. Hold spending for today.';
  } else {
    hero = fmt(data.remaining);
    unit = 'left of ${fmt(budget)} today';
    palLine = state == AreaState.watch
        ? '$hero left, and the day is not over.'
        : '$hero left for today.';
  }

  final totals = _dayTotals(data);
  final week = _weekBars(
    now: now,
    valueOf: (day) => totals[day] ?? 0,
    isOff: (v) => hasBudget && v > budget,
  );

  return AreaDetail(
    tracker: data.tracker,
    hero: hero,
    unit: unit,
    state: state,
    palLine: palLine,
    contributors: [
      Contributor(
        label: 'Spent today',
        value: hasBudget ? '${fmt(spent)} of ${fmt(budget)}' : fmt(spent),
        fraction: hasBudget ? (spent / budget).clamp(0.0, 1.0) : 0,
        off: over,
      ),
      for (final c in data.categories.take(_topCategories))
        Contributor(label: c.label, value: fmt(c.amount), fraction: c.fraction),
    ],
    week: week,
    goal: hasBudget ? budget : 0,
    goalLabel: hasBudget ? '${fmt(budget)} daily budget' : '',
    weekNote: _weekNote(week, 'over budget'),
    days: data.days,
  );
}

AreaDetail _move(DetailData data, WeekPlanDay? workout, DateTime now) {
  final kcal = data.total.round();
  final goal = data.target.round();
  final hasGoal = goal > 0;
  final met = hasGoal && kcal >= goal;
  final planned = workout != null && !workout.isRest ? workout : null;
  final plannedName = planned?.routine ?? planned?.type;

  final String palLine;
  if (met) {
    palLine = 'Goal met.';
  } else {
    final lead =
        hasGoal ? '${goal - kcal} kcal to go.' : '$kcal kcal burned today.';
    palLine = planned != null && !planned.done
        ? '$lead $plannedName is planned today.'
        : lead;
  }

  final totals = _dayTotals(data);
  final week = _weekBars(
    now: now,
    valueOf: (day) => totals[day] ?? 0,
    isOff: (v) => hasGoal && v < goal,
  );

  return AreaDetail(
    tracker: data.tracker,
    hero: '$kcal',
    unit: hasGoal ? 'of $goal kcal burned' : 'kcal burned',
    state: progressState(done: kcal, goal: goal, now: now),
    palLine: palLine,
    contributors: [
      Contributor(
        label: 'Burned',
        value: hasGoal ? '$kcal of $goal kcal' : '$kcal kcal',
        fraction: hasGoal ? (kcal / goal).clamp(0.0, 1.0) : 0,
      ),
      if (planned != null)
        Contributor(
          label: plannedName!,
          value: planned.done
              ? 'Done'
              : planned.est == null
                  ? 'Planned'
                  : '${planned.est} min planned',
          fraction: planned.done ? 1 : 0,
        ),
    ],
    week: week,
    goal: hasGoal ? goal.toDouble() : 0,
    goalLabel: hasGoal ? '$goal kcal goal' : '',
    weekNote: _weekNote(week, 'under goal'),
    days: data.days,
  );
}

AreaDetail _routines(
  DetailData data,
  List<Entry> entries,
  List<RitualRoutine> routines,
  RitualsState? rituals,
  DateTime now,
) {
  // the routine count is the target. with no routines there is nothing to
  // complete, so the stored fallback target does not apply here.
  final total = routines.length;
  final done = total == 0 ? 0 : data.total.round();

  final String palLine;
  if (total == 0) {
    palLine = 'No routines set up yet.';
  } else if (done >= total) {
    palLine = 'All $total done.';
  } else {
    final next = rituals?.upNext;
    final lead = '${total - done} left.';
    palLine = next == null ? lead : '$lead ${next.name} is at ${next.time}.';
  }

  final week = _weekBars(
    now: now,
    valueOf: (day) => completedRoutines(entries, routines, day: day).toDouble(),
    isOff: (v) => v < total,
  );

  return AreaDetail(
    tracker: data.tracker,
    hero: '$done',
    unit: total == 0 ? 'routines set up' : 'of $total routines done',
    state: progressState(done: done, goal: total, now: now),
    palLine: palLine,
    contributors: [
      for (final r in routines) _routineContributor(r, rituals),
    ],
    week: week,
    goal: total.toDouble(),
    goalLabel: total == 0 ? '' : 'all $total routines',
    weekNote: _weekNote(week, 'missed'),
    days: data.days,
  );
}

Contributor _routineContributor(RitualRoutine r, RitualsState? rituals) {
  final steps = r.steps.length;
  final done = (rituals?.doneCount(r.id) ?? 0).clamp(0, steps);
  return Contributor(
    label: r.name,
    value: '$done of $steps steps',
    fraction: steps == 0 ? 0 : done / steps,
  );
}

/// Summed magnitude per calendar day, from the tracker's recent-entry groups.
Map<DateTime, double> _dayTotals(DetailData data) => {
      for (final g in data.days)
        g.day: g.entries
            .fold<double>(0, (s, e) => s + data.tracker.magnitudeOf(e)),
    };

List<WeekBar> _weekBars({
  required DateTime now,
  required double Function(DateTime day) valueOf,
  required bool Function(double value) isOff,
}) {
  final monday = startOfWeek(now);
  final today = startOfDay(now);
  return List.generate(DateTime.daysPerWeek, (i) {
    // calendar arithmetic, not a 24h duration, so a dst change keeps midnight
    final day = DateTime(monday.year, monday.month, monday.day + i);
    final label = kWeekdayLetters[i];
    if (day.isAfter(today)) return WeekBar(day: label, value: null);
    final value = valueOf(day);
    final isToday = day == today;
    return WeekBar(
      day: label,
      value: value,
      today: isToday,
      off: !isToday && isOff(value),
    );
  });
}

String _weekNote(List<WeekBar> week, String offNoun) {
  final offDays = week.where((b) => b.off).length;
  if (offDays == 0) return 'Every day on track';
  return '$offDays ${offDays == 1 ? 'day' : 'days'} $offNoun';
}

/// Streams the [AreaDetail] for [tracker]. The entries `await for` drives entry
/// edits; watching the goals, routines and weekly plan providers rebuilds this
/// one when only those change.
@riverpod
Stream<AreaDetail> areaDetail(Ref ref, DetailTracker tracker) async* {
  final entriesRepo = ref.watch(entryRepositoryProvider);
  final currency = ref.watch(appSettingsControllerProvider).currency;
  final goals = await ref.watch(goalsStreamProvider.future);
  final isRoutines = tracker == DetailTracker.rituals;
  final routines = isRoutines
      ? await ref.watch(ritualRoutinesStreamProvider.future)
      : const <RitualRoutine>[];
  final rituals =
      isRoutines ? await ref.watch(ritualsControllerProvider.future) : null;
  final workout = tracker == DetailTracker.move
      ? (await ref.watch(weeklyPlanControllerProvider.future)).today
      : null;

  await for (final entries in entriesRepo.watchAll()) {
    yield buildAreaDetail(
      tracker: tracker,
      entries: entries,
      goals: goals,
      routines: routines,
      rituals: rituals,
      workout: workout,
      currency: currency,
      now: clock.now(),
    );
  }
}
