import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../analysis/area.dart';
import '../analysis/area_state.dart';
import '../analysis/correlations.dart' show kShortNightMinutes;
import '../models/models.dart';
import '../screens/today/today_logic.dart' show routineMinute;
import '../util/dates.dart';
import '../util/format.dart';
import '../util/mood_scale.dart';
import 'providers.dart';
import 'rituals_controller.dart';
import 'sleep_controller.dart' show deriveSleepState;
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
    this.off,
  });

  final String label;
  final String value;

  /// 0..1, for the row's bar.
  final double fraction;

  /// The state this row puts the area in when it is what puts the area off
  /// track; null otherwise.
  final AreaState? off;
}

/// One day of the area page's week chart.
@immutable
class WeekBar {
  const WeekBar({
    required this.day,
    required this.value,
    this.today = false,
    this.off,
  });

  /// Single-letter weekday label.
  final String day;

  /// The day's amount, or null for a day after today or a day with nothing to
  /// average.
  final double? value;

  final bool today;

  /// How a past day that missed the goal leaves its area; null when it did
  /// not. Today is never off: it is not over yet, unless the page judges it.
  final AreaState? off;
}

/// One routine under "Today's routines" on the Routines page.
@immutable
class RoutineRow {
  const RoutineRow({
    required this.id,
    required this.name,
    required this.detail,
    required this.done,
    required this.semanticLabel,
  });

  final String id, name;

  /// `Done`, `<time> · <n> steps`, or `<n> steps` when the time is empty.
  final String detail;

  final bool done;

  /// `<name>, done`, `<name>, at <time>, <n> steps`, or `<name>, <n> steps`.
  final String semanticLabel;
}

/// The area page view model for one [Area]. Sleep has one only when nights
/// are stored ([buildSleepDetail]).
@immutable
class AreaDetail {
  const AreaDetail({
    required this.area,
    required this.hero,
    required this.unit,
    required this.state,
    required this.palLine,
    required this.contributors,
    required this.week,
    required this.goal,
    required this.goalLabel,
    required this.weekNote,
    this.days = const [],
    this.meals = const [],
    this.routines = const [],
  });

  final Area area;
  final String hero;
  final String unit;

  /// Null for areas without a state rule, which show no state word.
  final AreaState? state;
  final String palLine;
  final List<Contributor> contributors;

  /// Seven bars, Monday first.
  final List<WeekBar> week;

  /// The daily goal the week is measured against, 0 when none is set.
  final double goal;

  /// What the goal line stands for, empty when no goal is set.
  final String goalLabel;

  final String weekNote;

  /// Recent entries grouped by day, newest day first. Empty for areas without
  /// an entry tracker.
  final List<DayGroup> days;

  /// Today's meals, oldest first. Nutrition only.
  final List<NutritionMeal> meals;

  /// Today's routines in the rituals order. Routines only.
  final List<RoutineRow> routines;
}

const int _topCategories = 3;

// energy per gram, for each macro's share of the day's macro calories.
const int _kcalPerGramProtein = 4;
const int _kcalPerGramCarbs = 4;
const int _kcalPerGramFat = 9;

const String _noMeals = 'No meals logged yet today.';
const String _noCheckin = 'No check-in yet today.';

/// Builds the [AreaDetail] for [area], one with an entry tracker (Money, Move
/// or Routines). Pure: [entries] is the full entry history, [now] anchors
/// "today" and the week.
AreaDetail buildAreaDetail({
  required Area area,
  required List<Entry> entries,
  required Goals goals,
  required List<RitualRoutine> routines,
  required RitualsState? rituals,
  required WeekPlanDay? workout,
  required Currency currency,
  required DateTime now,
}) {
  final tracker = area.tracker;
  if (tracker == null) {
    throw ArgumentError.value(area, 'area', 'has no entry tracker');
  }
  final data =
      buildDetailData(tracker, entries, goals, routines: routines, now: now);
  return switch (tracker) {
    DetailTracker.money => _money(data, currency, now),
    DetailTracker.move => _move(data, workout, now),
    DetailTracker.rituals => _routines(data, entries, routines, rituals, now),
  };
}

/// The Nutrition page. Pure: [meals] covers at least this week up to [now].
AreaDetail buildNutritionDetail(List<NutritionMeal> meals, DateTime now) {
  final todays = _onDay(meals, now, (m) => m.timestamp);

  final protein = todays.fold<int>(0, (s, m) => s + m.macros.protein.mid);
  final carbs = todays.fold<int>(0, (s, m) => s + m.macros.carbs.mid);
  final fat = todays.fold<int>(0, (s, m) => s + m.macros.fat.mid);
  // there are no macro targets, so each bar is its share of the macro calories
  final macroKcal = protein * _kcalPerGramProtein +
      carbs * _kcalPerGramCarbs +
      fat * _kcalPerGramFat;
  Contributor macro(String label, int grams, int kcalPerGram) => Contributor(
        label: label,
        value: '$grams g',
        fraction: macroKcal == 0 ? 0 : grams * kcalPerGram / macroKcal,
      );

  final count = todays.length;
  return AreaDetail(
    area: Area.nutrition,
    hero: _kcal(kcalEatenOn(meals, now)),
    unit: 'kcal eaten today',
    state: null,
    palLine: switch (count) {
      0 => _noMeals,
      1 => '1 meal logged today.',
      _ => '$count meals logged today.',
    },
    contributors: [
      macro('Protein', protein, _kcalPerGramProtein),
      macro('Carbs', carbs, _kcalPerGramCarbs),
      macro('Fat', fat, _kcalPerGramFat),
    ],
    week: _weekBars(
      now: now,
      valueOf: (day) => kcalEatenOn(meals, day),
      isOff: (_) => false,
    ),
    goal: 0,
    goalLabel: '',
    weekNote: 'Kcal eaten each day',
    meals: todays,
  );
}

/// The Mood page. Pure: [checkins] covers at least this week up to [now].
AreaDetail buildMoodDetail(List<MoodCheckin> checkins, DateTime now) {
  final todays = _onDay(checkins, now, (c) => c.timestamp);
  final latest = todays.isEmpty ? null : todays.last;
  String at(MoodCheckin c) =>
      clockLabel(c.timestamp.hour * 60 + c.timestamp.minute);

  return AreaDetail(
    area: Area.mood,
    hero: latest == null ? '—' : moodWord(latest.pleasantness),
    unit: latest == null ? 'No check-in yet today' : 'at ${at(latest)}',
    state: null,
    palLine: latest == null ? _noCheckin : 'Last check-in at ${at(latest)}.',
    contributors: [
      for (final c in todays)
        Contributor(
          label: at(c),
          value: moodWord(c.pleasantness),
          fraction: c.pleasantness.clamp(0.0, 1.0),
        ),
    ],
    week: _weekBars(
      now: now,
      valueOf: (day) {
        final ofDay = _onDay(checkins, day, (c) => c.timestamp);
        if (ofDay.isEmpty) return null;
        return ofDay.fold<double>(0, (s, c) => s + c.pleasantness) /
            ofDay.length;
      },
      isOff: (_) => false,
    ),
    goal: 0,
    goalLabel: '',
    weekNote: 'Average of each day',
  );
}

/// The Sleep page from the stored [nights] (ascending), the same nights Pal's
/// findings read. Null when none are stored: no sleep source is connected.
AreaDetail? buildSleepDetail(List<SleepNight> nights, DateTime now) {
  if (nights.isEmpty) return null;
  final sleep = deriveSleepState(nights);
  final usual = hm(sleep.usualMinutes);
  final byDay = {for (final n in nights) n.countsToward: n};
  final last = byDay[startOfDay(now)];
  final week = _weekBars(
    now: now,
    valueOf: (day) => byDay[day]?.asleepMinutes.toDouble(),
    isOff: (v) => v < kShortNightMinutes,
    // last night is over, so today's bar is judged like the rest.
    judgesToday: true,
  );
  final short = week.where((b) => b.off != null).length;

  final String palLine;
  if (last == null) {
    palLine = 'No night synced for last night yet. Your usual is $usual.';
  } else if (last.asleepMinutes < kShortNightMinutes) {
    palLine = 'A short night, under your usual $usual.';
  } else if (last.wakes > 2) {
    palLine = '${last.wakes} wake-ups. Your usual is $usual.';
  } else {
    palLine = 'Your usual is $usual.';
  }

  double share(int part, int whole) => whole > 0 ? (part / whole).clamp(0.0, 1.0) : 0;
  return AreaDetail(
    area: Area.sleep,
    hero: last == null ? '—' : hm(last.asleepMinutes),
    unit: last == null ? 'No night synced yet' : 'asleep last night',
    state: null,
    palLine: palLine,
    contributors: [
      if (last != null) ...[
        Contributor(
          label: 'In bed',
          value: hm(last.inBedMinutes),
          fraction: share(last.asleepMinutes, last.inBedMinutes),
        ),
        Contributor(
          label: 'Deep',
          value: hm(last.deepMinutes),
          fraction: share(last.deepMinutes, last.asleepMinutes),
        ),
        Contributor(
          label: 'REM',
          value: hm(last.remMinutes),
          fraction: share(last.remMinutes, last.asleepMinutes),
        ),
      ],
    ],
    week: week,
    goal: 0,
    goalLabel: '',
    weekNote: short == 0 ? 'No short nights' : '$short short ${short == 1 ? 'night' : 'nights'}',
  );
}

/// The items of [items] on [day]'s calendar date, oldest first.
List<T> _onDay<T>(
  List<T> items,
  DateTime day,
  DateTime Function(T item) timeOf,
) =>
    items.where((i) => startOfDay(timeOf(i)) == startOfDay(day)).toList()
      ..sort((a, b) => timeOf(a).compareTo(timeOf(b)));

String _kcal(double kcal) => groupThousands('${kcal.round()}', ',');

AreaDetail _money(DetailData data, Currency currency, DateTime now) {
  final spent = data.total;
  final budget = data.target;
  final hasBudget = budget > 0;
  final over = hasBudget && spent > budget;
  final state = moneyState(spent: spent, budget: budget, now: now);
  String fmt(num v) => formatCurrency(v, currency);

  // the hero already says how much; Pal's line says how the day is going.
  final String hero, unit, palLine;
  if (!hasBudget) {
    hero = fmt(spent);
    unit = 'spent today';
    palLine = 'Set a daily budget to see your pace.';
  } else if (over) {
    hero = fmt(spent - budget);
    unit = 'over ${fmt(budget)} today';
    palLine = 'Over budget. Hold spending for the rest of today.';
  } else {
    hero = fmt(data.remaining);
    unit = 'left of ${fmt(budget)} today';
    palLine = budgetNearlySpent(spent: spent, budget: budget)
        ? "Almost all of today's budget is spent."
        : state == AreaState.watch
            ? "Spending is ahead of the day's pace."
            : "Spending is within the day's pace.";
  }

  final totals = _dayTotals(data);
  final week = _weekBars(
    now: now,
    valueOf: (day) => totals[day] ?? 0,
    isOff: (v) => hasBudget && v > budget,
    // over budget is Needs care by the money rule (DESIGN.md section 11).
    offState: AreaState.care,
    judgesToday: true,
  );

  return AreaDetail(
    area: Area.money,
    hero: hero,
    unit: unit,
    state: state,
    palLine: palLine,
    contributors: [
      Contributor(
        label: 'Spent today',
        value: hasBudget ? '${fmt(spent)} of ${fmt(budget)}' : fmt(spent),
        fraction: hasBudget ? (spent / budget).clamp(0.0, 1.0) : 0,
        off: over ? AreaState.care : null,
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
    palLine = planned != null && !planned.settled
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
    area: Area.move,
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
              : planned.settled
                  ? 'Another workout done today'
                  : planned.est == null
                      ? 'Planned'
                      : '${planned.est} min planned',
          fraction: planned.settled ? 1 : 0,
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
  // the routines with steps are the target. with none there is nothing to
  // complete, so the stored fallback target does not apply here.
  final total = trackedRoutines(routines).length;
  final done = total == 0 ? 0 : data.total.round();
  final next = rituals?.upNextAt(now);

  final String palLine;
  if (routines.isEmpty) {
    palLine = kNoRoutinesLine;
  } else if (total == 0) {
    palLine = kNoStepsLine;
  } else if (done >= total) {
    palLine = 'All $total done.';
  } else {
    final lead = '${total - done} left.';
    palLine = next == null ? lead : '$lead ${_nextLine(next, now)}';
  }

  final week = _weekBars(
    now: now,
    valueOf: (day) => completedRoutines(entries, routines, day: day).toDouble(),
    isOff: (v) => v < total,
  );

  return AreaDetail(
    area: Area.routines,
    hero: '$done',
    unit: total > 0
        ? 'of $total routines done'
        : routines.isEmpty
            ? kNoRoutinesUnit
            : kNoStepsUnit,
    state: progressState(done: done, goal: total, now: now),
    palLine: palLine,
    contributors: [
      if (total > 0)
        Contributor(label: 'Done', value: '$done of $total', fraction: done / total),
      if (next != null) _nextContributor(next),
    ],
    week: week,
    goal: total.toDouble(),
    goalLabel: total == 0 ? '' : 'all $total routines',
    weekNote: _weekNote(week, 'missed'),
    days: data.days,
    // an empty routine still lists, so it can be found and given a step.
    routines: [
      for (final r in routines) _routineRow(r, rituals?.isComplete(r) ?? false),
    ],
  );
}

String _steps(RitualRoutine r) =>
    '${r.steps.length} ${r.steps.length == 1 ? 'step' : 'steps'}';

RoutineRow _routineRow(RitualRoutine r, bool done) {
  final hasTime = r.time.isNotEmpty;
  return RoutineRow(
    id: r.id,
    name: r.name,
    detail: done
        ? 'Done'
        : hasTime
            ? '${r.time} · ${_steps(r)}'
            : _steps(r),
    done: done,
    semanticLabel: done
        ? '${r.name}, done'
        : hasTime
            ? '${r.name}, at ${r.time}, ${_steps(r)}'
            : '${r.name}, ${_steps(r)}',
  );
}

/// "Evening is at 9:00 PM." ahead of its time, "was due at" once it has passed.
String _nextLine(RitualRoutine r, DateTime now) {
  final m = routineMinute(r.time);
  if (m == null) return '${r.name} is next.';
  final passed = m <= now.hour * 60 + now.minute;
  return '${r.name} ${passed ? 'was due' : 'is'} at ${r.time}.';
}

Contributor _nextContributor(RitualRoutine r) => Contributor(
      label: r.time.isEmpty ? r.name : '${r.name}, ${r.time}',
      value: _steps(r),
      fraction: 0,
    );

/// Summed magnitude per calendar day, from the tracker's recent-entry groups.
Map<DateTime, double> _dayTotals(DetailData data) => {
      for (final g in data.days)
        g.day: g.entries
            .fold<double>(0, (s, e) => s + data.tracker.magnitudeOf(e)),
    };

/// [judgesToday] lets today be off before it ends: true where the value only
/// grows past the line (spend over budget), false where the rest of the day
/// can still reach a goal. An off day is [offState]: a missed goal is worth
/// watching unless the area's rule says more.
List<WeekBar> _weekBars({
  required DateTime now,
  required double? Function(DateTime day) valueOf,
  required bool Function(double value) isOff,
  AreaState offState = AreaState.watch,
  bool judgesToday = false,
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
      off: (!isToday || judgesToday) && value != null && isOff(value) ? offState : null,
    );
  });
}

String _weekNote(List<WeekBar> week, String offNoun) {
  final offDays = week.where((b) => b.off != null).length;
  if (offDays == 0) return 'Every day on track';
  return '$offDays ${offDays == 1 ? 'day' : 'days'} $offNoun';
}

/// Nights read for the Sleep page: enough for the 14-night usual and the week.
const int _sleepWindowDays = 30;

/// Streams the Sleep page, null while no nights are stored. A night counts
/// toward the day after it, so the window starts a day early.
@riverpod
Stream<AreaDetail?> sleepDetail(Ref ref) {
  final now = clock.now();
  final from = DateTime(now.year, now.month, now.day - _sleepWindowDays - 1);
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  return ref
      .watch(sleepRepositoryProvider)
      .watchNightsInRange(from, tomorrow)
      .map((nights) => buildSleepDetail(nights, clock.now()));
}

/// Streams the [AreaDetail] for [area]. Sleep reads [sleepDetailProvider]
/// instead, which is empty while no nights are stored.
@riverpod
Stream<AreaDetail> areaDetail(Ref ref, Area area) {
  final now = clock.now();
  final monday = startOfWeek(now);
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  return switch (area) {
    Area.money || Area.move || Area.routines => _trackedDetail(ref, area),
    Area.nutrition => ref
        .watch(nutritionRepositoryProvider)
        .watchMealsInRange(monday, tomorrow)
        .map((meals) => buildNutritionDetail(meals, clock.now())),
    Area.mood => ref
        .watch(moodRepositoryProvider)
        .watchCheckinsInRange(monday, tomorrow)
        .map((checkins) => buildMoodDetail(checkins, clock.now())),
    Area.sleep => Stream.error(UnsupportedError('Sleep reads sleepDetailProvider')),
  };
}

/// The entries `await for` drives entry edits; watching the goals, routines
/// and weekly plan providers rebuilds the provider when only those change.
Stream<AreaDetail> _trackedDetail(Ref ref, Area area) async* {
  final entriesRepo = ref.watch(entryRepositoryProvider);
  final currency = ref.watch(appSettingsControllerProvider).currency;
  final goals = await ref.watch(goalsStreamProvider.future);
  final isRoutines = area == Area.routines;
  final routines = isRoutines
      ? await ref.watch(ritualRoutinesStreamProvider.future)
      : const <RitualRoutine>[];
  final rituals =
      isRoutines ? await ref.watch(ritualsControllerProvider.future) : null;
  final workout = area == Area.move
      ? (await ref.watch(weeklyPlanControllerProvider.future)).today
      : null;

  await for (final entries in entriesRepo.watchAll()) {
    yield buildAreaDetail(
      area: area,
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
