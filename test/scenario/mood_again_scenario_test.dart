@Tags(['scenario'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/screens/today/today_screen.dart';

import '../support/today_fixture.dart';
import 'scenario_harness.dart';

const _restLead = 'Nothing is left. Rest up.';

/// Checked in this morning with no routines or workout: only a meal is left.
const _checkedIn = TodayDay(routines: [], workout: false, mood: true);

/// Checked in and fed, so nothing is left to do.
const _onlyAgain = TodayDay(routines: [], workout: false, mood: true, meal: true);

String _theme(bool dark) => dark ? 'dark' : 'light';

Finder _onCard(Finder matching) => find.descendant(of: find.byKey(todayCardKey), matching: matching);

/// The done mood row, which reads the mood word and checks in again.
Finder _row() => find.bySemanticsLabel(RegExp(r'^Check in again: Mood check-in, .+$'));

void main() {
  scenarioTest('mood check in again', (tester, dark) async {
    await bootToday(tester, dark: dark, day: _checkedIn);

    expect(_row(), findsOneWidget);
    // nothing else is planned, so the check-in was the day's one item.
    expect(_onCard(find.text('All done')), findsOneWidget);
    await shot(tester, 'mood_again_timeline_${_theme(dark)}');

    await tester.tap(_row());
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    await shot(tester, 'mood_again_card_${_theme(dark)}');
  });

  scenarioTest('mood after checking in again', (tester, dark) async {
    await bootToday(tester, dark: dark, day: _checkedIn);

    await tester.tap(_row());
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Log mood'));
    await tester.pumpAndSettle();

    // the day stays done; the mood row stays done and reads the new word.
    expect(_onCard(find.text('All done')), findsOneWidget);
    expect(_row(), findsOneWidget);
    await shot(tester, 'mood_after_checking_in_again_${_theme(dark)}');
  });

  scenarioTest('mood only check in again left', (tester, dark) async {
    await bootToday(tester, dark: dark, day: _onlyAgain);

    expect(find.text(_restLead), findsOneWidget);
    expect(_row(), findsOneWidget);
    await shot(tester, 'mood_only_again_${_theme(dark)}');
  });
}
