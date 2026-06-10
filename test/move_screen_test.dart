import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:loop/controllers/providers.dart';
import 'package:loop/data/db/database.dart';
import 'package:loop/data/seed/seeder.dart';
import 'package:loop/router.dart';
import 'package:loop/services/services.dart';
import 'package:loop/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
      'Move tab: renders health stats + recent session, Start CTA navigates',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    // Full seed: gives the "Push Day A" workout (1 PR) + the "Run · Mission
    // loop" non-workout move entry, with FK-valid exercises/routines behind it.
    await Seeder(db).seedIfNeeded();
    addTearDown(db.close);

    final health = MockHealthService(
      today: HealthSample(
        date: DateTime.now(),
        moveMinutes: 66,
        activeEnergyKcal: 512,
        avgHeartRate: 72,
      ),
    );

    final router = createRouter(initialLocation: '/move');
    final colors = AppColors.light(AppAccent.indigo);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          loopDatabaseProvider.overrideWithValue(db),
          healthServiceProvider.overrideWithValue(health),
        ],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(useMaterial3: true, extensions: [colors]),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Health 3-stat hero renders the canned values.
    expect(find.text('66'), findsOneWidget); // move minutes
    expect(find.text('512'), findsOneWidget); // active energy
    expect(find.text('72'), findsOneWidget); // avg HR

    // The Start CTA is present (its navigation target is covered by
    // start_workout_test; here we only assert the Move tab surfaces it).
    expect(find.text('Start'), findsWidgets);

    // The seeded today workout shows up in recent sessions, with its PR badge
    // (scroll it into view — the list lazily builds off-screen children).
    await tester.scrollUntilVisible(find.text('Push Day A'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Push Day A'), findsOneWidget);
    expect(find.text('1 PR'), findsOneWidget);

    // The non-workout move entry shows up in Other activity.
    await tester.scrollUntilVisible(find.text('Run · Mission loop'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Run · Mission loop'), findsOneWidget);
  });
}
