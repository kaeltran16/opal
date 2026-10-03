import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/controllers/pal_memory_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/seed/seeder.dart';
import 'package:opal/router.dart';
import 'package:opal/screens/reflect/evening_close_out_screen.dart';
import 'package:opal/services/pal/mock_pal_service.dart';
import 'package:opal/services/pal/pal_service.dart';
import 'package:opal/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/flush_provider_timers.dart';

const _fact = PalFact(id: 'f-1', text: 'Training for a marathon in October');
const _pattern = InsightPattern(
    colorToken: 'money',
    title: 'Fridays cost the most',
    detail: 'Dining out drives the spike.');

/// A mock whose stored facts really change on delete, so a test sees the row
/// go away through the same provider refresh the app uses.
class _MemoryPal extends MockPalService {
  _MemoryPal({this.failDelete = false}) : super(latency: Duration.zero);

  final bool failDelete;
  final List<PalFact> facts = [_fact];

  @override
  Future<PalMemoryDigest> memory() async =>
      PalMemoryDigest(facts: List.of(facts));

  @override
  Future<PalMemoryDigest> deleteFact(String id) async {
    if (failDelete) throw StateError('offline');
    facts.removeWhere((f) => f.id == id);
    return PalMemoryDigest(facts: List.of(facts));
  }
}

/// Boots the full app (router + theme) at [location] with an in-memory db and a
/// zero-latency [MockPalService].
Future<void> _pumpApp(WidgetTester tester,
    {required String location,
    PalMemoryDigest? memory,
    PalService? pal}) async {
  // tall surface so the whole You tab lays out; the default ~800x600 window
  // lazy-builds the list and leaves the lower sections off-screen.
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final db = LoopDatabase.forTesting(NativeDatabase.memory());
  await Seeder(db).seedIfNeeded();
  addTearDown(db.close);

  final router = createRouter(initialLocation: location);
  final colors = AppColors.light();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        loopDatabaseProvider.overrideWithValue(db),
        palServiceProvider
            .overrideWithValue(pal ?? MockPalService(latency: Duration.zero)),
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

Finder _switch(String label) => find.byWidgetPredicate((w) =>
    w is Semantics &&
    w.properties.label == label &&
    w.properties.toggled != null);

bool _isOn(WidgetTester tester, String label) =>
    tester.widget<Semantics>(_switch(label)).properties.toggled!;

void main() {
  group('Pal on the You tab', () {
    testWidgets('shows memory, autopilot and what Pal noticed',
        (tester) async {
      await _pumpApp(tester,
          location: '/you',
          memory: const PalMemoryDigest(facts: [_fact], patterns: [_pattern]));

      expect(find.text('PAL'), findsOneWidget);
      expect(find.text('What Pal remembers'), findsOneWidget);
      expect(find.text('Training for a marathon in October'), findsOneWidget);
      expect(find.text('Fridays cost the most'), findsOneWidget);
      expect(find.text('Rent auto-pay watch'), findsOneWidget);
      expect(find.text('What Pal noticed'), findsOneWidget);
      // the hub's brief and Needs you live on Today now.
      expect(find.text("TODAY'S BRIEF"), findsNothing);
      expect(find.text('Needs you'), findsNothing);

      await flushProviderTimers(tester);
    });

    testWidgets('forgetting a fact deletes it and drops the row',
        (tester) async {
      final pal = _MemoryPal();
      await _pumpApp(tester, location: '/you', pal: pal);
      expect(find.text(_fact.text), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Forget this fact'));
      await tester.pumpAndSettle();

      expect(pal.facts, isEmpty);
      expect(find.text(_fact.text), findsNothing);

      await flushProviderTimers(tester);
    });

    testWidgets('a failed forget keeps the fact and says so', (tester) async {
      await _pumpApp(tester, location: '/you', pal: _MemoryPal(failDelete: true));

      await tester.tap(find.bySemanticsLabel('Forget this fact'));
      await tester.pumpAndSettle();

      expect(find.text(_fact.text), findsOneWidget);
      expect(find.text("Couldn't forget that. Try again."), findsOneWidget);

      await flushProviderTimers(tester);
    });

    testWidgets('memory is always shown, with an empty state on first run',
        (tester) async {
      // no `memory:` override: the mock returns an empty digest.
      await _pumpApp(tester, location: '/you');

      expect(find.text('What Pal remembers'), findsOneWidget);
      expect(
        find.text("As we talk, I'll note facts you mention and patterns I learn "
            'here — you can delete anything.'),
        findsOneWidget,
      );

      await flushProviderTimers(tester);
    });

    testWidgets('wiping memory asks for confirmation first', (tester) async {
      await _pumpApp(tester,
          location: '/you', memory: const PalMemoryDigest(facts: [_fact]));

      await tester.tap(find.text('Clear what Pal remembers'));
      await tester.pumpAndSettle();

      // a confirm step appears; the fact is still present until confirmed.
      expect(find.text('Clear all memory?'), findsOneWidget);
      expect(find.text(_fact.text), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Clear all memory?'), findsNothing);
      expect(find.text(_fact.text), findsOneWidget);

      await flushProviderTimers(tester);
    });

    testWidgets('memory controls expose accessibility labels', (tester) async {
      await _pumpApp(tester,
          location: '/you', memory: const PalMemoryDigest(facts: [_fact]));

      expect(find.bySemanticsLabel('Forget this fact'), findsOneWidget);
      expect(find.bySemanticsLabel('Clear all Pal memory'), findsOneWidget);

      await flushProviderTimers(tester);
    });

    testWidgets('a learned pattern can be dismissed locally', (tester) async {
      await _pumpApp(tester,
          location: '/you', memory: const PalMemoryDigest(patterns: [_pattern]));

      expect(find.text(_pattern.title), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Dismiss this pattern'));
      await tester.pumpAndSettle();

      expect(find.text(_pattern.title), findsNothing);

      await flushProviderTimers(tester);
    });

    testWidgets('tapping an autopilot row flips its switch', (tester) async {
      await _pumpApp(tester, location: '/you');

      expect(_isOn(tester, 'Rent auto-pay watch'), isTrue);
      expect(_isOn(tester, 'Coffee nudge at \$15 / wk'), isFalse);

      await tester.tap(find.text('Rent auto-pay watch'));
      await tester.pumpAndSettle();
      expect(_isOn(tester, 'Rent auto-pay watch'), isFalse);

      await tester.tap(find.text('Coffee nudge at \$15 / wk'));
      await tester.pumpAndSettle();
      expect(_isOn(tester, 'Coffee nudge at \$15 / wk'), isTrue);

      await flushProviderTimers(tester);
    });

    testWidgets('the noticed feed keeps its filter pills', (tester) async {
      await _pumpApp(tester, location: '/you');

      expect(find.text('What Pal noticed'), findsOneWidget);
      for (final pill in ['All', 'Unread', 'Money', 'Workout', 'Routines']) {
        expect(find.text(pill), findsWidgets, reason: pill);
      }
      expect(find.bySemanticsLabel('Mark all read'), findsOneWidget);

      await flushProviderTimers(tester);
    });

    testWidgets('Reviews no longer has a Pal row', (tester) async {
      await _pumpApp(tester, location: '/you');

      expect(find.text("Your daily brief & what Pal's handling"), findsNothing);
      expect(find.text("Today's recap"), findsOneWidget);

      await flushProviderTimers(tester);
    });
  });

  group('old Pal paths', () {
    for (final path in ['/pal', '/pal-home', '/pal-inbox']) {
      testWidgets('$path lands on the You tab', (tester) async {
        await _pumpApp(tester, location: path);
        expect(find.text('What Pal remembers'), findsOneWidget);
        await flushProviderTimers(tester);
      });
    }
  });

  // the hub's Needs you cards moved to Today's action card; a later row is
  // tapped first to bring its proposal onto the card.
  group('Needs you on Today', () {
    /// The header's Undo; a receipt row's is labelled with its title.
    Finder undo() => find.bySemanticsLabel('Undo');

    // these run on the wall clock, so which item starts on the card varies.
    Future<void> select(WidgetTester tester, String title) async {
      final row = find.bySemanticsLabel('$title, any time. Do this next');
      if (row.evaluate().isEmpty) return;
      await tester.tap(row);
      await tester.pumpAndSettle();
    }

    testWidgets('the primary pill settles a proposal; Undo brings it back',
        (tester) async {
      await _pumpApp(tester, location: '/today');
      await select(tester, 'Set aside \$40 for rent');
      final progress = find.textContaining(RegExp(r'^\d+ of \d+ done$'));
      final before = tester.widget<Text>(progress).data;
      expect(undo(), findsNothing);

      // the money action approves in place (no navigation).
      await tester.tap(find.text('Hold \$40'));
      await tester.pumpAndSettle();

      expect(find.text('Hold \$40'), findsNothing);
      expect(find.text('Set aside \$40 for rent'), findsNothing);
      expect(tester.widget<Text>(progress).data, isNot(before));

      await tester.tap(undo());
      await tester.pumpAndSettle();

      expect(find.text('Hold \$40'), findsOneWidget);
      expect(tester.widget<Text>(progress).data, before);

      await flushProviderTimers(tester);
    });

    testWidgets('Not now removes the proposal', (tester) async {
      await _pumpApp(tester, location: '/today');
      await select(tester, 'Move Legs day to Friday');

      expect(find.text('Reschedule'), findsOneWidget);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(find.text('Move Legs day to Friday'), findsNothing);

      await flushProviderTimers(tester);
    });

    testWidgets('a close-out proposal navigates instead of settling',
        (tester) async {
      await _pumpApp(tester, location: '/today');
      await select(tester, 'Close out tonight');

      await tester.tap(find.text('Start close-out'));
      await tester.pumpAndSettle();

      expect(find.byType(EveningCloseOutScreen), findsOneWidget);
      // still on the card behind the sheet, and nothing to undo.
      expect(find.text('Start close-out', skipOffstage: false), findsOneWidget);
      expect(undo(), findsNothing);

      await flushProviderTimers(tester);
    });
  });
}
