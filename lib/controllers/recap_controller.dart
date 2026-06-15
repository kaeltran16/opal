import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/models.dart';
import '../services/pal/pal_service.dart' show InsightRange;
import 'providers.dart';
import 'today_controller.dart' show goalsStreamProvider;
import 'weekly_review_controller.dart' show weekStartFor;

part 'recap_controller.g.dart';

/// One tinted stat tile in the Recap summary: a label, a big value, the
/// `of <target>` sub line, and a type accent. Same shape as `WeekStat`.
@immutable
class RecapStat {
  const RecapStat({
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

/// The fully-computed Recap summary for one [range] (day / week / month): the
/// three stat tiles plus the period subtitle. All math lives here so the screen
/// stays dumb and this is unit-testable.
@immutable
class RecapData {
  const RecapData({
    required this.range,
    required this.periodStart,
    required this.spent,
    required this.budget,
    required this.moveKcal,
    required this.moveTarget,
    required this.ritualsKept,
    required this.ritualsTarget,
  });

  /// The period this recap covers.
  final InsightRange range;

  /// 00:00 of the first day in the period (today / Monday / first-of-month).
  final DateTime periodStart;

  /// Absolute sum of expense amounts (money entries, amount < 0) in the period.
  final double spent;

  /// Period budget = dailyBudget * days-in-period.
  final double budget;

  /// Total movement active energy (move entries' [Entry.calories]) in the period.
  final int moveKcal;

  /// Period move target = dailyMoveKcal * days-in-period.
  final int moveTarget;

  /// Count of ritual entries logged in the period.
  final int ritualsKept;

  /// Period rituals target = effective daily target * days-in-period.
  final int ritualsTarget;

  static const _monthsLong = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static const _monthsShort = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static const _weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday',
  ];

  /// The subtitle under the "Recap" title, per range:
  /// day → "Tuesday, June 18"; week → "Jun 15–21"; month → "June".
  String get subtitle {
    switch (range) {
      case InsightRange.day:
        final d = periodStart;
        return '${_weekdays[d.weekday - 1]}, '
            '${_monthsLong[d.month - 1]} ${d.day}';
      case InsightRange.week:
        final end = periodStart.add(const Duration(days: 6));
        final start = '${_monthsShort[periodStart.month - 1]} ${periodStart.day}';
        final endLabel = periodStart.month == end.month
            ? '${end.day}'
            : '${_monthsShort[end.month - 1]} ${end.day}';
        return '$start–$endLabel';
      case InsightRange.month:
        return _monthsLong[periodStart.month - 1];
    }
  }

  /// The three Recap tiles, in order (money / move / rituals). Matches the
  /// Weekly Review's tile label / value / sub formatting and color tokens.
  List<RecapStat> get tiles => [
        RecapStat(
          label: 'Spent',
          value: '\$${spent.toStringAsFixed(0)}',
          sub: 'of \$${budget.toStringAsFixed(0)}',
          colorToken: 'money',
        ),
        RecapStat(
          label: 'Moved',
          value: '$moveKcal',
          sub: 'of $moveTarget kcal',
          colorToken: 'move',
        ),
        RecapStat(
          label: 'Rituals',
          value: '$ritualsKept',
          sub: 'of $ritualsTarget',
          colorToken: 'rituals',
        ),
      ];
}

/// Number of calendar days in the period containing [now] for [range]:
/// day → 1, week → 7, month → days in the current month.
int _periodDays(InsightRange range, DateTime now) => switch (range) {
      InsightRange.day => 1,
      InsightRange.week => 7,
      InsightRange.month => DateTime(now.year, now.month + 1, 0).day,
    };

/// 00:00 of the first day of the period containing [now] for [range].
DateTime _periodStart(InsightRange range, DateTime now) => switch (range) {
      InsightRange.day => DateTime(now.year, now.month, now.day),
      InsightRange.week => weekStartFor(now),
      InsightRange.month => DateTime(now.year, now.month),
    };

/// Folds the period's [periodEntries] against [goals] into the [RecapData]
/// tiles. Pure — extracted from the provider so it can be tested with fixtures.
/// [now] defaults to [DateTime.now] and only fixes the covered period.
RecapData buildRecapData(
  InsightRange range,
  List<Entry> periodEntries,
  Goals goals, {
  int routineCount = 0,
  DateTime? now,
}) {
  final n = now ?? DateTime.now();
  final days = _periodDays(range, n);
  var spent = 0.0;
  var moveKcal = 0;
  var ritualsKept = 0;
  for (final e in periodEntries) {
    switch (e.type) {
      case EntryType.money:
        if ((e.amount ?? 0) < 0) spent += e.amount!.abs();
      case EntryType.move:
        moveKcal += e.calories ?? 0;
      case EntryType.rituals:
        ritualsKept += 1;
    }
  }
  return RecapData(
    range: range,
    periodStart: _periodStart(range, n),
    spent: spent,
    budget: goals.dailyBudget * days,
    moveKcal: moveKcal,
    moveTarget: goals.dailyMoveKcal * days,
    ritualsKept: ritualsKept,
    ritualsTarget: effectiveDailyRitualTarget(routineCount, goals) * days,
  );
}

/// Streams the [RecapData] for [range] over the current period. Reactive:
/// re-emits when the period's entries or the goals change.
@riverpod
Stream<RecapData> recapData(Ref ref, InsightRange range) async* {
  final entriesRepo = ref.watch(entryRepositoryProvider);
  final ritualRepo = ref.watch(ritualRepositoryProvider);
  final goals = ref.watch(goalsStreamProvider).asData?.value ?? const Goals();

  final now = DateTime.now();
  final start = _periodStart(range, now);
  final end = switch (range) {
    InsightRange.day => start.add(const Duration(days: 1)),
    InsightRange.week => start.add(const Duration(days: 7)),
    InsightRange.month => DateTime(now.year, now.month + 1),
  };

  await for (final entries in entriesRepo.watchEntriesInRange(start, end)) {
    final routineCount = (await ritualRepo.getAll()).length;
    yield buildRecapData(range, entries, goals,
        routineCount: routineCount, now: now);
  }
}
