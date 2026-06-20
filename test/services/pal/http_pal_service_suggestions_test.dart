import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opal/models/models.dart';
import 'package:opal/services/pal/http_pal_service.dart';
import 'package:opal/services/pal/pal_service.dart';

PalContextSource _ctx() => PalContextSource(
      chat: () async => {'userName': 'Kael'},
      review: (_, _) async => {},
      insights: (_) async => {},
      suggest: (_, _) async => {'dayOfWeek': 'Sat'},
      postWorkout: (_) async => {},
      resolveRoutineTitle: (_) async => null,
    );

HttpPalService _svc(MockClient client) => HttpPalService(
      baseUrl: 'https://x.test',
      httpClient: client,
      tokens: TokenProvider(token: () async => 't', clear: () async {}),
      context: _ctx(),
    );

void main() {
  test('decodes suggestions and drops malformed items', () async {
    final client = MockClient((req) async {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      expect(body['surface'], 'composer');
      return http.Response(
        jsonEncode({
          'suggestions': [
            {
              'label': 'Coffee, \$5',
              'icon': 'dollarsign.circle.fill',
              'colorToken': 'money',
              'entry': {'type': 'money', 'title': 'Coffee', 'amount': -5, 'category': 'Coffee', 'minutes': null},
            },
            {'label': "How's my week?", 'icon': 'chart.bar.fill', 'colorToken': 'accent'},
            {'icon': 'x'}, // malformed: no label → dropped
          ],
        }),
        200,
      );
    });
    final out = await _svc(client).suggestions(SuggestionSurface.composer);
    expect(out, hasLength(2));
    expect(out[0].entry?.type, EntryType.money);
    expect(out[0].entry?.amount, -5);
    expect(out[1].entry, isNull);
  });

  test('routineGoal posts the suggest context', () async {
    final client = MockClient((req) async {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      expect(body['surface'], 'routineGoal');
      expect((body['context'] as Map)['dayOfWeek'], 'Sat');
      return http.Response(jsonEncode({'suggestions': []}), 200);
    });
    final out = await _svc(client).suggestions(SuggestionSurface.routineGoal);
    expect(out, isEmpty);
  });
}
