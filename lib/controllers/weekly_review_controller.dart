import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/models.dart';
import '../services/services.dart' show ReviewRange;
import '../util/dates.dart';
import '../util/format.dart';
import 'providers.dart';
import 'today_controller.dart' show goalsStreamProvider;

part 'weekly_review_controller.g.dart';

/// One tinted stat tile in the Weekly Review three-ring summary (handoff screen
/// 17): a label, a big value, the `of <target>` sub line, and a type accent.
@immutable
class WeekStat {
  const WeekStat({
    required this.label,
    required this.value,
    required this.sub,
    required this.colorToken,
  });

  /// Tile title, e.g. "Spent".
  final String label;

  /// Big formatted value, e.g. "\$435" or "296".
  final String value;

  /// Sub line under the value, e.g. "of \$595".
  final String sub;

  /// `context.colors.forType(colorToken)` accent ('money'|'move'|'rituals').
  final String colorToken;
}

/// The fully-computed week summary for the current week (Mon–Sun): the three
/// stat tiles plus the date eyebrows. All math lives here so the screen stays
/// dumb and this is unit-testable.
@immutable
class WeeklyStats {
  const WeeklyStats({
    required this.weekStart,
    required this.spent,
    required this.budget,
    required this.moveKcal,
    required this.moveTarget,
    required this.ritualsKept,
    required this.ritualsTarget,
  });

  /// Monday 00:00 of the week these stats cover.
  final DateTime weekStart;

  /// Absolute sum of expense amounts (money entries, amount < 0) this week.
  final double spent;

  /// Weekly budget = dailyBudget * 7.
  final double budget;

  /// Total movement active energy (move entries' [Entry.calories]) this week.
  final int moveKcal;

  /// Weekly move target = dailyMoveKcal * 7.
  final int moveTarget;

  /// Count of ritual entries logged this week.
  final int ritualsKept;

  /// Weekly rituals target = dailyRitualTarget * 7.
  final int ritualsTarget;

  /// Sunday (week end, inclusive) — Monday + 6 days.
  DateTime get weekEnd => weekStart.add(const Duration(days: 6));

  /// Next review date — the Sunday that closes this week.
  DateTime get nextReview => weekEnd;

  /// Eyebrow span, e.g. "Apr 17–23" or "Apr 28–May 4" when the week crosses a
  /// month boundary.
  String get rangeLabel {
    final start = '${kMonthsShort[weekStart.month - 1]} ${weekStart.day}';
    final end = weekStart.month == weekEnd.month
        ? '${weekEnd.day}'
        : '${kMonthsShort[weekEnd.month - 1]} ${weekEnd.day}';
    return '$start–$end';
  }

  /// "Next review" footer label, e.g. "Sunday, Apr 23".
  String get nextReviewLabel {
    final d = nextReview;
    return '${kWeekdays[d.weekday - 1]}, ${kMonthsShort[d.month - 1]} ${d.day}';
  }

  /// The three week tiles, in handoff order (money / move / rituals).
  List<WeekStat> tiles(Currency currency) => [
        WeekStat(
          label: 'Spent',
          value: formatCurrency(spent, currency),
          sub: 'of ${formatCurrency(budget, currency)}',
          colorToken: 'money',
        ),
        WeekStat(
          label: 'Workout',
          value: '$moveKcal',
          sub: 'of $moveTarget kcal',
          colorToken: 'move',
        ),
        WeekStat(
          label: 'Routines',
          value: '$ritualsKept',
          sub: 'of $ritualsTarget',
          colorToken: 'rituals',
        ),
      ];
}

/// Monday 00:00 of the week containing [now].
DateTime weekStartFor(DateTime now) => startOfWeek(now);

/// Folds the week's [entries] against [goals] into the [WeeklyStats] tiles.
/// Pure — extracted from the provider so it can be tested with fixtures.
/// [now] defaults to [DateTime.now] and only fixes the covered week.
WeeklyStats buildWeeklyStats(
  List<Entry> entries,
  Goals goals, {
  int routineCount = 0,
  DateTime? now,
}) {
  final weekStart = weekStartFor(now ?? DateTime.now());
  var spent = 0.0;
  var moveKcal = 0;
  var ritualsKept = 0;
  for (final e in entries) {
    switch (e.type) {
      case EntryType.money:
        if ((e.amount ?? 0) < 0) spent += e.amount!.abs();
      case EntryType.move:
        moveKcal += e.calories ?? 0;
      case EntryType.rituals:
        ritualsKept += 1;
    }
  }
  return WeeklyStats(
    weekStart: weekStart,
    spent: spent,
    budget: goals.dailyBudget * 7,
    moveKcal: moveKcal,
    moveTarget: goals.dailyMoveKcal * 7,
    ritualsKept: ritualsKept,
    ritualsTarget: effectiveDailyRitualTarget(routineCount, goals) * 7,
  );
}

/// Streams the [WeeklyStats] for the current week (Mon–Sun). Reactive: re-emits
/// when this week's entries or the goals change.
@riverpod
Stream<WeeklyStats> weeklyStats(Ref ref) async* {
  final entriesRepo = ref.watch(entryRepositoryProvider);
  final ritualRepo = ref.watch(ritualRepositoryProvider);
  final goals = ref.watch(goalsStreamProvider).asData?.value ?? const Goals();

  final now = DateTime.now();
  final start = weekStartFor(now);
  final end = start.add(const Duration(days: 7));

  await for (final entries in entriesRepo.watchEntriesInRange(start, end)) {
    final routineCount = (await ritualRepo.getAll()).length;
    yield buildWeeklyStats(entries, goals, routineCount: routineCount, now: now);
  }
}

/// Drives the Pal-written weekly narrative: holds the review text with a loading
/// state, and re-requests it on [regenerate]. Mirrors [MonthlyReviewController]
/// — reuses the [PalService.review] seam, passing the current week's start.
@riverpod
class WeeklyReviewController extends _$WeeklyReviewController {
  DateTime get _weekStart => weekStartFor(DateTime.now());

  @override
  Future<String> build() {
    final pal = ref.watch(palServiceProvider);
    return pal.review(_weekStart, ReviewRange.week);
  }

  /// Re-requests the narrative from [PalService.review], showing the loading
  /// state while the new text is fetched.
  Future<void> regenerate() async {
    final pal = ref.read(palServiceProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => pal.review(_weekStart, ReviewRange.week));
  }
}
