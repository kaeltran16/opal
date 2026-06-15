import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/models.dart';
import 'providers.dart';

part 'insights_money_controller.g.dart';

/// One month's expense total in the 6-month trend. [partial] flags the current
/// (in-progress) month so the chart can hatch it and the average can exclude it.
@immutable
class MonthSpend {
  const MonthSpend({
    required this.label,
    required this.year,
    required this.month,
    required this.total,
    required this.partial,
  });

  /// Short month name (Jan..Dec).
  final String label;
  final int year;
  final int month;

  /// Summed expense magnitude for the month.
  final double total;

  /// Whether this is the current, still-open month.
  final bool partial;
}

/// One category's current-month spend with its share, month-over-month delta,
/// and presentation (icon + color token resolved against the envelopes).
@immutable
class CategoryInsight {
  const CategoryInsight({
    required this.label,
    required this.amount,
    required this.fraction,
    required this.deltaPct,
    required this.icon,
    required this.colorToken,
  });

  /// Display label (canonical envelope name or the raw category).
  final String label;

  /// This month's summed magnitude for the category.
  final double amount;

  /// `amount / currentMonthTotal` (0..1); 0 when the month total is 0.
  final double fraction;

  /// Signed percent change vs last month, rounded; null when last month was 0.
  final int? deltaPct;

  /// SF symbol for the row's icon tile.
  final String icon;

  /// `context.colors.forType(colorToken)` accent.
  final String colorToken;
}

/// The fully-computed Insights view model: the 6-month trend plus the current
/// month's category breakdown. All math lives here so the screen stays dumb.
@immutable
class InsightsData {
  const InsightsData({required this.months, required this.categories});

  /// Six calendar months ending at the current month, oldest-first.
  final List<MonthSpend> months;

  /// Current-month category breakdown, largest-first.
  final List<CategoryInsight> categories;

  /// The current (last) month's total.
  double get currentTotal => months.isEmpty ? 0 : months.last.total;

  /// Mean of the non-partial months' totals; 0 when there are none.
  double get average {
    final full = months.where((m) => !m.partial).toList();
    if (full.isEmpty) return 0;
    return full.fold<double>(0, (s, m) => s + m.total) / full.length;
  }

  /// The most recent full (non-partial) month's total; 0 when there is none.
  double get lastFullTotal {
    final full = months.where((m) => !m.partial).toList();
    return full.isEmpty ? 0 : full.last.total;
  }

  /// Signed percent change of [currentTotal] vs [lastFullTotal], rounded; null
  /// when there's no prior baseline (lastFull == 0).
  int? get momPct {
    final prev = lastFullTotal;
    if (prev == 0) return null;
    return (((currentTotal - prev) / prev) * 100).round();
  }

  /// Largest month total, for bar scaling; 0 when empty.
  double get maxMonthTotal =>
      months.fold<double>(0, (m, e) => e.total > m ? e.total : m);
}

const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Title-cases a single word (used for the 'Uncategorized' fallback label).
String _titleCase(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}';

/// Signed percent change of [now] vs [then], rounded; null when then == 0.
/// Mirrors `monthly_review_controller`'s `_pctChange`.
int? _pctChange(num now, num then) {
  if (then == 0) return null;
  return (((now - then) / then) * 100).round();
}

/// Builds an [InsightsData] from a 6-month window of [windowEntries] and the
/// budget [envelopes] (used to resolve a category's icon + color token).
/// Extracted from the provider so it can be tested directly with fixtures.
InsightsData buildInsightsData(
  List<Entry> windowEntries,
  List<BudgetEnvelope> envelopes, {
  DateTime? now,
}) {
  final anchor = now ?? DateTime.now();

  // --- 6-month trend ---------------------------------------------------------
  // The six calendar months ending at the anchor's month, oldest-first.
  final monthKeys = <(int year, int month)>[
    for (var i = 5; i >= 0; i--)
      () {
        final d = DateTime(anchor.year, anchor.month - i);
        return (d.year, d.month);
      }(),
  ];
  final monthTotals = {for (final k in monthKeys) k: 0.0};
  for (final e in windowEntries) {
    if (e.type != EntryType.money) continue;
    if ((e.amount ?? 0) >= 0) continue;
    final key = (e.timestamp.year, e.timestamp.month);
    if (monthTotals.containsKey(key)) {
      monthTotals[key] = monthTotals[key]! + e.amount!.abs();
    }
  }
  final currentKey = monthKeys.last;
  final months = [
    for (final k in monthKeys)
      MonthSpend(
        label: _monthNames[k.$2 - 1],
        year: k.$1,
        month: k.$2,
        total: monthTotals[k]!,
        partial: k == currentKey,
      ),
  ];

  // --- Category breakdown (current month) ------------------------------------
  // Resolve a display label + icon/color per category key. Envelopes win for
  // presentation; unmatched categories fall back to a generic money treatment.
  final envByKey = <String, BudgetEnvelope>{
    for (final env in envelopes) env.category.trim().toLowerCase(): env,
  };

  String labelFor(String key, String raw) {
    final env = envByKey[key];
    if (env != null) return env.category;
    if (key == 'uncategorized') return 'Uncategorized';
    return raw;
  }

  final curTotals = <String, double>{};
  final curRaw = <String, String>{};
  final prevTotals = <String, double>{};
  for (final e in windowEntries) {
    if (e.type != EntryType.money) continue;
    if ((e.amount ?? 0) >= 0) continue;
    final raw = (e.category ?? '').trim();
    final key = raw.isEmpty ? 'uncategorized' : raw.toLowerCase();
    final mk = (e.timestamp.year, e.timestamp.month);
    if (mk == currentKey) {
      curTotals[key] = (curTotals[key] ?? 0) + e.amount!.abs();
      curRaw[key] = raw.isEmpty ? 'Uncategorized' : raw;
    } else if (mk == monthKeys[monthKeys.length - 2]) {
      prevTotals[key] = (prevTotals[key] ?? 0) + e.amount!.abs();
    }
  }

  final currentMonthTotal =
      curTotals.values.fold<double>(0, (s, v) => s + v);

  final categories = curTotals.entries.map((e) {
    final key = e.key;
    final amount = e.value;
    final env = envByKey[key];
    return CategoryInsight(
      label: labelFor(key, curRaw[key] ?? _titleCase(key)),
      amount: amount,
      fraction: currentMonthTotal == 0 ? 0 : amount / currentMonthTotal,
      deltaPct: _pctChange(amount, prevTotals[key] ?? 0),
      icon: env?.icon ?? 'creditcard.fill',
      colorToken: env?.colorToken ?? 'money',
    );
  }).toList()
    ..sort((a, b) => b.amount.compareTo(a.amount));

  return InsightsData(months: months, categories: categories);
}

/// Streams the [InsightsData] over a rolling 6-month window. Reactive: re-emits
/// whenever entries in the window change. Reads envelopes one-shot per emission.
@riverpod
Stream<InsightsData> insightsData(Ref ref) async* {
  final entriesRepo = ref.watch(entryRepositoryProvider);
  final envelopeRepo = ref.watch(budgetEnvelopeRepositoryProvider);

  final now = DateTime.now();
  final start = DateTime(now.year, now.month - 5);
  final end = DateTime(now.year, now.month + 1);

  await for (final entries in entriesRepo.watchEntriesInRange(start, end)) {
    final envelopes = await envelopeRepo.getEnvelopes();
    yield buildInsightsData(entries, envelopes, now: now);
  }
}
