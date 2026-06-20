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

import '../support/flush_provider_timers.dart';

/// Task 10 smoke test — boot the seeded app at /nutrition and assert the landing
/// renders past the loading state (hero + week strip + seeded meals). Mirrors the
/// canonical seeded-screen harness in move_screen_test.dart (1ms Pal so the
/// controller resolves under pumpAndSettle; flushProviderTimers as the last line).
void main() {
  testWidgets('Nutrition landing renders hero, meals, and week strip',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    await Seeder(db).seedIfNeeded();
    addTearDown(db.close);

    final router = createRouter(initialLocation: '/nutrition');
    final colors = AppColors.light(AppAccent.indigo);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          loopDatabaseProvider.overrideWithValue(db),
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

    // The hero eyebrow renders at the top once the controller emits data —
    // proves the landing left the loading state.
    expect(find.text('TODAY'), findsOneWidget);

    // Meals and the week strip sit below the fold; the scroll view culls
    // off-screen children, so scroll each into view before asserting
    // (mirrors move_screen_test).
    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
        find.text('Oats & banana'), 300, scrollable: scrollable);
    expect(find.text('Oats & banana'), findsOneWidget);

    await tester.scrollUntilVisible(
        find.text('This week'), 300, scrollable: scrollable);
    expect(find.text('This week'), findsOneWidget);

    await flushProviderTimers(tester);
  });
}
