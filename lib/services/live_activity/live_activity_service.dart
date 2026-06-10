import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The Live Activity / Dynamic Island seam (U25).
///
/// Mirrors the live workout session — see [WorkoutSessionController] — onto an
/// iOS ActivityKit Live Activity: a lock-screen banner + Dynamic Island showing
/// a live-ticking workout timer, the current exercise, completed sets, an
/// optional rest countdown, and a "Pal listening" affordance. Tapping the
/// island / banner deep-links back to the active workout screen
/// (`/session/:routineId`, `AppRoute.activeSession`).
///
/// This is a thin Dart wrapper over the native `opal/live_activity`
/// [MethodChannel]; all the ActivityKit work lives on the Swift side
/// (`ios/Runner/LiveActivities/OpalLiveActivityBridge.swift` +
/// `ios/OpalWidgets/`). The live timer ticks on-device via SwiftUI
/// `Text(timerInterval:)`, so [update] is only needed when the *content*
/// changes (exercise / set / rest), not every second.
///
/// Live Activities only exist on iOS 16.1+. Everywhere else (Android, web,
/// Windows, tests) wire the [NoopLiveActivityService] so call sites stay
/// platform-agnostic — exactly like [NotificationService] / [HapticsService].
abstract interface class LiveActivityService {
  /// Whether the user has Live Activities enabled for the app.
  ///
  /// `false` on every non-iOS platform and on iOS < 16.1. Call sites should
  /// gate [start] on this so a denied user never blocks the workout flow.
  Future<bool> areActivitiesEnabled();

  /// Begins a Live Activity for a workout session and returns its activity id
  /// (used by [update] / [end]), or `null` if one could not be started
  /// (disabled, unsupported OS, or the system activity budget is exhausted).
  ///
  /// [routineId] is baked into the activity's deep-link target
  /// (`opal://session/<routineId>`) so a tap routes to the right session.
  /// [routineName] labels the banner; [startedAt] anchors the live-ticking
  /// timer so it stays correct without per-second pushes.
  Future<String?> start({
    required String routineId,
    required String routineName,
    required DateTime startedAt,
  });

  /// Pushes new content into a running activity identified by [activityId].
  ///
  /// [elapsed] is informational only — the island ticks on its own from
  /// `startedAt`; pass it so the native side can reconcile after a long
  /// background gap. [currentExercise], [completedSets] and [restRemaining]
  /// update the displayed exercise, set count and rest countdown. A non-null
  /// [restRemaining] makes the island show the rest timer instead of the
  /// elapsed timer; pass `null` (or [Duration.zero]) when rest ends.
  Future<void> update({
    required String activityId,
    required Duration elapsed,
    String? currentExercise,
    int? completedSets,
    Duration? restRemaining,
  });

  /// Ends and dismisses the Live Activity identified by [activityId]. Safe to
  /// call with a stale / unknown id (no-op).
  Future<void> end(String activityId);
}

/// No-op [LiveActivityService] for non-iOS platforms, web, and tests.
///
/// Live Activities have no backing off iOS, so this does nothing and reports
/// activities as disabled. The real [MethodChannelLiveActivityService] is wired
/// on iOS behind the same interface (see the provider snippet in U25 notes).
class NoopLiveActivityService implements LiveActivityService {
  const NoopLiveActivityService();

  @override
  Future<bool> areActivitiesEnabled() async => false;

  @override
  Future<String?> start({
    required String routineId,
    required String routineName,
    required DateTime startedAt,
  }) async =>
      null;

  @override
  Future<void> update({
    required String activityId,
    required Duration elapsed,
    String? currentExercise,
    int? completedSets,
    Duration? restRemaining,
  }) async {}

  @override
  Future<void> end(String activityId) async {}
}

/// iOS-backed [LiveActivityService] over the `opal/live_activity`
/// [MethodChannel].
///
/// Each method forwards to the native `OpalLiveActivityBridge`, which drives
/// `Activity<OpalWorkoutActivityAttributes>` via ActivityKit. Durations cross
/// the channel as whole seconds (`int`) and the start time as epoch
/// milliseconds, matching the Swift argument mapping. Any
/// [PlatformException] / [MissingPluginException] is swallowed so a failed
/// activity never breaks the workout — the methods degrade to the no-op
/// behaviour of [NoopLiveActivityService].
class MethodChannelLiveActivityService implements LiveActivityService {
  /// Creates the service. A custom [channel] can be injected for tests.
  const MethodChannelLiveActivityService({
    MethodChannel channel = const MethodChannel('opal/live_activity'),
    // Named params can't be private, so an initializing formal isn't possible
    // while keeping `channel` injectable for tests.
    // ignore: prefer_initializing_formals
  }) : _channel = channel;

  final MethodChannel _channel;

  @override
  Future<bool> areActivitiesEnabled() async {
    try {
      final enabled = await _channel.invokeMethod<bool>('areEnabled');
      return enabled ?? false;
    } on PlatformException catch (e) {
      debugPrint('LiveActivity.areEnabled failed: ${e.message}');
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<String?> start({
    required String routineId,
    required String routineName,
    required DateTime startedAt,
  }) async {
    try {
      return await _channel.invokeMethod<String>('start', <String, dynamic>{
        'routineId': routineId,
        'routineName': routineName,
        'startedAtMs': startedAt.millisecondsSinceEpoch,
      });
    } on PlatformException catch (e) {
      debugPrint('LiveActivity.start failed: ${e.message}');
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<void> update({
    required String activityId,
    required Duration elapsed,
    String? currentExercise,
    int? completedSets,
    Duration? restRemaining,
  }) async {
    try {
      await _channel.invokeMethod<void>('update', <String, dynamic>{
        'activityId': activityId,
        'elapsedSeconds': elapsed.inSeconds,
        'currentExercise': currentExercise,
        'completedSets': completedSets,
        // Whole seconds; null clears the rest countdown.
        'restRemainingSeconds': restRemaining?.inSeconds,
      });
    } on PlatformException catch (e) {
      debugPrint('LiveActivity.update failed: ${e.message}');
    } on MissingPluginException {
      // No native side (non-iOS) — ignore.
    }
  }

  @override
  Future<void> end(String activityId) async {
    try {
      await _channel.invokeMethod<void>('end', <String, dynamic>{
        'activityId': activityId,
      });
    } on PlatformException catch (e) {
      debugPrint('LiveActivity.end failed: ${e.message}');
    } on MissingPluginException {
      // No native side (non-iOS) — ignore.
    }
  }
}
