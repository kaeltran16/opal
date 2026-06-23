import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/models.dart';
import '../util/dates.dart';
import 'providers.dart';

part 'mood_controller.g.dart';

/// One bar in the 7-day mood strip.
///
/// [value] is the day's mean pleasantness (0..1). A null [value] means no
/// check-ins were logged for that calendar day — the week chart should render
/// this as an empty/greyed bar. Prefer nullable over a separate [hasData] flag
/// to keep the chart's conditional logic in one place.
class MoodBar {
  const MoodBar({
    required this.dayLetter,
    required this.value,
    required this.isToday,
  });

  /// Single weekday letter ('M', 'T', 'W', 'T', 'F', 'S', 'S'), Monday-first.
  final String dayLetter;

  /// Mean pleasantness for the day, or null if no check-ins recorded.
  final double? value;

  final bool isToday;
}

/// The Mood view model. All math lives here; the screen is dumb.
class MoodState {
  const MoodState({
    required this.todayCheckins,
    required this.todayLean,
    required this.mostTag,
    required this.lastCheckin,
    required this.week,
  });

  /// Today's check-ins, ascending by time.
  final List<MoodCheckin> todayCheckins;

  /// Mean pleasantness of today's check-ins (0..1).
  /// Defaults to 0.5 when no check-ins exist — a neutral midpoint that avoids
  /// a misleading "unpleasant" read before the user has logged anything.
  final double todayLean;

  /// Most frequently used tag among today's check-ins; null if none / no tags.
  final String? mostTag;

  /// The latest of today's check-ins; null if none.
  final MoodCheckin? lastCheckin;

  /// 7 entries, oldest-day first → today last. Each day's mean pleasantness,
  /// or null for days with no check-ins.
  final List<MoodBar> week;
}

// ---------------------------------------------------------------------------
// Private helpers (top-level so they can be tested without the provider)
// ---------------------------------------------------------------------------

double _mean(Iterable<double> values) {
  var sum = 0.0;
  var count = 0;
  for (final v in values) {
    sum += v;
    count++;
  }
  return count == 0 ? 0.0 : sum / count;
}

String? _mostFrequentTag(List<MoodCheckin> checkins) {
  final counts = <String, int>{};
  for (final c in checkins) {
    if (c.tag != null && c.tag!.isNotEmpty) {
      counts[c.tag!] = (counts[c.tag!] ?? 0) + 1;
    }
  }
  if (counts.isEmpty) return null;
  return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
}

MoodState _deriveState(
  List<MoodCheckin> today,
  List<MoodCheckin> weekCheckins,
  DateTime now,
) {
  final todayLean = today.isEmpty ? 0.5 : _mean(today.map((c) => c.pleasantness));
  final mostTag = _mostFrequentTag(today);
  final lastCheckin = today.isEmpty ? null : today.last;

  // build 7 calendar-day buckets: [now-6 days .. today], each day keyed by
  // midnight of that day.
  final todayStart = startOfDay(now);
  final week = List<MoodBar>.generate(7, (i) {
    final dayStart = todayStart.subtract(Duration(days: 6 - i));
    final dayEnd = dayStart.add(const Duration(days: 1));
    final dayCheckins = weekCheckins.where((c) {
      final ts = c.timestamp;
      return !ts.isBefore(dayStart) && ts.isBefore(dayEnd);
    }).toList();
    return MoodBar(
      dayLetter: kWeekdayLetters[dayStart.weekday - 1],
      value: dayCheckins.isEmpty ? null : _mean(dayCheckins.map((c) => c.pleasantness)),
      isToday: i == 6,
    );
  });

  return MoodState(
    todayCheckins: today,
    todayLean: todayLean,
    mostTag: mostTag,
    lastCheckin: lastCheckin,
    week: week,
  );
}

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

/// Streams the Mood view model and owns check-in logging. Mirrors
/// [NutritionController]'s stream-build pattern.
@riverpod
class MoodController extends _$MoodController {
  @override
  Stream<MoodState> build() async* {
    final repo = ref.watch(moodRepositoryProvider);

    await for (final today in repo.watchCheckinsForDay()) {
      final now = DateTime.now();
      final todayStart = startOfDay(now);
      // fetch the 7-day window [6 days ago midnight .. tomorrow midnight) so
      // each emission rebuilds the full week strip with up-to-date data.
      final weekStart = todayStart.subtract(const Duration(days: 6));
      final weekEnd = todayStart.add(const Duration(days: 1));
      final weekCheckins = await repo.getCheckinsInRange(weekStart, weekEnd);
      yield _deriveState(today, weekCheckins, now);
    }
  }

  /// Logs a manual check-in with [pleasantness] (0..1) and an optional [tag].
  Future<void> logCheckin(double pleasantness, String? tag) async {
    // resolve providers before the first await: this is an autodispose stream
    // provider, so touching `ref` after an async gap can hit a disposed Ref
    // when nothing else is keeping the controller alive.
    final repo = ref.read(moodRepositoryProvider);
    final haptics = ref.read(hapticsServiceProvider);
    await repo.insert(MoodCheckin(
          id: '',
          timestamp: DateTime.now(),
          pleasantness: pleasantness,
          tag: tag,
          source: EntrySource.manual,
        ));
    await haptics.light();
  }
}
