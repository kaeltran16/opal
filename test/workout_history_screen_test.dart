import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/repositories/workout_repository.dart';
import 'package:opal/models/models.dart';
import 'package:opal/screens/move/workout_history_screen.dart';
import 'package:opal/theme/app_colors.dart';
import 'package:opal/widgets/stat_row.dart';

import 'support/flush_provider_timers.dart';
import 'support/semantics_blocks.dart';

final _now = DateTime(2026, 10, 14, 10);
final _colors = AppColors.light();

Workout _workout(String id, String name, Duration ago, {double kg = 0}) {
  final started = _now.subtract(ago);
  return Workout(
    id: id,
    name: name,
    startedAt: started,
    endedAt: started.add(const Duration(minutes: 45)),
    sets: [
      if (kg > 0)
        SetLog(id: '$id-s', exerciseId: 'bench', weightKg: kg, reps: 5, done: true, isPR: true),
    ],
  );
}

Future<void> _pump(WidgetTester tester, List<Workout> workouts,
    {double textScale = 1}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final db = LoopDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  await db.into(db.exercises).insert(ExercisesCompanion.insert(
      id: 'bench', name: 'Bench', group: 'Push', muscle: 'Chest', icon: 'dumbbell'));
  final repo = WorkoutRepository(db);
  for (final w in workouts) {
    await repo.insert(w);
  }

  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const WorkoutHistoryScreen()),
      GoRoute(
        path: '/workout/:id',
        name: 'workoutDetail',
        builder: (_, state) => Text('detail ${state.pathParameters['id']}'),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        loopDatabaseProvider.overrideWithValue(db),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, extensions: [_colors]),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _stat(String value) => find.descendant(
    of: find.byType(StatRow).first, matching: find.text(value));

void _historyTest(
    String name, Future<void> Function(WidgetTester tester) body) {
  testWidgets(name, (tester) async {
    await withClock(Clock.fixed(_now), () async {
      try {
        await body(tester);
      } finally {
        await flushProviderTimers(tester);
      }
    });
  });
}

void main() {
  // two sessions inside 8 weeks (recent half heavier than the prior half) and
  // one older than 6 months.
  final workouts = [
    _workout('w1', 'Push A', const Duration(days: 2), kg: 100),
    _workout('w2', 'Pull A', const Duration(days: 42), kg: 80),
    _workout('w3', 'Legs A', const Duration(days: 280)),
  ];

  _historyTest('renders the header, range control and summary', (tester) async {
    await _pump(tester, workouts);

    expect(find.text('History and trends'), findsOneWidget);
    expect(find.text('8 weeks'), findsOneWidget);
    expect(find.text('All time'), findsOneWidget);
    expect(find.text('Sessions'), findsOneWidget);
  });

  _historyTest('the subtitle follows the selected range', (tester) async {
    await _pump(tester, workouts);
    expect(find.text('Sessions in the last 8 weeks'), findsOneWidget);

    await tester.tap(find.text('6 months'));
    await tester.pumpAndSettle();
    expect(find.text('Sessions in the last 6 months'), findsOneWidget);

    await tester.tap(find.text('All time'));
    await tester.pumpAndSettle();
    expect(find.text('All sessions, all time'), findsOneWidget);
  });

  _historyTest('switching the range updates the stats', (tester) async {
    await _pump(tester, workouts);
    expect(_stat('2'), findsOneWidget);

    await tester.tap(find.text('All time'));
    await tester.pumpAndSettle();
    expect(_stat('3'), findsOneWidget);
    expect(_stat('2'), findsNothing);
  });

  _historyTest('the trend sentence carries no state colour', (tester) async {
    await _pump(tester, workouts);

    final trend = find.text('Up 25% on the previous 4 weeks');
    expect(trend, findsOneWidget);
    expect(tester.widget<Text>(trend).style!.color, _colors.ink3);
  });

  _historyTest('a screen reader reaches each heading and session row on its own',
      (tester) async {
    final semantics = tester.ensureSemantics();
    // one session in range: a lone row is where the heading folded into it
    await _pump(tester, [workouts.first]);
    await tester.scrollUntilVisible(find.text('Push A'), 200,
        scrollable: find.byType(Scrollable).first);

    expectOwnSemanticsNodes(tester, [
      'Volume trend',
      '0.5 t total',
      'Weekly balance',
      'No pull or legs sets in this range. A pull day would even things out.',
      'Personal records · 1',
      'All sessions · 1',
      'Push A',
    ]);
    semantics.dispose();
  });

  _historyTest('a session row opens its detail', (tester) async {
    await _pump(tester, workouts);

    final row = find.text('Pull A');
    await tester.scrollUntilVisible(row, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.text('detail w2'), findsOneWidget);
  });

  _historyTest('a range with no sessions shows the empty line', (tester) async {
    await _pump(tester, [workouts.last]);

    expect(find.text('No sessions in this range.'), findsOneWidget);
    expect(find.byType(StatRow), findsNothing);

    await tester.tap(find.text('All time'));
    await tester.pumpAndSettle();
    expect(find.text('No sessions in this range.'), findsNothing);
    await tester.scrollUntilVisible(find.text('Legs A'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Legs A'), findsOneWidget);
  });

  _historyTest('nothing overflows at text scale 1.3 on a 390 wide screen',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(tester, workouts, textScale: 1.3);

    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('Pull A'), 200, scrollable: list);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(find.text('All time'), -200, scrollable: list);
    await tester.tap(find.text('All time'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Legs A'), 200, scrollable: list);
    expect(tester.takeException(), isNull);
  });
}
