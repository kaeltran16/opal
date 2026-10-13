@Tags(['scenario'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/analysis/area.dart';
import 'package:opal/screens/areas/areas_screen.dart';
import 'package:opal/screens/detail/detail_screen.dart';
import 'package:opal/screens/move/move_screen.dart';
import 'package:opal/screens/profile/profile_screen.dart';
import 'package:opal/screens/today/today_screen.dart';
import 'package:opal/widgets/activity_rings.dart';
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

Finder _onYou(Finder matching) =>
    find.descendant(of: find.byType(ProfileScreen), matching: matching);

Finder _tab(Pattern label) =>
    find.descendant(of: find.byType(GlassTabBar), matching: find.bySemanticsLabel(label));

/// The end-to-end pass over the merged result: the fully seeded app, as the
/// goldens boot it, from Today to the Areas tab and its Money page, back, then
/// Workout and You.
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

    await tester.tap(_tab(RegExp('^Areas')));
    await tester.pumpAndSettle();

    expect(find.byType(AreasScreen), findsOneWidget);
    expect(find.byType(ActivityRings), findsOneWidget);
    expect(find.text('Also tracked'), findsOneWidget);
    await shot(tester, 'final_areas_$theme');

    await tester.tap(find.bySemanticsLabel(RegExp(r'^Money([:,]|$)')));
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

    await tester.tap(find.bySemanticsLabel('Back to Areas'));
    await tester.pumpAndSettle();
    expect(find.byType(DetailScreen), findsNothing);
    expect(find.byType(AreasScreen), findsOneWidget);

    await tester.tap(_tab('Workout'));
    await tester.pumpAndSettle();
    expect(find.byType(MoveScreen), findsOneWidget);

    await tester.tap(_tab('You'));
    await tester.pumpAndSettle();
    // the Areas group once sat after Goals; bring the rows now there into view.
    final reviews = _onYou(find.text('Reviews'));
    await tester.scrollUntilVisible(
      reviews,
      100,
      scrollable: _onYou(find.byType(Scrollable)).first,
    );
    await tester.pumpAndSettle();
    expect(_onYou(find.text('Budgets')).hitTestable(), findsOneWidget);
    expect(reviews.hitTestable(), findsOneWidget);
    for (final gone in ['AREAS', 'Sleep', 'Mood']) {
      expect(_onYou(find.text(gone)), findsNothing, reason: gone);
    }
    await shot(tester, 'final_you_$theme');
  });
}
