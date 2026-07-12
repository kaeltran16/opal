import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/models.dart';
import 'providers.dart';

part 'budget_recommendations_controller.g.dart';

/// Which way a category's spend is heading over the recent window.
enum SpendTrend { increasing, stable, decreasing }

/// How much history backs a recommendation (from the transaction count).
enum RecommendationConfidence { high, medium, low }

/// A suggested monthly cap for one spend category, derived from the last three
/// completed months. Pure data — the UI composes the human-readable reasoning
/// from these fields so this stays currency- and copy-agnostic.
@immutable
class BudgetRecommendation {
  const BudgetRecommendation({
    required this.category,
    required this.suggestedCap,
    required this.currentCap,
    required this.monthlyAverage,
    required this.trend,
    required this.percentChange,
    required this.confidence,
    required this.bufferFraction,
  });

  /// Display category name (the envelope's name when one exists, else the
  /// entry's own category text).
  final String category;

  /// Suggested monthly cap: the 3-month average plus a trend-based buffer,
  /// rounded up to a currency-appropriate unit.
  final double suggestedCap;

  /// The current envelope cap for this category, or null when none is set yet.
  final double? currentCap;

  /// Average monthly spend across the last three completed months.
  final double monthlyAverage;

  final SpendTrend trend;

  /// Signed percent change of the most recent completed month vs the 3-month
  /// average (e.g. +16.7 for "rising 17%"). 0 when there's no baseline.
  final double percentChange;

  final RecommendationConfidence confidence;

  /// The buffer applied over the average, as a fraction (0.15 = +15%). Derived
  /// from [trend]; exposed so the UI needn't re-derive the mapping.
  final double bufferFraction;
}

// Buffer applied over the 3-month average, by trend. A rising category gets
// more headroom; a falling one less.
const double _stableBuffer = 0.15;
const double _increasingBuffer = 0.25;
const double _decreasingBuffer = 0.10;

// A month is "increasing"/"decreasing" only past this band vs the average.
const double _trendBand = 0.10;

// Confidence from transaction count over the 3-month window (≈3/month = high).
const int _highConfidenceTxns = 9;
const int _lowConfidenceTxns = 3;

// Base rounding unit in USD-scale; multiplied by the currency's budgetScale so
// caps round to 50,000₫ / $50 — clean numbers in either currency.
const double _roundingBaseUnit = 50;

// Number of completed months the recommendation is based on.
const int _windowMonths = 3;

/// Per-category accumulator over the window: spend bucketed by how many months
/// back the entry falls (index 0 = most recent completed month).
class _CategoryAccumulator {
  _CategoryAccumulator(this.display);
  String display;
  final List<double> monthly = List<double>.filled(_windowMonths, 0);
  int count = 0;
}

SpendTrend _detectTrend(double recentMonth, double average) {
  if (average == 0) return SpendTrend.stable;
  final pct = (recentMonth - average) / average;
  if (pct > _trendBand) return SpendTrend.increasing;
  if (pct < -_trendBand) return SpendTrend.decreasing;
  return SpendTrend.stable;
}

double _bufferFor(SpendTrend trend) => switch (trend) {
      SpendTrend.increasing => _increasingBuffer,
      SpendTrend.decreasing => _decreasingBuffer,
      SpendTrend.stable => _stableBuffer,
    };

RecommendationConfidence _confidenceFor(int txnCount) {
  if (txnCount >= _highConfidenceTxns) return RecommendationConfidence.high;
  if (txnCount < _lowConfidenceTxns) return RecommendationConfidence.low;
  return RecommendationConfidence.medium;
}

/// Builds suggested caps from [entries] spanning the three completed months
/// before [now]. Extracted from the provider so it can be tested directly.
///
/// For each spend category with expenses, averages the three months, sizes a
/// buffer from the trend (most-recent completed month vs that average), and
/// rounds up to [roundTo]. Categories are matched to [envelopes] via
/// [normalizeCategory] to attach the current cap and prefer the envelope's
/// display name. Sorted by suggested cap, highest first.
List<BudgetRecommendation> buildBudgetRecommendations(
  List<Entry> entries, {
  required List<BudgetEnvelope> envelopes,
  required double roundTo,
  DateTime? now,
}) {
  final anchor = now ?? DateTime.now();
  final currentMonthOrdinal = anchor.year * 12 + anchor.month;

  final capByCategory = <String, double>{
    for (final e in envelopes) normalizeCategory(e.category): e.cap,
  };
  final nameByCategory = <String, String>{
    for (final e in envelopes) normalizeCategory(e.category): e.category,
  };

  final byCategory = <String, _CategoryAccumulator>{};
  for (final entry in entries) {
    if (!entry.isExpense) continue;
    final key = normalizeCategory(entry.category);
    if (key.isEmpty) continue;
    final entryOrdinal = entry.timestamp.year * 12 + entry.timestamp.month;
    final monthsBack = currentMonthOrdinal - entryOrdinal;
    if (monthsBack < 1 || monthsBack > _windowMonths) continue;

    final acc = byCategory.putIfAbsent(
      key,
      () => _CategoryAccumulator(nameByCategory[key] ?? entry.category!.trim()),
    );
    acc.monthly[monthsBack - 1] += entry.amount!.abs();
    acc.count++;
  }

  final recommendations = <BudgetRecommendation>[];
  byCategory.forEach((key, acc) {
    final total = acc.monthly.fold<double>(0, (s, v) => s + v);
    final average = total / _windowMonths;
    if (average <= 0) return;

    final recentMonth = acc.monthly[0];
    final trend = _detectTrend(recentMonth, average);
    final buffer = _bufferFor(trend);
    final raw = average * (1 + buffer);
    final suggested =
        roundTo > 0 ? (raw / roundTo).ceil() * roundTo : raw;
    final percentChange =
        average == 0 ? 0.0 : ((recentMonth - average) / average) * 100;

    recommendations.add(BudgetRecommendation(
      category: acc.display,
      suggestedCap: suggested,
      currentCap: capByCategory[key],
      monthlyAverage: average,
      trend: trend,
      percentChange: percentChange,
      confidence: _confidenceFor(acc.count),
      bufferFraction: buffer,
    ));
  });

  recommendations.sort((a, b) => b.suggestedCap.compareTo(a.suggestedCap));
  return recommendations;
}

/// Streams suggested caps for the current month, recomputed whenever the last
/// three months' entries change. Reads envelopes one-shot per emission.
@riverpod
Stream<List<BudgetRecommendation>> budgetRecommendations(Ref ref) async* {
  final entriesRepo = ref.watch(entryRepositoryProvider);
  final envelopeRepo = ref.watch(budgetEnvelopeRepositoryProvider);
  final currency = ref.watch(appSettingsControllerProvider).currency;

  final now = DateTime.now();
  final windowStart = DateTime(now.year, now.month - _windowMonths);
  final windowEnd = DateTime(now.year, now.month);
  final roundTo = _roundingBaseUnit * currency.budgetScale;

  await for (final entries
      in entriesRepo.watchEntriesInRange(windowStart, windowEnd)) {
    final envelopes = await envelopeRepo.getEnvelopes();
    yield buildBudgetRecommendations(
      entries,
      envelopes: envelopes,
      roundTo: roundTo,
      now: now,
    );
  }
}
