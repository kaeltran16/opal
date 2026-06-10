import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/models.dart';
import 'providers.dart';

part 'today_controller.g.dart';

/// One bucket of the Today timeline (Morning / Afternoon / Evening).
class TimelineBucket {
  const TimelineBucket(this.label, this.entries);
  final String label;
  final List<Entry> entries;
}

/// The fully-computed Today view model: ring fractions, the three summary-tile
/// values, and the timeline buckets — all derived from live repository data.
/// The screen is dumb; all math lives here so it is testable.
class TodayState {
  const TodayState({
    required this.entries,
    required this.goals,
  });

  final List<Entry> entries;
  final Goals goals;

  /// Move-minutes for the day: sum of the duration of logged move entries.
  int get moveMinutes => entries
      .where((e) => e.type == EntryType.move)
      .fold<int>(0, (s, e) => s + (e.duration ?? 0));

  /// Total spent today (absolute value of expense amounts).
  double get moneySpent => entries
      .where((e) => e.type == EntryType.money && (e.amount ?? 0) < 0)
      .fold<double>(0, (s, e) => s + e.amount!.abs());

  /// Number of completed rituals today.
  int get ritualsDone =>
      entries.where((e) => e.type == EntryType.rituals).length;

  // --- Ring fractions (0..1+) ------------------------------------------------

  double get moneyRing =>
      goals.dailyBudget == 0 ? 0 : moneySpent / goals.dailyBudget;
  double get moveRing =>
      goals.dailyMoveMinutes == 0 ? 0 : moveMinutes / goals.dailyMoveMinutes;
  double get ritualsRing =>
      goals.dailyRitualTarget == 0 ? 0 : ritualsDone / goals.dailyRitualTarget;

  List<double> get rings => [moneyRing, moveRing, ritualsRing];

  /// Rituals remaining to hit target (never negative).
  int get ritualsRemaining =>
      (goals.dailyRitualTarget - ritualsDone).clamp(0, goals.dailyRitualTarget);

  // --- Timeline buckets ------------------------------------------------------

  /// Entries split into Morning (<12) / Afternoon (12–18) / Evening (>=18),
  /// each newest-first (the source stream is already ordered desc).
  List<TimelineBucket> get buckets {
    List<Entry> inHours(bool Function(int h) test) =>
        entries.where((e) => test(e.timestamp.hour)).toList();
    return [
      TimelineBucket('Morning', inHours((h) => h < 12)),
      TimelineBucket('Afternoon', inHours((h) => h >= 12 && h < 18)),
      TimelineBucket('Evening', inHours((h) => h >= 18)),
    ];
  }
}

/// The live goals row (defaults until set). Watched by [todayState] so a
/// goals-only edit (budget/targets in Settings) re-emits Today on its own.
@riverpod
Stream<Goals> goalsStream(Ref ref) =>
    ref.watch(goalsRepositoryProvider).watchGoals();

/// Streams the Today view model from the live entries + goals streams.
/// Re-emits whenever either changes: the entries `await for` drives entry
/// edits, and watching [goalsStreamProvider] rebuilds this provider on a
/// goals-only edit.
@riverpod
Stream<TodayState> todayState(Ref ref) async* {
  final entriesRepo = ref.watch(entryRepositoryProvider);
  final goals = ref.watch(goalsStreamProvider).asData?.value ?? const Goals();

  await for (final entries in entriesRepo.watchToday()) {
    yield TodayState(entries: entries, goals: goals);
  }
}
