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

  Future<void> syncSample(WidgetSyncService service) => service.sync(
        moneyRing: 0.7,
        moveRing: 0.45,
        ritualsRing: 0.6,
        moneySpent: 42,
        dailyBudget: 60,
        moveKcal: 180,
        dailyMoveKcal: 400,
        ritualsDone: 3,
        dailyRitualTarget: 5,
      );

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
    expect(body['moneyRing'], closeTo(0.7, 1e-9));
    expect(body['moveRing'], closeTo(0.45, 1e-9));
    expect(body['ritualsRing'], closeTo(0.6, 1e-9));
    expect(body['moneySpent'], 42);
    expect(body['dailyBudget'], 60);
    expect(body['moveKcal'], 180);
    expect(body['dailyMoveKcal'], 400);
    expect(body['ritualsDone'], 3);
    expect(body['dailyRitualTarget'], 5);
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
