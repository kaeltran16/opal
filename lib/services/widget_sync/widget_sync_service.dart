import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Pushes today's progress to the iOS home-screen rings widget.
///
/// Mirrors the [LiveActivityService] seam: a thin Dart wrapper over the native
/// `opal/widget_sync` [MethodChannel]. The Swift side writes the values to the
/// shared App Group and asks WidgetKit to reload. No-op everywhere off iOS.
///
/// Takes pre-computed fractions and counts (never a view model) so it stays in
/// the services layer with no dependency on the controllers layer — the
/// `TodayState` -> args mapping lives in `WidgetSyncController`.
abstract interface class WidgetSyncService {
  /// Pushes the latest snapshot. Safe to call often; a failed sync never throws
  /// (the widget keeps its last snapshot).
  Future<void> sync({
    required double moneyRing,
    required double moveRing,
    required double ritualsRing,
    required double moneySpent,
    required double dailyBudget,
    required int moveKcal,
    required int dailyMoveKcal,
    required int ritualsDone,
    required int dailyRitualTarget,
  });
}

/// No-op [WidgetSyncService] for non-iOS platforms, web, and tests.
class NoopWidgetSyncService implements WidgetSyncService {
  const NoopWidgetSyncService();

  @override
  Future<void> sync({
    required double moneyRing,
    required double moveRing,
    required double ritualsRing,
    required double moneySpent,
    required double dailyBudget,
    required int moveKcal,
    required int dailyMoveKcal,
    required int ritualsDone,
    required int dailyRitualTarget,
  }) async {}
}

/// iOS-backed [WidgetSyncService] over the `opal/widget_sync` [MethodChannel].
///
/// Forwards the snapshot to the native `OpalWidgetSyncBridge`, which persists it
/// to the shared App Group and reloads WidgetKit. Any [PlatformException] /
/// [MissingPluginException] is swallowed so a failed sync never breaks the app
/// — it degrades to the no-op behaviour of [NoopWidgetSyncService].
class MethodChannelWidgetSyncService implements WidgetSyncService {
  /// Creates the service. A custom [channel] can be injected for tests.
  const MethodChannelWidgetSyncService({
    MethodChannel channel = const MethodChannel('opal/widget_sync'),
    // ignore: prefer_initializing_formals
  }) : _channel = channel;

  final MethodChannel _channel;

  @override
  Future<void> sync({
    required double moneyRing,
    required double moveRing,
    required double ritualsRing,
    required double moneySpent,
    required double dailyBudget,
    required int moveKcal,
    required int dailyMoveKcal,
    required int ritualsDone,
    required int dailyRitualTarget,
  }) async {
    try {
      await _channel.invokeMethod<void>('sync', <String, dynamic>{
        'moneyRing': moneyRing,
        'moveRing': moveRing,
        'ritualsRing': ritualsRing,
        'moneySpent': moneySpent,
        'dailyBudget': dailyBudget,
        'moveKcal': moveKcal,
        'dailyMoveKcal': dailyMoveKcal,
        'ritualsDone': ritualsDone,
        'dailyRitualTarget': dailyRitualTarget,
      });
    } on PlatformException catch (e) {
      debugPrint('WidgetSync.sync failed: ${e.message}');
    } on MissingPluginException {
      // No native side (non-iOS) — ignore.
    }
  }
}
