import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/repositories/weekly_plan_repository.dart';
import 'package:opal/screens/move/weekly_plan_screen.dart';
import 'package:opal/theme/app_colors.dart';

import 'support/flush_provider_timers.dart';

void main() {
  // pumpAndSettle never settles here: the screen's live Drift query stream keeps
  // the scheduler busy, so this test drives it with bounded pump()s instead.
  testWidgets(
      'Weekly Plan: tapping a rest day assigns a routine (plan re-derives)',
      (WidgetTester tester) async {
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    // One routine, no schedule assignments — every day starts as Rest.
    await db.into(db.routines).insert(RoutinesCompanion.insert(
          id: 'r1',
          name: 'Push A',
          tag: 'upper',
          estMin: const Value(45),
        ));

    final colors = AppColors.light(AppAccent.indigo);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [loopDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(useMaterial3: true, extensions: [colors]),
          home: const WeeklyPlanScreen(),
        ),
      ),
    );
    await tester.pump(); // build
    await tester.pump(const Duration(milliseconds: 100)); // initial stream emit

    // Baseline: nothing scheduled.
    expect(find.text('0 of 0 done · 0 min planned'), findsOneWidget);

    // Bring Monday's schedule row into view and open its assign sheet.
    final monday = find.text('Rest day').first;
    await tester.scrollUntilVisible(monday, 120,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(monday);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // sheet open anim

    expect(find.text('ASSIGN ROUTINE'), findsOneWidget);
    await tester.tap(find.text('Push A').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // sheet close anim

    // The assignment was upserted (Monday = weekday 1 → r1).
    final schedule = await WeeklyPlanRepository(db).getSchedule();
    expect(schedule.where((a) => a.weekday == 1).single.routineId, 'r1');

    // Let Drift's query-stream notification fire on the real event loop, then
    // pump so the re-derived plan paints.
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // The plan re-derived: Monday is no longer a rest day (6 remain) and the
    // weekly note now counts one scheduled workout.
    expect(find.text('Push A'), findsWidgets);
    expect(find.text('Rest day'), findsNWidgets(6));
    expect(find.text('0 of 1 done · 1 workout left this week.'), findsOneWidget);

    await flushProviderTimers(tester);
  });
}
