import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/models.dart';
import 'providers.dart';

part 'profile_controller.g.dart';

/// The fully-computed "You" profile view model: the this-year 2×2 stat grid plus
/// the "Member since" year. All aggregation lives here so the screen is dumb and
/// this is unit-testable.
///
/// Stats are derived from the live [Entry] stream (money/move/rituals) and the
/// rituals list (for the longest streak), scoped to the current calendar year.
@immutable
class ProfileStats {
  const ProfileStats({
    required this.totalSpent,
    required this.moveMinutes,
    required this.ritualsKept,
    required this.longestStreak,
    required this.memberSince,
    this.bestMoveDay,
    this.bestMoveDayMinutes = 0,
  });

  /// Sum of this year's expense magnitudes (amount < 0), as a positive number.
  final double totalSpent;

  /// Sum of this year's move-entry durations, in minutes.
  final int moveMinutes;

  /// Count of this year's completed ritual entries.
  final int ritualsKept;

  /// Best current streak across all rituals (days).
  final int longestStreak;

  /// Earliest entry's full timestamp, or null when there are no entries.
  final DateTime? memberSince;

  /// Day (date-only) with the most move minutes this year, or null when none.
  final DateTime? bestMoveDay;

  /// Minutes moved on [bestMoveDay] (0 when there is no move data).
  final int bestMoveDayMinutes;

  /// Year the user joined (earliest entry's year, else the current year).
  /// Kept for callers that only need the year; derived from [memberSince].
  int get memberSinceYear => memberSince?.year ?? DateTime.now().year;

  /// Whole hours moved this year (minutes ÷ 60, floored).
  int get moveHours => moveMinutes ~/ 60;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileStats &&
          other.totalSpent == totalSpent &&
          other.moveMinutes == moveMinutes &&
          other.ritualsKept == ritualsKept &&
          other.longestStreak == longestStreak &&
          other.memberSince == memberSince &&
          other.bestMoveDay == bestMoveDay &&
          other.bestMoveDayMinutes == bestMoveDayMinutes;

  @override
  int get hashCode => Object.hash(
        totalSpent,
        moveMinutes,
        ritualsKept,
        longestStreak,
        memberSince,
        bestMoveDay,
        bestMoveDayMinutes,
      );
}

/// Pure milestone math for the streak celebration. Returns the next streak
/// target strictly above [streak] on a fixed ladder, or null when [streak] has
/// already passed the top rung (no fabricated target).
int? nextStreakMilestone(int streak) {
  const ladder = [7, 14, 30, 60, 100, 180, 365];
  for (final m in ladder) {
    if (m > streak) return m;
  }
  return null;
}

/// Pure: the calendar day a [streak]-day run started, counting back from
/// [today] inclusive (a streak of 1 started today). Null for a zero streak.
DateTime? streakStartDate(int streak, DateTime today) {
  if (streak <= 0) return null;
  final d = DateTime(today.year, today.month, today.day);
  return d.subtract(Duration(days: streak - 1));
}

/// Folds [entries] (all-time) + [routines] into the this-year [ProfileStats].
/// Extracted from the provider so it can be tested directly with fixtures.
ProfileStats buildProfileStats(
  List<Entry> entries,
  List<RitualRoutine> routines, {
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final year = today.year;

  var totalSpent = 0.0;
  var moveMinutes = 0;
  var ritualsKept = 0;
  DateTime? memberSince;
  // this-year move minutes per calendar day, for the "best day" stat
  final moveByDay = <DateTime, int>{};

  for (final e in entries) {
    if (memberSince == null || e.timestamp.isBefore(memberSince)) {
      memberSince = e.timestamp;
    }
    if (e.timestamp.year != year) continue;
    switch (e.type) {
      case EntryType.money:
        if ((e.amount ?? 0) < 0) totalSpent += e.amount!.abs();
      case EntryType.move:
        final mins = e.duration ?? 0;
        moveMinutes += mins;
        final day = DateTime(
            e.timestamp.year, e.timestamp.month, e.timestamp.day);
        moveByDay[day] = (moveByDay[day] ?? 0) + mins;
      case EntryType.rituals:
        ritualsKept += 1;
    }
  }

  final longestStreak = routines.isEmpty
      ? 0
      : routines.map((r) => r.streak).reduce((a, b) => a > b ? a : b);

  DateTime? bestMoveDay;
  var bestMoveDayMinutes = 0;
  moveByDay.forEach((day, mins) {
    if (mins > bestMoveDayMinutes) {
      bestMoveDayMinutes = mins;
      bestMoveDay = day;
    }
  });

  return ProfileStats(
    totalSpent: totalSpent,
    moveMinutes: moveMinutes,
    ritualsKept: ritualsKept,
    longestStreak: longestStreak,
    memberSince: memberSince,
    bestMoveDay: bestMoveDay,
    bestMoveDayMinutes: bestMoveDayMinutes,
  );
}

/// The live routines list (display-ordered). Watched by [profileStats] so a
/// routine edit (e.g. a streak change) re-emits the stats on its own.
@riverpod
Stream<List<RitualRoutine>> profileRoutines(Ref ref) =>
    ref.watch(ritualRepositoryProvider).watchRoutines();

/// Streams the [ProfileStats] for the "You" tab. Reactive: re-emits whenever the
/// entries or rituals change. Reads all entries (year stats span the whole year,
/// not just today) and folds them via [buildProfileStats].
///
/// Combines the two live sources by `await for`-ing entries while watching the
/// routines stream: a routine change rebuilds this provider (so the longest-
/// streak stat refreshes), and entry edits drive the inner loop.
@riverpod
Stream<ProfileStats> profileStats(Ref ref) async* {
  final entryRepo = ref.watch(entryRepositoryProvider);
  final routines =
      ref.watch(profileRoutinesProvider).asData?.value ?? const <RitualRoutine>[];

  await for (final entries in entryRepo.watchAll()) {
    yield buildProfileStats(entries, routines);
  }
}
