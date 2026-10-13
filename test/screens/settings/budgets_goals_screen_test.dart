import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/repositories/repositories.dart';
import 'package:opal/models/models.dart';
import 'package:opal/screens/settings/budgets_goals_screen.dart';
import 'package:opal/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Goals whose load the test releases, recording what Save writes.
class _FakeGoals extends GoalsRepository {
  _FakeGoals(super.db, {this.failSave = false});

  final bool failSave;
  final loaded = Completer<Goals>();
  final saved = <Goals>[];

  @override
  Future<Goals> get() => loaded.future;

  @override
  Future<void> upsert(Goals goals) async {
    if (failSave) throw StateError('disk full');
    saved.add(goals);
  }
}

Future<_FakeGoals> _pump(WidgetTester tester, {bool failSave = false}) async {
  tester.view.physicalSize = const Size(400, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final db = LoopDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final goals = _FakeGoals(db, failSave: failSave);

  final router = GoRouter(
    initialLocation: '/host',
    routes: [
      GoRoute(
        path: '/host',
        builder: (context, state) => const Scaffold(body: Text('Host')),
        routes: [
          GoRoute(path: 'goals', builder: (context, state) => const BudgetsGoalsScreen()),
        ],
      ),
    ],
  );

  await tester.pumpWidget(ProviderScope(
    overrides: [
      loopDatabaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs),
      goalsRepositoryProvider.overrideWithValue(goals),
    ],
    child: MaterialApp.router(
      theme: ThemeData(extensions: [AppColors.light()]),
      routerConfig: router,
    ),
  ));
  await tester.pumpAndSettle();
  router.go('/host/goals');
  await tester.pumpAndSettle();
  return goals;
}

Future<void> _load(WidgetTester tester, _FakeGoals goals) async {
  goals.loaded.complete(const Goals(dailyBudget: 60, dailyMoveKcal: 400, dailyRitualTarget: 3));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Save is disabled until the goals load', (tester) async {
    final goals = await _pump(tester);

    expect(find.text('Budgets & goals'), findsOneWidget);
    expect(find.text('…'), findsOneWidget);
    expect(tester.getSemantics(find.bySemanticsLabel('Save')),
        isSemantics(label: 'Save', isButton: true, isEnabled: false));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(goals.saved, isEmpty);
    expect(find.byType(BudgetsGoalsScreen), findsOneWidget);

    await _load(tester, goals);
    expect(find.text('\$60'), findsOneWidget);
    expect(tester.getSemantics(find.bySemanticsLabel('Save')),
        isSemantics(label: 'Save', isButton: true, isEnabled: true));
  });

  testWidgets('steppers change the values', (tester) async {
    final goals = await _pump(tester);
    await _load(tester, goals);

    await tester.tap(find.bySemanticsLabel('Increase Budget'));
    await tester.pumpAndSettle();
    expect(find.text('\$65'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Decrease Workout'));
    await tester.pumpAndSettle();
    expect(find.text('350 kcal'), findsOneWidget);

    // routines derive from the routine count, so they have no steppers.
    expect(find.bySemanticsLabel('Increase Routines'), findsNothing);
  });

  testWidgets('Save persists the goals and closes the screen', (tester) async {
    final goals = await _pump(tester);
    await _load(tester, goals);

    await tester.tap(find.bySemanticsLabel('Increase Budget'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(goals.saved, hasLength(1));
    expect(goals.saved.single.dailyBudget, 65);
    expect(goals.saved.single.dailyMoveKcal, 400);
    expect(goals.saved.single.dailyRitualTarget, 3);
    expect(find.byType(BudgetsGoalsScreen), findsNothing);
    expect(find.text('Host'), findsOneWidget);
  });

  testWidgets('a failed save shows the snackbar and stays', (tester) async {
    final goals = await _pump(tester, failSave: true);
    await _load(tester, goals);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't save — try again."), findsOneWidget);
    expect(find.byType(BudgetsGoalsScreen), findsOneWidget);
  });
}
