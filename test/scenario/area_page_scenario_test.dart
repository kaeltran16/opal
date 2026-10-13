@Tags(['scenario'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/analysis/area.dart';
import 'package:opal/analysis/area_state.dart';
import 'package:opal/app.dart';
import 'package:opal/controllers/area_detail_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/models/models.dart';
import 'package:opal/screens/areas/areas_screen.dart';
import 'package:opal/screens/detail/detail_screen.dart';
import 'package:opal/screens/nutrition/nutrition_meal_detail_screen.dart';
import 'package:opal/screens/rituals/rituals_builder_screen.dart';
import 'package:opal/screens/rituals/routine_player_screen.dart';
import 'package:opal/widgets/contributor_bar.dart';
import 'package:opal/widgets/glass_tab_bar.dart';
import 'package:opal/widgets/week_bars.dart';

import '../support/golden_harness.dart' show appRouter;
import '../support/today_fixture.dart';
import 'scenario_harness.dart';

const _areas = {
  'money': Area.money,
  'move': Area.move,
  'routines': Area.routines,
};

const _dateLine = 'MON 28 SEP · 9:30 AM';
const _manage = 'Manage routines';
const _addMeal = 'Add a meal';
const _noMeals = 'No meals logged yet today.';
const _noRoutines = 'No routines set up yet.';
const _seedRoutines = ['Morning', 'Midday reset', 'Evening wind-down'];

String _theme(bool dark) => dark ? 'dark' : 'light';

Finder _onPage(Finder matching) =>
    find.descendant(of: find.byType(DetailScreen), matching: matching);

Finder _areaRow(String title) => find.bySemanticsLabel(RegExp('^$title([:,]|\$)'));

Finder get _pageScrollable => _onPage(find.byType(Scrollable)).first;

/// Opens the Areas tab.
Future<void> _toAreas(WidgetTester tester) async {
  await tester.tap(find.descendant(
      of: find.byType(GlassTabBar), matching: find.bySemanticsLabel(RegExp('^Areas'))));
  await tester.pumpAndSettle();
}

/// Opens an area page the way the user does: from its row or card on the
/// Areas tab, scrolled clear of the bars first.
Future<void> _open(WidgetTester tester, Area area) async {
  await _toAreas(tester);
  await tester.ensureVisible(_areaRow(area.title));
  await tester.pumpAndSettle();
  await tester.tap(_areaRow(area.title));
  await tester.pumpAndSettle();
  expect(
    find.byWidgetPredicate((w) => w is DetailScreen && w.area == area),
    findsOneWidget,
  );
}

Future<void> _openMoney(WidgetTester tester) => _open(tester, Area.money);

/// Scrolls the page until [finder] is clear of the bars.
Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200, scrollable: _pageScrollable);
  await tester.pumpAndSettle();
}

/// Back to the top of the page, for the shot.
Future<void> _toTop(WidgetTester tester) async {
  tester.state<ScrollableState>(_pageScrollable).position.jumpTo(0);
  await tester.pumpAndSettle();
}

void main() {
  for (final MapEntry(key: name, value: area) in _areas.entries) {
    scenarioTest('area $name', (tester, dark) async {
      await bootToday(tester, dark: dark, day: const TodayDay(firstRoutineDone: true));
      await _open(tester, area);

      expect(_onPage(find.text(area.title)), findsOneWidget);
      expect(_onPage(find.text(_dateLine)), findsOneWidget);
      expect(_onPage(find.text('What is shaping it')), findsOneWidget);
      expect(_onPage(find.byType(ContributorBar)), findsWidgets);
      // the routines list can push the goal caption below the built rows, so
      // scroll to it, then back to the top for the shot.
      await _reveal(tester, _onPage(find.textContaining('Dashed line: ')));
      expect(_onPage(find.byType(WeekBars)), findsOneWidget);
      expect(_onPage(find.textContaining('Dashed line: ')), findsOneWidget);
      await _toTop(tester);
      await shot(tester, 'area_${name}_${_theme(dark)}');
    });
  }

  scenarioTest('area nutrition', (tester, dark) async {
    await bootToday(tester, dark: dark, day: const TodayDay(meal: true));
    await _open(tester, Area.nutrition);

    expect(_onPage(find.text('345')), findsOneWidget);
    expect(_onPage(find.text('kcal eaten today')), findsOneWidget);
    expect(_onPage(find.text('1 meal logged today.')), findsOneWidget);
    for (final macro in ['Protein', 'Carbs', 'Fat']) {
      expect(_onPage(find.text(macro)), findsOneWidget, reason: macro);
    }
    for (final state in AreaState.values) {
      expect(_onPage(find.text(state.word)), findsNothing, reason: state.word);
    }
    await _reveal(tester, _onPage(find.text(_addMeal)));
    expect(_onPage(find.text("Today's meals")), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(', $mealTitle, 345 kcal\$')), findsOneWidget);
    await _reveal(tester, _onPage(find.byType(WeekBars)));
    expect(_onPage(find.text('Kcal eaten each day')), findsOneWidget);
    expect(_onPage(find.textContaining('Dashed line')), findsNothing);
    await _toTop(tester);
    await shot(tester, 'area_nutrition_${_theme(dark)}');
  });

  scenarioTest('area nutrition empty', (tester, dark) async {
    await bootToday(tester, dark: dark);
    await _open(tester, Area.nutrition);

    expect(_onPage(find.text('0')), findsOneWidget);
    expect(_onPage(find.text('kcal eaten today')), findsOneWidget);
    expect(_onPage(find.text(_noMeals)), findsOneWidget);
    expect(
      tester
          .widgetList<ContributorBar>(_onPage(find.byType(ContributorBar)))
          .map((b) => b.fraction),
      everyElement(0),
    );
    await _reveal(tester, _onPage(find.text(_addMeal)));
    expect(find.bySemanticsLabel(RegExp(', $mealTitle, ')), findsNothing);
    await shot(tester, 'area_nutrition_empty_${_theme(dark)}');
  });

  scenarioTest('area nutrition meal', (tester, dark) async {
    await bootToday(tester, dark: dark, day: const TodayDay(meal: true));
    await _open(tester, Area.nutrition);
    final meal = find.bySemanticsLabel(RegExp(', $mealTitle, '));
    await _reveal(tester, meal);
    await tester.tap(meal);
    await tester.pumpAndSettle();

    expect(find.byType(NutritionMealDetailScreen), findsOneWidget);
    expect(find.text(mealTitle), findsWidgets);
    await shot(tester, 'area_nutrition_meal_${_theme(dark)}');
  });

  scenarioTest('area nutrition add', (tester, dark) async {
    await bootToday(tester, dark: dark, day: const TodayDay(meal: true));
    await _open(tester, Area.nutrition);
    await _reveal(tester, _onPage(find.text(_addMeal)));
    await tester.tap(find.bySemanticsLabel(_addMeal));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    await shot(tester, 'area_nutrition_add_${_theme(dark)}');
  });

  scenarioTest('area routines empty', (tester, dark) async {
    await bootToday(tester, dark: dark, day: const TodayDay(routines: []));
    await _open(tester, Area.routines);

    expect(_onPage(find.text('0')), findsOneWidget);
    expect(_onPage(find.text('routines set up')), findsOneWidget);
    expect(_onPage(find.text(_noRoutines)), findsOneWidget);
    expect(_onPage(find.text('Done')), findsNothing);
    await _reveal(tester, _onPage(find.text(_manage)));
    for (final name in _seedRoutines) {
      expect(_onPage(find.text(name)), findsNothing, reason: name);
    }
    await shot(tester, 'area_routines_empty_${_theme(dark)}');
  });

  scenarioTest('area routines manage', (tester, dark) async {
    await bootToday(tester, dark: dark);
    await _open(tester, Area.routines);
    await _reveal(tester, _onPage(find.text(_manage)));
    await tester.tap(find.bySemanticsLabel(_manage));
    await tester.pumpAndSettle();

    expect(find.byType(RitualsBuilderScreen), findsOneWidget);
    await shot(tester, 'area_routines_manage_${_theme(dark)}');
  });

  scenarioTest('area routines player', (tester, dark) async {
    await bootToday(tester, dark: dark);
    await _open(tester, Area.routines);
    final morning = find.bySemanticsLabel(RegExp('^Morning, at 7:00 AM, \\d+ steps\$'));
    await _reveal(tester, morning);
    await tester.tap(morning);
    await tester.pumpAndSettle();

    expect(find.byType(RoutinePlayerScreen), findsOneWidget);
    await shot(tester, 'area_routines_player_${_theme(dark)}');
  });

  scenarioTest('area sleep', (tester, dark) async {
    await bootToday(tester, dark: dark);
    await _open(tester, Area.sleep);

    expect(_onPage(find.text('Sleep')), findsOneWidget);
    expect(_onPage(find.text('No sleep data yet')), findsOneWidget);
    expect(
      _onPage(find.text('Sleep needs a data source, and none is connected yet.')),
      findsOneWidget,
    );
    expect(_onPage(find.byType(ContributorBar)), findsNothing);
    expect(_onPage(find.byType(WeekBars)), findsNothing);
    await shot(tester, 'area_sleep_${_theme(dark)}');
  });

  scenarioTest('area mood', (tester, dark) async {
    await bootToday(tester, dark: dark, day: const TodayDay(mood: true));
    await _open(tester, Area.mood);

    expect(_onPage(find.text('Slightly pleasant')), findsWidgets);
    expect(_onPage(find.text('at 6:50 AM')), findsOneWidget);
    expect(_onPage(find.text('Last check-in at 6:50 AM.')), findsOneWidget);
    expect(_onPage(find.byType(ContributorBar)), findsOneWidget);
    await _reveal(tester, _onPage(find.byType(WeekBars)));
    expect(_onPage(find.text('Average of each day')), findsOneWidget);
    await _toTop(tester);
    await shot(tester, 'area_mood_${_theme(dark)}');
  });

  scenarioTest('area mood empty', (tester, dark) async {
    await bootToday(tester, dark: dark);
    await _open(tester, Area.mood);

    expect(_onPage(find.text('—')), findsOneWidget);
    expect(_onPage(find.text('No check-in yet today')), findsOneWidget);
    expect(_onPage(find.text('No check-in yet today.')), findsOneWidget);
    expect(_onPage(find.byType(ContributorBar)), findsNothing);
    await shot(tester, 'area_mood_empty_${_theme(dark)}');
  });

  scenarioTest('area money over budget', (tester, dark) async {
    await bootToday(tester, dark: dark, day: const TodayDay(spent: 80));
    await _openMoney(tester);

    expect(_onPage(find.text(AreaState.care.word)), findsOneWidget);
    expect(_onPage(find.textContaining(RegExp('^over .* today\$'))), findsOneWidget);
    expect(
      tester.widgetList<ContributorBar>(_onPage(find.byType(ContributorBar))).first.off,
      isTrue,
    );
    await shot(tester, 'area_money_over_budget_${_theme(dark)}');
  });

  scenarioTest('area money scrolled to the recent entries', (tester, dark) async {
    await bootToday(tester, dark: dark, day: const TodayDay(spent: 32));
    final entries = ProviderScope.containerOf(tester.element(find.byType(LoopApp)))
        .read(entryRepositoryProvider);
    const earlier = [
      (1, 'Bookshop', 18.0),
      (1, 'Bakery', 6.5),
      (2, 'Train ticket', 24.0),
      (2, 'Pharmacy', 11.2),
      (3, 'Hardware store', 9.0),
    ];
    for (final (i, (daysAgo, title, amount)) in earlier.indexed) {
      await entries.insert(Entry(
        id: 'earlier-$i',
        timestamp: DateTime(2026, 9, 28 - daysAgo, 12, i),
        type: EntryType.money,
        title: title,
        amount: -amount,
        source: EntrySource.manual,
      ));
    }
    await tester.pumpAndSettle();
    await _openMoney(tester);

    await _reveal(tester, find.text('Hardware store'));
    expect(_onPage(find.text('Yesterday')), findsOneWidget);
    expect(_onPage(find.text('Bookshop')), findsOneWidget);
    expect(_onPage(find.text('Hardware store')), findsOneWidget);
    expect(_onPage(find.text(_dateLine)), findsNothing);
    await shot(tester, 'area_money_scrolled_${_theme(dark)}');
  });

  scenarioTest('area move empty', (tester, dark) async {
    await bootToday(tester, dark: dark, day: const TodayDay.empty());
    await _open(tester, Area.move);

    expect(_onPage(find.text('kcal burned')), findsOneWidget);
    expect(_onPage(find.text(AreaState.good.word)), findsOneWidget);
    expect(_onPage(find.text('Nothing logged yet.')), findsOneWidget);
    expect(find.textContaining('Dashed line'), findsNothing);
    await shot(tester, 'area_move_empty_${_theme(dark)}');
  });

  scenarioTest('area error', (tester, dark) async {
    await bootToday(tester, dark: dark, overrides: [
      areaDetailProvider
          .overrideWith((ref, area) => Stream.error(StateError('no database'))),
    ]);
    await _openMoney(tester);

    expect(_onPage(find.text("Couldn't load Money.")), findsOneWidget);
    expect(_onPage(find.text(_dateLine)), findsOneWidget);
    expect(find.bySemanticsLabel('Back to Areas'), findsOneWidget);
    expect(_onPage(find.byType(WeekBars)), findsNothing);
    await shot(tester, 'area_error_${_theme(dark)}');
  });

  scenarioTest('area loading', (tester, dark) async {
    final never = StreamController<AreaDetail>();
    addTearDown(never.close);
    await bootToday(tester, dark: dark, overrides: [
      areaDetailProvider.overrideWith((ref, area) => never.stream),
    ]);
    await _openMoney(tester);

    expect(_onPage(find.text('…')), findsOneWidget);
    expect(find.bySemanticsLabel('Back to Areas'), findsOneWidget);
    expect(_onPage(find.byType(WeekBars)), findsNothing);
    await shot(tester, 'area_loading_${_theme(dark)}');
  });

  scenarioTest('area back', (tester, dark) async {
    await bootToday(tester, dark: dark);
    await _openMoney(tester);

    // back pops to the Areas tab, where the page was opened.
    await tester.tap(find.bySemanticsLabel('Back to Areas'));
    await tester.pumpAndSettle();

    expect(find.byType(DetailScreen), findsNothing);
    expect(find.byType(AreasScreen), findsOneWidget);
    await shot(tester, 'area_back_${_theme(dark)}');
  });

  scenarioTest('area deep link nutrition', (tester, dark) async {
    await bootToday(tester, dark: dark, day: const TodayDay(meal: true));
    final router = appRouter(tester);
    router.go('/nutrition');
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.path, '/areas/nutrition');
    expect(
      find.byWidgetPredicate((w) => w is DetailScreen && w.area == Area.nutrition),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Back to Areas'), findsOneWidget);
    await shot(tester, 'area_deep_link_nutrition_${_theme(dark)}');
  });
}
