import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/models.dart';
import 'providers.dart';

part 'today_controller.g.dart';

/// Timeline grouping mode for the Today screen. [day] buckets today's entries
/// by time of day (Morning/Afternoon/Evening); [week] buckets the current
/// week's entries by calendar day, most-recent first.
enum TimelineMode { day, week }

/// The selected timeline mode. Tapping the Today timeline toggle flips it; the
/// [todayState] stream watches it and rebuilds its buckets accordingly.
@riverpod
class TimelineModeController extends _$TimelineModeController {
  @override
  TimelineMode build() => TimelineMode.day;

  void toggle() =>
      state = state == TimelineMode.day ? TimelineMode.week : TimelineMode.day;

  void set(TimelineMode mode) => state = mode;
}

/// One bucket of the Today timeline (Morning / Afternoon / Evening in day mode;
/// a weekday label in week mode).
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
    this.mode = TimelineMode.day,
    List<Entry>? timelineEntries,
  }) : timelineEntries = timelineEntries ?? entries;

  /// Today's entries — the source of truth for rings, tiles, and day-mode
  /// timeline buckets.
  final List<Entry> entries;

  /// Entries that feed the timeline. Same as [entries] in day mode; the full
  /// week (newest-first) in week mode.
  final List<Entry> timelineEntries;
  final Goals goals;
  final TimelineMode mode;

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

  /// The timeline buckets for the current [mode].
  List<TimelineBucket> get buckets =>
      mode == TimelineMode.week ? _weekBuckets : _dayBuckets;

  /// Today's entries split into Morning (<12) / Afternoon (12–18) /
  /// Evening (>=18), each newest-first (the source stream is already desc).
  List<TimelineBucket> get _dayBuckets {
    List<Entry> inHours(bool Function(int h) test) =>
        timelineEntries.where((e) => test(e.timestamp.hour)).toList();
    return [
      TimelineBucket('Morning', inHours((h) => h < 12)),
      TimelineBucket('Afternoon', inHours((h) => h >= 12 && h < 18)),
      TimelineBucket('Evening', inHours((h) => h >= 18)),
    ];
  }

  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  /// The week's entries grouped by calendar day, most-recent day first. Rows
  /// within a day stay newest-first (the source stream is already desc).
  List<TimelineBucket> get _weekBuckets {
    final byDay = <DateTime, List<Entry>>{};
    for (final e in timelineEntries) {
      final t = e.timestamp;
      final day = DateTime(t.year, t.month, t.day);
      (byDay[day] ??= []).add(e);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final day in days)
        TimelineBucket(_weekdays[day.weekday - 1], byDay[day]!),
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
  final mode = ref.watch(timelineModeControllerProvider);

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  // Week runs Monday → end of today (half-open upper bound = tomorrow 00:00).
  final weekStart = today.subtract(Duration(days: now.weekday - 1));
  final tomorrow = today.add(const Duration(days: 1));

  await for (final entries in entriesRepo.watchToday()) {
    final timelineEntries = mode == TimelineMode.week
        ? await entriesRepo.watchEntriesInRange(weekStart, tomorrow).first
        : entries;
    yield TodayState(
      entries: entries,
      timelineEntries: timelineEntries,
      goals: goals,
      mode: mode,
    );
  }
}
