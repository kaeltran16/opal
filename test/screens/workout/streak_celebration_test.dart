import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/seed/seeder.dart';
import 'package:opal/screens/reflect/streak_celebration_screen.dart';
import 'package:opal/theme/app_colors.dart';
import 'package:opal/widgets/controls.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mounts the celebration pushed over a stub home (or alone, so Keep going
/// has nothing to pop) with the seeded in-memory DB.
Future<void> _pump(WidgetTester tester, {bool overHome = true}) async {
  tester.view.physicalSize = const Size(390, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final db = LoopDatabase.forTesting(NativeDatabase.memory());
  await Seeder(db).seedIfNeeded();
  addTearDown(db.close);

  final router = GoRouter(
    initialLocation: overHome ? '/' : '/streak',
    routes: [
      GoRoute(path: '/', builder: (c, s) => const Scaffold(body: Text('Home'))),
      GoRoute(path: '/today', builder: (c, s) => const Scaffold(body: Text('Today'))),
      GoRoute(path: '/streak', builder: (c, s) => const StreakCelebrationScreen()),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        loopDatabaseProvider.overrideWithValue(db),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, extensions: [AppColors.light()]),
        routerConfig: router,
      ),
    ),
  );
  if (overHome) router.push('/streak');
  await tester.pumpAndSettle();
}

// unmount, then drain the autoDispose stream providers' cleanup timers.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('the streak number is light display type under Workout streak',
      (tester) async {
    await _pump(tester);

    expect(find.text('Workout streak'), findsOneWidget);
    final number = find.byWidgetPredicate((w) =>
        w is Text && w.data != null && RegExp(r'^\d+$').hasMatch(w.data!));
    expect(number, findsOneWidget);
    final style = tester.widget<Text>(number).style!;
    expect(style.fontSize, 64);
    expect(style.fontWeight, FontWeight.w300);
    expect(tester.takeException(), isNull);

    await _unmount(tester);
  });

  testWidgets('there is exactly one primary pill, Keep going', (tester) async {
    await _pump(tester);

    final primaries = find.byWidgetPredicate((w) => w is PillButton && w.primary);
    expect(primaries, findsOneWidget);
    expect(tester.widget<PillButton>(primaries).label, 'Keep going');

    await _unmount(tester);
  });

  testWidgets('Keep going closes the celebration', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Keep going'));
    await tester.pumpAndSettle();
    expect(find.byType(StreakCelebrationScreen), findsNothing);
    expect(find.text('Home'), findsOneWidget);

    await _unmount(tester);
  });

  testWidgets('Keep going with nothing to pop goes to Today', (tester) async {
    await _pump(tester, overHome: false);

    await tester.tap(find.text('Keep going'));
    await tester.pumpAndSettle();
    expect(find.text('Today'), findsOneWidget);

    await _unmount(tester);
  });
}
