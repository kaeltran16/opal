import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/app.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/repositories/repositories.dart';
import 'package:opal/models/models.dart';
import 'package:opal/screens/onboarding/onboarding_screen.dart';
import 'package:opal/screens/today/today_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/flush_provider_timers.dart';

/// Boots [LoopApp] with an in-memory DB + mock prefs. [onboardingComplete]
/// seeds the gate flag; [failGoals] makes saving the goals throw.
Future<({LoopDatabase db, SharedPreferences prefs})> _pumpApp(
  WidgetTester tester, {
  required bool onboardingComplete,
  bool failGoals = false,
}) async {
  // the board's phone; the default 800x600 window scrolls the controls under
  // the pill.
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({
    if (onboardingComplete) 'settings.onboardingComplete': true,
  });
  final prefs = await SharedPreferences.getInstance();
  final db = LoopDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        loopDatabaseProvider.overrideWithValue(db),
        if (failGoals) goalsRepositoryProvider.overrideWithValue(_FailingGoals(db)),
      ],
      child: const LoopApp(),
    ),
  );
  await tester.pumpAndSettle();
  return (db: db, prefs: prefs);
}

class _FailingGoals extends GoalsRepository {
  _FailingGoals(super.db);

  @override
  Future<void> upsert(Goals goals) async => throw StateError('disk full');
}

Future<void> _tapAndSettle(WidgetTester tester, String text) async {
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

/// Walks from Welcome to the routines step with the defaults.
Future<void> _toRoutines(WidgetTester tester) async {
  await _tapAndSettle(tester, 'Get started');
  await _tapAndSettle(tester, 'Continue');
  await _tapAndSettle(tester, 'Continue');
  expect(find.text('Choose your routines'), findsOneWidget);
}

void main() {
  testWidgets('with onboardingComplete=false the app shows onboarding',
      (tester) async {
    await _pumpApp(tester, onboardingComplete: false);

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(TodayScreen), findsNothing);
    expect(find.text('Welcome to Opal'), findsOneWidget);
    expect(find.text('Pal'), findsOneWidget);
    expect(find.text('1 of 4'), findsOneWidget);
  });

  testWidgets('with onboardingComplete=true the gate redirects to Today',
      (tester) async {
    await _pumpApp(tester, onboardingComplete: true);

    expect(find.byType(TodayScreen), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);

    await flushProviderTimers(tester);
  });

  testWidgets(
      'completing the flow writes Goals + rituals and flips the flag',
      (tester) async {
    final h = await _pumpApp(tester, onboardingComplete: false);

    // Step 1 (Welcome) — enter a name, then Get started.
    await tester.enterText(find.byType(TextField), 'Mira');
    await _tapAndSettle(tester, 'Get started');

    // Step 2 (Budget) — pick $120, then Continue.
    expect(find.text('Set a daily budget'), findsOneWidget);
    expect(find.text('2 of 4'), findsOneWidget);
    await _tapAndSettle(tester, '\$120');
    await _tapAndSettle(tester, 'Continue');

    // Step 3 (Move goal) — pick 700 kcal, then Continue.
    expect(find.text('Pick a workout goal'), findsOneWidget);
    await _tapAndSettle(tester, '700 kcal');
    await _tapAndSettle(tester, 'Continue');

    // Step 4 (Routines) — defaults pre-selected; finish.
    expect(find.text('Choose your routines'), findsOneWidget);
    await _tapAndSettle(tester, 'Start tracking');

    expect(find.byType(TodayScreen), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);

    expect(SettingsRepository(h.prefs).onboardingComplete, isTrue);
    expect(SettingsRepository(h.prefs).displayName, 'Mira');

    final goals = await GoalsRepository(h.db).get();
    expect(goals.dailyBudget, 120);
    expect(goals.dailyMoveKcal, 700);
    expect(goals.dailyRitualTarget, 5);

    final routines = await RitualRepository(h.db).getAll();
    expect(routines.length, 3);
    expect(routines.map((r) => r.name).toSet(), contains('Morning'));
    expect(routines.first.steps, isNotEmpty);

    await flushProviderTimers(tester);
  });

  testWidgets('with every routine off Start tracking is disabled',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final h = await _pumpApp(tester, onboardingComplete: false);
    await _toRoutines(tester);
    expect(find.text('Pick at least one routine to start.'), findsNothing);

    for (final name in ['Morning', 'Midday reset', 'Evening wind-down']) {
      await _tapAndSettle(tester, name);
    }

    expect(find.text('Pick at least one routine to start.'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Start tracking')),
      isSemantics(isButton: true, hasEnabledState: true, isEnabled: false),
    );

    await _tapAndSettle(tester, 'Start tracking');
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(SettingsRepository(h.prefs).onboardingComplete, isFalse);
    semantics.dispose();
  });

  testWidgets('a failed save shows calm copy, stays put, and a toggle clears it',
      (tester) async {
    final h = await _pumpApp(tester, onboardingComplete: false, failGoals: true);
    await _toRoutines(tester);

    await _tapAndSettle(tester, 'Start tracking');

    expect(find.text("Couldn't save. Try again."), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(TodayScreen), findsNothing);
    expect(SettingsRepository(h.prefs).onboardingComplete, isFalse);

    await _tapAndSettle(tester, 'Midday reset');
    expect(find.text("Couldn't save. Try again."), findsNothing);
  });

  testWidgets('Skip from step 2 finishes with the defaults', (tester) async {
    final h = await _pumpApp(tester, onboardingComplete: false);
    await _tapAndSettle(tester, 'Get started');
    expect(find.text('Set a daily budget'), findsOneWidget);

    await _tapAndSettle(tester, 'Skip');

    expect(find.byType(TodayScreen), findsOneWidget);
    expect(SettingsRepository(h.prefs).onboardingComplete, isTrue);
    final goals = await GoalsRepository(h.db).get();
    expect(goals.dailyBudget, 85);
    expect(goals.dailyMoveKcal, 500);
    expect(goals.dailyRitualTarget, 5);
    expect((await RitualRepository(h.db).getAll()).length, 3);

    await flushProviderTimers(tester);
  });
}
