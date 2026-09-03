import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opal/services/pal/http_pal_service.dart';
import 'package:opal/services/pal/pal_service.dart';

/// In-memory [PalResponseCache] so a test can observe hits/misses without prefs.
class _MemCache extends PalResponseCache {
  final Map<String, String> store = {};

  @override
  Future<String?> get(String key) async => store[key];

  @override
  Future<void> put(String key, String value) async => store[key] = value;
}

HttpPalService _service(
  MockClient client,
  PalResponseCache cache,
  Future<Map<String, Object?>> Function() chat,
) =>
    HttpPalService(
      baseUrl: 'https://x.test',
      httpClient: client,
      tokens: TokenProvider(token: () async => 't', clear: () async {}),
      cache: cache,
      context: PalContextSource(
        chat: chat,
        review: (_, _) async => {},
        insights: (_) async => {},
        suggest: (_, _) async => {},
        postWorkout: (_) async => {},
        resolveRoutineTitle: (_) async => null,
      ),
    );

/// A chat context shaped like [buildChatContext]'s output. [entries] drives the
/// bucket; [spentToday] is the kind of volatile field that must NOT.
Map<String, Object?> _ctx({required List<String> entries, required double spentToday}) => {
      'userName': 'K',
      'todayEntries': entries,
      'spentToday': spentToday,
      'moveStreakDays': 3,
      'hourOfDay': 9,
      'weekday': 2,
    };

void main() {
  test('a volatile context change still serves the cached suggestions', () async {
    var calls = 0;
    final client = MockClient((req) async {
      calls++;
      return http.Response(
        jsonEncode({
          'suggestions': [
            {'label': 'Verve coffee', 'kind': 'log_money', 'colorToken': 'money', 'entry': null},
          ],
        }),
        200,
      );
    });
    final cache = _MemCache();
    var ctx = _ctx(entries: const ['coffee'], spentToday: 5);
    final svc = _service(client, cache, () async => ctx);

    await svc.suggestions(SuggestionSurface.composer);
    // same number of logged entries, but spend/streak moved — the old key
    // (full-context JSON) would miss here.
    ctx = _ctx(entries: const ['coffee'], spentToday: 9);
    final second = await svc.suggestions(SuggestionSurface.composer);

    expect(calls, 1, reason: 'second open should hit the cache');
    expect(second.single.label, 'Verve coffee');
  });

  test('logging something changes the bucket and refetches', () async {
    var calls = 0;
    final client = MockClient((req) async {
      calls++;
      return http.Response(jsonEncode({'suggestions': const []}), 200);
    });
    final cache = _MemCache();
    var ctx = _ctx(entries: const ['coffee'], spentToday: 5);
    final svc = _service(client, cache, () async => ctx);

    await svc.suggestions(SuggestionSurface.composer);
    ctx = _ctx(entries: const ['coffee', 'lunch'], spentToday: 20);
    await svc.suggestions(SuggestionSurface.composer);

    expect(calls, 2, reason: 'a new entry should produce fresh chips');
  });
}
