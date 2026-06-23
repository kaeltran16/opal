import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/models.dart';
import '../util/dates.dart';
import 'providers.dart';

part 'sleep_controller.g.dart';

/// One bar in the 7-night sleep strip. [minutes] is asleepMinutes for that
/// night. [isToday] is true for the most recent / last night in the window.
class SleepBar {
  const SleepBar({
    required this.dayLetter,
    required this.minutes,
    required this.isToday,
  });

  /// Single weekday letter ('M', 'T', 'W', 'T', 'F', 'S', 'S'), Monday-first.
  final String dayLetter;
  final int minutes;
  final bool isToday;
}

/// The Sleep view model. All math lives here; the screen is dumb.
///
/// [read] is '' when there are no nights yet (no lastNight).
class SleepState {
  const SleepState({
    required this.lastNight,
    required this.usualMinutes,
    required this.read,
    required this.week,
    required this.month,
    required this.syncedNights,
  });

  /// Most recent night in the window; null if none synced.
  final SleepNight? lastNight;

  /// Trailing 14-night median of asleepMinutes. 0 if no nights.
  final int usualMinutes;

  /// Qualitative word: 'restful' | 'short' | 'broken'. '' if no lastNight.
  final String read;

  /// The last up-to-7 nights mapped to [SleepBar], ascending by night.
  /// Fewer than 7 entries when fewer nights have synced.
  final List<SleepBar> week;

  /// The last up-to-30 nights' asleepMinutes, ascending.
  final List<int> month;

  /// Total nights in the 30-day window. Screen treats < 3 as needs-sync.
  final int syncedNights;
}

// ---------------------------------------------------------------------------
// Private helpers (top-level so they're unit-testable without the provider)
// ---------------------------------------------------------------------------

/// Integer median of a non-empty sorted-or-unsorted list.
/// Sorts a copy, returns the middle value for odd counts; for even counts
/// returns (lower + upper) / 2 rounded to nearest int.
/// Returns 0 for an empty list.
int _median(List<int> values) {
  if (values.isEmpty) return 0;
  final sorted = List<int>.from(values)..sort();
  final mid = sorted.length ~/ 2;
  if (sorted.length.isOdd) return sorted[mid];
  return ((sorted[mid - 1] + sorted[mid]) / 2).round();
}

/// Qualitative read of a single night. Called only when a lastNight exists.
String _sleepRead(int asleep, int usual, int wakes) {
  if (asleep >= usual && wakes <= 2) return 'restful';
  if (asleep < usual - 30) return 'short';
  return 'broken';
}

SleepState _deriveState(List<SleepNight> nights, DateTime now) {
  if (nights.isEmpty) {
    return const SleepState(
      lastNight: null,
      usualMinutes: 0,
      read: '',
      week: [],
      month: [],
      syncedNights: 0,
    );
  }

  // nights is ascending by night (repository guarantee)
  final lastNight = nights.last;

  // trailing 14-night median
  final trailingForMedian = nights.length > 14
      ? nights.sublist(nights.length - 14)
      : nights;
  final usualMinutes =
      _median(trailingForMedian.map((n) => n.asleepMinutes).toList());

  final read = _sleepRead(lastNight.asleepMinutes, usualMinutes, lastNight.wakes);

  // last up-to-7 nights for the week strip
  final weekNights = nights.length > 7
      ? nights.sublist(nights.length - 7)
      : nights;
  final week = weekNights.map((n) {
    return SleepBar(
      // weekday is 1=Monday … 7=Sunday; kWeekdayLetters is Monday-first
      dayLetter: kWeekdayLetters[n.night.weekday - 1],
      minutes: n.asleepMinutes,
      isToday: n == lastNight,
    );
  }).toList();

  // last up-to-30 nights for the sparkline
  final monthNights = nights.length > 30
      ? nights.sublist(nights.length - 30)
      : nights;
  final month = monthNights.map((n) => n.asleepMinutes).toList();

  return SleepState(
    lastNight: lastNight,
    usualMinutes: usualMinutes,
    read: read,
    week: week,
    month: month,
    syncedNights: nights.length,
  );
}

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

/// Streams the Sleep view model. Read-only; sleep nights are written only by
/// the health sync. Mirrors [NutritionController]'s stream-build pattern.
@riverpod
class SleepController extends _$SleepController {
  @override
  Stream<SleepState> build() async* {
    final repo = ref.watch(sleepRepositoryProvider);
    final now = DateTime.now();
    // 30-day window: from midnight 30 days ago to tomorrow midnight so today's
    // nights are included regardless of the exact time build() is called.
    final windowStart = startOfDay(now).subtract(const Duration(days: 30));
    final tomorrow = startOfDay(now).add(const Duration(days: 1));
    await for (final nights in repo.watchNightsInRange(windowStart, tomorrow)) {
      yield _deriveState(nights, now);
    }
  }
}
