import 'package:clock/clock.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/data/seed/seed_data.dart';
import 'package:opal/models/models.dart';
import 'package:opal/screens/rituals/rituals_builder_screen.dart';
import 'package:opal/screens/rituals/routine_player_screen.dart';

import '../support/flush_provider_timers.dart';
import '../support/golden_harness.dart' show appRouter;
import '../support/today_fixture.dart';

final _morning = Clock.fixed(DateTime(2026, 9, 28, 9, 30));

const _emptyRoutine = RitualRoutine(
  id: 'empty',
  name: 'Midday reset',
  time: '1:00 PM',
  tone: RitualTone.midday,
  icon: 'sun.max.fill',
  blurb: 'Break the desk spell',
);

void _playerTest(String name, Future<void> Function(WidgetTester tester) body) {
  testWidgets(name, (tester) async {
    await withClock(_morning, () async {
      try {
        await body(tester);
      } finally {
        // a failed expectation must still flush, or the next test hangs.
        await flushProviderTimers(tester);
      }
    });
  });
}

/// Boots the app and opens the player on [routineId].
Future<void> _open(
  WidgetTester tester, {
  String routineId = 'morning',
  TodayDay day = const TodayDay(),
}) async {
  await bootToday(tester, day: day);
  appRouter(tester).push('/rituals/player/$routineId');
  await tester.pumpAndSettle();
  expect(find.byType(RoutinePlayerScreen), findsOneWidget);
}

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.tap(find.bySemanticsLabel(label));
  await tester.pumpAndSettle();
}

void main() {
  _playerTest('Mark done records the step and advances', (tester) async {
    await _open(tester);
    expect(find.text('Step 1 of 5'), findsOneWidget);
    expect(find.text('0 of 5 done'), findsOneWidget);
    expect(find.text('Glass of water'), findsOneWidget);
    expect(find.text('Up next'), findsOneWidget);
    expect(find.text('Wash my face'), findsOneWidget);

    await _tap(tester, 'Mark done');
    expect(find.text('Step 2 of 5'), findsOneWidget);
    expect(find.text('1 of 5 done'), findsOneWidget);
    expect(find.bySemanticsLabel('1 of 5 done'), findsWidgets);
  });

  _playerTest('the step glyph draws as a line', (tester) async {
    await _open(tester);
    // seed step 1 stores drop.fill.
    expect(find.text('Glass of water'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.drop), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.drop_fill), findsNothing);
  });

  _playerTest('Skip advances without completing', (tester) async {
    await _open(tester);
    await _tap(tester, 'Skip');
    expect(find.text('Step 2 of 5'), findsOneWidget);
    expect(find.text('0 of 5 done'), findsOneWidget);
  });

  _playerTest('Back is disabled at step 1 and steps back after', (tester) async {
    await _open(tester);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Back')),
      isSemantics(label: 'Back', isButton: true, hasEnabledState: true, isEnabled: false),
    );
    await _tap(tester, 'Back');
    expect(find.text('Step 1 of 5'), findsOneWidget);

    await _tap(tester, 'Skip');
    await _tap(tester, 'Back');
    expect(find.text('Step 1 of 5'), findsOneWidget);
  });

  _playerTest('an already-done step shows Next step', (tester) async {
    await _open(tester);
    expect(find.text('Next step'), findsNothing);
    await _tap(tester, 'Mark done');
    await _tap(tester, 'Back');
    expect(find.text('Step 1 of 5'), findsOneWidget);
    expect(find.text('Next step'), findsOneWidget);
    expect(find.text('Mark done'), findsNothing);

    await _tap(tester, 'Next step');
    expect(find.text('Step 2 of 5'), findsOneWidget);
    expect(find.text('1 of 5 done'), findsOneWidget);
  });

  _playerTest('finishing every step says the routine is done', (tester) async {
    await _open(tester);
    for (var i = 0; i < 5; i++) {
      await _tap(tester, 'Mark done');
    }
    expect(find.text('Done · Morning'), findsOneWidget);
    expect(find.text('Morning is done.'), findsOneWidget);
    expect(find.text('5 of 5 steps'), findsOneWidget);
    expect(find.text('done today'), findsOneWidget);
    // today's finished routine counts toward the streak.
    expect(find.text('1-day streak'), findsOneWidget);

    await _tap(tester, 'Back to routines');
    expect(find.byType(RoutinePlayerScreen), findsNothing);
  });

  _playerTest('finishing with skips says how many got done', (tester) async {
    await _open(tester);
    await _tap(tester, 'Mark done');
    await _tap(tester, 'Skip');
    await _tap(tester, 'Mark done');
    await _tap(tester, 'Skip');
    await _tap(tester, 'Mark done');
    expect(find.text('Morning, 3 of 5 done.'), findsOneWidget);
    expect(find.text('3 of 5 steps'), findsOneWidget);
    expect(find.text('Morning is done.'), findsNothing);
  });

  _playerTest('a routine with no steps points to Manage routines', (tester) async {
    await _open(
      tester,
      routineId: _emptyRoutine.id,
      day: TodayDay(routines: [...SeedData.ritualRoutines(), _emptyRoutine]),
    );
    expect(find.text('No steps yet'), findsOneWidget);
    expect(find.text('Add a step to Midday reset to start it.'), findsOneWidget);

    await _tap(tester, 'Manage routines');
    expect(find.byType(RitualsBuilderScreen), findsOneWidget);
  });

  _playerTest('an unknown id says the routine was not found', (tester) async {
    await _open(tester, routineId: 'missing');
    expect(find.text('Routine not found'), findsOneWidget);
    expect(find.text('It may have been deleted.'), findsOneWidget);
    expect(find.bySemanticsLabel('Back to routines'), findsOneWidget);
  });
}
