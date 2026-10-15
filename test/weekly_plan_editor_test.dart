import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:opal/controllers/providers.dart';
import 'package:opal/controllers/workout_session_controller.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/repositories/weekly_plan_repository.dart';
import 'package:opal/screens/move/weekly_plan_screen.dart';
import 'package:opal/theme/app_colors.dart';
import 'package:opal/widgets/pal_lead.dart';

import 'support/flush_provider_timers.dart';
import 'support/semantics_blocks.dart';

// a wednesday, so today is weekday 3.
final _wednesday = Clock.fixed(DateTime(2026, 10, 14, 10));

Future<LoopDatabase> _db() async {
  final db = LoopDatabase.forTesting(NativeDatabase.memory());
  await db.into(db.routines).insert(RoutinesCompanion.insert(
        id: 'r1',
        name: 'Push A',
        tag: 'upper',
        estMin: const Value(45),
      ));
  return db;
}

Future<void> _pump(WidgetTester tester, LoopDatabase db) async {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const WeeklyPlanScreen()),
      GoRoute(
        path: '/session/:routineId',
        name: 'activeSession',
        builder: (_, state) =>
            Text('session ${state.pathParameters['routineId']}'),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [loopDatabaseProvider.overrideWithValue(db)],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, extensions: [AppColors.light()]),
        routerConfig: router,
      ),
    ),
  );
  await tester.pump(); // build
  await tester.pump(const Duration(milliseconds: 100)); // initial stream emit
}

/// Lets Drift's query-stream notification fire on the real event loop, then
/// pumps so the re-derived plan paints.
Future<void> _settleStream(WidgetTester tester) async {
  await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

/// Opens the assign sheet from Monday's schedule row.
Future<void> _openMonday(WidgetTester tester) async {
  final monday = find.text('Mon');
  await tester.scrollUntilVisible(monday, 120,
      scrollable: find.byType(Scrollable).first);
  await tester.tap(monday);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400)); // sheet open anim
  expect(find.text('Assign routine'), findsOneWidget);
}

void _planTest(String name, Future<void> Function(WidgetTester tester) body) {
  // pumpAndSettle never settles here: the screen's live Drift query stream
  // keeps the scheduler busy, so these tests drive it with bounded pump()s.
  testWidgets(name, (tester) async {
    await withClock(_wednesday, () async {
      try {
        await body(tester);
      } finally {
        await flushProviderTimers(tester);
      }
    });
  });
}

void main() {
  _planTest('a schedule row opens the assign sheet, which assigns a routine',
      (tester) async {
    final db = await _db();
    addTearDown(db.close);
    await _pump(tester, db);

    // nothing scheduled: every row reads Rest, and today is a rest day with
    // its line and no card.
    expect(find.text('0 of 0 done · 0 min planned'), findsOneWidget);
    expect(find.text('Rest'), findsNWidgets(7));
    expect(find.text('Rest day'), findsOneWidget);
    expect(find.byType(ActionCard), findsNothing);

    await _openMonday(tester);
    await tester.tap(find.text('Push A').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // sheet close anim

    final schedule = await WeeklyPlanRepository(db).getSchedule();
    expect(schedule.where((a) => a.weekday == 1).single.routineId, 'r1');

    await _settleStream(tester);
    expect(find.text('Push A'), findsOneWidget);
    expect(find.text('45 min'), findsOneWidget);
    expect(find.text('Rest'), findsNWidgets(6));
    expect(find.text('0 of 1 done · 1 workout left this week.'), findsOneWidget);
  });

  _planTest('Rest day in the assign sheet makes the day a rest day',
      (tester) async {
    final db = await _db();
    addTearDown(db.close);
    await WeeklyPlanRepository(db).upsert(1, 'r1');
    await _pump(tester, db);
    await _settleStream(tester);
    expect(find.text('Rest'), findsNWidgets(6));

    await _openMonday(tester);
    // the sheet marks the current assignment.
    expect(find.text('Current'), findsOneWidget);
    await tester.tap(find.text('Rest day').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // sheet close anim

    final schedule = await WeeklyPlanRepository(db).getSchedule();
    expect(schedule.where((a) => a.weekday == 1).single.routineId, isNull);

    await _settleStream(tester);
    expect(find.text('Rest'), findsNWidgets(7));
  });

  _planTest('a day in the week strip opens its assign sheet', (tester) async {
    final db = await _db();
    addTearDown(db.close);
    await _pump(tester, db);

    await tester.tap(find.text('M'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // sheet open anim
    expect(find.text('Assign routine'), findsOneWidget);
  });

  _planTest('a screen reader reaches today\'s heading, its button and Schedule on their own',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final db = await _db();
    addTearDown(db.close);
    await WeeklyPlanRepository(db).upsert(DateTime.wednesday, 'r1');
    await _pump(tester, db);
    await _settleStream(tester);

    expectOwnSemanticsNodes(tester, [
      'Push A',
      'Start workout',
      'Schedule',
      'Tap a day to set or change its routine.',
    ]);
    semantics.dispose();
  });

  _planTest('Start workout on today opens the session through the launcher',
      (tester) async {
    final db = await _db();
    addTearDown(db.close);
    await WeeklyPlanRepository(db).upsert(DateTime.wednesday, 'r1');
    await _pump(tester, db);
    await _settleStream(tester);

    expect(find.byType(ActionCard), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Rest day'), findsNothing);

    await tester.tap(find.text('Start workout'));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // push anim

    expect(find.text('session r1'), findsOneWidget);
    final container =
        ProviderScope.containerOf(tester.element(find.text('session r1')));
    expect(container.read(runningSessionProvider), 'r1');
  });
}
