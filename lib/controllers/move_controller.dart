import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/models.dart';
import 'providers.dart';

part 'move_controller.g.dart';

/// A single recent workout decorated with the derived bits the Move card needs:
/// a relative-date label, whether it should read as cardio (accent-tinted), and
/// the rounded duration/volume figures.
class RecentSession {
  const RecentSession({
    required this.workout,
    required this.relativeDate,
    required this.isCardio,
  });

  final Workout workout;
  final String relativeDate;
  final bool isCardio;

  /// Whole-minute training duration (0 when the session is still open).
  int get durationMinutes => workout.duration?.inMinutes ?? 0;

  /// Volume in tonnes, one decimal (e.g. "1.2t"). Empty for cardio (no volume).
  double get volumeTonnes => workout.totalVolumeKg / 1000;
}

/// The fully-computed Move view model: today's logged move minutes, the recent
/// sessions (newest 3, decorated), the non-workout movement entries, and the
/// quick-link counts. The screen is dumb; all derivation lives here so it is
/// testable.
class MoveState {
  const MoveState({
    required this.moveMinutes,
    required this.activeEnergyKcal,
    this.avgHeartRate,
    required this.recentSessions,
    required this.otherActivity,
    required this.routineCount,
    this.suggestedRoutineName,
  });

  /// Sum of today's logged move-entry durations (minutes).
  final int moveMinutes;

  /// No data source after health removal; always null for now.
  final int? activeEnergyKcal;
  final int? avgHeartRate;

  /// The three newest workouts, decorated for the recent-sessions cards.
  final List<RecentSession> recentSessions;

  /// Non-workout move entries (e.g. a logged run) for the "Other activity"
  /// section. Empty when there is none (the screen omits the section).
  final List<Entry> otherActivity;

  /// Total routine count (drives the "My routines" quick-link value).
  final int routineCount;

  /// Pal's suggested routine name for the Start CTA, or null when there are no
  /// routines yet.
  final String? suggestedRoutineName;

  /// Count of completed PRs across the recent sessions (hero "records" framing).
  int get recentPrCount =>
      recentSessions.fold(0, (sum, s) => sum + s.workout.prCount);
}

/// Relative-date label for a session start: "Today", "Yesterday", or "Nd ago"
/// (calendar-day difference, not 24h windows). Pure so it is unit-testable.
String relativeDateLabel(DateTime startedAt, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(startedAt.year, startedAt.month, startedAt.day);
  final days = today.difference(day).inDays;
  if (days <= 0) return 'Today';
  if (days == 1) return 'Yesterday';
  return '${days}d ago';
}

/// Streams the Move view model off the live workouts stream, plus the routines
/// and non-workout move entries re-read each tick. Re-emits whenever the
/// workouts table changes.
@riverpod
Stream<MoveState> moveState(Ref ref) async* {
  final workoutRepo = ref.watch(workoutRepositoryProvider);
  final entryRepo = ref.watch(entryRepositoryProvider);
  final routineRepo = ref.watch(routineRepositoryProvider);

  // Drive off the live workouts stream; re-read routines + entries each tick
  // (small tables) so counts and the cardio classification stay current.
  await for (final workouts in workoutRepo.watchWorkouts()) {
    final routines = await routineRepo.getAll();
    final entries = await entryRepo.getAll();

    // routineId -> cardio? for tagging recent sessions.
    final cardioRoutineIds = {
      for (final r in routines)
        if (r.tag == RoutineTag.cardio) r.id,
    };

    final now = DateTime.now();
    final recent = workouts
        .take(3)
        .map((w) => RecentSession(
              workout: w,
              relativeDate: relativeDateLabel(w.startedAt, now),
              isCardio: w.routineId != null &&
                  cardioRoutineIds.contains(w.routineId),
            ))
        .toList();

    final other = entries
        .where((e) => e.type == EntryType.move && e.workoutId == null)
        .toList();

    final today = DateTime(now.year, now.month, now.day);
    final moveMinutes = entries
        .where((e) =>
            e.type == EntryType.move &&
            DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day) ==
                today)
        .fold<int>(0, (sum, e) => sum + (e.duration ?? 0));

    yield MoveState(
      moveMinutes: moveMinutes,
      activeEnergyKcal: null,
      avgHeartRate: null,
      recentSessions: recent,
      otherActivity: other,
      routineCount: routines.length,
      suggestedRoutineName: routines.isEmpty ? null : routines.first.name,
    );
  }
}
