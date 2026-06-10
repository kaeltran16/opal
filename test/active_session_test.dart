import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:loop/controllers/providers.dart';
import 'package:loop/data/db/database.dart';
import 'package:loop/data/seed/seeder.dart';
import 'package:loop/screens/workout/active_session_screen.dart';
import 'package:loop/services/services.dart';
import 'package:loop/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records haptic calls so the wiring (medium @10s, success @0s) is observable.
class _SpyHaptics implements HapticsService {
  int lightCount = 0;
  int mediumCount = 0;
  int successCount = 0;
  @override
  Future<void> light() async => lightCount++;
  @override
  Future<void> medium() async => mediumCount++;
  @override
  Future<void> success() async => successCount++;
}

/// Mounts [ActiveSessionScreen] inside a minimal GoRouter (so `pop` and the
/// `postWorkout` finish-navigation resolve) wrapped in a ProviderScope whose DB
/// is the seeded in-memory one. The `postWorkout` route is a stub here — U14
/// owns the real summary; this only proves the finish contract navigates.
Future<void> _pump(
  WidgetTester tester,
  LoopDatabase db,
  SharedPreferences prefs,
  HapticsService haptics,
) async {
  // Tall surface so the header + current-exercise card + up-next all lay out
  // without the ListView culling off-screen children (keeps find.text simple).
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: '/session/seed-routine-push-a',
    routes: [
      GoRoute(
        path: '/session/:routineId',
        name: 'activeSession',
        builder: (context, state) => ActiveSessionScreen(
          routineId: state.pathParameters['routineId']!,
        ),
      ),
      GoRoute(
        path: '/post',
        name: 'postWorkout',
        builder: (context, state) => const Scaffold(body: Text('Summary')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        loopDatabaseProvider.overrideWithValue(db),
        hapticsServiceProvider.overrideWithValue(haptics),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          extensions: [AppColors.light(AppAccent.indigo)],
        ),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late LoopDatabase db;
  late SharedPreferences prefs;
  late _SpyHaptics haptics;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = LoopDatabase.forTesting(NativeDatabase.memory());
    await Seeder(db).seedIfNeeded();
    haptics = _SpyHaptics();
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('renders the first exercise of the seeded Push Day A routine',
      (tester) async {
    await _pump(tester, db, prefs, haptics);

    // Header carries the routine name (uppercased eyebrow).
    expect(find.text('● PUSH DAY A'), findsOneWidget);
    // First exercise card shows Barbell Bench Press.
    expect(find.text('Barbell Bench Press'), findsOneWidget);
    // Active set offers the Complete button; rest banner is not shown yet.
    expect(find.text('Complete set'), findsOneWidget);
    expect(find.text('REST'), findsNothing);
  });

  testWidgets('completing the active set advances state and starts rest',
      (tester) async {
    await _pump(tester, db, prefs, haptics);

    // Log the first (active) set at its prefilled target.
    await tester.tap(find.text('Complete set'));
    await tester.pumpAndSettle();

    // A non-PR set fires the light cue (success is reserved for PRs).
    expect(haptics.lightCount, greaterThan(0));

    // The rest banner now shows (engine started the 120s rest).
    expect(find.text('REST'), findsOneWidget);

    // The first set rendered as a done row; a second active set remains.
    expect(find.text('SET 1'), findsWidgets);

    // Skip the rest to cancel the real periodic timer before the test ends
    // (a pending Timer.periodic would trip the binding's timer check).
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('REST'), findsNothing);
  });
}
