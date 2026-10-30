import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../pal/http_pal_service.dart' show TokenProvider;

/// One change in an area's state word, effective from [at] until the next.
@immutable
class StateChange {
  const StateChange({required this.at, required this.state, required this.word});

  final DateTime at;
  final String state;
  final String word;

  Map<String, Object?> toJson() =>
      {'at': _epochSeconds(at), 'state': state, 'word': word};
}

/// One widget row, display-ready. [fraction] is null on rows without a ring.
@immutable
class WidgetRow {
  const WidgetRow({this.fraction, required this.value, required this.states});

  final double? fraction;
  final String value;
  final List<StateChange> states;

  Map<String, Object?> toJson() => {
        if (fraction != null) 'fraction': fraction,
        'value': value,
        'states': [for (final s in states) s.toJson()],
      };
}

/// The v2 widget payload. The widget shows each row's states on schedule and
/// falls back to dashes at [until].
@immutable
class WidgetSnapshot {
  const WidgetSnapshot({
    required this.until,
    required this.move,
    required this.routines,
    required this.money,
  });

  final DateTime until;
  final WidgetRow move;
  final WidgetRow routines;
  final WidgetRow money;

  Map<String, Object?> toJson() => {
        'until': _epochSeconds(until),
        'move': move.toJson(),
        'routines': routines.toJson(),
        'money': money.toJson(),
      };
}

int _epochSeconds(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;

/// Pushes today's progress to the iOS home-screen rings widget.
///
/// A free Apple team can't provision an App Group, so the app and the widget
/// extension can't share local storage. Instead the app POSTs the snapshot to
/// the proxy (`POST /v1/widget/snapshot`) and the widget fetches it over HTTP;
/// after a successful push we nudge WidgetKit to reload immediately via the
/// thin native `opal/widget_sync` [MethodChannel]. No-op everywhere off iOS.
///
/// Takes a display-ready [WidgetSnapshot] (never a view model) so it stays in
/// the services layer with no dependency on the controllers layer — the
/// `TodayState` -> snapshot mapping lives in `WidgetSyncController`.
abstract interface class WidgetSyncService {
  /// Pushes the latest snapshot. Safe to call often; a failed sync never throws
  /// (the widget keeps its last snapshot).
  Future<void> sync(WidgetSnapshot snapshot);
}

/// No-op [WidgetSyncService] for non-iOS platforms, web, and tests.
class NoopWidgetSyncService implements WidgetSyncService {
  const NoopWidgetSyncService();

  @override
  Future<void> sync(WidgetSnapshot snapshot) async {}
}

/// HTTP-backed [WidgetSyncService]: POSTs the snapshot to the proxy, then asks
/// the native side to reload WidgetKit so the widget re-fetches immediately.
///
/// Shares the proxy's http client + device-token plumbing with [HttpPalService].
/// A failed push (network, non-2xx, missing native
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
  Future<void> sync(WidgetSnapshot snapshot) async {
    final body = snapshot.toJson();

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
