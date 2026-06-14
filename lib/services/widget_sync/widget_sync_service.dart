import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../pal/http_pal_service.dart' show TokenProvider;

/// Pushes today's progress to the iOS home-screen rings widget.
///
/// A free Apple team can't provision an App Group, so the app and the widget
/// extension can't share local storage. Instead the app POSTs the snapshot to
/// the proxy (`POST /v1/widget/snapshot`) and the widget fetches it over HTTP;
/// after a successful push we nudge WidgetKit to reload immediately via the
/// thin native `opal/widget_sync` [MethodChannel]. No-op everywhere off iOS.
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

/// HTTP-backed [WidgetSyncService]: POSTs the snapshot to the proxy, then asks
/// the native side to reload WidgetKit so the widget re-fetches immediately.
///
/// Shares the proxy's http client + device-token plumbing with [HttpPalService]
/// and [HttpHealthService]. A failed push (network, non-2xx, missing native
/// bridge) is swallowed so it never breaks the app — the widget just keeps its
/// last fetched snapshot until its next timeline refresh.
class HttpWidgetSyncService implements WidgetSyncService {
  HttpWidgetSyncService({
    required String baseUrl,
    required http.Client httpClient,
    required this.tokens,
    MethodChannel channel = const MethodChannel('opal/widget_sync'),
    this.timeout = const Duration(seconds: 30),
  })  : _base = Uri.parse(baseUrl),
        _http = httpClient,
        // ignore: prefer_initializing_formals
        _channel = channel;

  final Uri _base;
  final http.Client _http;
  final TokenProvider tokens;
  final MethodChannel _channel;
  final Duration timeout;

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
    final body = <String, dynamic>{
      'moneyRing': moneyRing,
      'moveRing': moveRing,
      'ritualsRing': ritualsRing,
      'moneySpent': moneySpent,
      'dailyBudget': dailyBudget,
      'moveKcal': moveKcal,
      'dailyMoveKcal': dailyMoveKcal,
      'ritualsDone': ritualsDone,
      'dailyRitualTarget': dailyRitualTarget,
    };

    try {
      Future<http.Response> send() async {
        final token = await tokens.token();
        return _http
            .post(
              _base.replace(path: '/v1/widget/snapshot'),
              headers: {
                'content-type': 'application/json',
                'authorization': 'Bearer $token',
              },
              body: jsonEncode(body),
            )
            .timeout(timeout);
      }

      var res = await send();
      if (res.statusCode == 401) {
        await tokens.clear();
        res = await send();
      }
      if (res.statusCode >= 200 && res.statusCode < 300) {
        await _reloadWidget();
      } else {
        debugPrint('WidgetSync.sync returned ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('WidgetSync.sync failed: $e');
    }
  }

  /// Nudges WidgetKit to re-fetch now rather than wait for its timeline policy.
  /// `reloadAllTimelines` needs no entitlement, so it works on a free team.
  Future<void> _reloadWidget() async {
    try {
      await _channel.invokeMethod<void>('reload');
    } on MissingPluginException {
      // no native side (non-iOS) — ignore.
    } on PlatformException catch (e) {
      debugPrint('WidgetSync.reload failed: ${e.message}');
    }
  }
}
