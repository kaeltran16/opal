import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opal/models/models.dart';
import 'package:opal/services/pal/http_pal_service.dart';
import 'package:opal/services/pal/pal_service.dart';

HttpPalService _service(Map<String, dynamic> body) {
  final client = MockClient((req) async => http.Response(
        jsonEncode(body), 200, headers: {'content-type': 'application/json'}));
  return HttpPalService(
    baseUrl: 'https://x.test',
    httpClient: client,
    tokens: TokenProvider(token: () async => 't', clear: () async {}),
    context: PalContextSource(
      chat: () async => {},
      review: (_, __) async => {},
      insights: (_) async => {},
      suggest: (_, __) async => {},
      postWorkout: (_) async => {},
      resolveRoutineTitle: (_) async => null,
    ),
  );
}

void main() {
  test('insights keeps a nutrition colour token (not clamped to rituals)', () async {
    final svc = _service({
      'headline': null, 'lede': null, 'suggestion': null, 'correlationNarration': null,
      'wins': const [],
      'patterns': [
        {'colorToken': 'nutrition', 'title': 'Lighter lunches', 'detail': 'fewer cals midday'}
      ],
    });
    final res = await svc.insights(InsightRange.week);
    expect(res.patterns.single.colorToken, 'nutrition');
  });

  test('chat decodes a log_meal action', () async {
    final svc = _service({
      'reply': 'In the bank.',
      'actions': [
        {'kind': 'log_meal', 'name': 'Burrito', 'slot': 'Lunch', 'calLo': 520, 'calHi': 820, 'confidence': 'med'}
      ],
    });
    final res = await svc.chat(const [], 'had a burrito for lunch');
    final meal = res.actions.single as LogMealAction;
    expect(meal.name, 'Burrito');
    expect(meal.cal, const IntRange(520, 820));
    expect(meal.confidence, NutritionConfidence.med);
    expect(meal.slot, 'Lunch');
  });

  test('chat drops a log_meal missing its calorie range', () async {
    final svc = _service({
      'reply': 'ok',
      'actions': [
        {'kind': 'log_meal', 'name': 'Burrito'}
      ],
    });
    final res = await svc.chat(const [], 'burrito');
    expect(res.actions, isEmpty);
  });
}
