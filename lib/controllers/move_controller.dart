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

/// One day of the hero week-strip: its weekday letter, whether a workout was
/// completed that day, and whether it is today. The strip renders Mon→Sun.
class WeekDay {
  const WeekDay({required this.letter, required this.done, required this.today});

  final String letter;
  final bool done;
  final bool today;
}

/// Weekly workout goal (no per-user data source yet — see controller FLAG).
const int kWeeklyWorkoutGoal = 4;

/// The fully-computed Move view model: today's logged move minutes, the recent
/// sessions (newest 3, decorated), the non-workout movement entries, and the
/// quick-link counts. The screen is dumb; all derivation lives here so it is
/// testable.
class MoveState {
  const MoveState({
    required this.moveKcal,
    required this.recentSessions,
    required this.otherActivity,
    required this.routineCount,
    required this.weekDays,
    required this.weekWorkouts,
    required this.weekVolumeKg,
    required this.weekMinutes,
    required this.weekPrCount,
    this.suggestedRoutineName,
  });

  /// Sum of today's logged move-entry active energy (kcal).
  final int moveKcal;

  /// The three newest workouts, decorated for the recent-sessions cards.
  final List<RecentSession> recentSessions;

  /// Non-workout move entries (e.g. a logged run) for the "Other activity"
  /// section. Empty when there is none (the screen omits the section).
  final List<Entry> otherActivity;

  /// Total routine count (drives the "My routines" quick-link value).
  final int routineCount;

  /// Mon→Sun strip for the hero calendar (done/today states).
  final List<WeekDay> weekDays;

  /// Completed workouts in the current ISO week (hero focal number).
  final int weekWorkouts;

  /// This week's total completed-set volume in kilograms.
  final double weekVolumeKg;

  /// This week's total training minutes.
  final int weekMinutes;

  /// This week's personal-record count (hero "Records" stat).
  final int weekPrCount;

  /// Pal's suggested routine name for the Start CTA, or null when there are no
  /// routines yet.
  final String? suggestedRoutineName;

  /// Weekly goal the hero ring/headline measures against.
  int get weekGoal => kWeeklyWorkoutGoal;

  /// Workouts-vs-goal completion as a 0..1 fraction (capped at 1).
  double get weekProgress =>
      weekGoal == 0 ? 0 : (weekWorkouts / weekGoal).clamp(0.0, 1.0);

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

/// Builds the Mon→Sun hero week-strip from this week's completed [workouts].
/// A day reads "done" when at least one workout was completed on it; "today"
/// follows [now]. Pure so it is unit-testable.
List<WeekDay> buildWeekDays(List<Workout> workouts, DateTime now) {
  const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  final today = DateTime(now.year, now.month, now.day);
  final monday = today.subtract(Duration(days: today.weekday - DateTime.monday));
  final doneDays = <int>{
    for (final w in workouts)
      if (w.isComplete)
        DateTime(w.startedAt.year, w.startedAt.month, w.startedAt.day)
            .difference(monday)
            .inDays,
  };
  return [
    for (var i = 0; i < 7; i++)
      WeekDay(
        letter: letters[i],
        done: doneDays.contains(i),
        today: monday.add(Duration(days: i)) == today,
      ),
  ];
}

/// Streams the Move view model off the live workouts stream, plus the routines,
/// exercise catalog and non-workout move entries re-read each tick. Re-emits
/// whenever the workouts table changes.
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
    final moveKcal = entries
        .where((e) =>
            e.type == EntryType.move &&
            DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day) ==
                today)
        .fold<int>(0, (sum, e) => sum + (e.calories ?? 0));

    // this-week aggregates (Mon 00:00 → now) drive the hero ring/strip/stats.
    final monday =
        today.subtract(Duration(days: today.weekday - DateTime.monday));
    final weekWorkouts = workouts
        .where((w) =>
            w.isComplete &&
            !w.startedAt.isBefore(monday) &&
            w.startedAt.isBefore(monday.add(const Duration(days: 7))))
        .toList();

    yield MoveState(
      moveKcal: moveKcal,
      recentSessions: recent,
      otherActivity: other,
      routineCount: routines.length,
      weekDays: buildWeekDays(workouts, now),
      weekWorkouts: weekWorkouts.length,
      weekVolumeKg:
          weekWorkouts.fold<double>(0, (s, w) => s + w.totalVolumeKg),
      weekMinutes: weekWorkouts.fold<int>(
          0, (s, w) => s + (w.duration?.inMinutes ?? 0)),
      weekPrCount: weekWorkouts.fold<int>(0, (s, w) => s + w.prCount),
      suggestedRoutineName: routines.isEmpty ? null : routines.first.name,
    );
  }
}
