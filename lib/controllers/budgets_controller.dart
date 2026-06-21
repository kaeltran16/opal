import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/models.dart';
import 'providers.dart';
import 'today_controller.dart' show goalsStreamProvider;

part 'budgets_controller.g.dart';

/// One envelope with its month-to-date spend. All ratios are derived so the
/// screen stays dumb and this is unit-testable.
@immutable
class EnvelopeSpend {
  const EnvelopeSpend({required this.envelope, required this.spent});

  final BudgetEnvelope envelope;

  /// Sum of matched expense magnitudes this month.
  final double spent;

  /// The envelope's monthly cap.
  double get cap => envelope.cap;

  /// Cap minus spend (can go negative when over budget).
  double get remaining => cap - spent;

  /// Whether spend has exceeded the cap.
  bool get over => spent > cap;

  /// `spent / cap` (0..1+); 0 when the cap is 0.
  double get progress => cap == 0 ? 0 : spent / cap;
}

/// The fully-computed budgets view model for one month: per-envelope spend plus
/// rollup totals and pacing. All math lives here.
@immutable
class BudgetsData {
  const BudgetsData({
    required this.envelopes,
    required this.month,
    required this.monthlyBudget,
  });

  /// Per-envelope spend rows, in envelope [BudgetEnvelope.position] order.
  final List<EnvelopeSpend> envelopes;

  /// First day of the month this data covers.
  final DateTime month;

  /// The monthly budget basis = `dailyBudget * daysInMonth`. Single source of
  /// truth shared with the Day/Week/Month recap so editing the daily budget
  /// moves this screen's target (the per-envelope cap sum was seed-frozen and
  /// ignored the only editable budget).
  final double monthlyBudget;

  /// The monthly budget target. Derived from the editable daily budget, not the
  /// summed per-envelope caps (which stay on each [EnvelopeSpend.cap] row).
  double get totalCap => monthlyBudget;

  /// Summed month-to-date spend across all envelopes.
  double get totalSpent =>
      envelopes.fold<double>(0, (s, e) => s + e.spent);

  /// Budget minus spend (can go negative).
  double get totalLeft => totalCap - totalSpent;

  /// `totalSpent / monthlyBudget` (0..1+); 0 when there's no budget.
  double get totalProgress => totalCap == 0 ? 0 : totalSpent / totalCap;

  /// Fraction of the month elapsed (day-of-month / days-in-month). Derived from
  /// [month] vs now and clamped to the covered month, so a fully-elapsed past
  /// month reads 1.0 and a future month reads 0.0 — correct even if a historical
  /// month is ever rendered.
  double get monthPaceFraction => _elapsedDays / _daysInMonth;

  /// Days remaining in the month (inclusive of today). Clamped to the covered
  /// month so a past month reads 0 and a future month reads the full month.
  int get daysLeft => _daysInMonth - _elapsedDays;

  int get _daysInMonth => DateTime(month.year, month.month + 1, 0).day;

  /// Elapsed day-of-month for [month], clamped to [1, _daysInMonth]: the real
  /// day-of-month when now is inside [month], a full month when now is past it,
  /// and the first day when now precedes it.
  int get _elapsedDays {
    final now = DateTime.now();
    final isThisMonth = now.year == month.year && now.month == month.month;
    if (isThisMonth) return now.day;
    final nowMonth = DateTime(now.year, now.month);
    return nowMonth.isAfter(month) ? _daysInMonth : 1;
  }

  /// Whether overall spend is on or under the calendar pace (small slack).
  bool get onPace => totalProgress <= monthPaceFraction + 0.02;
}

/// Catch-all row for expenses whose category matches no envelope. Cap 0 — it's
/// a tally, not a budget. Its presence keeps the Budgets total equal to the
/// real month spend (and to Insights), so nothing is ever silently dropped.
const _uncategorizedEnvelope = BudgetEnvelope(
  id: 'env-uncategorized',
  category: 'Uncategorized',
  cap: 0,
  icon: 'tray.fill',
  colorToken: 'money',
  position: 1 << 30,
);

/// Builds a [BudgetsData] from [envelopes] and the month's [monthEntries].
/// Extracted from the provider so it can be tested directly with fixtures.
///
/// Matching rule: each expense entry (money type, negative amount) is bucketed
/// into the envelope whose category matches via [normalizeCategory]; its
/// `amount.abs()` is summed. Expenses matching no envelope are summed into an
/// "Uncategorized" row (appended only when non-zero) so [BudgetsData.totalSpent]
/// always equals the real month spend. Envelope order is preserved.
BudgetsData buildBudgetsData(
  List<BudgetEnvelope> envelopes,
  List<Entry> monthEntries, {
  Goals goals = const Goals(),
  DateTime? now,
}) {
  final ordered = [...envelopes]
    ..sort((a, b) => a.position.compareTo(b.position));

  final byCategory = <String, double>{
    for (final e in ordered) normalizeCategory(e.category): 0,
  };
  var uncategorized = 0.0;
  for (final entry in monthEntries) {
    if (entry.type != EntryType.money) continue;
    if ((entry.amount ?? 0) >= 0) continue;
    final magnitude = entry.amount!.abs();
    final key = normalizeCategory(entry.category);
    if (byCategory.containsKey(key)) {
      byCategory[key] = byCategory[key]! + magnitude;
    } else {
      uncategorized += magnitude;
    }
  }

  final spends = [
    for (final env in ordered)
      EnvelopeSpend(envelope: env, spent: byCategory[normalizeCategory(env.category)] ?? 0),
    if (uncategorized > 0)
      EnvelopeSpend(envelope: _uncategorizedEnvelope, spent: uncategorized),
  ];

  final anchor = now ?? DateTime.now();
  final month = DateTime(anchor.year, anchor.month);
  final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
  return BudgetsData(
    envelopes: spends,
    month: month,
    monthlyBudget: goals.dailyBudget * daysInMonth,
  );
}

/// Streams the [BudgetsData] for the current month. Reactive: re-emits whenever
/// this month's entries change. Reads envelopes one-shot per emission.
@riverpod
Stream<BudgetsData> budgetsData(Ref ref) async* {
  final entriesRepo = ref.watch(entryRepositoryProvider);
  final envelopeRepo = ref.watch(budgetEnvelopeRepositoryProvider);
  // watched (not one-shot) so a daily-budget edit re-emits the monthly target.
  final goals = ref.watch(goalsStreamProvider).asData?.value ?? const Goals();

  final now = DateTime.now();
  final start = DateTime(now.year, now.month);
  final end = DateTime(now.year, now.month + 1);

  await for (final entries in entriesRepo.watchEntriesInRange(start, end)) {
    final envelopes = await envelopeRepo.getEnvelopes();
    yield buildBudgetsData(envelopes, entries, goals: goals, now: now);
  }
}
