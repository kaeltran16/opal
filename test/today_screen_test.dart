import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/app.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/controllers/spending_controller.dart' show DetailTracker;
import 'package:opal/models/models.dart';
import 'package:opal/screens/detail/detail_screen.dart';
import 'package:opal/screens/reflect/evening_close_out_screen.dart';
import 'package:opal/screens/shell/tab_header.dart';
import 'package:opal/services/pal/mock_pal_service.dart';
import 'package:opal/services/pal/pal_service.dart';
import 'package:opal/widgets/activity_rings.dart';

import 'support/flush_provider_timers.dart';
import 'support/golden_harness.dart' show bootApp;

final _monday = Clock.fixed(DateTime(2026, 9, 28, 9, 30));

/// A mock whose day headline and agenda the test picks; `throwInsights`
/// makes the brief fail so Today falls back to its local numbers.
class _Pal extends MockPalService {
  _Pal({this.headline, this.throwInsights = false, this.proposals})
      : super(latency: Duration.zero, seed: 0);

  final String? headline;
  final bool throwInsights;
  final List<PalProposal>? proposals;
  int insightsCalls = 0;

  @override
  Future<PalInsights> insights(InsightRange range) async {
    if (range == InsightRange.day) insightsCalls++;
    if (throwInsights) throw Exception('offline');
    if (range == InsightRange.day && headline != null) {
      return PalInsights(headline: headline);
    }
    return super.insights(range);
  }

  @override
  Future<PalAgenda> agenda() async {
    final p = proposals;
    return p == null ? super.agenda() : PalAgenda(proposals: p);
  }
}

PalProposal _proposal(String id, String title) => PalProposal(
      id: id,
      tag: 'Money',
      colorToken: 'money',
      icon: 'dollarsign.circle.fill',
      title: title,
      body: 'Body for $title.',
      approveLabel: 'Got it',
      approveIcon: 'checkmark',
      doneLabel: '$title done',
    );

/// Boots the seeded app on Today under the fixed Monday clock, on a surface
/// tall enough that every section is laid out.
Future<void> _boot(WidgetTester tester, MockPalService pal) async {
  tester.view.physicalSize = const Size(800, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await bootApp(tester, palService: pal);
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(LoopApp)));

/// Logs every step of every routine today, which completes the Routines area.
Future<void> _completeEveryRoutine(WidgetTester tester) async {
  final container = _container(tester);
  final routinesSub = container.listen(ritualRoutinesStreamProvider.future, (_, _) {});
  addTearDown(routinesSub.close);
  await tester.pumpAndSettle();
  final routines = await routinesSub.read();

  final repo = container.read(entryRepositoryProvider);
  final inserts = [
    for (final r in routines)
      for (final s in r.steps)
        repo.insert(Entry(
          id: 'done-${s.id}',
          timestamp: DateTime(2026, 9, 28, 9),
          type: EntryType.rituals,
          title: s.title,
          ritualId: s.id,
          source: EntrySource.manual,
        )),
  ];
  await tester.pumpAndSettle();
  await Future.wait(inserts);
}

void main() {
  testWidgets('the brief shows Pal\'s lead and its chips open their area',
      (tester) async {
    await withClock(_monday, () async {
      await _boot(tester, _Pal(headline: 'Steady start.'));

      expect(find.textContaining('Steady start.', findRichText: true), findsOneWidget);
      expect(find.textContaining('MONDAY, SEPTEMBER 28'), findsOneWidget);
      expect(find.textContaining('Good morning'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel(RegExp(r'^Spent .* open Money$')));
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate((w) => w is DetailScreen && w.tracker == DetailTracker.money),
        findsOneWidget,
      );

      await flushProviderTimers(tester);
    });
  });

  testWidgets('a failed brief falls back to the what\'s-left row',
      (tester) async {
    await withClock(_monday, () async {
      await _boot(tester, _Pal(throwInsights: true));

      expect(find.text("Pal's brief is catching up"), findsOneWidget);
      // the three columns, not the area cards below them.
      expect(find.bySemanticsLabel(RegExp(r'^Spent \S+ of')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Workout \d')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Routines \d')), findsOneWidget);

      await flushProviderTimers(tester);
    });
  });

  testWidgets('pulling Today down refetches the brief', (tester) async {
    await withClock(_monday, () async {
      final pal = _Pal(headline: 'Steady start.');
      await _boot(tester, pal);
      final before = pal.insightsCalls;
      // the indicator arms at a share of the viewport, which a 400 pt pull
      // never reaches on the tall layout surface; pull on a phone instead.
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();

      await tester.fling(find.byType(TabHeaderScrollView), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();

      expect(pal.insightsCalls, before + 1);
      await flushProviderTimers(tester);
    });
  });

  testWidgets('returning to the app refetches the brief', (tester) async {
    await withClock(_monday, () async {
      final pal = _Pal(headline: 'Steady start.');
      await _boot(tester, pal);
      final before = pal.insightsCalls;

      // AppLifecycleListener asserts every transition, so walk the real sequence.
      for (final state in const [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(pal.insightsCalls, before + 1);
      await flushProviderTimers(tester);
    });
  });

  testWidgets('Needs you is hidden with an empty agenda', (tester) async {
    await withClock(_monday, () async {
      await _boot(tester, _Pal(proposals: const []));

      expect(find.text('Needs you'), findsNothing);

      await flushProviderTimers(tester);
    });
  });

  testWidgets('Needs you shows its proposals with a count', (tester) async {
    await withClock(_monday, () async {
      await _boot(
        tester,
        _Pal(proposals: [_proposal('a', 'Rent auto-pays'), _proposal('b', 'Push Day A')]),
      );

      expect(find.text('Needs you'), findsOneWidget);
      expect(find.bySemanticsLabel('2 need you'), findsOneWidget);
      expect(find.text('Rent auto-pays'), findsOneWidget);
      expect(find.text('Push Day A'), findsOneWidget);

      await flushProviderTimers(tester);
    });
  });

  testWidgets('Undo deletes a Done-by-Pal entry, even one already gone',
      (tester) async {
    await withClock(_monday, () async {
      await _boot(tester, _Pal());
      final repo = _container(tester).read(entryRepositoryProvider);

      Entry emailed(String id, String title) => Entry(
            id: id,
            timestamp: DateTime(2026, 9, 28, 8),
            type: EntryType.money,
            title: title,
            amount: -5.75,
            source: EntrySource.email,
          );
      // the insert only completes once fake time advances, so don't await it
      // before pumping.
      final inserted = [
        repo.insert(emailed('e-verve', 'Verve Coffee')),
        repo.insert(emailed('e-blue', 'Blue Bottle')),
      ];
      await tester.pumpAndSettle();
      await Future.wait(inserted);

      expect(find.text('Done by Pal · from your Gmail receipt'), findsWidgets);
      expect(find.textContaining('Logged Verve Coffee, '), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Undo Verve Coffee'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Undo Verve Coffee'), findsNothing);
      final all = repo.getAll();
      await tester.pumpAndSettle();
      expect((await all).any((e) => e.id == 'e-verve'), isFalse);

      // deleted elsewhere first: Undo must not throw, and the row goes away.
      final gone = repo.deleteById('e-blue');
      await tester.tap(find.bySemanticsLabel('Undo Blue Bottle'));
      await tester.pumpAndSettle();
      await gone;
      expect(tester.takeException(), isNull);
      expect(find.bySemanticsLabel('Undo Blue Bottle'), findsNothing);

      await flushProviderTimers(tester);
    });
  });

  testWidgets('a complete Routines card sinks below the incomplete cards',
      (tester) async {
    await withClock(_monday, () async {
      await _boot(tester, _Pal());
      await _completeEveryRoutine(tester);

      double top(String card) =>
          tester.getTopLeft(find.bySemanticsLabel(RegExp('^$card card'))).dy;
      final routines = top('Routines');
      // sleep is due at minute 0 either way; money and move only rank above
      // routines (next slot 7:00 AM) once routines count as complete.
      expect(top('Sleep'), lessThan(routines));
      expect(top('Money'), lessThan(routines));
      expect(top('Move'), lessThan(routines));

      await flushProviderTimers(tester);
    });
  });

  testWidgets('with every routine done, the Routines card starts the close-out',
      (tester) async {
    await withClock(_monday, () async {
      await _boot(tester, _Pal());
      await _completeEveryRoutine(tester);

      expect(find.text('Evening close-out'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Start Evening close-out'));
      await tester.pumpAndSettle();
      expect(find.byType(EveningCloseOutScreen), findsOneWidget);

      await flushProviderTimers(tester);
    });
  });

  testWidgets('the rings hero and the search button are gone', (tester) async {
    await withClock(_monday, () async {
      await _boot(tester, _Pal());

      expect(find.byType(ActivityRings), findsNothing);
      expect(find.bySemanticsLabel('Search'), findsNothing);

      await flushProviderTimers(tester);
    });
  });
}
