import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../analysis/spend_alerts.dart';
import 'providers.dart';

part 'budget_advisories_controller.g.dart';

// Month-to-date spend, in USD-scale, before an uncovered category is worth
// suggesting an envelope for. Multiplied by the currency's budgetScale the same
// way `_roundingBaseUnit` is, so the floor reads as $500 / 500,000₫.
const double _unbudgetedFloorBase = 500;

/// The advisory (non-urgent) budget findings the Budgets screen lists: spend
/// with no envelope covering it, and envelopes with more headroom than the
/// category uses.
///
/// Pure data — the screen composes the copy and formats the currency, matching
/// `BudgetRecommendation` and [EnvelopeForecast].
@immutable
class BudgetAdvisories {
  const BudgetAdvisories({
    required this.unbudgeted,
    required this.savings,
  });

  final List<UnbudgetedCategory> unbudgeted;
  final List<SavingsOpportunity> savings;

  bool get isEmpty => unbudgeted.isEmpty && savings.isEmpty;
}

/// Streams the advisory findings, recomputed whenever entries in the window
/// change. Reads envelopes one-shot per emission, mirroring
/// `budgetRecommendations`.
///
/// The window spans the three completed months (for the savings average) plus
/// the current one (for uncovered spend), so both detectors share a single
/// subscription.
@riverpod
Stream<BudgetAdvisories> budgetAdvisories(Ref ref) async* {
  final entriesRepo = ref.watch(entryRepositoryProvider);
  final envelopeRepo = ref.watch(budgetEnvelopeRepositoryProvider);
  final currency = ref.watch(appSettingsControllerProvider).currency;

  final now = DateTime.now();
  final windowStart = DateTime(now.year, now.month - kSavingsWindowMonths);
  final windowEnd = DateTime(now.year, now.month + 1);
  final roundTo = kBudgetRoundingBaseUnit * currency.budgetScale;
  final minSpend = _unbudgetedFloorBase * currency.budgetScale;

  await for (final entries
      in entriesRepo.watchEntriesInRange(windowStart, windowEnd)) {
    final envelopes = await envelopeRepo.getEnvelopes();
    yield BudgetAdvisories(
      unbudgeted: detectUnbudgetedCategories(
        entries,
        envelopes: envelopes,
        minSpend: minSpend,
        roundTo: roundTo,
        now: now,
      ),
      savings: detectSavingsOpportunities(
        entries,
        envelopes: envelopes,
        roundTo: roundTo,
        now: now,
      ),
    );
  }
}
