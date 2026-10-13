@Tags(['scenario'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/analysis/area.dart';
import 'package:opal/screens/detail/detail_screen.dart';
import 'package:opal/screens/today/today_screen.dart';
import 'package:opal/widgets/contributor_bar.dart';
import 'package:opal/widgets/day_scene.dart';
import 'package:opal/widgets/glass_tab_bar.dart';
import 'package:opal/widgets/pal_ask_bar.dart';
import 'package:opal/widgets/pal_label.dart';
import 'package:opal/widgets/week_bars.dart';

import '../support/golden_harness.dart';
import 'scenario_harness.dart';

const _dateLine = 'MON 28 SEP · 9:30 AM';

Finder _onToday(Finder matching) =>
    find.descendant(of: find.byType(TodayScreen), matching: matching);

Finder _onPage(Finder matching) =>
    find.descendant(of: find.byType(DetailScreen), matching: matching);

/// The end-to-end pass over the merged result: the fully seeded app, as the
/// goldens boot it, on Today and then on the Money area page, opened from the
/// Areas tab.
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

    await tester.tap(find.descendant(
        of: find.byType(GlassTabBar), matching: find.bySemanticsLabel(RegExp('^Areas'))));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(RegExp('^Money')));
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (w) => w is DetailScreen && w.area == Area.money,
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Back to Areas'), findsOneWidget);
    expect(_onPage(find.text('Money')), findsOneWidget);
    expect(_onPage(find.text(_dateLine)), findsOneWidget);
    expect(_onPage(find.text('What is shaping it')), findsOneWidget);
    expect(_onPage(find.byType(ContributorBar)), findsWidgets);
    expect(_onPage(find.byType(WeekBars)), findsOneWidget);
    await shot(tester, 'final_area_money_$theme');
  });
}
