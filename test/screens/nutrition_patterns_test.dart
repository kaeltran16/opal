import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/repositories/repositories.dart';
import 'package:opal/data/seed/seeder.dart';
import 'package:opal/models/models.dart';
import 'package:opal/router.dart';
import 'package:opal/services/pal/mock_pal_service.dart';
import 'package:opal/theme/app_colors.dart';
import 'package:opal/theme/app_text.dart';

import '../support/flush_provider_timers.dart';

/// Boots the full seeded app starting at /nutrition/patterns and asserts the
/// connections screen title + at least one pattern card title.
void main() {
  testWidgets(
      'Connections screen shows title and at least one pattern card',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'settings.onboardingComplete': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    await Seeder(db).seedIfNeeded();
    addTearDown(db.close);

    // Build the router starting directly at the patterns screen so we don't
    // need programmatic navigation from inside the test.
    final router = createRouter(
      initialLocation: '/nutrition/patterns',
      isOnboardingComplete: () => true,
    );

    final colors = AppColors.light(AppAccent.blue);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          loopDatabaseProvider.overrideWithValue(db),
          palServiceProvider.overrideWithValue(
              MockPalService(latency: const Duration(milliseconds: 1))),
        ],
        child: MaterialApp.router(
          theme: ThemeData(
            useMaterial3: true,
            extensions: [colors],
          ),
          routerConfig: router,
          builder: (context, child) => DefaultTextStyle(
            style: AppFonts.sf(size: 17, color: colors.ink, letterSpacing: -0.43),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The screen header should be visible.
    expect(find.text('Connections'), findsWidgets);

    // The controller always returns at least 4 patterns (three are static
    // qualitative patterns; the first is computed from real data but always
    // present). Assert at least one title is rendered.
    expect(
      find.textContaining(RegExp(
          r'Takeout vs\. home|Fuel around workouts|Mornings set the tone|Your steady rhythm')),
      findsWidgets,
    );

    await flushProviderTimers(tester);
  });

  testWidgets(
      'Connections screen renders CorrelationCard when Move×Nutrition correlation clears the bar',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'settings.onboardingComplete': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    // Seed 24 days: on workout days (every other day) calories are high (~700 cal);
    // on rest days calories are low (~250 cal). This creates a strong
    // Move×Nutrition correlation (|r| >> 0.4, n=24 >> 21).
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final entryRepo = EntryRepository(db);
    final nutritionRepo = NutritionRepository(db);

    for (var i = 0; i < 24; i++) {
      final day = today.subtract(Duration(days: 24 - i));
      final isWorkoutDay = i.isEven;

      if (isWorkoutDay) {
        // move entry with substantial calories so the series is non-trivial
        await entryRepo.insert(Entry(
          id: '',
          timestamp: day.add(const Duration(hours: 7)),
          type: EntryType.move,
          title: 'Run',
          calories: 400,
          duration: 40,
          source: EntrySource.manual,
        ));
      }

      // nutrition meal: high cal on workout days, low cal on rest days
      final cal = isWorkoutDay
          ? const IntRange(600, 800)   // ~700 cal midpoint
          : const IntRange(200, 300);  // ~250 cal midpoint
      await nutritionRepo.insert(NutritionMeal(
        id: '',
        timestamp: day.add(const Duration(hours: 12)),
        slot: 'Lunch',
        name: 'Test meal',
        source: NutritionSource.manual,
        icon: 'fork.knife',
        confidence: NutritionConfidence.med,
        cal: cal,
        macros: macrosFromCal(cal),
      ));
    }

    final router = createRouter(
      initialLocation: '/nutrition/patterns',
      isOnboardingComplete: () => true,
    );

    final colors = AppColors.light(AppAccent.blue);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          loopDatabaseProvider.overrideWithValue(db),
          palServiceProvider.overrideWithValue(
              MockPalService(latency: const Duration(milliseconds: 1))),
        ],
        child: MaterialApp.router(
          theme: ThemeData(
            useMaterial3: true,
            extensions: [colors],
          ),
          routerConfig: router,
          builder: (context, child) => DefaultTextStyle(
            style: AppFonts.sf(size: 17, color: colors.ink, letterSpacing: -0.43),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // CorrelationCard shows the PAL NOTICED eyebrow + tap subline
    expect(find.text('PAL NOTICED'), findsWidgets);
    expect(find.text('Tap to see the numbers.'), findsWidgets);

    await flushProviderTimers(tester);
  });
}
