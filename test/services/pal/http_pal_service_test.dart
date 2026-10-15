import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opal/models/models.dart';
import 'package:opal/services/pal/http_pal_service.dart';
import 'package:opal/services/pal/pal_service.dart';

HttpPalService _service(Map<String, dynamic> body, {void Function(http.Request)? onRequest}) {
  final client = MockClient((req) async {
    onRequest?.call(req);
    return http.Response(
        jsonEncode(body), 200, headers: {'content-type': 'application/json'});
  });
  return HttpPalService(
    baseUrl: 'https://x.test',
    httpClient: client,
    tokens: TokenProvider(token: () async => 't', clear: () async {}),
    context: PalContextSource(
      chat: () async => {},
      review: (_, _) async => {},
      insights: (_) async => {},
      suggest: (_, _) async => {},
      postWorkout: (_) async => {},
      resolveRoutineTitle: (_) async => null,
      agendaTargets: () async => {
        'rituals': [
          {'id': 'evening', 'name': 'Evening', 'steps': ['Read']}
        ],
        'workouts': <Object?>[],
        'week': <Object?>[],
      },
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

  group('agenda', () {
    test('the request carries the targets', () async {
      Map<String, dynamic>? sent;
      final svc = _service({'proposals': const [], 'autopilot': const []},
          onRequest: (r) => sent = jsonDecode(r.body) as Map<String, dynamic>);
      await svc.agenda();
      expect(sent!['targets'], containsPair('rituals', [
        {'id': 'evening', 'name': 'Evening', 'steps': ['Read']}
      ]));
    });

    test('a proposal with no known action decodes to nothing', () async {
      final svc = _service({
        'proposals': [
          {'id': 'a', 'title': 'Hold funds', 'action': 'hold_funds'},
          {'id': 'b', 'title': 'Plain', 'action': null},
        ],
        'autopilot': const [],
      });
      expect((await svc.agenda()).proposals, isEmpty);
    });

    test('an add_ritual without its ritual is dropped', () async {
      final svc = _service({
        'proposals': [
          {'id': 'a', 'title': 'Add', 'action': 'add_ritual'},
        ],
        'autopilot': const [],
      });
      expect((await svc.agenda()).proposals, isEmpty);
    });

    test('a valid reschedule decodes its slot', () async {
      final svc = _service({
        'proposals': [
          {
            'id': 'a',
            'title': 'Move legs',
            'action': 'reschedule_workout',
            'slot': {'weekday': 5, 'routineId': 'seed-routine-legs'},
          },
          {'id': 'b', 'title': 'No slot', 'action': 'reschedule_workout'},
        ],
        'autopilot': const [],
      });
      final proposals = (await svc.agenda()).proposals;
      expect(proposals, hasLength(1));
      expect(proposals.single.reschedulesWorkout, isTrue);
      expect(proposals.single.slot, (weekday: 5, routineId: 'seed-routine-legs'));
    });
  });
}
