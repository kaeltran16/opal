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
    required this.memberSinceYear,
  });

  /// Sum of this year's expense magnitudes (amount < 0), as a positive number.
  final double totalSpent;

  /// Sum of this year's move-entry durations, in minutes.
  final int moveMinutes;

  /// Count of this year's completed ritual entries.
  final int ritualsKept;

  /// Best current streak across all rituals (days).
  final int longestStreak;

  /// Year the user joined (earliest entry's year, else the current year).
  final int memberSinceYear;

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
          other.memberSinceYear == memberSinceYear;

  @override
  int get hashCode => Object.hash(
        totalSpent,
        moveMinutes,
        ritualsKept,
        longestStreak,
        memberSinceYear,
      );
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
  int? earliestYear;

  for (final e in entries) {
    final y = e.timestamp.year;
    if (earliestYear == null || y < earliestYear) earliestYear = y;
    if (y != year) continue;
    switch (e.type) {
      case EntryType.money:
        if ((e.amount ?? 0) < 0) totalSpent += e.amount!.abs();
      case EntryType.move:
        moveMinutes += e.duration ?? 0;
      case EntryType.rituals:
        ritualsKept += 1;
    }
  }

  final longestStreak = routines.isEmpty
      ? 0
      : routines.map((r) => r.streak).reduce((a, b) => a > b ? a : b);

  return ProfileStats(
    totalSpent: totalSpent,
    moveMinutes: moveMinutes,
    ritualsKept: ritualsKept,
    longestStreak: longestStreak,
    memberSinceYear: earliestYear ?? year,
  );
}

/// Streams the [ProfileStats] for the "You" tab. Reactive: re-emits whenever the
/// entries or rituals change. Reads all entries (year stats span the whole year,
/// not just today) and folds them via [buildProfileStats].
@riverpod
Stream<ProfileStats> profileStats(Ref ref) async* {
  final entryRepo = ref.watch(entryRepositoryProvider);
  final ritualRepo = ref.watch(ritualRepositoryProvider);

  await for (final entries in entryRepo.watchAll()) {
    final routines = await ritualRepo.getAll();
    yield buildProfileStats(entries, routines);
  }
}
