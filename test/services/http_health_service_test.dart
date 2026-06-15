import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opal/services/health/http_health_service.dart';
import 'package:opal/services/pal/http_pal_service.dart';

void main() {
  late int clears;
  TokenProvider tokenProvider() {
    clears = 0;
    return TokenProvider(
      token: () async => 'tok',
      clear: () async => clears++,
    );
  }

  HttpHealthService build(MockClient client) => HttpHealthService(
        baseUrl: 'https://pal.test',
        httpClient: client,
        tokens: tokenProvider(),
      );

  test('GETs /v1/health/day?date=... with the bearer token', () async {
    late http.Request seen;
    final service = build(MockClient((req) async {
      seen = req;
      return http.Response(
        jsonEncode({
          'date': '2026-06-09',
          'metrics': {
            'activeEnergy': {'value': 412, 'unit': 'kcal'},
            'steps': {'value': 8423, 'unit': 'count'},
          },
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }));

    final day = await service.fetchDay(DateTime(2026, 6, 9));

    expect(seen.url.path, '/v1/health/day');
    expect(seen.url.queryParameters['date'], '2026-06-09');
    expect(seen.headers['authorization'], 'Bearer tok');
    expect(day.activeEnergyKcal, 412);
    expect(day.steps, 8423);
  });

  test('defaults missing metrics to 0', () async {
    final service = build(MockClient((req) async => http.Response(
          jsonEncode({'date': '2026-06-09', 'metrics': {}}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        )));

    final day = await service.fetchDay(DateTime(2026, 6, 9));

    expect(day.activeEnergyKcal, 0);
    expect(day.steps, 0);
  });

  test('rounds fractional metric values to int', () async {
    final service = build(MockClient((req) async => http.Response(
          jsonEncode({
            'metrics': {
              'activeEnergy': {'value': 411.6, 'unit': 'kcal'},
            },
          }),
          200,
        )));

    final day = await service.fetchDay(DateTime(2026, 6, 9));

    expect(day.activeEnergyKcal, 412);
    expect(day.steps, 0);
  });

  test('re-registers once on 401 then retries', () async {
    var calls = 0;
    final service = build(MockClient((req) async {
      calls++;
      if (calls == 1) return http.Response('unauthorized', 401);
      return http.Response(
        jsonEncode({
          'metrics': {
            'activeEnergy': {'value': 100, 'unit': 'kcal'},
          },
        }),
        200,
      );
    }));

    final day = await service.fetchDay(DateTime(2026, 6, 9));

    expect(day.activeEnergyKcal, 100);
    expect(calls, 2);
    expect(clears, 1);
  });

  test('throws PalException on a non-2xx after retry', () async {
    final service = build(MockClient((req) async => http.Response('boom', 502)));
    expect(
      () => service.fetchDay(DateTime(2026, 6, 9)),
      throwsA(isA<PalException>()),
    );
  });

  test('throws PalException (not a raw TypeError) on a malformed 2xx body',
      () async {
    // a 200 with an HTML error page / non-object JSON must normalize to
    // PalException so the caller's offline path is reached consistently.
    final service = build(MockClient(
        (req) async => http.Response('<html>maintenance</html>', 200)));
    expect(
      () => service.fetchDay(DateTime(2026, 6, 9)),
      throwsA(isA<PalException>()),
    );
  });
}
