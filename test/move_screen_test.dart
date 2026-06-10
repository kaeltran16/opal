import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/seed/seeder.dart';
import 'package:opal/router.dart';
import 'package:opal/theme/app_colors.dart';
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

    final router = createRouter(initialLocation: '/move');
    final colors = AppColors.light(AppAccent.indigo);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          loopDatabaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(useMaterial3: true, extensions: [colors]),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Move hero: minutes are derived from logged move entries; energy + HR have
    // no data source post-HealthKit, so both read '—'.
    expect(find.text('WORKOUT'), findsOneWidget);
    expect(find.text('ENERGY'), findsOneWidget);
    expect(find.text('AVG HR'), findsOneWidget);
    expect(find.text('—'), findsAtLeastNWidgets(2)); // energy + HR unavailable

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
