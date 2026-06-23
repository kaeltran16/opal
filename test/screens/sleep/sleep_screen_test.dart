import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:opal/analysis/correlations.dart';
import 'package:opal/controllers/correlations_controller.dart';
import 'package:opal/controllers/sleep_controller.dart';
import 'package:opal/models/models.dart';
import 'package:opal/screens/sleep/sleep_screen.dart';
import 'package:opal/theme/app_colors.dart';

// ─── Fixture data ─────────────────────────────────────────────────────────────

final _lastNight = SleepNight(
  id: 'test-night-1',
  night: DateTime(2026, 6, 23),
  asleepMinutes: 450, // 7h 30m
  inBedMinutes: 480,
  bedtime: '23:15',
  wake: '7:15',
  deepMinutes: 90,
  remMinutes: 120,
  coreMinutes: 180,
  awakeMinutes: 30,
  wakes: 2,
  source: EntrySource.health,
);

final _fullState = SleepState(
  lastNight: _lastNight,
  usualMinutes: 420,
  read: 'restful',
  week: const [
    SleepBar(dayLetter: 'M', minutes: 420, isToday: false),
    SleepBar(dayLetter: 'T', minutes: 390, isToday: false),
    SleepBar(dayLetter: 'W', minutes: 450, isToday: false),
    SleepBar(dayLetter: 'T', minutes: 400, isToday: false),
    SleepBar(dayLetter: 'F', minutes: 410, isToday: false),
    SleepBar(dayLetter: 'S', minutes: 480, isToday: false),
    SleepBar(dayLetter: 'S', minutes: 450, isToday: true),
  ],
  month: [420, 390, 450, 400, 410, 480, 450],
  syncedNights: 7,
);

final _needsSyncState = SleepState(
  lastNight: null,
  usualMinutes: 0,
  read: '',
  week: const [],
  month: const [],
  syncedNights: 2,
);

// ─── Harness ─────────────────────────────────────────────────────────────────

/// Wraps [SleepScreen] in a themed ProviderScope with provider overrides and a
/// minimal GoRouter (needed for TabHeaderScrollView's pushNamed calls).
Widget _wrap({
  required SleepState sleepState,
  List<Correlation> correlations = const [],
}) {
  final colors = AppColors.light(AppAccent.indigo);

  // minimal GoRouter: just the root route + the routes TabHeaderScrollView navigates to
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: SleepScreen()),
        routes: [
          GoRoute(
            path: 'you',
            builder: (_, _) =>
                const Scaffold(body: Center(child: Text('you'))),
          ),
          GoRoute(
            path: 'pal',
            builder: (_, _) =>
                const Scaffold(body: Center(child: Text('pal'))),
          ),
        ],
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      sleepControllerProvider.overrideWith(
        () => _FakeSleepController(sleepState),
      ),
      surfacedCorrelationsProvider.overrideWith(
        (_) async => correlations,
      ),
    ],
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, extensions: [colors]),
      routerConfig: router,
    ),
  );
}

// Stub controller: extends the public [SleepController] and overrides [build]
// so tests never touch the real repository. The generated _$SleepController
// base class is not imported directly — [SleepController] is the public type
// visible without the .g.dart, and [overrideWith] only needs the public type.
class _FakeSleepController extends SleepController {
  _FakeSleepController(this._state);
  final SleepState _state;

  @override
  Stream<SleepState> build() async* {
    yield _state;
  }
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  // ── Full state (syncedNights >= 3) ──────────────────────────────────────────

  testWidgets(
      'SleepScreen full state shows hero eyebrow and duration fragment',
      (t) async {
    await t.pumpWidget(_wrap(sleepState: _fullState));
    await t.pumpAndSettle();

    // hero eyebrow
    expect(find.text('LAST NIGHT'), findsOneWidget);
    // duration hours digit — 450 min = 7h30, so '7' should appear
    expect(find.text('7'), findsOneWidget);
  });

  testWidgets('SleepScreen full state shows stage label "Deep"', (t) async {
    await t.pumpWidget(_wrap(sleepState: _fullState));
    await t.pumpAndSettle();

    expect(find.text('DEEP'), findsOneWidget);
  });

  testWidgets('SleepScreen full state shows the read chip text', (t) async {
    await t.pumpWidget(_wrap(sleepState: _fullState));
    await t.pumpAndSettle();

    expect(find.text('restful'), findsOneWidget);
  });

  testWidgets('SleepScreen full state shows in-bed meta line fragment',
      (t) async {
    await t.pumpWidget(_wrap(sleepState: _fullState));
    await t.pumpAndSettle();

    // bedtime clock string is in the meta line
    expect(find.textContaining('23:15'), findsOneWidget);
  });

  testWidgets(
      'SleepScreen full state shows trend chart when scrolled into view',
      (t) async {
    await t.pumpWidget(_wrap(sleepState: _fullState));
    await t.pumpAndSettle();

    final scrollable = find.byType(Scrollable).first;
    await t.scrollUntilVisible(
        find.text('Recent nights'), 200, scrollable: scrollable);
    expect(find.text('Recent nights'), findsOneWidget);
  });

  // ── Needs-sync state (syncedNights < 3) ─────────────────────────────────────

  testWidgets('SleepScreen needs-sync state shows onboarding copy', (t) async {
    await t.pumpWidget(_wrap(sleepState: _needsSyncState));
    await t.pumpAndSettle();

    expect(find.text('A few more nights'), findsOneWidget);
  });

  testWidgets('SleepScreen needs-sync does NOT show hero eyebrow', (t) async {
    await t.pumpWidget(_wrap(sleepState: _needsSyncState));
    await t.pumpAndSettle();

    expect(find.text('LAST NIGHT'), findsNothing);
  });

  testWidgets('SleepScreen needs-sync shows correct synced count', (t) async {
    await t.pumpWidget(_wrap(sleepState: _needsSyncState));
    await t.pumpAndSettle();

    // syncedNights = 2 → "2 of 3 nights synced"
    expect(find.textContaining('2 of 3 nights synced'), findsOneWidget);
  });

  testWidgets('SleepScreen needs-sync shows Open Health settings button',
      (t) async {
    await t.pumpWidget(_wrap(sleepState: _needsSyncState));
    await t.pumpAndSettle();

    expect(find.text('Open Health settings'), findsOneWidget);
  });

  // ── Connections section ──────────────────────────────────────────────────────

  testWidgets('SleepScreen hides Connections section when no sleep corr',
      (t) async {
    await t.pumpWidget(_wrap(sleepState: _fullState, correlations: const []));
    await t.pumpAndSettle();

    expect(find.text('Connections'), findsNothing);
  });

  testWidgets(
      'SleepScreen shows Connections section with a sleep correlation',
      (t) async {
    const sleepCorr = Correlation(
      a: Dimension.sleep,
      b: Dimension.mood,
      r: 0.45,
      n: 25,
    );
    await t.pumpWidget(
        _wrap(sleepState: _fullState, correlations: const [sleepCorr]));
    await t.pumpAndSettle();

    final scrollable = find.byType(Scrollable).first;
    await t.scrollUntilVisible(
        find.text('Connections'), 300, scrollable: scrollable);
    expect(find.text('Connections'), findsOneWidget);
    expect(find.text('PAL NOTICED'), findsOneWidget);
  });
}
