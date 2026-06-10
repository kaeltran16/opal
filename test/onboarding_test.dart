import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/app.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/repositories/repositories.dart';
import 'package:opal/screens/onboarding/onboarding_screen.dart';
import 'package:opal/screens/today/today_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Boots [LoopApp] with an in-memory DB + mock prefs. [onboardingComplete]
/// seeds the gate flag.
Future<({LoopDatabase db, SharedPreferences prefs})> _pumpApp(
  WidgetTester tester, {
  required bool onboardingComplete,
}) async {
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
      ],
      child: const LoopApp(),
    ),
  );
  await tester.pumpAndSettle();
  return (db: db, prefs: prefs);
}

void main() {
  testWidgets('with onboardingComplete=false the app shows onboarding',
      (tester) async {
    await _pumpApp(tester, onboardingComplete: false);

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(TodayScreen), findsNothing);
    expect(find.text('Welcome to\nOpal'), findsOneWidget);
  });

  testWidgets('with onboardingComplete=true the gate redirects to Today',
      (tester) async {
    await _pumpApp(tester, onboardingComplete: true);

    expect(find.byType(TodayScreen), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
  });

  testWidgets(
      'completing the flow writes Goals + rituals and flips the flag',
      (tester) async {
    final h = await _pumpApp(tester, onboardingComplete: false);

    // Step 1 (Welcome) → Get started.
    expect(find.byType(OnboardingScreen), findsOneWidget);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    // Step 2 (Budget) — pick $120, then Continue.
    expect(find.text('Set a daily\nbudget'), findsOneWidget);
    await tester.tap(find.text('\$120'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Step 3 (Move goal) — pick 45 min, then Continue.
    expect(find.text('Pick a\nmove goal'), findsOneWidget);
    await tester.tap(find.text('45 min'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Step 4 (Rituals) — defaults pre-selected; finish.
    expect(find.text('Choose your\nrituals'), findsOneWidget);
    await tester.tap(find.text('Start tracking'));
    await tester.pumpAndSettle();

    // Landed on Today.
    expect(find.byType(TodayScreen), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);

    // Flag flipped.
    expect(SettingsRepository(h.prefs).onboardingComplete, isTrue);

    // Goals persisted with the chosen budget/move goal + ritual target 5.
    final goals = await GoalsRepository(h.db).get();
    expect(goals.dailyBudget, 120);
    expect(goals.dailyMoveMinutes, 45);
    expect(goals.dailyRitualTarget, 5);

    // The three default time-of-day ritual routines were seeded.
    final routines = await RitualRepository(h.db).getAll();
    expect(routines.length, 3);
    final names = routines.map((r) => r.name).toSet();
    expect(names, contains('Morning'));
    expect(routines.first.steps, isNotEmpty);
  });
}
