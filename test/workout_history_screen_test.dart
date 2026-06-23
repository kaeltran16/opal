import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/seed/seeder.dart';
import 'package:opal/screens/move/workout_history_screen.dart';
import 'package:opal/theme/app_colors.dart';

void main() {
  testWidgets('WorkoutHistoryScreen renders header, range control and summary',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    await Seeder(db).seedIfNeeded();
    addTearDown(db.close);

    final colors = AppColors.light(AppAccent.blue);
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const WorkoutHistoryScreen(),
        ),
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
          theme: ThemeData(useMaterial3: true, extensions: [colors]),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Nav title + the range control's three options.
    expect(find.text('History & trends'), findsOneWidget);
    expect(find.text('8 weeks'), findsOneWidget);
    expect(find.text('All time'), findsOneWidget);

    // A summary tile label renders (above the fold).
    expect(find.text('SESSIONS'), findsOneWidget);

    // Unmount + flush so the disposed autoDispose drift stream's zero-duration
    // cleanup timer fires before teardown's pending-timer check.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  });
}
