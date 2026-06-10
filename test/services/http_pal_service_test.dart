import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opal/models/models.dart';
import 'package:opal/services/pal/http_pal_service.dart';

void main() {
  // A token store stub that hands back a fixed token and counts clears.
  late int clears;
  TokenProvider tokenProvider() {
    clears = 0;
    return TokenProvider(
      token: () async => 'tok',
      clear: () async => clears++,
    );
  }

  // Minimal context fetcher stub: the service calls this to assemble context.
  PalContextSource contextStub() => PalContextSource(
        chat: () async => {'userName': 'Kael', 'todayEntries': <String>[], 'dailyBudget': 60,
          'moveGoalMin': 30, 'ritualGoal': 5, 'spentToday': 0, 'movedTodayMin': 0,
          'ritualsDoneToday': 0, 'weekSpent': 0, 'weekBudget': 420, 'weekMovedMin': 0,
          'weekRitualsDone': 0, 'weekRitualGoal': 35, 'moveStreakDays': 0},
        review: (_) async => {'spent': 100, 'spentDeltaPct': 0, 'hoursMoved': 1, 'movedDeltaPct': 0,
          'activeDays': 1, 'ritualsKept': 1, 'ritualsTarget': 5, 'ritualsPct': 20, 'streakDays': 1,
          'topCategory': 'Food', 'topCategoryPct': 30, 'discoveredPattern': 'steady'},
        suggest: (_) async => {'recentWorkouts': <Object>[], 'dayOfWeek': 'Wed',
          'availableRoutines': [{'id': 'r2', 'name': 'Legs'}]},
        postWorkout: (_) async => {'routineName': 'Push', 'setCount': 1, 'volumeKg': 60,
          'prCount': 0, 'prExercises': <String>[], 'lastSessionVolumeKg': null, 'daysAgoLastSession': null},
        resolveRoutineTitle: (id) async => 'Legs',
      );

  HttpPalService build(MockClient client) => HttpPalService(
        baseUrl: 'https://pal.test',
        httpClient: client,
        tokens: tokenProvider(),
        context: contextStub(),
      );

  test('chat posts to /v1/chat and returns the reply', () async {
    late http.Request seen;
    final service = build(MockClient((req) async {
      seen = req;
      return http.Response(jsonEncode({'reply': 'Nice — logged it.'}), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }));

    final reply = await service.chat([], 'hi');

    expect(reply, 'Nice — logged it.');
    expect(seen.url.path, '/v1/chat');
    expect(seen.headers['authorization'], 'Bearer tok');
    expect(jsonDecode(seen.body)['message'], 'hi');
  });

  test('parse maps the response into a ParsedEntryDraft (expense negated)', () async {
    final service = build(MockClient((req) async => http.Response(
          jsonEncode({'type': 'money', 'amount': 5, 'duration': null, 'category': 'Coffee', 'title': 'Coffee', 'note': null}),
          200,
        )));

    final draft = await service.parse('coffee 5');

    expect(draft.type, EntryType.money);
    expect(draft.title, 'Coffee');
    expect(draft.amount, -5); // positive money amount becomes an expense
    expect(draft.category, 'Coffee');
  });

  test('suggestWorkout fills title from resolveRoutineTitle', () async {
    final service = build(MockClient((req) async =>
        http.Response(jsonEncode({'routineId': 'r2', 'reason': 'Legs rested.'}), 200)));

    final s = await service.suggestWorkout();

    expect(s.routineId, 'r2');
    expect(s.rationale, 'Legs rested.');
    expect(s.title, 'Legs');
  });

  test('re-registers once on 401 then retries', () async {
    var calls = 0;
    final service = build(MockClient((req) async {
      calls++;
      if (calls == 1) return http.Response('unauthorized', 401);
      return http.Response(jsonEncode({'reply': 'ok'}), 200);
    }));

    final reply = await service.chat([], 'hi');

    expect(reply, 'ok');
    expect(calls, 2);
    expect(clears, 1); // token was cleared before the retry
  });

  test('throws PalException on a non-2xx after retry', () async {
    final service = build(MockClient((req) async => http.Response('boom', 502)));
    expect(() => service.review(DateTime(2026, 6)), throwsA(isA<PalException>()));
  });
}
