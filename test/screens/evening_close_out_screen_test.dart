import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/controllers/providers.dart';
import 'package:opal/models/models.dart';
import 'package:opal/screens/pal/pal_composer_screen.dart';
import 'package:opal/screens/reflect/evening_close_out_screen.dart';

import '../support/flush_provider_timers.dart';
import '../support/golden_harness.dart' show appRouter;
import '../support/today_fixture.dart';

final _monday = Clock.fixed(DateTime(2026, 9, 28, 21, 30));

const _first = 'Phone on the charger';
const _second = 'Skincare';
const _loadError = "Couldn't load your routines. Try again in a moment.";

/// Boots Today on a tall surface, then pushes the close-out.
void _closeOutTest(
  String name,
  Future<void> Function(WidgetTester tester) body, {
  TodayDay day = const TodayDay(),
  List<Override> overrides = const [],
}) {
  testWidgets(name, (tester) async {
    await withClock(_monday, () async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      try {
        await bootToday(tester, day: day, overrides: overrides);
        appRouter(tester).push('/close-out');
        await tester.pumpAndSettle();
        expect(find.byType(EveningCloseOutScreen), findsOneWidget);
        expect(find.text('Close out your day.'), findsOneWidget);
        await body(tester);
      } finally {
        // a failed expectation must still flush, or the next test hangs.
        await flushProviderTimers(tester);
      }
    });
  });
}

Future<void> _tapLabel(WidgetTester tester, String label) async {
  await tester.tap(find.bySemanticsLabel(label).last);
  await tester.pumpAndSettle();
}

void main() {
  _closeOutTest('Mark done completes the first open step and moves the card on', (tester) async {
    expect(find.text('MON 28 SEP · 9:30 PM'), findsOneWidget);
    expect(find.text('0 of 4 steps done. 4 more to close the ring.'), findsOneWidget);
    expect(find.text('Now'), findsOneWidget);
    // the card's title and its row in the list.
    expect(find.text(_first), findsNWidgets(2));
    expect(find.text(_second), findsOneWidget);

    await _tapLabel(tester, 'Mark done');

    expect(find.text('1 of 4 steps done. 3 more to close the ring.'), findsOneWidget);
    expect(find.text(_first), findsOneWidget);
    expect(find.text(_second), findsNWidgets(2));
    expect(tester.getSemantics(find.bySemanticsLabel(_first)),
        isSemantics(label: _first, hasCheckedState: true, isChecked: true, isButton: true));
  });

  _closeOutTest('tapping a done row unchecks it', (tester) async {
    await _tapLabel(tester, 'Mark done');
    expect(find.text('1 of 4 steps done. 3 more to close the ring.'), findsOneWidget);

    await _tapLabel(tester, _first);

    expect(find.text('0 of 4 steps done. 4 more to close the ring.'), findsOneWidget);
    expect(find.text(_first), findsNWidgets(2));
    expect(tester.getSemantics(find.bySemanticsLabel(_first).last),
        isSemantics(label: _first, hasCheckedState: true, isChecked: false, isButton: true));
  });

  _closeOutTest('with every step done the card says Good night, which leaves', (tester) async {
    for (var i = 0; i < 3; i++) {
      await _tapLabel(tester, 'Mark done');
    }
    expect(find.text('3 of 4 steps done. One more to close the ring.'), findsOneWidget);
    await _tapLabel(tester, 'Mark done');

    expect(find.text('4 of 4 steps done. The ring is closed.'), findsOneWidget);
    expect(find.text('All done'), findsOneWidget);
    expect(find.text('Rest easy'), findsOneWidget);
    expect(find.text('Mark done'), findsNothing);

    await _tapLabel(tester, 'Good night');

    expect(find.byType(EveningCloseOutScreen), findsNothing);
  });

  _closeOutTest('with no routines the close-out has nothing to close', (tester) async {
    expect(find.text('No wind-down steps yet.'), findsOneWidget);
    expect(find.text('Nothing to close'), findsOneWidget);
    expect(find.text('Good night'), findsOneWidget);
    expect(find.text('Tonight'), findsNothing);
  }, day: const TodayDay(routines: []));

  // never emits until the test is done, then empties so riverpod can dispose.
  final pending = StreamController<List<RitualRoutine>>();
  _closeOutTest('while the routines load the summary waits', (tester) async {
    expect(find.text('…'), findsOneWidget);
    expect(find.text('No wind-down steps yet.'), findsNothing);
    expect(find.text('Mark done'), findsNothing);
    expect(find.text('Good night'), findsNothing);
    expect(find.text('Tonight'), findsNothing);

    pending.add(const []);
    await tester.pumpAndSettle();
  }, overrides: [ritualRoutinesStreamProvider.overrideWith((ref) => pending.stream)]);

  _closeOutTest('a failing load shows calm copy and no card', (tester) async {
    await tester.pumpAndSettle();
    expect(find.text(_loadError), findsOneWidget);
    expect(find.text('Mark done'), findsNothing);
    expect(find.text('Good night'), findsNothing);
    expect(find.text('Tonight'), findsNothing);
  }, overrides: [
    ritualRoutinesStreamProvider
        .overrideWith((ref) => Stream<List<RitualRoutine>>.error(Exception('db closed'))),
  ]);

  _closeOutTest('the Pal row opens the composer, and Close returns to the close-out',
      (tester) async {
    await _tapLabel(tester, 'Ask Pal for a reflection prompt');
    expect(find.byType(PalComposerSheet), findsOneWidget);

    await _tapLabel(tester, 'Close');

    expect(find.byType(PalComposerSheet), findsNothing);
    expect(find.text('Close out your day.'), findsOneWidget);
  });
}
