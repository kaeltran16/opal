import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart' hide Provider;
import '../services/services.dart';
import '../util/format.dart';
import 'workout_session_controller.dart';

// plain providers, not @riverpod: their .g.dart can't be generated without a
// Dart SDK here (see watchLogProvider)

/// The phone's calls to the Watch during a workout; a no-op off iOS.
final watchWorkoutServiceProvider = Provider<WatchWorkoutService>(
  (ref) => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
      ? const ChannelWatchWorkoutService()
      : const NoopWatchWorkoutService(),
);

/// Answers the Watch's workout commands; the app engine binds it to `opal/watch`.
final watchWorkoutProvider = Provider<WatchWorkout>((ref) {
  final watch = WatchWorkout(ref);
  ref.onDispose(watch.dispose);
  return watch;
});

/// The session as the Watch shows it, display-ready like the Pal replies.
///
/// [session] tells sessions apart and [rev] orders snapshots within one, so
/// the Watch can drop one that arrives late or twice. Rest goes as a deadline,
/// [restEndsAt], so the Watch counts down on its own.
WatchReply buildWatchSnapshot(
  ActiveSessionState state, {
  required int rev,
  required int restSeconds,
  DateTime? restEndsAt,
  bool ended = false,
}) {
  final workout = state.activeWorkout;
  final base = <String, Object?>{
    WatchKeys.type: WatchKeys.workout,
    WatchKeys.session: workout.startedAt.millisecondsSinceEpoch,
    WatchKeys.rev: rev,
  };
  final set = state.currentSet;
  final exercise = state.currentExercise;
  if (ended) return {...base, WatchKeys.phase: WatchKeys.phaseEnded};
  if (state.isComplete || set == null || exercise == null) {
    final logged = workout.sets.where((s) => s.done).length;
    return {
      ...base,
      WatchKeys.phase: WatchKeys.phaseDone,
      WatchKeys.logged: '$logged of ${workout.sets.length} sets',
    };
  }

  final number = state.currentSetIndex + 1;
  final total = state.currentExerciseSets.length;
  final planned = set.isTimed
      ? '${set.minutes ?? kDefaultTimedMinutes} min'
      : '${formatWeight(set.weightKg)} kg × ${set.reps}';
  // the phone's set card rule: a timed set has no best, and only a heavier
  // planned weight is ahead of it. A rest carries them too: the Watch shows
  // the set itself once the rest runs out while the phone is asleep.
  final pr = set.isTimed ? null : exercise.pr;
  final shared = {
    ...base,
    WatchKeys.setId: set.id,
    WatchKeys.timed: set.isTimed,
    WatchKeys.exercise: exercise.name,
    WatchKeys.setLabel: 'Set $number of $total',
    WatchKeys.planned: planned,
    WatchKeys.progress: '${exercise.name} · $number of $total sets',
    WatchKeys.canSkip: state.nextExercise != null,
    if (pr != null && set.weightKg > pr.weightKg)
      WatchKeys.ahead: 'Ahead of your best by ${formatWeight(set.weightKg - pr.weightKg)} kg'
    else if (pr != null)
      WatchKeys.best: 'Best ${formatWeight(pr.weightKg)} kg × ${pr.reps}',
  };
  if (state.isResting && restEndsAt != null) {
    return {
      ...shared,
      WatchKeys.phase: WatchKeys.phaseRest,
      WatchKeys.restEndsAt: restEndsAt.millisecondsSinceEpoch,
      WatchKeys.restTotal: math.max(restSeconds, state.restRemaining),
      WatchKeys.next: 'Set $number · $planned',
    };
  }
  return {...shared, WatchKeys.phase: WatchKeys.phaseSet};
}

/// Runs the Watch's commands against the session running on the phone.
///
/// Commands that act on a set carry the id of the set the Watch showed and
/// apply only while it is still the current one, so a Try again after a lost
/// reply can't log a set twice. Every command answers with the snapshot.
class WatchWorkout {
  WatchWorkout(this._ref);

  final Ref _ref;
  final _finished = StreamController<Workout>.broadcast();

  /// Workouts finished from the Watch; the app opens their summary.
  Stream<Workout> get finishedOnWatch => _finished.stream;

  void dispose() => _finished.close();

  Future<WatchReply> handle(Map<Object?, Object?> message) async {
    final routineId = _ref.read(runningSessionProvider);
    if (routineId == null) return noWorkout;
    final provider = workoutSessionControllerProvider(routineId);
    final state = await _ref.read(provider.future);
    final session = _ref.read(provider.notifier);
    final set = state.currentSet;
    final onSet = set != null && message[WatchKeys.setId] == set.id;

    switch (message[WatchKeys.command]) {
      case WatchKeys.complete when onSet:
        _complete(session, set, message[WatchKeys.distanceKm]);
      case WatchKeys.addSet when onSet:
        session.addSet();
      case WatchKeys.skipExercise when onSet:
        session.skipExercise();
      case WatchKeys.skipRest when state.isResting:
        session.skipRest();
      case WatchKeys.addRest when state.isResting:
        session.addRestTime();
      case WatchKeys.finish:
        final workout = await session.finish(
          fromWatch: WatchWorkoutStats.fromMessage(message) ?? const WatchWorkoutStats(),
        );
        _finished.add(workout);
    }
    return session.watchSnapshot();
  }

  /// Logs the planned values; a timed set takes the Watch's distance, or the
  /// planned one when the Watch measured none.
  void _complete(WorkoutSessionController session, SetLog set, Object? watchKm) {
    if (!set.isTimed) {
      session.logCurrentSet(weightKg: set.weightKg, reps: set.reps);
      return;
    }
    session.logCurrentTimedSet(
      minutes: set.minutes ?? kDefaultTimedMinutes,
      distanceKm: watchKm is num && watchKm > 0 ? watchKm.toDouble() : set.distanceKm,
    );
  }
}
