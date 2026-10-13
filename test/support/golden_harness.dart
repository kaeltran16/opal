import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/app.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/seed/seeder.dart';
import 'package:opal/services/pal/mock_pal_service.dart';

import 'flush_provider_timers.dart';

/// A Monday morning, so the greeting reads "Good morning" and week-based
/// screens start on a fresh week. Seed data and every screen read `clock.now()`,
/// so pinning it here is what keeps goldens from drifting with the calendar.
final goldenClock = Clock.fixed(DateTime(2026, 9, 28, 9, 30));

/// Golden tests render with the Ahem test font, whose glyphs are taller than
/// the real SF font the layouts were tuned for, so a few fixed-height tiles
/// (e.g. SummaryTile) report a cosmetic RenderFlex overflow that would
/// otherwise fail the test. These are debug-only layout warnings, not real
/// crashes; swallow just those so the baseline can still be captured.
///
/// Must be installed from inside the test body: the test binding resets
/// FlutterError.onError when each test starts, so a setUp override is undone
/// before the first pump.
void ignoreOverflowErrors() {
  final inner = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exception.toString().contains('A RenderFlex overflowed')) {
      return;
    }
    inner?.call(details);
  };
}

/// Pins the test surface so golden geometry is deterministic.
void pinSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Boots the full seeded app (onboardingComplete=true) and settles the first
/// frame, mirroring `widget_test.dart`. [dark] persists the dark theme before
/// boot so the app starts in it. [overrides] are appended after the
/// harness's own.
///
/// The default Pal service is a zero-latency, fixed-seed mock: the stock mock
/// waits 600 ms and picks replies at random, which would leave loading states
/// or shuffled copy in the capture.
Future<void> bootApp(
  WidgetTester tester, {
  bool dark = false,
  MockPalService? palService,
  List<Override> overrides = const [],
}) async {
  ignoreOverflowErrors();
  SharedPreferences.setMockInitialValues({
    'settings.onboardingComplete': true,
    'settings.brightness': dark ? 'dark' : 'light',
  });
  final prefs = await SharedPreferences.getInstance();
  final db = LoopDatabase.forTesting(NativeDatabase.memory());
  await Seeder(db).seedIfNeeded();
  addTearDown(db.close);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        loopDatabaseProvider.overrideWithValue(db),
        palServiceProvider.overrideWithValue(
          palService ?? MockPalService(latency: Duration.zero, seed: 0),
        ),
        ...overrides,
      ],
      child: const LoopApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// The app's router, found from the first mounted [Scaffold]. Navigating by
/// path rather than by tapping the tab bar keeps goldens stable across shell
/// redesigns.
GoRouter appRouter(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Scaffold).first));

/// Registers a light and a dark golden for [name]. Each runs [body] under
/// [goldenClock], then captures the [MaterialApp] into
/// `goldens/<name>_<light|dark>.png` next to the calling test file.
void goldenTest(
  String name,
  Future<void> Function(WidgetTester t, bool dark) body,
) {
  for (final dark in [false, true]) {
    final theme = dark ? 'dark' : 'light';
    testWidgets('golden: $name ($theme)', (tester) async {
      await withClock(goldenClock, () async {
        pinSurface(tester);
        await body(tester, dark);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/${name}_$theme.png'),
        );
        await flushProviderTimers(tester);
      });
    });
  }
}
