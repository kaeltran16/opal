import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opal/models/models.dart';
import 'package:opal/services/pal/http_pal_service.dart';
import 'package:opal/services/pal/pal_context_builder.dart';

/// In-memory [PalResponseCache] so a test can observe hits/misses without prefs.
class _MemCache extends PalResponseCache {
  final Map<String, String> store = {};

  @override
  Future<String?> get(String key) async => store[key];

  @override
  Future<void> put(String key, String value) async => store[key] = value;
}

const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

void main() {
  late List<Workout> workouts;
  late List<Routine> routines;
  late DateTime now;
  late List<bool> posted; // the 'another' flag of each request that reached the proxy
  late HttpPalService svc;

  setUp(() {
    workouts = [
      Workout(id: 'w1', routineId: 'push', name: 'Push', startedAt: DateTime(2026, 10, 13, 18), sets: const []),
    ];
    routines = [
      Routine(id: 'push', name: 'Push', tag: RoutineTag.fromWire('custom')),
      Routine(id: 'legs', name: 'Legs', tag: RoutineTag.fromWire('custom')),
    ];
    now = DateTime(2026, 10, 14, 9);
    posted = [];
    svc = HttpPalService(
      baseUrl: 'https://pal.test',
      httpClient: MockClient((req) async {
        final another = jsonDecode(req.body)['another'] as bool;
        posted.add(another);
        return http.Response(
            jsonEncode({'routineId': another ? 'push' : 'legs', 'reason': 'r${posted.length}'}), 200);
      }),
      tokens: TokenProvider(token: () async => 't', clear: () async {}),
      cache: _MemCache(),
      // mirrors the real seam: the context is rebuilt on every call from what
      // is logged now, so a change in state is a change in the key.
      context: PalContextSource(
        chat: () async => const {},
        review: (_, _) async => const {},
        insights: (_) async => const {},
        suggest: (_, excludeRoutineId) async => buildSuggestContext(
          recentWorkouts: workouts,
          dayOfWeek: _weekdays[now.weekday - 1],
          availableRoutines: routines.where((r) => r.id != excludeRoutineId).toList(),
          exercisesById: const {},
          now: now,
        ),
        postWorkout: (_) async => const {},
        resolveRoutineTitle: (id) async => routines.where((r) => r.id == id).firstOrNull?.name,
      ),
    );
  });

  test('opening the pick twice the same day makes one call', () async {
    final first = await svc.suggestWorkout();
    now = DateTime(2026, 10, 14, 21);
    final second = await svc.suggestWorkout();

    expect(posted, [false]);
    expect(second.routineId, first.routineId);
    expect(second.rationale, first.rationale);
    expect(second.title, 'Legs');
  });

  test('a logged workout refetches the pick', () async {
    await svc.suggestWorkout();
    workouts = [
      Workout(id: 'w2', routineId: 'legs', name: 'Legs', startedAt: DateTime(2026, 10, 14, 8), sets: const []),
      ...workouts,
    ];
    await svc.suggestWorkout();

    expect(posted, [false, false]);
  });

  test('a new day refetches the pick', () async {
    await svc.suggestWorkout();
    now = DateTime(2026, 10, 15, 7);
    await svc.suggestWorkout();

    expect(posted, [false, false]);
  });

  test('a new routine refetches the pick', () async {
    await svc.suggestWorkout();
    routines = [...routines, Routine(id: 'pull', name: 'Pull', tag: RoutineTag.fromWire('custom'))];
    await svc.suggestWorkout();

    expect(posted, [false, false]);
  });

  test('another always calls and leaves the cached default in place', () async {
    final pick = await svc.suggestWorkout();
    final a1 = await svc.suggestWorkout(another: true, excludeRoutineId: pick.routineId);
    final a2 = await svc.suggestWorkout(another: true, excludeRoutineId: pick.routineId);
    final again = await svc.suggestWorkout();

    expect(posted, [false, true, true]);
    expect(a1.rationale, isNot(a2.rationale));
    expect(again.routineId, pick.routineId);
    expect(again.rationale, pick.rationale);
  });

  test('a failed pick is not cached', () async {
    var fail = true;
    final failing = HttpPalService(
      baseUrl: 'https://pal.test',
      httpClient: MockClient((req) async {
        posted.add(false);
        return fail
            ? http.Response('boom', 500)
            : http.Response(jsonEncode({'routineId': 'legs', 'reason': 'ok'}), 200);
      }),
      tokens: TokenProvider(token: () async => 't', clear: () async {}),
      cache: _MemCache(),
      context: svc.context,
    );

    await expectLater(failing.suggestWorkout(), throwsA(isA<PalException>()));
    fail = false;
    final pick = await failing.suggestWorkout();

    expect(posted, [false, false]);
    expect(pick.rationale, 'ok');
  });
}
