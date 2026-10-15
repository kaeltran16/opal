@Tags(['scenario'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/app.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/repositories/workout_repository.dart';
import 'package:opal/models/models.dart';
import 'package:opal/router.dart';
import 'package:opal/screens/move/workout_history_screen.dart';
import 'package:opal/screens/workout/post_workout_screen.dart';
import 'package:opal/screens/workout/workout_detail_screen.dart';

import '../support/golden_harness.dart';
import 'scenario_harness.dart';

const _workoutId = 'timed-run';
const _name = 'Treadmill intervals';
const _wantMinutes = 20;
const _wantKm = 3.2;
const _wantRow = '20 min · 3.2 km';
const _sessionAgo = Duration(hours: 2);
const _movePath = '/move';

String _theme(bool dark) => dark ? 'dark' : 'light';

Workout _treadmillSession() {
  final started = goldenClock.now().subtract(_sessionAgo);
  return Workout(
    id: _workoutId,
    name: _name,
    startedAt: started,
    endedAt: started.add(const Duration(minutes: _wantMinutes)),
    sets: const [
      SetLog(
        id: 'timed-run-1',
        exerciseId: 'treadmill',
        weightKg: 0,
        reps: 0,
        done: true,
        minutes: _wantMinutes,
        distanceKm: _wantKm,
      ),
    ],
  );
}

Future<void> _seedSession(WidgetTester tester, Workout w) async {
  final container = ProviderScope.containerOf(tester.element(find.byType(LoopApp)));
  final repo = WorkoutRepository(container.read(loopDatabaseProvider));
  await tester.runAsync(() => repo.insert(w));
}

void _expectNoKgOrPercent() {
  expect(find.text('kg lifted'), findsNothing);
  expect(find.textContaining('0 kg'), findsNothing);
  expect(find.textContaining('0%'), findsNothing);
}

void main() {
  scenarioTest('timed summary', (tester, dark) async {
    await bootApp(tester, dark: dark);
    final w = _treadmillSession();

    appRouter(tester).pushNamed(AppRoute.postWorkout.name, extra: w);
    await tester.pumpAndSettle();

    expect(find.byType(PostWorkoutScreen), findsOneWidget);
    expect(find.text('$_wantMinutes'), findsOneWidget);
    expect(find.textContaining('$_wantKm km'), findsWidgets);
    expect(find.text('Muscles worked'), findsNothing);
    _expectNoKgOrPercent();
    await shot(tester, 'timed_summary_${_theme(dark)}');
  });

  scenarioTest('timed workout detail', (tester, dark) async {
    await bootApp(tester, dark: dark);
    await _seedSession(tester, _treadmillSession());

    appRouter(tester).pushNamed(AppRoute.workoutDetail.name,
        pathParameters: {'id': _workoutId});
    await tester.pumpAndSettle();

    expect(find.byType(WorkoutDetailScreen), findsOneWidget);
    expect(find.text('$_wantMinutes'), findsOneWidget);
    expect(find.textContaining('$_wantKm km'), findsWidgets);
    _expectNoKgOrPercent();
    await shot(tester, 'timed_detail_${_theme(dark)}');
  });

  scenarioTest('timed history and move rows', (tester, dark) async {
    await bootApp(tester, dark: dark);
    await _seedSession(tester, _treadmillSession());
    final router = appRouter(tester);

    router.pushNamed(AppRoute.workoutHistory.name);
    await tester.pumpAndSettle();

    expect(find.byType(WorkoutHistoryScreen), findsOneWidget);
    await tester.scrollUntilVisible(find.text(_wantRow), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text(_wantRow), findsOneWidget);
    await shot(tester, 'timed_history_row_${_theme(dark)}');

    router.go(_movePath);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text(_wantRow), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text(_wantRow), findsOneWidget);
    await shot(tester, 'timed_move_row_${_theme(dark)}');
  });
}
