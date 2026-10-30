import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'watch_channel.dart';

/// What the Watch's workout measured over the whole session.
@immutable
class WatchWorkoutStats {
  const WatchWorkoutStats({this.heartRate, this.kcal});

  /// Reads the numbers out of a Watch message or reply; null when it has none.
  static WatchWorkoutStats? fromMessage(Map<Object?, Object?> message) {
    final heartRate = message[WatchKeys.heartRate];
    final kcal = message[WatchKeys.kcal];
    if (heartRate is! num && kcal is! num) return null;
    return WatchWorkoutStats(
      heartRate: heartRate is num ? heartRate.round() : null,
      kcal: kcal is num ? kcal.round() : null,
    );
  }

  /// Average heart rate, bpm.
  final int? heartRate;

  /// Active energy, kcal.
  final int? kcal;

  @override
  bool operator ==(Object other) =>
      other is WatchWorkoutStats && other.heartRate == heartRate && other.kcal == kcal;

  @override
  int get hashCode => Object.hash(heartRate, kcal);
}

/// The phone's calls to the Watch during a workout. The Watch is optional, so
/// none of these throws: a failure is logged and the workout goes on.
abstract interface class WatchWorkoutService {
  /// Opens the Watch app with its workout running (`HKHealthStore.startWatchApp`).
  /// Does nothing without a paired Watch that has the app.
  Future<void> start({required bool cardio});

  /// Sends a session snapshot to the Watch.
  Future<void> push(WatchReply snapshot);

  /// Asks the Watch to end its workout and returns what it measured, or null
  /// when it doesn't answer in time.
  Future<WatchWorkoutStats?> end();
}

/// Off iOS there is no Watch.
class NoopWatchWorkoutService implements WatchWorkoutService {
  const NoopWatchWorkoutService();

  @override
  Future<void> start({required bool cardio}) async {}

  @override
  Future<void> push(WatchReply snapshot) async {}

  @override
  Future<WatchWorkoutStats?> end() async => null;
}

/// [WatchWorkoutService] over `opal/watch`; the native end is `OpalWatchSession`.
class ChannelWatchWorkoutService implements WatchWorkoutService {
  const ChannelWatchWorkoutService({
    this.channel = watchChannel,
    this.endTimeout = const Duration(seconds: 3),
  });

  final MethodChannel channel;

  /// How long Finish on the phone waits for the Watch's numbers.
  final Duration endTimeout;

  @override
  Future<void> start({required bool cardio}) =>
      _call('startWorkout', {'cardio': cardio});

  @override
  Future<void> push(WatchReply snapshot) => _call('pushWorkout', snapshot);

  @override
  Future<WatchWorkoutStats?> end() async {
    try {
      final reply = await channel
          .invokeMethod<Map<Object?, Object?>>('endWorkout')
          .timeout(endTimeout);
      return reply == null ? null : WatchWorkoutStats.fromMessage(reply);
    } on TimeoutException {
      debugPrint('opal/watch endWorkout: no answer in ${endTimeout.inSeconds} s');
    } on PlatformException catch (e) {
      debugPrint('opal/watch endWorkout failed: ${e.message}');
    } on MissingPluginException {
      // no native side
    }
    return null;
  }

  Future<void> _call(String method, Object? arguments) async {
    try {
      await channel.invokeMethod<void>(method, arguments);
    } on PlatformException catch (e) {
      debugPrint('opal/watch $method failed: ${e.message}');
    } on MissingPluginException {
      // no native side
    }
  }
}
