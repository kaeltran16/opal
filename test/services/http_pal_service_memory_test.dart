import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opal/services/pal/http_pal_service.dart';
import 'package:opal/services/pal/pal_service.dart';

HttpPalService _service(MockClient client) => HttpPalService(
      baseUrl: 'https://x.test',
      httpClient: client,
      tokens: TokenProvider(token: () async => 't', clear: () async {}),
      context: PalContextSource(
        chat: () async => {},
        review: (_, _) async => {},
        insights: (_) async => {'range': 'month', 'entries': <String>[], 'spendByWeekday': <num>[]},
        suggest: (_, _) async => {},
        postWorkout: (_) async => {},
        resolveRoutineTitle: (_) async => null,
      ),
    );

void main() {
  test('memory() decodes facts and patterns', () async {
    final client = MockClient((req) async {
      expect(req.method, 'GET');
      expect(req.url.path, '/v1/memory');
      return http.Response(
        jsonEncode({
          'facts': [{'id': 'f-1', 'text': 'marathon in October'}],
          'patterns': [{'colorToken': 'move', 'title': 'Mornings', 'detail': 'before noon'}],
        }),
        200,
      );
    });
    final d = await _service(client).memory();
    expect(d.facts.single, const PalFact(id: 'f-1', text: 'marathon in October'));
    expect(d.patterns.single.title, 'Mornings');
  });

  test('deleteFact() DELETEs the fact path and returns the updated digest', () async {
    final client = MockClient((req) async {
      expect(req.method, 'DELETE');
      expect(req.url.path, '/v1/memory/facts/f-1');
      return http.Response(jsonEncode({'facts': [], 'patterns': []}), 200);
    });
    final d = await _service(client).deleteFact('f-1');
    expect(d.isEmpty, isTrue);
  });

  test('refreshMemory() POSTs the refresh path with an insights context', () async {
    final client = MockClient((req) async {
      expect(req.method, 'POST');
      expect(req.url.path, '/v1/memory/refresh');
      expect((jsonDecode(req.body) as Map)['context'], isA<Map>());
      return http.Response(
        jsonEncode({
          'facts': [],
          'patterns': [{'colorToken': 'money', 'title': 'Fridays', 'detail': 'dining out'}],
        }),
        200,
      );
    });
    final d = await _service(client).refreshMemory();
    expect(d.patterns.single.title, 'Fridays');
  });
}
