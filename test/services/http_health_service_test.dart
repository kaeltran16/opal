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

  // ---------------------------------------------------------------------------
  // fetchSleep
  // ---------------------------------------------------------------------------

  test('GETs /v1/health/sleep with from/to params and bearer token', () async {
    late http.Request seen;
    final service = build(MockClient((req) async {
      seen = req;
      return http.Response(
        jsonEncode({'nights': []}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }));

    await service.fetchSleep(DateTime(2026, 6, 1), DateTime(2026, 6, 8));

    expect(seen.url.path, '/v1/health/sleep');
    expect(seen.url.queryParameters['from'], '2026-06-01');
    expect(seen.url.queryParameters['to'], '2026-06-08');
    expect(seen.headers['authorization'], 'Bearer tok');
  });

  test('maps sleep JSON fields including nested stages', () async {
    final service = build(MockClient((req) async => http.Response(
          jsonEncode({
            'nights': [
              {
                'night': '2026-06-07',
                'asleepMinutes': 421,
                'inBedMinutes': 450,
                'bedtime': '23:14',
                'wake': '7:02',
                'stages': {
                  'deep': 68,
                  'rem': 112,
                  'core': 205,
                  'awake': 36,
                },
                'wakes': 3,
                'sourceRef': 'apple-health-abc',
              }
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        )));

    final nights =
        await service.fetchSleep(DateTime(2026, 6, 7), DateTime(2026, 6, 8));

    expect(nights, hasLength(1));
    final n = nights.first;
    expect(n.night, DateTime(2026, 6, 7));
    expect(n.asleepMinutes, 421);
    expect(n.inBedMinutes, 450);
    expect(n.bedtime, '23:14');
    expect(n.wake, '7:02');
    expect(n.deepMinutes, 68);
    expect(n.remMinutes, 112);
    expect(n.coreMinutes, 205);
    expect(n.awakeMinutes, 36);
    expect(n.wakes, 3);
    expect(n.sourceRef, 'apple-health-abc');
  });

  test('defaults absent sleep fields to 0 / empty string / null', () async {
    final service = build(MockClient((req) async => http.Response(
          jsonEncode({
            'nights': [
              {'night': '2026-06-07'},
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        )));

    final nights =
        await service.fetchSleep(DateTime(2026, 6, 7), DateTime(2026, 6, 8));

    expect(nights, hasLength(1));
    final n = nights.first;
    expect(n.asleepMinutes, 0);
    expect(n.inBedMinutes, 0);
    expect(n.bedtime, '');
    expect(n.wake, '');
    expect(n.deepMinutes, 0);
    expect(n.remMinutes, 0);
    expect(n.coreMinutes, 0);
    expect(n.awakeMinutes, 0);
    expect(n.wakes, 0);
    expect(n.sourceRef, isNull);
  });

  test('rounds fractional sleep minute values to int', () async {
    final service = build(MockClient((req) async => http.Response(
          jsonEncode({
            'nights': [
              {
                'night': '2026-06-07',
                'asleepMinutes': 420.6,
                'stages': {'deep': 67.5},
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        )));

    final nights =
        await service.fetchSleep(DateTime(2026, 6, 7), DateTime(2026, 6, 8));

    expect(nights.first.asleepMinutes, 421);
    expect(nights.first.deepMinutes, 68);
  });

  test('returns empty list when nights array is absent', () async {
    final service = build(MockClient((req) async => http.Response(
          jsonEncode({}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        )));

    final nights =
        await service.fetchSleep(DateTime(2026, 6, 1), DateTime(2026, 6, 8));

    expect(nights, isEmpty);
  });

  test('fetchSleep throws PalException on non-2xx', () async {
    final service =
        build(MockClient((req) async => http.Response('boom', 503)));
    expect(
      () => service.fetchSleep(DateTime(2026, 6, 1), DateTime(2026, 6, 8)),
      throwsA(isA<PalException>()),
    );
  });

  test('fetchSleep throws PalException on malformed 2xx body', () async {
    final service = build(MockClient(
        (req) async => http.Response('<html>error</html>', 200)));
    expect(
      () => service.fetchSleep(DateTime(2026, 6, 1), DateTime(2026, 6, 8)),
      throwsA(isA<PalException>()),
    );
  });
}
