import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/seed/seeder.dart';
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
}
