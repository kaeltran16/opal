import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/seed/seeder.dart';
import 'package:opal/screens/mood/mood_screen.dart';
import 'package:opal/services/pal/mock_pal_service.dart';
import 'package:opal/theme/app_colors.dart';

import '../../support/flush_provider_timers.dart';

/// Wraps MoodScreen in enough scaffolding for it to render:
///   - ProviderScope with a seeded in-memory DB
///   - MaterialApp with AppColors (so context.colors works)
///   - a minimal GoRouter (for the /pal-composer route the CorrelationCard
///     trust sheet tries to navigate to)
Widget _buildApp(
    LoopDatabase db, SharedPreferences prefs, AppColors colors) {
  // stub routes required by TabHeaderScrollView (profile + pal buttons)
  // and CorrelationCard (pal-composer navigation)
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        name: 'mood',
        builder: (_, __) => const Scaffold(body: MoodScreen()),
      ),
      GoRoute(
        path: '/you',
        name: 'you',
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('you'))),
      ),
      GoRoute(
        path: '/pal',
        name: 'pal',
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('pal'))),
      ),
      GoRoute(
        path: '/pal-composer',
        name: 'palComposer',
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('pal-composer'))),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      loopDatabaseProvider.overrideWithValue(db),
      palServiceProvider.overrideWithValue(
        MockPalService(latency: const Duration(milliseconds: 1)),
      ),
    ],
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, extensions: [colors]),
      routerConfig: router,
    ),
  );
}

void main() {
  testWidgets('Mood landing renders hero eyebrow and week chart after seeding',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    await Seeder(db).seedIfNeeded();
    addTearDown(db.close);

    final colors = AppColors.light(AppAccent.indigo);

    await tester.pumpWidget(_buildApp(db, prefs, colors));
    await tester.pumpAndSettle();

    // hero eyebrow — confirms the screen exited loading state
    expect(find.text('TODAY LEANS'), findsOneWidget);

    // averaged-from line confirms the hero body rendered
    expect(find.textContaining('averaged from'), findsOneWidget);

    // scroll into the week section
    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('This week'),
      300,
      scrollable: scrollable,
    );
    expect(find.text('This week'), findsOneWidget);

    // week chart footer
    await tester.scrollUntilVisible(
      find.textContaining('Above the line'),
      300,
      scrollable: scrollable,
    );
    expect(find.textContaining('Above the line'), findsOneWidget);

    await flushProviderTimers(tester);
  });

  testWidgets('Mood landing renders check-in again row', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    await Seeder(db).seedIfNeeded();
    addTearDown(db.close);

    await tester.pumpWidget(_buildApp(db, prefs, AppColors.light(AppAccent.indigo)));
    await tester.pumpAndSettle();

    expect(find.text('Check in again'), findsOneWidget);

    await flushProviderTimers(tester);
  });
}
