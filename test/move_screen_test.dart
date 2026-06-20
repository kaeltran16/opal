import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/seed/seeder.dart';
import 'package:opal/router.dart';
import 'package:opal/services/pal/mock_pal_service.dart';
import 'package:opal/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/flush_provider_timers.dart';

void main() {
  testWidgets(
      'Move tab: renders this-week hero + recent session, Start CTA navigates',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    // Full seed: gives the "Push Day A" workout (1 PR) + the "Run · Mission
    // loop" non-workout move entry, with FK-valid exercises/routines behind it.
    await Seeder(db).seedIfNeeded();
    addTearDown(db.close);

    final router = createRouter(initialLocation: '/move');
    final colors = AppColors.light(AppAccent.indigo);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          loopDatabaseProvider.overrideWithValue(db),
          // Fast Pal so the Start CTA's suggestWorkout() resolves under
          // pumpAndSettle (the CTA now shows the shared Pal pick).
          palServiceProvider.overrideWithValue(
              MockPalService(latency: const Duration(milliseconds: 1))),
        ],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(useMaterial3: true, extensions: [colors]),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Move hero: redesigned "This week" hero with workouts-vs-goal headline and
    // a Volume / Time / Records stat row (no HealthKit calorie/HR content).
    expect(find.text('THIS WEEK'), findsOneWidget);
    // weekly goal = the seed plan's 5 planned (non-rest) days, shared with the
    // Weekly Plan screen (not the old hardcoded 4).
    expect(find.text('/ 5 workouts'), findsOneWidget);
    expect(find.text('VOLUME'), findsOneWidget);
    expect(find.text('TIME'), findsOneWidget);
    expect(find.text('RECORDS'), findsOneWidget);
    expect(find.text('ENERGY'), findsNothing);
    expect(find.text('AVG HR'), findsNothing);

    // The Start CTA is present (its navigation target is covered by
    // start_workout_test; here we only assert the Move tab surfaces it).
    expect(find.text('Start'), findsWidgets);

    // The seeded today workout shows up in recent sessions, with its PR badge
    // (scroll it into view — the list lazily builds off-screen children).
    // "Push Day A" also appears in the Start CTA (it's the shared Pal pick), so
    // expect it more than once.
    await tester.scrollUntilVisible(find.text('Push Day A'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Push Day A'), findsWidgets);
    // "1 PR" appears on the session card's PR badge and the hero Records stat.
    expect(find.text('1 PR'), findsWidgets);

    // The non-workout move entry shows up in Other activity.
    await tester.scrollUntilVisible(find.text('Run · Mission loop'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Run · Mission loop'), findsOneWidget);

    await flushProviderTimers(tester);
  });
}
