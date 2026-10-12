@Tags(['scenario'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/controllers/spending_controller.dart' show DetailTracker;
import 'package:opal/screens/detail/detail_screen.dart';
import 'package:opal/screens/profile/profile_screen.dart';
import 'package:opal/screens/today/today_screen.dart';
import 'package:opal/widgets/contributor_bar.dart';
import 'package:opal/widgets/day_scene.dart';
import 'package:opal/widgets/glass_tab_bar.dart';
import 'package:opal/widgets/pal_ask_bar.dart';
import 'package:opal/widgets/inset_section.dart';
import 'package:opal/widgets/pal_label.dart';
import 'package:opal/widgets/week_bars.dart';

import '../support/golden_harness.dart';
import 'scenario_harness.dart';

const _dateLine = 'MON 28 SEP · 9:30 AM';
// a third of the way down the viewport: the Areas group sits above the tab bar.
const _areasAlignment = 0.3;

Finder _onToday(Finder matching) =>
    find.descendant(of: find.byType(TodayScreen), matching: matching);

Finder _onPage(Finder matching) =>
    find.descendant(of: find.byType(DetailScreen), matching: matching);

/// The end-to-end pass over the merged result: the fully seeded app, as the
/// goldens boot it, on Today and then on the Money area page, opened from the
/// You tab's Areas group.
void main() {
  scenarioTest('final', (tester, dark) async {
    final theme = dark ? 'dark' : 'light';
    await bootApp(tester, dark: dark);

    expect(
      Theme.of(tester.element(find.byType(TodayScreen))).brightness,
      dark ? Brightness.dark : Brightness.light,
    );
    expect(_onToday(find.text(_dateLine)), findsOneWidget);
    expect(_onToday(find.byType(DayScene)), findsOneWidget);
    for (final area in ['Money', 'Move', 'Routines']) {
      expect(find.bySemanticsLabel(RegExp('^$area: ')), findsNothing);
    }
    expect(
      find.descendant(of: _onToday(find.byType(PalLabel)), matching: find.text('Pal')),
      findsOneWidget,
    );
    expect(_onToday(find.byKey(todayCardKey)), findsOneWidget);
    expect(find.byType(PalAskBar), findsOneWidget);
    expect(find.byType(GlassTabBar), findsOneWidget);
    await shot(tester, 'final_today_$theme');

    await tester.tap(find.bySemanticsLabel('You'));
    await tester.pumpAndSettle();
    final areas = find.text('AREAS');
    await tester.scrollUntilVisible(
      areas,
      200,
      scrollable: find
          .descendant(of: find.byType(ProfileScreen), matching: find.byType(Scrollable))
          .first,
    );
    await Scrollable.ensureVisible(tester.element(areas), alignment: _areasAlignment);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListRow, 'Money'));
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (w) => w is DetailScreen && w.tracker == DetailTracker.money,
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Back to Today'), findsOneWidget);
    expect(_onPage(find.text('Money')), findsOneWidget);
    expect(_onPage(find.text(_dateLine)), findsOneWidget);
    expect(_onPage(find.text('What is shaping it')), findsOneWidget);
    expect(_onPage(find.byType(ContributorBar)), findsWidgets);
    expect(_onPage(find.byType(WeekBars)), findsOneWidget);
    await shot(tester, 'final_area_money_$theme');
  });
}
