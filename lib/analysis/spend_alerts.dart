import 'package:flutter/foundation.dart';

import '../models/models.dart';

/// Length of each half of the week-over-week velocity comparison, in days.
const int kVelocityWindowDays = 7;

/// Week-over-week swing in total spend before the change in pace is worth
/// reporting.
const double kVelocityChangeThreshold = 0.30;

/// Month-over-month rise in one category before it reads as a spike.
const double kCategorySpikeThreshold = 0.40;

/// A capped envelope whose recent average sits below this share of its cap is
/// carrying more headroom than it needs.
const double kUnderspendCeiling = 0.70;

/// Headroom left over the average when suggesting a cap, as a fraction.
const double kSuggestedCapBuffer = 0.10;

/// Base rounding unit for suggested caps, in USD-scale. Multiplied by the
/// currency's `budgetScale` so caps round to $50 / 50,000₫. Shared by every
/// surface that proposes a cap, so two of them can't round differently.
const double kBudgetRoundingBaseUnit = 50;

/// Completed months averaged for the cap suggestions. Matches the window
/// `buildBudgetRecommendations` uses so the two can't disagree.
const int kSavingsWindowMonths = 3;

int _monthOrdinal(DateTime d) => d.year * 12 + d.month;

/// Rounds [value] up to the next whole [unit], or returns it unchanged when
/// [unit] is not a usable step.
double _roundUpTo(double value, double unit) =>
    unit > 0 ? (value / unit).ceil() * unit : value;

/// A suggested cap: the average plus [kSuggestedCapBuffer], rounded up.
double _suggestCap(double average, double roundTo) =>
    _roundUpTo(average * (1 + kSuggestedCapBuffer), roundTo);

/// Total expense magnitude in `[start, end)`.
double _totalBetween(List<Entry> entries, DateTime start, DateTime end) {
  var total = 0.0;
  for (final e in entries) {
    if (!e.isExpense) continue;
    if (e.timestamp.isBefore(start) || !e.timestamp.isBefore(end)) continue;
    total += e.amount!.abs();
  }
  return total;
}

/// How this week's spending pace compares with last week's.
///
/// Pure data — no copy, no formatted currency, matching [EnvelopeForecast] and
/// `BudgetRecommendation`.
@immutable
class VelocityChange {
  const VelocityChange({
    required this.recent,
    required this.previous,
    required this.changeFraction,
  });

  /// Spend over the last [kVelocityWindowDays] days, today included.
  final double recent;

  /// Spend over the [kVelocityWindowDays] days before that.
  final double previous;

  /// Signed change against [previous] (0.4 = 40% more than last week).
  final double changeFraction;

  bool get isAccelerating => changeFraction > 0;
}

/// One category spending materially more this month than last.
@immutable
class CategorySpike {
  const CategorySpike({
    required this.category,
    required this.thisMonth,
    required this.lastMonth,
    required this.changeFraction,
  });

  final String category;
  final double thisMonth;
  final double lastMonth;

  /// Signed change against [lastMonth] (0.4 = 40% more).
  final double changeFraction;
}

/// A category drawing real money this month with no envelope covering it.
@immutable
class UnbudgetedCategory {
  const UnbudgetedCategory({
    required this.category,
    required this.monthSpend,
    required this.suggestedCap,
  });

  final String category;

  /// Month-to-date spend in this category.
  final double monthSpend;

  /// A starting cap sized off [monthSpend].
  final double suggestedCap;
}

/// An envelope whose cap has run well ahead of what the category actually uses.
@immutable
class SavingsOpportunity {
  const SavingsOpportunity({
    required this.category,
    required this.cap,
    required this.monthlyAverage,
    required this.suggestedCap,
  });

  final String category;

  /// The envelope's current monthly cap.
  final double cap;

  /// Average monthly spend over the last [kSavingsWindowMonths] completed
  /// months.
  final double monthlyAverage;

  /// A tighter cap sized off [monthlyAverage].
  final double suggestedCap;

  /// What the tighter cap frees up each month.
  double get monthlySaving => cap - suggestedCap;
}

/// This week's spend against last week's, or null when the swing is inside
/// [kVelocityChangeThreshold] or there's no prior week to compare against.
///
/// A zero prior week is not infinite acceleration — it is no baseline, which is
/// a different (and quieter) thing to say.
VelocityChange? detectVelocityChange(
  List<Entry> entries, {
  required DateTime now,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final recentStart =
      today.subtract(const Duration(days: kVelocityWindowDays - 1));
  final previousStart =
      recentStart.subtract(const Duration(days: kVelocityWindowDays));
  final end = today.add(const Duration(days: 1));

  final previous = _totalBetween(entries, previousStart, recentStart);
  if (previous <= 0) return null;

  final recent = _totalBetween(entries, recentStart, end);
  final change = (recent - previous) / previous;
  if (change.abs() < kVelocityChangeThreshold) return null;

  return VelocityChange(
    recent: recent,
    previous: previous,
    changeFraction: change,
  );
}

/// Per-category month-over-month rises past [kCategorySpikeThreshold], steepest
/// first.
///
/// A category with no last-month spend is skipped rather than reported as an
/// infinite rise — "you started spending on this" is a different signal, and one
/// this detector deliberately leaves alone.
List<CategorySpike> detectCategorySpikes(
  List<Entry> entries, {
  required DateTime now,
}) {
  final thisMonthOrdinal = _monthOrdinal(now);

  final thisMonth = <String, double>{};
  final lastMonth = <String, double>{};
  final display = <String, String>{};

  for (final e in entries) {
    if (!e.isExpense) continue;
    final key = normalizeCategory(e.category);
    if (key.isEmpty) continue;

    final monthsBack = thisMonthOrdinal - _monthOrdinal(e.timestamp);
    if (monthsBack == 0) {
      thisMonth[key] = (thisMonth[key] ?? 0) + e.amount!.abs();
    } else if (monthsBack == 1) {
      lastMonth[key] = (lastMonth[key] ?? 0) + e.amount!.abs();
    } else {
      continue;
    }
    display.putIfAbsent(key, () => e.category!.trim());
  }

  final spikes = <CategorySpike>[];
  thisMonth.forEach((key, current) {
    final prior = lastMonth[key] ?? 0;
    if (prior <= 0) return;
    final change = (current - prior) / prior;
    if (change < kCategorySpikeThreshold) return;
    spikes.add(CategorySpike(
      category: display[key] ?? key,
      thisMonth: current,
      lastMonth: prior,
      changeFraction: change,
    ));
  });

  spikes.sort((a, b) => b.changeFraction.compareTo(a.changeFraction));
  return spikes;
}

/// Categories with at least [minSpend] this month that no envelope covers,
/// biggest first.
///
/// Envelopes are matched by [normalizeCategory] — the same rule the budgets
/// screen and [forecastEnvelopes] use — so a differently-cased category cannot
/// look uncovered.
List<UnbudgetedCategory> detectUnbudgetedCategories(
  List<Entry> entries, {
  required List<BudgetEnvelope> envelopes,
  required double minSpend,
  required double roundTo,
  required DateTime now,
}) {
  final covered = {for (final e in envelopes) normalizeCategory(e.category)};
  final thisMonthOrdinal = _monthOrdinal(now);

  final spend = <String, double>{};
  final display = <String, String>{};
  for (final e in entries) {
    if (!e.isExpense) continue;
    if (_monthOrdinal(e.timestamp) != thisMonthOrdinal) continue;
    final key = normalizeCategory(e.category);
    if (key.isEmpty || covered.contains(key)) continue;
    spend[key] = (spend[key] ?? 0) + e.amount!.abs();
    display.putIfAbsent(key, () => e.category!.trim());
  }

  final out = <UnbudgetedCategory>[];
  spend.forEach((key, total) {
    if (total < minSpend) return;
    out.add(UnbudgetedCategory(
      category: display[key] ?? key,
      monthSpend: total,
      suggestedCap: _suggestCap(total, roundTo),
    ));
  });

  out.sort((a, b) => b.monthSpend.compareTo(a.monthSpend));
  return out;
}

/// Capped envelopes averaging below [kUnderspendCeiling] of their cap over the
/// last [kSavingsWindowMonths] completed months, biggest saving first.
///
/// Completed months only for the average: measuring a still-open month against
/// a full-month cap would call every envelope underspent on the 2nd. The open
/// month still vetoes: an envelope whose spend this month already passes the
/// suggested cap (over budget included) has no room to trim.
List<SavingsOpportunity> detectSavingsOpportunities(
  List<Entry> entries, {
  required List<BudgetEnvelope> envelopes,
  required double roundTo,
  required DateTime now,
}) {
  final capped = envelopes.where((e) => e.cap > 0).toList();
  if (capped.isEmpty) return const [];

  final thisMonthOrdinal = _monthOrdinal(now);
  final totals = <String, double>{};
  final thisMonth = <String, double>{};
  for (final e in entries) {
    if (!e.isExpense) continue;
    final monthsBack = thisMonthOrdinal - _monthOrdinal(e.timestamp);
    if (monthsBack < 0 || monthsBack > kSavingsWindowMonths) continue;
    final key = normalizeCategory(e.category);
    if (key.isEmpty) continue;
    final bucket = monthsBack == 0 ? thisMonth : totals;
    bucket[key] = (bucket[key] ?? 0) + e.amount!.abs();
  }

  final out = <SavingsOpportunity>[];
  for (final env in capped) {
    final average =
        (totals[normalizeCategory(env.category)] ?? 0) / kSavingsWindowMonths;
    // No history is not the same as thrift — say nothing rather than propose a
    // cap off an empty window.
    if (average <= 0) continue;
    if (average >= env.cap * kUnderspendCeiling) continue;

    final suggested = _suggestCap(average, roundTo);
    if (suggested >= env.cap) continue;
    if ((thisMonth[normalizeCategory(env.category)] ?? 0) > suggested) continue;

    out.add(SavingsOpportunity(
      category: env.category,
      cap: env.cap,
      monthlyAverage: average,
      suggestedCap: suggested,
    ));
  }

  out.sort((a, b) => b.monthlySaving.compareTo(a.monthlySaving));
  return out;
}
