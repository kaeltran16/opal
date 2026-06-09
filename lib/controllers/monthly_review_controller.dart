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
    required this.colorToken,
    required this.icon,
  });

  /// Row title, e.g. "Total spent".
  final String label;

  /// Big formatted value, e.g. "\$1,840" or "12".
  final String value;

  /// Optional trailing unit, e.g. "min" or "days".
  final String? unit;

  /// `context.colors.forType(colorToken)` accent ('money'|'move'|'rituals'|'').
  final String colorToken;

  /// SF Symbol name for the row's tinted icon tile.
  final String icon;
}

/// The fully-computed "By the numbers" block for [month], derived from the
/// repositories. All math lives here so the screen is dumb and this is
/// unit-testable.
@immutable
class MonthlyStats {
  const MonthlyStats({
    required this.month,
    required this.totalSpent,
    required this.moveMinutes,
    required this.ritualsKept,
    required this.longestStreak,
  });

  final DateTime month;

  /// Absolute sum of expense amounts (money entries, amount < 0) this month.
  final double totalSpent;

  /// Total movement minutes (move entries' [Entry.duration]) this month.
  final int moveMinutes;

  /// Count of ritual entries logged this month.
  final int ritualsKept;

  /// Longest current ritual streak (days) across all rituals.
  final int longestStreak;

  /// The four big stat rows, in handoff order.
  List<ReviewStat> get rows => [
        ReviewStat(
          label: 'Total spent',
          value: '\$${totalSpent.toStringAsFixed(0)}',
          colorToken: 'money',
          icon: 'dollarsign.circle.fill',
        ),
        ReviewStat(
          label: 'Time moved',
          value: '$moveMinutes',
          unit: 'min',
          colorToken: 'move',
          icon: 'figure.run',
        ),
        ReviewStat(
          label: 'Rituals kept',
          value: '$ritualsKept',
          colorToken: 'rituals',
          icon: 'sparkles',
        ),
        ReviewStat(
          label: 'Streak',
          value: '$longestStreak',
          unit: longestStreak == 1 ? 'day' : 'days',
          colorToken: 'rituals',
          icon: 'flame.fill',
        ),
      ];
}

/// Folds the month's [entries] + [rituals] into the four [MonthlyStats] values.
/// Extracted from the provider so it can be tested directly with fixtures.
MonthlyStats buildMonthlyStats(
  DateTime month,
  List<Entry> entries,
  List<Ritual> rituals,
) {
  var spent = 0.0;
  var moveMinutes = 0;
  var ritualsKept = 0;
  for (final e in entries) {
    switch (e.type) {
      case EntryType.money:
        if ((e.amount ?? 0) < 0) spent += e.amount!.abs();
      case EntryType.move:
        moveMinutes += e.duration ?? 0;
      case EntryType.rituals:
        ritualsKept += 1;
    }
  }
  final longestStreak = rituals.fold<int>(
      0, (max, r) => r.streak > max ? r.streak : max);
  return MonthlyStats(
    month: DateTime(month.year, month.month),
    totalSpent: spent,
    moveMinutes: moveMinutes,
    ritualsKept: ritualsKept,
    longestStreak: longestStreak,
  );
}

/// Streams the [MonthlyStats] for the current month. Reactive: re-emits when
/// entries or rituals change. The "By the numbers" block reads this.
@riverpod
Stream<MonthlyStats> monthlyStats(Ref ref) async* {
  final entriesRepo = ref.watch(entryRepositoryProvider);
  final ritualRepo = ref.watch(ritualRepositoryProvider);

  final now = DateTime.now();
  final start = DateTime(now.year, now.month);
  final end = DateTime(now.year, now.month + 1);

  await for (final entries in entriesRepo.watchEntriesInRange(start, end)) {
    final rituals = await ritualRepo.getAll();
    yield buildMonthlyStats(start, entries, rituals);
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
