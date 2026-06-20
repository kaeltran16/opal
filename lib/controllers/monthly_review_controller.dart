import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/models.dart';
import '../services/pal/pal_context_builder.dart' show ritualStreakDays;
import '../services/services.dart' show ReviewRange;
import '../util/dates.dart';
import '../util/format.dart';
import 'providers.dart';

part 'monthly_review_controller.g.dart';

/// One big "By the numbers" stat row on the Monthly Review (handoff screen 14).
@immutable
class ReviewStat {
  const ReviewStat({
    required this.label,
    required this.value,
    this.unit,
    this.sub,
    required this.colorToken,
    required this.icon,
  });

  /// Row title, e.g. "Total spent".
  final String label;

  /// Big formatted value, e.g. "\$1,840" or "12".
  final String value;

  /// Optional trailing unit, e.g. "min" or "days".
  final String? unit;

  /// Optional secondary caption under the label, e.g. "↓ 12% vs March".
  final String? sub;

  /// `context.colors.forType(colorToken)` accent ('money'|'move'|'rituals'|'').
  final String colorToken;

  /// SF Symbol name for the row's tinted icon tile.
  final String icon;
}

/// Raw single-month aggregates folded from one month's entries. Used both for
/// the current month and (without rituals) the previous month, so deltas can be
/// computed by comparing two of these.
@immutable
class MonthAggregate {
  const MonthAggregate({
    required this.totalSpent,
    required this.moveKcal,
    required this.ritualsKept,
    required this.activeMoveDays,
  });

  const MonthAggregate.empty()
      : totalSpent = 0,
        moveKcal = 0,
        ritualsKept = 0,
        activeMoveDays = 0;

  /// Absolute sum of expense amounts (money entries, amount < 0).
  final double totalSpent;

  /// Total movement active energy (move entries' [Entry.calories]).
  final int moveKcal;

  /// Completed routines in the month (per-day completions summed).
  final int ritualsKept;

  /// Distinct calendar days with at least one move entry.
  final int activeMoveDays;
}

/// Folds one month's [entries] into a [MonthAggregate]. [monthStart]/[days]
/// scope the completed-routines count to that month.
MonthAggregate foldMonth(
  List<Entry> entries,
  List<RitualRoutine> routines,
  DateTime monthStart,
  int days,
) {
  var spent = 0.0;
  var moveKcal = 0;
  final moveDays = <int>{};
  for (final e in entries) {
    switch (e.type) {
      case EntryType.money:
        if ((e.amount ?? 0) < 0) spent += e.amount!.abs();
      case EntryType.move:
        moveKcal += e.calories ?? 0;
        final t = e.timestamp;
        moveDays.add(t.year * 10000 + t.month * 100 + t.day);
      case EntryType.rituals:
        break; // counted as completed routines below, not step entries
    }
  }
  return MonthAggregate(
    totalSpent: spent,
    moveKcal: moveKcal,
    ritualsKept: completedRoutinesInPeriod(entries, routines,
        start: monthStart, days: days),
    activeMoveDays: moveDays.length,
  );
}

/// Days in the month that [d] falls in.
int _daysInMonth(DateTime d) => DateTime(d.year, d.month + 1, 0).day;

/// The fully-computed "By the numbers" block for [month], derived from the
/// repositories. All math lives here so the screen is dumb and this is
/// unit-testable. Deltas compare [current] against [previous] (the prior month).
@immutable
class MonthlyStats {
  const MonthlyStats({
    required this.month,
    required this.current,
    required this.previous,
    required this.longestStreak,
    this.currency = Currency.usd,
  });

  final DateTime month;

  /// Display currency for the "Total spent" row.
  final Currency currency;

  /// This month's aggregates.
  final MonthAggregate current;

  /// The previous month's aggregates, for vs-last-month deltas.
  final MonthAggregate previous;

  /// Current ritual streak (days): consecutive days with at least one completed
  /// ritual step, computed from persisted ritual entries.
  final int longestStreak;

  double get totalSpent => current.totalSpent;
  int get moveKcal => current.moveKcal;
  int get ritualsKept => current.ritualsKept;

  /// The previous month's name, e.g. "March".
  String get _previousMonthName {
    final m = DateTime(month.year, month.month - 1);
    return kMonths[m.month - 1];
  }

  /// Signed percent change of [now] vs [then], rounded; null when there is no
  /// prior baseline (then == 0) so we don't divide by zero or invent a delta.
  int? _pctChange(num now, num then) {
    if (then == 0) return null;
    return (((now - then) / then) * 100).round();
  }

  /// "↓ 12% vs March" style caption, or null when there's no comparable prior
  /// month so we don't fabricate a delta.
  String? _deltaLabel(num now, num then) {
    final pct = _pctChange(now, then);
    if (pct == null) return null;
    final arrow = pct < 0 ? '↓' : (pct > 0 ? '↑' : '·');
    return '$arrow ${pct.abs()}% vs $_previousMonthName';
  }

  /// The four big stat rows, in handoff order.
  List<ReviewStat> get rows {
    final spentDelta = _deltaLabel(current.totalSpent, previous.totalSpent);
    final moveDelta = _pctChange(current.moveKcal, previous.moveKcal);
    final activeDays = current.activeMoveDays;
    final moveSubParts = <String>[
      if (moveDelta != null)
        '${moveDelta < 0 ? '↓' : (moveDelta > 0 ? '↑' : '·')} '
            '${moveDelta.abs()}% vs $_previousMonthName',
      if (activeDays > 0)
        '$activeDays active ${activeDays == 1 ? 'day' : 'days'}',
    ];
    return [
      ReviewStat(
        label: 'Total spent',
        value: formatCurrency(totalSpent, currency),
        sub: spentDelta,
        colorToken: 'money',
        icon: 'dollarsign.circle.fill',
      ),
      ReviewStat(
        label: 'Active energy',
        value: '$moveKcal',
        unit: 'kcal',
        sub: moveSubParts.isEmpty ? null : moveSubParts.join(' · '),
        colorToken: 'move',
        icon: 'flame.fill',
      ),
      ReviewStat(
        label: 'Routines kept',
        value: '$ritualsKept',
        // qualitative "best month yet" needs multi-month history; the only
        // computable comparison is vs the prior month.
        sub: _deltaLabel(current.ritualsKept, previous.ritualsKept),
        colorToken: 'rituals',
        icon: 'sparkles',
      ),
      ReviewStat(
        label: 'Streak',
        value: '$longestStreak',
        unit: longestStreak == 1 ? 'day' : 'days',
        sub: 'Routines, ongoing',
        colorToken: 'rituals',
        icon: 'flame.fill',
      ),
    ];
  }
}

/// Folds the current month's [entries] + [previous] month's entries into
/// [MonthlyStats]. [ritualStreak] is the current consecutive-day ritual streak,
/// computed upstream from a lookback that can span the month boundary. Extracted
/// from the provider so it can be tested with fixtures.
MonthlyStats buildMonthlyStats(
  DateTime month,
  List<Entry> entries,
  List<Entry> previousEntries,
  int ritualStreak, {
  List<RitualRoutine> routines = const [],
  Currency currency = Currency.usd,
}) {
  final monthStart = DateTime(month.year, month.month);
  final prevStart = DateTime(month.year, month.month - 1);
  return MonthlyStats(
    month: monthStart,
    current: foldMonth(entries, routines, monthStart, _daysInMonth(monthStart)),
    previous:
        foldMonth(previousEntries, routines, prevStart, _daysInMonth(prevStart)),
    longestStreak: ritualStreak,
    currency: currency,
  );
}

/// Streams the [MonthlyStats] for the current month. Reactive: re-emits when
/// this month's entries or rituals change; the previous month's entries are a
/// one-shot read each emission (they don't change once the month closes).
@riverpod
Stream<MonthlyStats> monthlyStats(Ref ref) async* {
  final entriesRepo = ref.watch(entryRepositoryProvider);
  final ritualRepo = ref.watch(ritualRepositoryProvider);
  final currency = ref.watch(appSettingsControllerProvider).currency;

  final now = DateTime.now();
  final start = DateTime(now.year, now.month);
  final end = DateTime(now.year, now.month + 1);
  final prevStart = DateTime(now.year, now.month - 1);
  final today = DateTime(now.year, now.month, now.day);

  await for (final entries in entriesRepo.watchEntriesInRange(start, end)) {
    // The prior month is closed, so a one-shot read (not a nested watch) is
    // correct — and a watch's `.first` never resolves under flutter_test's
    // fake async, which would wedge this stream in its loading state.
    final previous = await entriesRepo.getEntriesInRange(prevStart, start);
    // 60-day lookback so an ongoing ritual streak that spans the month start is
    // counted in full (the month window alone would truncate it).
    final lookback = await entriesRepo.getEntriesInRange(
      today.subtract(const Duration(days: 60)),
      today.add(const Duration(days: 1)),
    );
    final routines = await ritualRepo.getAll();
    yield buildMonthlyStats(
        start, entries, previous, ritualStreakDays(lookback, now: now),
        routines: routines, currency: currency);
  }
}

/// Drives the narrative card: holds the Pal-written review text with a loading
/// state, and re-requests it on [regenerate]. The narrative is the only async,
/// re-requestable piece; the stats are a separate reactive stream above.
@riverpod
class MonthlyReviewController extends _$MonthlyReviewController {
  @override
  Future<String> build() {
    final pal = ref.watch(palServiceProvider);
    final now = DateTime.now();
    return pal.review(DateTime(now.year, now.month), ReviewRange.month);
  }

  /// Re-requests the narrative from [PalService.review], showing the loading
  /// state while the new text is fetched (so the card can spin).
  Future<void> regenerate() async {
    final pal = ref.read(palServiceProvider);
    final now = DateTime.now();
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => pal.review(DateTime(now.year, now.month), ReviewRange.month),
    );
  }
}
