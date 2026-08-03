import 'package:flutter/foundation.dart';

import '../models/models.dart';

/// Where one envelope is heading by month end. Ordered least to most severe;
/// [forecastEnvelopes] sorts by this descending so the UI leads with trouble.
enum ForecastStatus { safe, warning, danger, exceeded }

/// Fraction of the cap that trips [ForecastStatus.warning] on spend alone, even
/// when the pace still lands inside the cap.
const double kWarningProgress = 0.80;

/// One envelope's month-end outlook: where spend stands, where the current pace
/// lands it, and what per-day allowance keeps it inside the cap.
///
/// Pure data — no copy. The UI composes wording and formats currency, the same
/// split [BudgetRecommendation] uses, so this stays currency-agnostic.
@immutable
class EnvelopeForecast {
  const EnvelopeForecast({
    required this.envelope,
    required this.spent,
    required this.dailyAverage,
    required this.projectedSpend,
    required this.daysRemaining,
    required this.recommendedDailyLimit,
    required this.status,
  });

  final BudgetEnvelope envelope;

  /// Month-to-date spend matched to this envelope.
  final double spent;

  /// [spent] over the elapsed days of the month, today included.
  final double dailyAverage;

  /// Month-end spend if [dailyAverage] holds for the rest of the month.
  ///
  /// A straight linear extrapolation, which is why it reads high early in the
  /// month off one large purchase. It also knows nothing about committed spend
  /// that hasn't landed yet (no recurring-charge detection exists), so a month
  /// with a subscription still to bill projects low.
  final double projectedSpend;

  /// Days left after today. 0 on the last day of the month.
  final int daysRemaining;

  /// Per-day allowance over [daysRemaining] that lands exactly on the cap, or
  /// null on the last day of the month, when there is no day left to pace over.
  /// Floors at 0 once the cap is already gone.
  final double? recommendedDailyLimit;

  final ForecastStatus status;

  String get category => envelope.category;

  /// The envelope's monthly cap.
  double get cap => envelope.cap;

  /// `spent / cap` (0..1+). Matches [EnvelopeSpend.progress] so the forecast and
  /// the budgets list can't disagree about how full an envelope reads.
  double get progress => cap == 0 ? 0 : spent / cap;

  /// How far past the cap the pace lands, or 0 when it lands inside.
  double get projectedOverage =>
      projectedSpend > cap ? projectedSpend - cap : 0;

  /// How far past the cap spend has already gone, or 0 when still inside.
  double get overspend => spent > cap ? spent - cap : 0;
}

/// Projects each capped envelope in [envelopes] to month end from the
/// month-to-date [monthEntries], anchored on [now].
///
/// Entries outside [now]'s calendar month are ignored, so the caller may pass a
/// wider window. Expenses are matched to envelopes by [normalizeCategory] — the
/// same rule as `buildBudgetsData` — and income is skipped.
///
/// Envelopes without a real cap are omitted: the budgets screen's
/// "Uncategorized" row is a tally with cap 0, and reporting it as exceeded on
/// the first expense would be nonsense.
///
/// Sorted most-severe first, then by the larger projected overage.
List<EnvelopeForecast> forecastEnvelopes(
  List<BudgetEnvelope> envelopes,
  List<Entry> monthEntries, {
  required DateTime now,
}) {
  final capped = envelopes.where((e) => e.cap > 0).toList();
  if (capped.isEmpty) return const [];

  final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
  final daysElapsed = now.day;
  final daysRemaining = daysInMonth - daysElapsed;

  final spentByKey = <String, double>{};
  for (final e in monthEntries) {
    if (!e.isExpense) continue;
    if (e.timestamp.year != now.year || e.timestamp.month != now.month) continue;
    final key = normalizeCategory(e.category);
    spentByKey[key] = (spentByKey[key] ?? 0) + e.amount!.abs();
  }

  final out = <EnvelopeForecast>[];
  for (final env in capped) {
    final spent = spentByKey[normalizeCategory(env.category)] ?? 0;
    final dailyAverage = spent / daysElapsed;
    final projectedSpend = dailyAverage * daysInMonth;
    final left = env.cap - spent;

    out.add(EnvelopeForecast(
      envelope: env,
      spent: spent,
      dailyAverage: dailyAverage,
      projectedSpend: projectedSpend,
      daysRemaining: daysRemaining,
      recommendedDailyLimit:
          daysRemaining == 0 ? null : (left <= 0 ? 0 : left / daysRemaining),
      status: _statusFor(spent: spent, projected: projectedSpend, cap: env.cap),
    ));
  }

  out.sort((a, b) {
    final bySeverity = b.status.index.compareTo(a.status.index);
    if (bySeverity != 0) return bySeverity;
    return b.projectedOverage.compareTo(a.projectedOverage);
  });
  return out;
}

/// The ladder: already gone beats heading there, which beats nearly full.
ForecastStatus _statusFor({
  required double spent,
  required double projected,
  required double cap,
}) {
  if (spent >= cap) return ForecastStatus.exceeded;
  if (projected >= cap) return ForecastStatus.danger;
  if (spent / cap >= kWarningProgress) return ForecastStatus.warning;
  return ForecastStatus.safe;
}
