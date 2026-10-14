import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../analysis/area.dart';
import '../analysis/area_state.dart';
import '../models/models.dart';
import '../screens/today/day_plan.dart' show clockLabel;
import '../screens/today/today_logic.dart';
import '../util/dates.dart';
import '../util/format.dart';
import '../util/mood_scale.dart';
import 'providers.dart';
import 'today_controller.dart';

part 'areas_controller.g.dart';

/// Where a vital usually sits by this hour, as 0..1 positions on its bar.
@immutable
class UsualBand {
  const UsualBand(this.low, this.high);

  final double low, high;
}

/// One area on the Areas tab: a ring legend row or an `Also tracked` card.
@immutable
class AreaSummary {
  const AreaSummary({
    required this.area,
    required this.state,
    required this.number,
    required this.unit,
    required this.progress,
    required this.usual,
    required this.semanticLabel,
  });

  final Area area;

  /// Null for areas without a state rule.
  final AreaState? state;

  /// Null when the card shows only its unit line.
  final String? number;

  final String unit;

  /// The ring fraction for Move and Routines (unclamped), else the bar's dot
  /// position 0..1. Null when there is no bar.
  final double? progress;

  /// Null under [_minHistoryDays] days of history, and for Move, Routines and
  /// Sleep.
  final UsualBand? usual;

  final String semanticLabel;
}

/// The Areas tab view model.
@immutable
class AreasSummary {
  const AreasSummary(this.areas);

  /// One per area, in [Area] order.
  final List<AreaSummary> areas;

  AreaSummary of(Area area) => areas.firstWhere((a) => a.area == area);

  List<AreaSummary> get _ruled =>
      areas.where((a) => a.area.hasStateRule).toList();

  /// Ruled areas at good or thriving.
  int get onTrack => _ruled.where((a) => !_isOff(a.state!)).length;

  /// Ruled areas at watch or care, in [Area] order.
  List<AreaSummary> get off => _ruled.where((a) => _isOff(a.state!)).toList();

  String get countLabel => '$onTrack of ${_ruled.length} on track';

  String get palLine {
    final names = [
      for (final (i, a) in off.indexed)
        i == 0 ? a.area.title : a.area.title.toLowerCase(),
    ];
    return switch (names.length) {
      0 => 'Everything is on track.',
      1 => '${names.single} is worth a look.',
      _ =>
        '${names.take(names.length - 1).join(', ')} and ${names.last} '
            'are worth a look.',
    };
  }

  /// The tab's dot: care if any area needs care, else watch, else none.
  AreaState? get tabDot {
    final states = off.map((a) => a.state);
    if (states.contains(AreaState.care)) return AreaState.care;
    return states.isEmpty ? null : AreaState.watch;
  }

  String get tabSemanticLabel {
    if (off.isEmpty) return _areasTitle;
    final parts = [
      for (final a in off)
        '${a.area.title.toLowerCase()} ${a.state!.word.toLowerCase()}',
    ];
    return '$_areasTitle, ${parts.join(', ')}';
  }
}

const String _areasTitle = 'Areas';

/// Days of history the usual band looks back over, and the fewest it needs.
const int _historyDays = 14;
const int _minHistoryDays = 7;

const double _bandLowPercentile = 0.25;
const double _bandHighPercentile = 0.75;

bool _isOff(AreaState s) => s == AreaState.watch || s == AreaState.care;

/// Builds the Areas tab view model. Pure: [today] holds today's ruled numbers,
/// [entries], [meals] and [checkins] cover at least the [_historyDays] days
/// before [now] plus today, for the usual bands.
AreasSummary buildAreasSummary({
  required GlanceNumbers today,
  required List<Entry> entries,
  required List<NutritionMeal> meals,
  required List<MoodCheckin> checkins,
  required Currency currency,
  required DateTime now,
}) => AreasSummary([
  for (final area in Area.values)
    switch (area) {
      Area.money => _money(today, entries, currency, now),
      Area.move => _move(today, now),
      Area.routines => _routines(today, now),
      Area.nutrition => _nutrition(meals, now),
      Area.sleep => _summary(Area.sleep, unit: 'No sleep data yet'),
      Area.mood => _mood(checkins, now),
    },
]);

AreaSummary _summary(
  Area area, {
  AreaState? state,
  String? number,
  required String unit,
  double? progress,
  UsualBand? usual,
}) {
  final reading = number == null ? unit : '$number $unit';
  final word = state == null ? '' : ' ${state.word}.';
  return AreaSummary(
    area: area,
    state: state,
    number: number,
    unit: unit,
    progress: progress,
    usual: usual,
    semanticLabel: '${area.title}: $reading.$word Open ${area.title}',
  );
}

AreaSummary _money(
  GlanceNumbers today,
  List<Entry> entries,
  Currency currency,
  DateTime now,
) {
  final spent = today.spent;
  final budget = today.budget;
  final state = moneyState(spent: spent, budget: budget, now: now);
  String fmt(num v) => formatCurrency(v, currency);

  if (budget <= 0) {
    return _summary(
      Area.money,
      state: state,
      number: fmt(spent),
      unit: 'spent today',
    );
  }
  double leftShare(double s) => ((budget - s) / budget).clamp(0.0, 1.0);
  final over = spent > budget;
  final history = _history(
    now,
    hasData: (from, to) =>
        entries.any((e) => _isSpend(e) && _within(e.timestamp, from, to)),
    valueAt: (from, cutoff) => leftShare(_spentBetween(entries, from, cutoff)),
  );
  return _summary(
    Area.money,
    state: state,
    number: fmt(over ? spent - budget : budget - spent),
    unit: '${over ? 'over' : 'left of'} ${fmt(budget)}',
    progress: leftShare(spent),
    usual: _band(history),
  );
}

AreaSummary _move(GlanceNumbers today, DateTime now) {
  final kcal = today.moveKcal;
  final goal = today.moveGoal;
  return _summary(
    Area.move,
    state: progressState(done: kcal, goal: goal, now: now),
    number: '$kcal',
    unit: goal > 0 ? 'of $goal kcal' : 'kcal',
    progress: goal > 0 ? kcal / goal : 0,
  );
}

AreaSummary _routines(GlanceNumbers today, DateTime now) {
  final done = today.routinesDone;
  final total = today.routinesTotal;
  return _summary(
    Area.routines,
    state: progressState(done: done, goal: total, now: now),
    number: '$done',
    unit: total > 0 ? 'of $total done' : 'routines set up',
    progress: total > 0 ? done / total : 0,
  );
}

AreaSummary _nutrition(List<NutritionMeal> meals, DateTime now) {
  double kcalBetween(DateTime from, DateTime cutoff) => meals
      .where((m) => _within(m.timestamp, from, cutoff, inclusive: true))
      .fold<double>(0, (s, m) => s + m.cal.mid);

  final kcal = kcalBetween(startOfDay(now), now);
  final history = _history(
    now,
    hasData: (from, to) => meals.any((m) => _within(m.timestamp, from, to)),
    valueAt: kcalBetween,
  );
  // no target, so the bar spans the largest of today and the usual days
  final scale = history.fold<double>(kcal, math.max);
  double share(double v) => scale == 0 ? 0 : v / scale;
  final band = _band(history);
  return _summary(
    Area.nutrition,
    number: groupThousands('${kcal.round()}', ','),
    unit: 'kcal eaten so far',
    progress: share(kcal),
    usual: band == null ? null : UsualBand(share(band.low), share(band.high)),
  );
}

AreaSummary _mood(List<MoodCheckin> checkins, DateTime now) {
  MoodCheckin? latestBetween(DateTime from, DateTime cutoff) => checkins
      .where((c) => _within(c.timestamp, from, cutoff, inclusive: true))
      .fold<MoodCheckin?>(
        null,
        (l, c) => l == null || c.timestamp.isAfter(l.timestamp) ? c : l,
      );

  final latest = latestBetween(startOfDay(now), now);
  if (latest == null) {
    return _summary(Area.mood, unit: 'No check-in yet today');
  }
  // a day whose first check-in comes after this hour has no value by now
  final history = [
    for (final day in _priorDays(now))
      ?latestBetween(day, _sameClock(day, now))?.pleasantness,
  ];
  final t = latest.timestamp;
  return _summary(
    Area.mood,
    number: moodWord(latest.pleasantness),
    unit: 'at ${clockLabel(t.hour * 60 + t.minute)}',
    progress: latest.pleasantness,
    usual: _band(history),
  );
}

/// The [_historyDays] midnights before [now]'s day, newest first.
Iterable<DateTime> _priorDays(DateTime now) sync* {
  for (var i = 1; i <= _historyDays; i++) {
    // calendar arithmetic, not a 24h duration, so a dst change keeps midnight
    yield DateTime(now.year, now.month, now.day - i);
  }
}

DateTime _sameClock(DateTime day, DateTime now) => DateTime(
  day.year,
  day.month,
  day.day,
  now.hour,
  now.minute,
  now.second,
  now.millisecond,
);

/// Each prior day's value at [now]'s clock time, for the days that have any
/// data of that kind. A day with data only later still counts: its value by
/// this hour is real, often 0.
List<double> _history(
  DateTime now, {
  required bool Function(DateTime from, DateTime to) hasData,
  required double Function(DateTime from, DateTime cutoff) valueAt,
}) => [
  for (final day in _priorDays(now))
    if (hasData(day, DateTime(day.year, day.month, day.day + 1)))
      valueAt(day, _sameClock(day, now)),
];

/// The 25th to 75th percentile of [values], or null under [_minHistoryDays].
UsualBand? _band(List<double> values) {
  if (values.length < _minHistoryDays) return null;
  final sorted = [...values]..sort();
  return UsualBand(
    _percentile(sorted, _bandLowPercentile),
    _percentile(sorted, _bandHighPercentile),
  );
}

/// Linear interpolation between the closest ranks of the ascending [sorted].
double _percentile(List<double> sorted, double p) {
  final rank = p * (sorted.length - 1);
  final lower = rank.floor();
  final upper = rank.ceil();
  return sorted[lower] + (sorted[upper] - sorted[lower]) * (rank - lower);
}

bool _within(
  DateTime t,
  DateTime from,
  DateTime to, {
  bool inclusive = false,
}) => !t.isBefore(from) && (inclusive ? !t.isAfter(to) : t.isBefore(to));

bool _isSpend(Entry e) => e.type == EntryType.money && (e.amount ?? 0) < 0;

double _spentBetween(List<Entry> entries, DateTime from, DateTime cutoff) =>
    entries
        .where(
          (e) =>
              _isSpend(e) &&
              _within(e.timestamp, from, cutoff, inclusive: true),
        )
        .fold<double>(0, (s, e) => s + e.amount!.abs());

/// The window the usual bands read: the [_historyDays] days before today, and
/// today.
({DateTime from, DateTime to}) _window() {
  final now = clock.now();
  return (
    from: DateTime(now.year, now.month, now.day - _historyDays),
    to: DateTime(now.year, now.month, now.day + 1),
  );
}

@riverpod
Stream<List<Entry>> _recentEntries(Ref ref) {
  final w = _window();
  return ref.watch(entryRepositoryProvider).watchEntriesInRange(w.from, w.to);
}

@riverpod
Stream<List<NutritionMeal>> _recentMeals(Ref ref) {
  final w = _window();
  return ref.watch(nutritionRepositoryProvider).watchMealsInRange(w.from, w.to);
}

@riverpod
Stream<List<MoodCheckin>> _recentCheckins(Ref ref) {
  final w = _window();
  return ref.watch(moodRepositoryProvider).watchCheckinsInRange(w.from, w.to);
}

/// Streams the Areas tab view model. Watching each source's `.future`
/// rebuilds this provider when today's numbers, entries, meals or check-ins
/// change.
@riverpod
Stream<AreasSummary> areasSummary(Ref ref) async* {
  final currency = ref.watch(appSettingsControllerProvider).currency;
  // watch the value, not its future: a today that never settles would make
  // the pending future throw when the container is torn down.
  final todayAsync = ref.watch(todayStateProvider);
  if (todayAsync.hasError) {
    Error.throwWithStackTrace(
      todayAsync.error!,
      todayAsync.stackTrace ?? StackTrace.current,
    );
  }
  final today = todayAsync.value;
  if (today == null) return;
  final entries = await ref.watch(_recentEntriesProvider.future);
  final meals = await ref.watch(_recentMealsProvider.future);
  final checkins = await ref.watch(_recentCheckinsProvider.future);
  // the routines with steps are the target, as on today. with none there is
  // nothing to complete, so the legacy step count does not apply.
  final routinesTotal = trackedRoutines(today.routines).length;
  yield buildAreasSummary(
    today: GlanceNumbers(
      spent: today.moneySpent,
      budget: today.goals.dailyBudget,
      moveKcal: today.moveKcal,
      moveGoal: today.goals.dailyMoveKcal,
      routinesDone: routinesTotal == 0 ? 0 : today.ritualsDone,
      routinesTotal: routinesTotal,
    ),
    entries: entries,
    meals: meals,
    checkins: checkins,
    currency: currency,
    now: clock.now(),
  );
}
