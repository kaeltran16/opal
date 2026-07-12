import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opal/models/models.dart';
import 'package:opal/services/pal/http_pal_service.dart';
import 'package:opal/services/pal/pal_service.dart';

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
          'moveGoalKcal': 500, 'ritualGoal': 5, 'spentToday': 0, 'movedTodayKcal': 0,
          'ritualsDoneToday': 0, 'weekSpent': 0, 'weekBudget': 420, 'weekMovedKcal': 0,
          'weekRitualsDone': 0, 'weekRitualGoal': 35, 'moveStreakDays': 0},
        review: (_, _) async => {'range': 'week', 'spent': 100, 'spentDeltaPct': null, 'kcalMoved': 1,
          'movedDeltaPct': null, 'activeDays': 1, 'ritualsKept': 1, 'ritualsTarget': 5, 'ritualsPct': 20,
          'streakDays': 1, 'topCategory': 'Food', 'topCategoryPct': 30},
        insights: (_) async => {'range': 'week', 'spent': 100, 'budget': 420, 'moveKcal': 60,
          'moveTargetKcal': 210, 'ritualsKept': 5, 'ritualsTarget': 35, 'activeDays': 2, 'streakDays': 3,
          'topCategory': 'Food', 'topCategoryPct': 30, 'spendByWeekday': <double>[0,0,0,0,100,0,0],
          'entries': <String>[]},
        suggest: (_, _) async => {'recentWorkouts': <Object>[], 'dayOfWeek': 'Wed',
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

    final result = await service.chat([], 'hi');

    expect(result.reply, 'Nice — logged it.');
    expect(result.actions, isEmpty);
    expect(seen.url.path, '/v1/chat');
    expect(seen.headers['authorization'], 'Bearer tok');
    expect(jsonDecode(seen.body)['message'], 'hi');
  });

  test('chat decodes actions: expense negated, income positive, unknown dropped', () async {
    final service = build(MockClient((req) async => http.Response(
          jsonEncode({
            'reply': 'Done.',
            'actions': [
              {'kind': 'log_expense', 'amount': 5, 'category': 'Coffee', 'title': 'coffee'},
              {'kind': 'log_income', 'amount': 1200, 'title': 'Paycheck'},
              {'kind': 'set_daily_budget', 'dailyBudget': 60},
              {'kind': 'create_routine', 'goal': 'a push day'},
              {'kind': 'log_movement', 'durationMinutes': 45, 'calories': 240, 'title': 'Run'},
              {'kind': 'teleport', 'amount': 9}, // unknown → dropped
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        )));

    final result = await service.chat([], 'add \$5 for coffee');

    expect(result.reply, 'Done.');
    expect(result.actions, hasLength(5));
    final expense = result.actions[0] as LogEntryAction;
    expect(expense.type, EntryType.money);
    expect(expense.amount, -5); // magnitude negated to an expense
    final income = result.actions[1] as LogEntryAction;
    expect(income.amount, 1200); // income stays positive
    final budget = result.actions[2] as SetGoalAction;
    expect(budget.target, GoalTarget.dailyBudget);
    expect(budget.value, 60);
    final routine = result.actions[3] as CreateRoutineAction;
    expect(routine.goal, 'a push day');
    final move = result.actions[4] as LogEntryAction;
    expect(move.type, EntryType.move);
    expect(move.durationMinutes, 45);
    expect(move.calories, 240);
  });

  test('parse maps the response into a ParsedEntryDraft (expense negated)', () async {
    final service = build(MockClient((req) async => http.Response(
          jsonEncode({'type': 'money', 'amount': 5, 'duration': null, 'category': 'Coffee', 'title': 'Coffee', 'note': null, 'direction': 'expense'}),
          200,
        )));

    final draft = await service.parse('coffee 5');

    expect(draft.type, EntryType.money);
    expect(draft.title, 'Coffee');
    expect(draft.amount, -5); // positive money amount becomes an expense
    expect(draft.category, 'Coffee');
  });

  test('parse keeps an income amount positive', () async {
    final service = build(MockClient((req) async => http.Response(
          jsonEncode({'type': 'money', 'amount': 500, 'duration': null, 'category': null, 'title': 'Paycheck', 'note': null, 'direction': 'income'}),
          200,
        )));

    final draft = await service.parse('got paid \$500');

    expect(draft.type, EntryType.money);
    expect(draft.amount, 500); // income stays positive
  });

  test('parse treats an absent direction as an expense', () async {
    final service = build(MockClient((req) async => http.Response(
          jsonEncode({'type': 'money', 'amount': 5, 'duration': null, 'category': 'Coffee', 'title': 'Coffee', 'note': null}),
          200,
        )));

    final draft = await service.parse('coffee 5');

    expect(draft.amount, -5); // missing direction defaults to expense
  });

  test('suggestWorkout fills title from resolveRoutineTitle', () async {
    final service = build(MockClient((req) async =>
        http.Response(jsonEncode({'routineId': 'r2', 'reason': 'Legs rested.'}), 200)));

    final s = await service.suggestWorkout();

    expect(s.routineId, 'r2');
    expect(s.rationale, 'Legs rested.');
    expect(s.title, 'Legs');
  });

  test('suggestWorkout forwards another + excludeRoutineId to the context seam', () async {
    ({bool another, String? excludeRoutineId})? seen;
    final service = HttpPalService(
      baseUrl: 'https://pal.test',
      httpClient: MockClient((req) async =>
          http.Response(jsonEncode({'routineId': 'r2', 'reason': ''}), 200)),
      tokens: tokenProvider(),
      context: PalContextSource(
        chat: () async => const {},
        review: (_, _) async => const {},
        insights: (_) async => const {},
        suggest: (another, excludeRoutineId) async {
          seen = (another: another, excludeRoutineId: excludeRoutineId);
          return {'availableRoutines': const <Object>[]};
        },
        postWorkout: (_) async => const {},
        resolveRoutineTitle: (_) async => 'Legs',
      ),
    );

    await service.suggestWorkout(another: true, excludeRoutineId: 'r1');

    expect(seen, (another: true, excludeRoutineId: 'r1'));
  });

  test('insights posts to /v1/insights and maps wins/patterns', () async {
    late http.Request seen;
    final service = build(MockClient((req) async {
      seen = req;
      return http.Response(
        jsonEncode({
          'headline': 'Steady week.',
          'lede': null,
          'suggestion': 'Plan groceries Thursday.',
          'wins': [
            {'colorToken': 'move', 'title': '11-day streak', 'sub': 'Longest in 3 months'}
          ],
          'patterns': [
            {'colorToken': 'bogus', 'title': 'Fridays cost most', 'detail': 'Dining out.'}
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }));

    final result = await service.insights(InsightRange.week);

    expect(seen.url.path, '/v1/insights');
    expect(jsonDecode(seen.body)['context']['range'], 'week');
    expect(result.headline, 'Steady week.');
    expect(result.suggestion, 'Plan groceries Thursday.');
    expect(result.wins.single.colorToken, 'move');
    expect(result.wins.single.title, '11-day streak');
    // unknown colorToken is clamped to a safe default
    expect(result.patterns.single.colorToken, 'rituals');
  });

  test('insights maps correlationNarration from the response', () async {
    final service = build(MockClient((req) async => http.Response(
          jsonEncode({
            'headline': 'Steady week.',
            'correlationNarration': 'You spend less on workout days.',
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        )));

    final result = await service.insights(InsightRange.week);

    expect(result.correlationNarration, 'You spend less on workout days.');
  });

  test('insights maps absent correlationNarration as null', () async {
    final service = build(MockClient((req) async => http.Response(
          jsonEncode({'headline': 'Steady week.'}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        )));

    final result = await service.insights(InsightRange.week);

    expect(result.correlationNarration, isNull);
  });

  test('re-registers once on 401 then retries', () async {
    var calls = 0;
    final service = build(MockClient((req) async {
      calls++;
      if (calls == 1) return http.Response('unauthorized', 401);
      return http.Response(jsonEncode({'reply': 'ok'}), 200);
    }));

    final result = await service.chat([], 'hi');

    expect(result.reply, 'ok');
    expect(calls, 2);
    expect(clears, 1); // token was cleared before the retry
  });

  test('throws PalException on a non-2xx after retry', () async {
    final service = build(MockClient((req) async => http.Response('boom', 502)));
    expect(() => service.review(DateTime(2026, 6), ReviewRange.month), throwsA(isA<PalException>()));
  });

  test('insights serves a repeated identical context from cache (one network call)', () async {
    var calls = 0;
    final service = HttpPalService(
      baseUrl: 'https://pal.test',
      httpClient: MockClient((req) async {
        calls++;
        return http.Response(jsonEncode({'headline': 'Steady week.'}), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }),
      tokens: tokenProvider(),
      context: contextStub(), // fixed context map → identical key
      cache: _MapCache(),
    );

    final first = await service.insights(InsightRange.week);
    final second = await service.insights(InsightRange.week);

    expect(calls, 1); // second call hit the cache
    expect(first.headline, 'Steady week.');
    expect(second.headline, 'Steady week.');
  });

  test('day insights refetch when today\'s context changes (a new log re-notices)', () async {
    var calls = 0;
    var spent = 100;
    final service = HttpPalService(
      baseUrl: 'https://pal.test',
      httpClient: MockClient((req) async {
        calls++;
        return http.Response(jsonEncode({'headline': 'h$calls'}), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }),
      tokens: tokenProvider(),
      context: PalContextSource(
        chat: () async => const {},
        review: (_, _) async => const {},
        insights: (_) async => {'range': 'day', 'spent': spent},
        suggest: (_, _) async => const {},
        postWorkout: (_) async => const {},
        resolveRoutineTitle: (_) async => null,
      ),
      cache: _MapCache(),
    );

    final first = await service.insights(InsightRange.day);
    spent = 250; // a new log changes today's context
    final second = await service.insights(InsightRange.day);

    expect(calls, 2); // content-keyed like week/month — a changed day refetches
    expect(first.headline, 'h1');
    expect(second.headline, 'h2'); // reflects the new log, not a frozen reply
  });

  test('day insights hit the cache when today\'s context is unchanged', () async {
    var calls = 0;
    final service = HttpPalService(
      baseUrl: 'https://pal.test',
      httpClient: MockClient((req) async {
        calls++;
        return http.Response(jsonEncode({'headline': 'h$calls'}), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }),
      tokens: tokenProvider(),
      context: PalContextSource(
        chat: () async => const {},
        review: (_, _) async => const {},
        insights: (_) async => const {'range': 'day', 'spent': 100},
        suggest: (_, _) async => const {},
        postWorkout: (_) async => const {},
        resolveRoutineTitle: (_) async => null,
      ),
      cache: _MapCache(),
    );

    await service.insights(InsightRange.day);
    await service.insights(InsightRange.day);

    expect(calls, 1); // identical context dedups — no re-bill on a plain re-view
  });

  test('insights refetches when the context changes (new key misses)', () async {
    var calls = 0;
    var spent = 100;
    final service = HttpPalService(
      baseUrl: 'https://pal.test',
      httpClient: MockClient((req) async {
        calls++;
        return http.Response(jsonEncode({'headline': 'h$calls'}), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }),
      tokens: tokenProvider(),
      context: PalContextSource(
        chat: () async => const {},
        review: (_, _) async => const {},
        insights: (_) async => {'range': 'week', 'spent': spent},
        suggest: (_, _) async => const {},
        postWorkout: (_) async => const {},
        resolveRoutineTitle: (_) async => null,
      ),
      cache: _MapCache(),
    );

    await service.insights(InsightRange.week);
    spent = 250; // an edited past entry changes the context
    await service.insights(InsightRange.week);

    expect(calls, 2);
  });
}

/// In-memory [PalResponseCache] for exercising the caching path without prefs.
class _MapCache extends PalResponseCache {
  final _store = <String, String>{};
  @override
  Future<String?> get(String key) async => _store[key];
  @override
  Future<void> put(String key, String value) async => _store[key] = value;
}
