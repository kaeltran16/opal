import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:opal/controllers/providers.dart';
import 'package:opal/controllers/weekly_plan_controller.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/seed/seeder.dart';
import 'package:opal/router.dart';
import 'package:opal/services/pal/mock_pal_service.dart';
import 'package:opal/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/flush_provider_timers.dart';

/// Boots the app on the Workout tab over the full seed: the "Push Day A"
/// workout (1 PR), the "Run · Mission loop" move entry, and the 5-day plan.
Future<GoRouter> _pumpTab(
  WidgetTester tester, {
  bool noPlan = false,
  // tall so the tab's rows sit above the shell's floating bars without
  // scrolling, and wide enough for the routine picker's grid.
  Size size = const Size(800, 1600),
  double textScale = 1,
  Future<void> Function(LoopDatabase db)? seed,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final db = LoopDatabase.forTesting(NativeDatabase.memory());
  await Seeder(db).seedIfNeeded();
  await seed?.call(db);
  addTearDown(db.close);

  final router = createRouter(initialLocation: '/move');
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        loopDatabaseProvider.overrideWithValue(db),
        // fast Pal so the lead's pick resolves under pumpAndSettle.
        palServiceProvider.overrideWithValue(
          MockPalService(latency: const Duration(milliseconds: 1)),
        ),
        if (noPlan)
          weeklyPlanControllerProvider.overrideWith(
            (ref) => Stream.value(const WeeklyPlan(days: [])),
          ),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, extensions: [AppColors.light()]),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

// the pushed route's state: a push leaves the base location as is.
String _path(GoRouter router) => router.state.uri.path;

Future<void> _scrollTo(WidgetTester tester, Finder finder) =>
    tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);

void main() {
  testWidgets('Workout tab: this week, the lead, recent, tools and other activity', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pumpTab(tester);

    // the weekly goal is the seed plan's 5 planned days, shared with Weekly plan.
    expect(find.text('This week'), findsOneWidget);
    expect(find.textContaining(' of 5 workouts'), findsOneWidget);
    expect(find.text('Volume'), findsOneWidget);
    expect(find.text('Time'), findsOneWidget);
    expect(find.text('Records'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^This week: trained ')), findsOneWidget);

    // the seed logged Push Day A today, so the lead has settled.
    expect(find.textContaining('Push Day A is done.'), findsOneWidget);

    await _scrollTo(tester, find.text('Recent'));
    expect(find.bySemanticsLabel(RegExp(r'^Push Day A, Today, .*new best$')), findsOneWidget);

    await _scrollTo(tester, find.text('Generate with Pal'));
    expect(find.text('Generate with Pal'), findsOneWidget);
    expect(find.text('Generate with AI'), findsNothing);

    await _scrollTo(tester, find.text('Run · Mission loop'));
    expect(find.text('Other activity'), findsOneWidget);

    // the header's only action is the +; no Pal orb, back or overflow menu.
    expect(find.bySemanticsLabel('Open Pal'), findsNothing);
    expect(find.bySemanticsLabel('Back'), findsNothing);
    expect(find.bySemanticsLabel('More options'), findsNothing);

    semantics.dispose();
    await flushProviderTimers(tester);
  });

  testWidgets('at text scale 1.3 on a 390-wide phone nothing overflows', (tester) async {
    await _pumpTab(tester, size: const Size(390, 844), textScale: 1.3);

    // an overflow anywhere on the way down fails the test.
    await _scrollTo(tester, find.text('Run · Mission loop'));
    expect(tester.takeException(), isNull);

    await flushProviderTimers(tester);
  });

  testWidgets('the week count and See all sit at their heading row ends', (tester) async {
    await _pumpTab(tester, size: const Size(390, 844));

    Rect headingRow(String heading) =>
        tester.getRect(find.ancestor(of: find.text(heading), matching: find.byType(Row)).first);

    expect(
      tester.getTopRight(find.textContaining(' of 5 workouts')).dx,
      moreOrLessEquals(headingRow('This week').right, epsilon: 0.5),
    );

    await _scrollTo(tester, find.text('See all'));
    expect(
      tester.getTopRight(find.text('See all')).dx,
      moreOrLessEquals(headingRow('Recent').right, epsilon: 0.5),
    );

    await flushProviderTimers(tester);
  });

  testWidgets('at 1.3 and 390 wide a long session title and No weekly plan yet fit', (tester) async {
    await _pumpTab(
      tester,
      noPlan: true,
      size: const Size(390, 844),
      textScale: 1.3,
      seed: (db) => db
          .update(db.workouts)
          .write(const WorkoutsCompanion(name: Value('Upper body push with a long accessory finisher block'))),
    );

    expect(find.text('No weekly plan yet'), findsOneWidget);
    await _scrollTo(tester, find.text('See all'));
    expect(tester.takeException(), isNull);

    await flushProviderTimers(tester);
  });

  testWidgets('with no weekly plan, the week reads No weekly plan yet', (tester) async {
    await _pumpTab(tester, noPlan: true);

    expect(find.text('No weekly plan yet'), findsOneWidget);

    await flushProviderTimers(tester);
  });

  testWidgets('the + is Start a workout and opens the routine picker', (tester) async {
    final router = await _pumpTab(tester);

    await tester.tap(find.bySemanticsLabel('Start a workout'));
    await tester.pumpAndSettle();

    expect(_path(router), '/move/start');
    await flushProviderTimers(tester);
  });

  testWidgets('New routine is a tool row that opens the editor', (tester) async {
    final router = await _pumpTab(tester);

    await _scrollTo(tester, find.text('New routine'));
    await tester.tap(find.text('New routine'));
    await tester.pumpAndSettle();

    expect(_path(router), '/move/routine-editor');
    await flushProviderTimers(tester);
  });

  testWidgets('See all opens the history', (tester) async {
    final router = await _pumpTab(tester);

    await _scrollTo(tester, find.text('See all'));
    await tester.tap(find.bySemanticsLabel('See all'));
    await tester.pumpAndSettle();

    expect(_path(router), '/move/history');
    await flushProviderTimers(tester);
  });

  testWidgets('the exercise library row shows the catalog count', (tester) async {
    await _pumpTab(tester);
    final container = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
    final count = (await container.read(exercisesProvider.future)).length;

    await _scrollTo(tester, find.text('Exercise library'));
    expect(find.bySemanticsLabel('Exercise library, $count'), findsOneWidget);

    await flushProviderTimers(tester);
  });
}
