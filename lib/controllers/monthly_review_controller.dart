import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/models.dart';
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
    required this.moveMinutes,
    required this.ritualsKept,
    required this.activeMoveDays,
  });

  const MonthAggregate.empty()
      : totalSpent = 0,
        moveMinutes = 0,
        ritualsKept = 0,
        activeMoveDays = 0;

  /// Absolute sum of expense amounts (money entries, amount < 0).
  final double totalSpent;

  /// Total movement minutes (move entries' [Entry.duration]).
  final int moveMinutes;

  /// Count of ritual entries logged.
  final int ritualsKept;

  /// Distinct calendar days with at least one move entry.
  final int activeMoveDays;
}

/// Folds one month's [entries] into a [MonthAggregate].
MonthAggregate foldMonth(List<Entry> entries) {
  var spent = 0.0;
  var moveMinutes = 0;
  var ritualsKept = 0;
  final moveDays = <int>{};
  for (final e in entries) {
    switch (e.type) {
      case EntryType.money:
        if ((e.amount ?? 0) < 0) spent += e.amount!.abs();
      case EntryType.move:
        moveMinutes += e.duration ?? 0;
        final t = e.timestamp;
        moveDays.add(t.year * 10000 + t.month * 100 + t.day);
      case EntryType.rituals:
        ritualsKept += 1;
    }
  }
  return MonthAggregate(
    totalSpent: spent,
    moveMinutes: moveMinutes,
    ritualsKept: ritualsKept,
    activeMoveDays: moveDays.length,
  );
}

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
  });

  final DateTime month;

  /// This month's aggregates.
  final MonthAggregate current;

  /// The previous month's aggregates, for vs-last-month deltas.
  final MonthAggregate previous;

  /// Longest current ritual streak (days) across all rituals.
  final int longestStreak;

  double get totalSpent => current.totalSpent;
  int get moveMinutes => current.moveMinutes;
  int get ritualsKept => current.ritualsKept;

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  /// The previous month's name, e.g. "March".
  String get _previousMonthName {
    final m = DateTime(month.year, month.month - 1);
    return _months[m.month - 1];
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
    final moveDelta = _pctChange(current.moveMinutes, previous.moveMinutes);
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
        value: '\$${totalSpent.toStringAsFixed(0)}',
        sub: spentDelta,
        colorToken: 'money',
        icon: 'dollarsign.circle.fill',
      ),
      ReviewStat(
        label: 'Workout time',
        value: '$moveMinutes',
        unit: 'min',
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
        sub: 'Workouts, ongoing',
        colorToken: 'rituals',
        icon: 'flame.fill',
      ),
    ];
  }
}

/// Folds the current month's [entries] + [previous] month's entries + [routines]
/// into [MonthlyStats]. Extracted from the provider so it can be tested with
/// fixtures.
MonthlyStats buildMonthlyStats(
  DateTime month,
  List<Entry> entries,
  List<Entry> previousEntries,
  List<RitualRoutine> routines,
) {
  final longestStreak =
      routines.fold<int>(0, (max, r) => r.streak > max ? r.streak : max);
  return MonthlyStats(
    month: DateTime(month.year, month.month),
    current: foldMonth(entries),
    previous: foldMonth(previousEntries),
    longestStreak: longestStreak,
  );
}

/// Streams the [MonthlyStats] for the current month. Reactive: re-emits when
/// this month's entries or rituals change; the previous month's entries are a
/// one-shot read each emission (they don't change once the month closes).
@riverpod
Stream<MonthlyStats> monthlyStats(Ref ref) async* {
  final entriesRepo = ref.watch(entryRepositoryProvider);
  final ritualRepo = ref.watch(ritualRepositoryProvider);

  final now = DateTime.now();
  final start = DateTime(now.year, now.month);
  final end = DateTime(now.year, now.month + 1);
  final prevStart = DateTime(now.year, now.month - 1);

  await for (final entries in entriesRepo.watchEntriesInRange(start, end)) {
    final previous =
        await entriesRepo.watchEntriesInRange(prevStart, start).first;
    final routines = await ritualRepo.getAll();
    yield buildMonthlyStats(start, entries, previous, routines);
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
    return pal.review(DateTime(now.year, now.month));
  }

  /// Re-requests the narrative from [PalService.review], showing the loading
  /// state while the new text is fetched (so the card can spin).
  Future<void> regenerate() async {
    final pal = ref.read(palServiceProvider);
    final now = DateTime.now();
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => pal.review(DateTime(now.year, now.month)),
    );
  }
}
