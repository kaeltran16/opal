import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/controllers/pal_memory_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/seed/seeder.dart';
import 'package:opal/router.dart';
import 'package:opal/services/pal/mock_pal_service.dart';
import 'package:opal/services/pal/pal_service.dart';
import 'package:opal/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/flush_provider_timers.dart';

/// Boots the full app (router + theme) at [location] with an in-memory db and a
/// zero-latency [MockPalService], so the Pal-brief Refresh resolves instantly.
Future<void> _pumpApp(WidgetTester tester,
    {required String location, PalMemoryDigest? memory}) async {
  // Tall surface so the long Pal Home / tab list renders fully — the default
  // ~800×600 test window lazy-builds the list and leaves lower sections (Ask Pal
  // CTA, autopilot, memory) off-screen and unhittable.
  tester.view.physicalSize = const Size(800, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final db = LoopDatabase.forTesting(NativeDatabase.memory());
  await Seeder(db).seedIfNeeded();
  addTearDown(db.close);

  final router = createRouter(initialLocation: location);
  final colors = AppColors.light(AppAccent.blue);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        loopDatabaseProvider.overrideWithValue(db),
        palServiceProvider
            .overrideWithValue(MockPalService(latency: Duration.zero)),
        if (memory != null) palMemoryProvider.overrideWith((ref) async => memory),
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
  group('Pal Home', () {
    testWidgets('renders the brief, needs-you actions, and all sections',
        (tester) async {
      await _pumpApp(tester, location: '/pal-home', memory: const PalMemoryDigest(
        facts: [PalFact(id: 'f-1', text: 'Training for a marathon in October')],
        patterns: [InsightPattern(
            colorToken: 'money', title: 'Fridays cost the most', detail: 'Dining out drives the spike.')],
      ));

      // Brief card + its default copy.
      expect(find.text("TODAY'S BRIEF"), findsOneWidget);
      expect(find.text('Refresh'), findsOneWidget);

      // Needs-you section + the four seeded actions.
      expect(find.text('Needs you'), findsOneWidget);
      expect(find.text('Move Legs day to Friday'), findsOneWidget);
      expect(find.text('Set aside \$40 for rent'), findsOneWidget);
      expect(find.text('Close out tonight'), findsOneWidget);
      expect(find.text('Add a 2-min wind-down ritual'), findsOneWidget);

      // On autopilot section (its header + an autopilot row title).
      expect(find.text('Rent auto-pay watch'), findsOneWidget);
      expect(find.text('What Pal remembers'), findsOneWidget);
      expect(find.text('Training for a marathon in October'), findsOneWidget);
      expect(find.text('Fridays cost the most'), findsOneWidget);
      expect(find.text('Ask Pal anything'), findsOneWidget);

      await flushProviderTimers(tester);
    });

    testWidgets('Approve flips a card to its done confirmation; Undo reverts',
        (tester) async {
      await _pumpApp(tester, location: '/pal-home');

      // The money action approves in place (no navigation).
      await tester.tap(find.text('Hold \$40'));
      await tester.pumpAndSettle();

      expect(find.text('Held \$40 in your Rent envelope'), findsOneWidget);
      expect(find.text('Done by Pal · just now'), findsOneWidget);
      expect(find.text('Hold \$40'), findsNothing);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(find.text('Hold \$40'), findsOneWidget);
      expect(find.text('Held \$40 in your Rent envelope'), findsNothing);

      await flushProviderTimers(tester);
    });

    testWidgets('Not now removes the card', (tester) async {
      await _pumpApp(tester, location: '/pal-home');

      // First card is the Workout action; dismiss it via its "Not now".
      expect(find.text('Move Legs day to Friday'), findsOneWidget);
      await tester.tap(find.text('Not now').first);
      await tester.pumpAndSettle();

      expect(find.text('Move Legs day to Friday'), findsNothing);

      await flushProviderTimers(tester);
    });

    testWidgets('close-out action navigates instead of flipping to done',
        (tester) async {
      await _pumpApp(tester, location: '/pal-home');

      await tester.tap(find.text('Start close-out'));
      await tester.pumpAndSettle();

      // It routes to the Evening Close-Out flow rather than showing the inline
      // "done" confirmation.
      expect(find.text('Close-out queued for 21:30'), findsNothing);

      await flushProviderTimers(tester);
    });

    testWidgets('memory section is always shown, with an empty-state on first run',
        (tester) async {
      // no `memory:` override → MockPalService returns an empty digest
      await _pumpApp(tester, location: '/pal-home');

      expect(find.text('What Pal remembers'), findsOneWidget);
      expect(
        find.text("As we talk, I'll note facts you mention and patterns I learn "
            'here — you can delete anything.'),
        findsOneWidget,
      );

      await flushProviderTimers(tester);
    });

    testWidgets('wiping memory asks for confirmation first', (tester) async {
      await _pumpApp(tester, location: '/pal-home', memory: const PalMemoryDigest(
        facts: [PalFact(id: 'f-1', text: 'Training for a marathon in October')],
      ));

      await tester.tap(find.text('Clear what Pal remembers'));
      await tester.pumpAndSettle();

      // a confirm step appears; the fact is still present until confirmed
      expect(find.text('Clear all memory?'), findsOneWidget);
      expect(find.text('Training for a marathon in October'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Clear all memory?'), findsNothing);
      expect(find.text('Training for a marathon in October'), findsOneWidget);

      await flushProviderTimers(tester);
    });

    testWidgets('memory controls expose accessibility labels', (tester) async {
      await _pumpApp(tester, location: '/pal-home', memory: const PalMemoryDigest(
        facts: [PalFact(id: 'f-1', text: 'Training for a marathon in October')],
      ));

      expect(find.bySemanticsLabel('Forget this fact'), findsOneWidget);
      expect(find.bySemanticsLabel('Clear all Pal memory'), findsOneWidget);

      await flushProviderTimers(tester);
    });

    testWidgets('a learned pattern can be dismissed locally', (tester) async {
      await _pumpApp(tester, location: '/pal-home', memory: const PalMemoryDigest(
        patterns: [InsightPattern(
            colorToken: 'money',
            title: 'Fridays cost the most',
            detail: 'Dining out drives the spike.')],
      ));

      expect(find.text('Fridays cost the most'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Dismiss this pattern'));
      await tester.pumpAndSettle();

      expect(find.text('Fridays cost the most'), findsNothing);

      await flushProviderTimers(tester);
    });

    testWidgets('brief auto-fetches from the daily-insights seam on open',
        (tester) async {
      await _pumpApp(tester, location: '/pal-home');

      // The brief is no longer a hardcoded showcase line — it is fetched from
      // MockPalService.insights(day) on open, so its headline is already shown
      // without tapping Refresh.
      expect(find.textContaining('On days you finish'), findsOneWidget);

      // Refresh re-fetches and keeps the seam-derived brief.
      await tester.tap(find.text('Refresh'));
      await tester.pumpAndSettle();
      expect(find.textContaining('On days you finish'), findsOneWidget);

      await flushProviderTimers(tester);
    });
  });

  group('Pal Home entry points', () {
    testWidgets('Today nav bar shows the Pal orb and it opens Pal Home',
        (tester) async {
      await _pumpApp(tester, location: '/today');

      final orb = find.bySemanticsLabel('Open Pal');
      expect(orb, findsOneWidget);

      await tester.tap(orb);
      await tester.pumpAndSettle();

      expect(find.text('Needs you'), findsOneWidget);
      expect(find.text('Ask Pal anything'), findsOneWidget);

      await flushProviderTimers(tester);
    });

    testWidgets('You tab Reviews section has a Pal row that opens Pal Home',
        (tester) async {
      await _pumpApp(tester, location: '/you');

      expect(find.text('Pal'), findsOneWidget);
      // Badge reflects the agenda seam (mock returns 4 proposals).
      expect(find.text('4 for you'), findsOneWidget);

      await tester.tap(find.text('Pal'));
      await tester.pumpAndSettle();

      expect(find.text('Needs you'), findsOneWidget);

      await flushProviderTimers(tester);
    });
  });
}
