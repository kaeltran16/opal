import 'package:flutter/foundation.dart';

import '../models/models.dart';

/// Rolling window for spend patterns: the last [kSpendWindowDays] days,
/// today included.
const int kSpendWindowDays = 30;

/// A weekday must average this many times the quietest spending weekday before
/// the gap is worth reporting.
const double kDayMultiplierThreshold = 1.5;

/// Relative gap between the weekend and weekday day-averages, as a fraction of
/// the larger side, before the split is worth reporting.
const double kWeekendDiffThreshold = 0.30;

/// Share of window spend one daypart must hold before it counts as the peak.
const double kDaypartShareThreshold = 0.40;

/// Shortest no-spend run worth calling a streak.
const int kMinNoSpendStreakDays = 7;

/// An expense must exceed this multiple of the window's mean expense to read as
/// unusual.
const double kUnusualMultiplier = 2.0;

/// How many unusual expenses to surface at most.
const int kMaxUnusual = 3;

/// Quarters of the day a spend can land in.
///
/// The hour boundaries (11 / 15 / 21) are the same ones
/// `NutritionController.slotForHour` uses for meal slots, so a food expense's
/// daypart and its meal slot always agree. That puts the small hours in
/// [morning] rather than a separate late-night bucket — a deliberate cost of
/// keeping the two surfaces on one clock.
enum SpendDaypart { morning, midday, evening, night }

SpendDaypart daypartFor(int hour) {
  if (hour < 11) return SpendDaypart.morning;
  if (hour < 15) return SpendDaypart.midday;
  if (hour < 21) return SpendDaypart.evening;
  return SpendDaypart.night;
}

int _dayOrd(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

/// Every aggregate the pattern detectors need, built in one pass over the
/// entries.
///
/// Exists so a screen showing several patterns walks the entry list once rather
/// than once per insight. All weekday-indexed lists are Monday-first (index 0 =
/// Monday), matching `kWeekdayLetters` and the week strips.
@immutable
class SpendAggregates {
  const SpendAggregates({
    required this.windowStart,
    required this.today,
    required this.expenses,
    required this.dayTotals,
    required this.dayOccurrences,
    required this.daypartTotals,
    required this.dailyTotals,
    required this.categoryTotals,
    required this.windowTotal,
  });

  /// Midnight of the window's first day.
  final DateTime windowStart;

  /// Midnight of the anchor day.
  final DateTime today;

  /// In-window expenses, in the order given.
  final List<Entry> expenses;

  /// Summed spend per weekday, Monday-first.
  final List<double> dayTotals;

  /// How many times each weekday falls inside the window, Monday-first. The
  /// divisor for [dayAverages] — a weekday's average is per occurrence of that
  /// weekday, not per transaction, so several small expenses on one day don't
  /// make the day read cheap.
  final List<int> dayOccurrences;

  /// Summed spend per [SpendDaypart], indexed by its `index`.
  final List<double> daypartTotals;

  /// Summed spend per calendar day, keyed by day ordinal. Only days with spend
  /// appear.
  final Map<int, double> dailyTotals;

  /// Summed spend per [normalizeCategory] key; blank categories fall under
  /// [kUncategorizedKey].
  final Map<String, double> categoryTotals;

  /// Summed spend across the window.
  final double windowTotal;

  int get expenseCount => expenses.length;

  /// Mean expense magnitude across the window; 0 when there are none.
  double get meanExpense =>
      expenses.isEmpty ? 0 : windowTotal / expenses.length;

  /// Spend per occurrence of each weekday, Monday-first. A weekday with no
  /// spend averages 0 — a genuine zero, not missing data.
  List<double> get dayAverages => [
        for (var i = 0; i < 7; i++)
          dayOccurrences[i] == 0 ? 0 : dayTotals[i] / dayOccurrences[i],
      ];
}

/// Folds [entries] into [SpendAggregates] over the [windowDays] ending on
/// [now]'s calendar day, inclusive.
///
/// Only expenses count: income and the move/rituals trackers are skipped.
SpendAggregates aggregateSpend(
  List<Entry> entries, {
  required DateTime now,
  int windowDays = kSpendWindowDays,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final windowStart = today.subtract(Duration(days: windowDays - 1));
  final windowEnd = today.add(const Duration(days: 1));

  final dayTotals = List<double>.filled(7, 0);
  final daypartTotals = List<double>.filled(SpendDaypart.values.length, 0);
  final dailyTotals = <int, double>{};
  final categoryTotals = <String, double>{};
  final expenses = <Entry>[];
  var windowTotal = 0.0;

  for (final e in entries) {
    if (!e.isExpense) continue;
    if (e.timestamp.isBefore(windowStart) || !e.timestamp.isBefore(windowEnd)) {
      continue;
    }
    final amount = e.amount!.abs();
    expenses.add(e);
    windowTotal += amount;
    dayTotals[e.timestamp.weekday - 1] += amount;
    daypartTotals[daypartFor(e.timestamp.hour).index] += amount;
    final ord = _dayOrd(e.timestamp);
    dailyTotals[ord] = (dailyTotals[ord] ?? 0) + amount;
    final raw = normalizeCategory(e.category);
    final key = raw.isEmpty ? kUncategorizedKey : raw;
    categoryTotals[key] = (categoryTotals[key] ?? 0) + amount;
  }

  final dayOccurrences = List<int>.filled(7, 0);
  for (var d = windowStart; !d.isAfter(today); d = d.add(const Duration(days: 1))) {
    dayOccurrences[d.weekday - 1]++;
  }

  return SpendAggregates(
    windowStart: windowStart,
    today: today,
    expenses: expenses,
    dayTotals: dayTotals,
    dayOccurrences: dayOccurrences,
    daypartTotals: daypartTotals,
    dailyTotals: dailyTotals,
    categoryTotals: categoryTotals,
    windowTotal: windowTotal,
  );
}

/// The heaviest spending weekday measured against the lightest one that still
/// sees spend. Weekdays are `DateTime.monday`..`DateTime.sunday` (1..7).
@immutable
class BiggestDay {
  const BiggestDay({
    required this.peakWeekday,
    required this.quietWeekday,
    required this.peakAverage,
    required this.quietAverage,
  });

  final int peakWeekday;
  final int quietWeekday;

  /// Spend per occurrence of [peakWeekday].
  final double peakAverage;

  /// Spend per occurrence of [quietWeekday].
  final double quietAverage;

  /// How many times heavier the peak day runs.
  double get multiplier => quietAverage == 0 ? 0 : peakAverage / quietAverage;
}

/// Weekend vs weekday spend, both as a per-day average so the unequal number of
/// days on each side doesn't skew the comparison.
@immutable
class WeekendSplit {
  const WeekendSplit({
    required this.weekendAverage,
    required this.weekdayAverage,
  });

  final double weekendAverage;
  final double weekdayAverage;

  bool get heavierOnWeekend => weekendAverage > weekdayAverage;

  /// Gap between the two sides as a fraction of the larger one (0..1).
  double get differenceFraction {
    final hi = weekendAverage > weekdayAverage ? weekendAverage : weekdayAverage;
    if (hi == 0) return 0;
    return (weekendAverage - weekdayAverage).abs() / hi;
  }
}

/// The daypart holding the largest share of window spend.
@immutable
class DaypartPeak {
  const DaypartPeak({
    required this.daypart,
    required this.total,
    required this.share,
  });

  final SpendDaypart daypart;

  /// Summed spend in this daypart across the window.
  final double total;

  /// [total] as a fraction of the window's spend (0..1).
  final double share;
}

/// A single expense that stands well clear of the window's mean.
@immutable
class UnusualExpense {
  const UnusualExpense({required this.entry, required this.multipleOfMean});

  final Entry entry;

  /// How many times the window's mean expense this one is.
  final double multipleOfMean;
}

/// Everything the patterns pass found. Each finding is null/empty when nothing
/// cleared its bar — the honest empty state, matching how surfaced correlations
/// stay silent rather than reporting noise.
///
/// Pure data: no prose and no formatted amounts, so the UI owns wording and
/// currency. (`Correlation.summary` in `correlations.dart` does compose prose,
/// because an LLM rephrases that sentence; nothing here needs that.)
@immutable
class SpendPatterns {
  const SpendPatterns({
    this.biggestDay,
    this.weekendSplit,
    this.daypartPeak,
    this.noSpendStreakDays = 0,
    this.unusual = const [],
  });

  final BiggestDay? biggestDay;
  final WeekendSplit? weekendSplit;
  final DaypartPeak? daypartPeak;

  /// Length of the current no-spend run ending yesterday, or 0 when there is
  /// none worth reporting.
  final int noSpendStreakDays;

  /// Standout expenses, largest first, at most [kMaxUnusual].
  final List<UnusualExpense> unusual;

  bool get isEmpty =>
      biggestDay == null &&
      weekendSplit == null &&
      daypartPeak == null &&
      noSpendStreakDays == 0 &&
      unusual.isEmpty;
}

/// Runs every detector over [a]. Each is independently gated, so a thin history
/// yields a mostly-empty result rather than confident noise.
SpendPatterns detectSpendPatterns(SpendAggregates a) => SpendPatterns(
      biggestDay: _biggestDay(a),
      weekendSplit: _weekendSplit(a),
      daypartPeak: _daypartPeak(a),
      noSpendStreakDays: _noSpendStreak(a),
      unusual: _unusual(a),
    );

BiggestDay? _biggestDay(SpendAggregates a) {
  final averages = a.dayAverages;
  // Compare only weekdays that see spend: five silent weekdays don't make
  // Tuesday "your quietest day", there's simply nothing to compare.
  final spending = [
    for (var i = 0; i < 7; i++)
      if (averages[i] > 0) i,
  ];
  if (spending.length < 2) return null;

  var peak = spending.first, quiet = spending.first;
  for (final i in spending) {
    if (averages[i] > averages[peak]) peak = i;
    if (averages[i] < averages[quiet]) quiet = i;
  }
  if (averages[peak] < averages[quiet] * kDayMultiplierThreshold) return null;

  return BiggestDay(
    peakWeekday: peak + 1,
    quietWeekday: quiet + 1,
    peakAverage: averages[peak],
    quietAverage: averages[quiet],
  );
}

WeekendSplit? _weekendSplit(SpendAggregates a) {
  var weekendTotal = 0.0, weekdayTotal = 0.0;
  var weekendDays = 0, weekdayDays = 0;
  for (var i = 0; i < 7; i++) {
    // Monday-first: indices 5 and 6 are Saturday and Sunday.
    if (i >= 5) {
      weekendTotal += a.dayTotals[i];
      weekendDays += a.dayOccurrences[i];
    } else {
      weekdayTotal += a.dayTotals[i];
      weekdayDays += a.dayOccurrences[i];
    }
  }
  if (weekendDays == 0 || weekdayDays == 0) return null;
  if (weekendTotal == 0 && weekdayTotal == 0) return null;

  final split = WeekendSplit(
    weekendAverage: weekendTotal / weekendDays,
    weekdayAverage: weekdayTotal / weekdayDays,
  );
  return split.differenceFraction < kWeekendDiffThreshold ? null : split;
}

DaypartPeak? _daypartPeak(SpendAggregates a) {
  if (a.windowTotal == 0) return null;

  var peak = 0;
  for (var i = 1; i < a.daypartTotals.length; i++) {
    if (a.daypartTotals[i] > a.daypartTotals[peak]) peak = i;
  }
  final share = a.daypartTotals[peak] / a.windowTotal;
  if (share < kDaypartShareThreshold) return null;

  return DaypartPeak(
    daypart: SpendDaypart.values[peak],
    total: a.daypartTotals[peak],
    share: share,
  );
}

/// Consecutive silent days counting back from yesterday. Today is excluded — the
/// day is still open, so a quiet morning isn't a streak yet.
///
/// Returns 0 with no spend in the window at all: an empty history is not a
/// no-spend achievement.
int _noSpendStreak(SpendAggregates a) {
  if (a.expenses.isEmpty) return 0;

  final windowDays = a.today.difference(a.windowStart).inDays + 1;
  var streak = 0;
  for (var i = 1; i < windowDays; i++) {
    final day = a.today.subtract(Duration(days: i));
    if (a.dailyTotals.containsKey(_dayOrd(day))) break;
    streak++;
  }
  return streak < kMinNoSpendStreakDays ? 0 : streak;
}

List<UnusualExpense> _unusual(SpendAggregates a) {
  final mean = a.meanExpense;
  if (mean == 0) return const [];

  final bar = mean * kUnusualMultiplier;
  final hits = a.expenses.where((e) => e.amount!.abs() > bar).toList()
    ..sort((x, y) => y.amount!.abs().compareTo(x.amount!.abs()));

  return [
    for (final e in hits.take(kMaxUnusual))
      UnusualExpense(entry: e, multipleOfMean: e.amount!.abs() / mean),
  ];
}
