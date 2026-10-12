import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opal/services/pal/http_pal_service.dart' show TokenProvider;
import 'package:opal/services/widget_sync/widget_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  TokenProvider tokensReturning(String token, {void Function()? onClear}) =>
      TokenProvider(token: () async => token, clear: () async => onClear?.call());

  final at = DateTime(2026, 10, 13, 11);
  final snapshot = WidgetSnapshot(
    until: DateTime(2026, 10, 14),
    move: WidgetRow(
      fraction: 0.62,
      value: '310 of 500 kcal',
      states: [StateChange(at: at, state: 'good', word: 'On track')],
    ),
    routines: WidgetRow(
      fraction: 0.5,
      value: '2 of 4 done',
      states: [StateChange(at: at, state: 'good', word: 'On track')],
    ),
    money: WidgetRow(
      value: r'$22 left of $60',
      states: [StateChange(at: at, state: 'watch', word: 'Worth watching')],
    ),
  );

  Future<void> syncSample(WidgetSyncService service) => service.sync(snapshot);

  // Records native reload calls (no native side in a unit test).
  List<String> captureReloadCalls() {
    const channel = MethodChannel('opal/widget_sync');
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    return calls;
  }

  test('posts the full snapshot to /v1/widget/snapshot then reloads', () async {
    final reloads = captureReloadCalls();
    late http.Request captured;
    final client = MockClient((req) async {
      captured = req;
      return http.Response('{"ok":true}', 200);
    });

    await syncSample(HttpWidgetSyncService(
      baseUrl: 'https://example.test',
      httpClient: client,
      tokens: tokensReturning('tok'),
    ));

    expect(captured.method, 'POST');
    expect(captured.url.path, '/v1/widget/snapshot');
    expect(captured.headers['authorization'], 'Bearer tok');
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body, snapshot.toJson());
    expect(body.keys, unorderedEquals(['until', 'move', 'routines', 'money']));
    expect(reloads, ['reload']); // success nudges an immediate widget reload
  });

  test('a non-2xx response never throws and skips the reload', () async {
    final reloads = captureReloadCalls();
    final client = MockClient((req) async => http.Response('nope', 500));

    await syncSample(HttpWidgetSyncService(
      baseUrl: 'https://example.test',
      httpClient: client,
      tokens: tokensReturning('tok'),
    ));

    expect(reloads, isEmpty);
  });

  test('clears the token and retries once on 401', () async {
    captureReloadCalls();
    var cleared = false;
    var attempts = 0;
    final client = MockClient((req) async {
      attempts++;
      return http.Response('', attempts == 1 ? 401 : 200);
    });

    await syncSample(HttpWidgetSyncService(
      baseUrl: 'https://example.test',
      httpClient: client,
      tokens: tokensReturning('tok', onClear: () => cleared = true),
    ));

    expect(cleared, isTrue);
    expect(attempts, 2);
  });

  test('a network error never throws', () async {
    captureReloadCalls();
    final client = MockClient((req) async => throw Exception('offline'));

    // must complete without throwing
    await syncSample(HttpWidgetSyncService(
      baseUrl: 'https://example.test',
      httpClient: client,
      tokens: tokensReturning('tok'),
    ));
  });
}
