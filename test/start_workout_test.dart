import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/seed/seeder.dart';
import 'package:opal/screens/workout/start_workout_screen.dart';
import 'package:opal/services/services.dart';
import 'package:opal/theme/app_colors.dart';

/// Records the routineId the Active Session was opened with, so the navigation
/// contract (`pushNamed('activeSession', pathParameters: {'routineId': ...})`)
/// can be asserted. The target body itself is inert.
class _Recorder {
  String? openedRoutineId;
}

/// Mounts [StartWorkoutScreen] in a minimal GoRouter + ProviderScope harness
/// with the standard overrides (db, prefs, the real MockPalService). A local
/// router keeps render assertions independent of the central wiring (the
/// orchestrator repoints `/move/start` → this screen). Inert named targets
/// `activeSession` / `exerciseLibrary` satisfy the screen's `pushNamed` calls.
Future<void> _pump(
  WidgetTester tester, {
  required SharedPreferences prefs,
  required LoopDatabase db,
  required _Recorder recorder,
  PalService? pal,
}) async {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const StartWorkoutScreen()),
      GoRoute(
        path: '/session/:routineId',
        name: 'activeSession',
        builder: (_, state) {
          recorder.openedRoutineId = state.pathParameters['routineId'];
          return const SizedBox();
        },
      ),
      GoRoute(
        path: '/library',
        name: 'exerciseLibrary',
        builder: (_, _) => const SizedBox(),
      ),
    ],
  );
  final colors = AppColors.light(AppAccent.blue);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        loopDatabaseProvider.overrideWithValue(db),
        palServiceProvider.overrideWithValue(pal ?? MockPalService()),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, extensions: [colors]),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'Start workout renders Pal pick + seeded routines and navigates on tap',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    // Seed the in-memory DB with the sample routines (Push/Pull/Leg/Upper +
    // Treadmill Intervals). Drift writes need uncontrolled async.
    await tester.runAsync(() => Seeder(db).seedIfNeeded());

    final recorder = _Recorder();
    // Deterministic Pal pick: the first canned suggestion is "Push Day A".
    await _pump(
      tester,
      prefs: prefs,
      db: db,
      recorder: recorder,
      pal: MockPalService(latency: const Duration(milliseconds: 1), seed: 1),
    );

    // Pal's-pick card renders the suggestion title + eyebrow. "Push Day A" also
    // appears as a strength card, so the title is matched among >= 1 widgets.
    expect(find.text("PAL'S PICK FOR TODAY"), findsOneWidget);
    expect(find.text('Push Day A'), findsWidgets);

    // Section headers reflect the seeded split (4 strength, 1 cardio). The
    // cardio section sits below the strength grid — scroll it into view (the
    // ListView lazily builds off-screen children).
    expect(find.text('STRENGTH · 4'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('CARDIO · 1'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('CARDIO · 1'), findsOneWidget);

    // Seeded routines appear (strength grid + cardio row).
    expect(find.text('Pull Day A'), findsOneWidget);
    expect(find.text('Leg Day'), findsOneWidget);
    expect(find.text('Treadmill Intervals'), findsOneWidget);

    // Tapping a routine card opens the Active Session with its id.
    await tester.ensureVisible(find.text('Leg Day'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leg Day'));
    await tester.pumpAndSettle();
    expect(recorder.openedRoutineId, 'seed-routine-legs');

    // Unmount and flush: disposing the autoDispose drift stream provider makes
    // drift schedule a zero-duration cleanup timer (StreamQueryStore
    // .markAsClosed); pump once so it fires before teardown's timer check.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  });
}
