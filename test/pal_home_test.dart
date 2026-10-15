import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/seed/seeder.dart';
import 'package:opal/router.dart';
import 'package:opal/screens/reflect/evening_close_out_screen.dart';
import 'package:opal/screens/today/today_screen.dart' show todayCardKey;
import 'package:opal/services/pal/mock_pal_service.dart';
import 'package:opal/services/pal/pal_service.dart';
import 'package:opal/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/flush_provider_timers.dart';
import 'support/today_fixture.dart' show TodayPal;

/// Boots the full app (router + theme) at [location] with an in-memory db and a
/// zero-latency [MockPalService].
Future<void> _pumpApp(WidgetTester tester,
    {required String location, PalService? pal}) async {
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
  group('Pal on the You tab', () {
    testWidgets('Reviews no longer has a Pal row', (tester) async {
      await _pumpApp(tester, location: '/you');

      expect(find.text("Your daily brief & what Pal's handling"), findsNothing);
      expect(find.text('Reviews'), findsOneWidget);

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

  // the hub's Needs you cards moved to Today's action card; a proposal is
  // approved from its row or its card, and put off from the card.
  group('Needs you on Today', () {
    Finder undo() => find.bySemanticsLabel('Undo');
    Finder card(String title) =>
        find.descendant(of: find.byKey(todayCardKey), matching: find.text(title));

    // these run on the wall clock, so which item starts on the card varies,
    // and the row may sit behind the More button.
    Future<void> showAllLater(WidgetTester tester) async {
      final more = find.textContaining('more later today');
      if (more.evaluate().isEmpty) return;
      await tester.tap(more);
      await tester.pumpAndSettle();
    }

    Finder row(String title) => find.bySemanticsLabel(
        RegExp('^${RegExp.escape(title)}, (any time|at .+)[.] Do this next\$'));

    /// Puts off whatever leads until [title] is on the card.
    Future<void> toCard(WidgetTester tester, String title) async {
      final skip = find.descendant(
          of: find.byKey(todayCardKey), matching: find.textContaining(RegExp(r'^Not (now|today)$')));
      while (card(title).evaluate().isEmpty && skip.evaluate().isNotEmpty) {
        await tester.tap(skip);
        await tester.pumpAndSettle();
      }
      expect(card(title), findsOneWidget);
    }

    testWidgets('a proposal approved from its row or card settles; Undo brings it back',
        (tester) async {
      await _pumpApp(tester, location: '/today');
      const rent = 'Set aside \$40 for rent';
      expect(undo(), findsNothing);

      // the money action approves in place (no navigation).
      if (card(rent).evaluate().isNotEmpty) {
        await tester.tap(find.text('Hold \$40'));
      } else {
        await showAllLater(tester);
        await tester.tap(row(rent));
      }
      await tester.pumpAndSettle();

      expect(find.text('Hold \$40'), findsNothing);
      expect(find.text(rent), findsNothing);

      await tester.tap(undo());
      await tester.pumpAndSettle();

      expect(find.text(rent), findsOneWidget);

      await flushProviderTimers(tester);
    });

    testWidgets('Not now removes the proposal', (tester) async {
      await _pumpApp(tester, location: '/today');
      await toCard(tester, 'Move Legs day to Friday');

      expect(find.text('Reschedule'), findsOneWidget);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(find.text('Move Legs day to Friday'), findsNothing);

      await flushProviderTimers(tester);
    });

    testWidgets('the close-out proposal lends its sentence to the Close-out row',
        (tester) async {
      // a blank brief, so the lead is the close-out's own sentence.
      await _pumpApp(tester, location: '/today', pal: TodayPal(headline: ''));
      await toCard(tester, 'Close-out');

      // no separate proposal row; Pal's body is the row's sentence.
      expect(find.text('Close out tonight', skipOffstage: false), findsNothing);
      expect(find.text('Start close-out', skipOffstage: false), findsNothing);
      expect(find.textContaining('A 5-min wind-down'), findsOneWidget);

      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();

      expect(find.byType(EveningCloseOutScreen), findsOneWidget);
      expect(undo(), findsNothing);

      await flushProviderTimers(tester);
    });
  });
}
