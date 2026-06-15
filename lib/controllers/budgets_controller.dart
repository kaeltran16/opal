import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/models.dart';
import 'providers.dart';

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
  const BudgetsData({required this.envelopes, required this.month});

  /// Per-envelope spend rows, in envelope [BudgetEnvelope.position] order.
  final List<EnvelopeSpend> envelopes;

  /// First day of the month this data covers.
  final DateTime month;

  /// Summed caps across all envelopes.
  double get totalCap =>
      envelopes.fold<double>(0, (s, e) => s + e.cap);

  /// Summed month-to-date spend across all envelopes.
  double get totalSpent =>
      envelopes.fold<double>(0, (s, e) => s + e.spent);

  /// Cap minus spend across all envelopes (can go negative).
  double get totalLeft => totalCap - totalSpent;

  /// `totalSpent / totalCap` (0..1+); 0 when there's no cap.
  double get totalProgress => totalCap == 0 ? 0 : totalSpent / totalCap;

  /// Fraction of the month elapsed (day-of-month / days-in-month), relative to
  /// now. Used to judge whether spend is keeping pace with the calendar.
  double get monthPaceFraction {
    final now = DateTime.now();
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    return now.day / daysInMonth;
  }

  /// Days remaining in the month (inclusive of today), relative to now.
  int get daysLeft {
    final now = DateTime.now();
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    return daysInMonth - now.day;
  }

  /// Whether overall spend is on or under the calendar pace (small slack).
  bool get onPace => totalProgress <= monthPaceFraction + 0.02;
}

/// Builds a [BudgetsData] from [envelopes] and the month's [monthEntries].
/// Extracted from the provider so it can be tested directly with fixtures.
///
/// Matching rule: each expense entry (money type, negative amount) is bucketed
/// into the envelope whose category matches case-insensitively (trimmed); its
/// `amount.abs()` is summed. Unmatched expenses are dropped (counted toward no
/// envelope). Envelope order ([BudgetEnvelope.position]) is preserved.
BudgetsData buildBudgetsData(
  List<BudgetEnvelope> envelopes,
  List<Entry> monthEntries, {
  DateTime? now,
}) {
  final ordered = [...envelopes]
    ..sort((a, b) => a.position.compareTo(b.position));

  final byCategory = <String, double>{
    for (final e in ordered) e.category.trim().toLowerCase(): 0,
  };
  for (final entry in monthEntries) {
    if (entry.type != EntryType.money) continue;
    if ((entry.amount ?? 0) >= 0) continue;
    final key = (entry.category ?? '').trim().toLowerCase();
    if (byCategory.containsKey(key)) {
      byCategory[key] = byCategory[key]! + entry.amount!.abs();
    }
  }

  final spends = ordered
      .map((env) => EnvelopeSpend(
            envelope: env,
            spent: byCategory[env.category.trim().toLowerCase()] ?? 0,
          ))
      .toList();

  final anchor = now ?? DateTime.now();
  return BudgetsData(
    envelopes: spends,
    month: DateTime(anchor.year, anchor.month),
  );
}

/// Streams the [BudgetsData] for the current month. Reactive: re-emits whenever
/// this month's entries change. Reads envelopes one-shot per emission.
@riverpod
Stream<BudgetsData> budgetsData(Ref ref) async* {
  final entriesRepo = ref.watch(entryRepositoryProvider);
  final envelopeRepo = ref.watch(budgetEnvelopeRepositoryProvider);

  final now = DateTime.now();
  final start = DateTime(now.year, now.month);
  final end = DateTime(now.year, now.month + 1);

  await for (final entries in entriesRepo.watchEntriesInRange(start, end)) {
    final envelopes = await envelopeRepo.getEnvelopes();
    yield buildBudgetsData(envelopes, entries, now: now);
  }
}
