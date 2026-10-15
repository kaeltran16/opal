@Tags(['scenario'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:opal/screens/today/today_screen.dart';

import '../support/today_fixture.dart';
import 'scenario_harness.dart';

const _again = 'Check in again';
const _restLead = 'Nothing is left. Rest up.';

/// Checked in this morning with no routines or workout: only a meal is left.
const _checkedIn = TodayDay(routines: [], workout: false, mood: true);

/// Checked in and fed, so the only thing still listed is Check in again.
const _onlyAgain = TodayDay(routines: [], workout: false, mood: true, meal: true);

String _theme(bool dark) => dark ? 'dark' : 'light';

Finder _onToday(Finder matching) =>
    find.descendant(of: find.byType(TodayScreen), matching: matching);

Finder _row() => find.bySemanticsLabel('$_again, any time. Do this next');

void main() {
  scenarioTest('mood check in again', (tester, dark) async {
    await bootToday(tester, dark: dark, day: _checkedIn);

    expect(_row(), findsOneWidget);
    await shot(tester, 'mood_again_timeline_${_theme(dark)}');

    await tester.tap(_row());
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byKey(todayCardKey), matching: find.text(_again)),
      findsOneWidget,
    );
    expect(_onToday(find.text('Check in')), findsOneWidget);
    await shot(tester, 'mood_again_card_${_theme(dark)}');
  });

  scenarioTest('mood only check in again left', (tester, dark) async {
    await bootToday(tester, dark: dark, day: _onlyAgain);

    expect(find.text(_restLead), findsOneWidget);
    expect(_row(), findsOneWidget);
    await shot(tester, 'mood_only_again_${_theme(dark)}');
  });
}
