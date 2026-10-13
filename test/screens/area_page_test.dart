import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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
import 'package:opal/theme/theme.dart';
import 'package:opal/util/format.dart';
import 'package:opal/widgets/contributor_bar.dart';
import 'package:opal/widgets/day_scene.dart';
import 'package:opal/widgets/glass_tab_bar.dart';
import 'package:opal/widgets/pal_label.dart';
import 'package:opal/widgets/week_bars.dart';

import '../support/flush_provider_timers.dart';
import '../support/golden_harness.dart' show appRouter;
import '../support/today_fixture.dart';

final _monday = Clock.fixed(DateTime(2026, 9, 28, 9, 30));

const _longTitle = 'Groceries for the whole week and the dinner party on Saturday night';

/// Areas with a provider behind the page: every one but Sleep.
final _detailAreas = Area.values.where((a) => a != Area.sleep);

/// A day with a meal and a check-in, so every page has something to show.
const _fullDay = TodayDay(meal: true, mood: true, firstRoutineDone: true);

Finder _onPage(Finder matching) =>
    find.descendant(of: find.byType(DetailScreen), matching: matching);

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(LoopApp)));

Currency _currency(WidgetTester tester) =>
    _container(tester).read(appSettingsControllerProvider).currency;

String _path(WidgetTester tester) =>
    appRouter(tester).routerDelegate.currentConfiguration.uri.path;

/// Boots Today on a surface tall enough that the whole page is built.
Future<void> _boot(
  WidgetTester tester, {
  TodayDay day = const TodayDay(),
  bool strictLayout = false,
}) async {
  tester.view.physicalSize = const Size(390, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await bootToday(tester, day: day, strictLayout: strictLayout);
}

/// Opens [area]'s page from the Areas tab.
Future<void> _openPage(WidgetTester tester, Area area) async {
  await tester.tap(find.descendant(
      of: find.byType(GlassTabBar), matching: find.bySemanticsLabel(RegExp('^Areas'))));
  await tester.pumpAndSettle();
  await tester.tap(find.bySemanticsLabel(RegExp('^${area.title}')));
  await tester.pumpAndSettle();
  expect(
    find.byWidgetPredicate((w) => w is DetailScreen && w.area == area),
    findsOneWidget,
  );
}

/// Opens [area]'s page and returns what the provider gave it.
Future<AreaDetail> _open(WidgetTester tester, Area area) async {
  await _openPage(tester, area);
  return _container(tester).read(areaDetailProvider(area)).requireValue;
}

Future<void> _insert(WidgetTester tester, Entry entry) async {
  await _container(tester).read(entryRepositoryProvider).insert(entry);
  await tester.pumpAndSettle();
}

Entry _spend(String id, DateTime at, String title, double amount) => Entry(
      id: id,
      timestamp: at,
      type: EntryType.money,
      title: title,
      amount: -amount,
      source: EntrySource.manual,
    );

void _expectNoStateWord() {
  for (final state in AreaState.values) {
    expect(_onPage(find.text(state.word)), findsNothing, reason: state.word);
  }
}

void _pageTest(String name, Future<void> Function(WidgetTester tester) body) {
  testWidgets(name, (tester) async {
    await withClock(_monday, () async {
      try {
        await body(tester);
      } finally {
        // a failed expectation must still flush, or the next test hangs.
        await flushProviderTimers(tester);
      }
    });
  });
}

void main() {
  for (final area in Area.values) {
    _pageTest('${area.name}: back reads Areas, the scene is drawn, and back pops to Areas',
        (tester) async {
      await _boot(tester, day: _fullDay);
      await _openPage(tester, area);

      expect(_onPage(find.text(area.title)), findsOneWidget);
      expect(_onPage(find.text('Areas')), findsOneWidget);
      expect(_onPage(find.byType(DayScene)), findsOneWidget);
      expect(_onPage(find.text('MON 28 SEP · 9:30 AM')), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Back to Areas'));
      await tester.pumpAndSettle();

      expect(find.byType(DetailScreen), findsNothing);
      expect(find.byType(AreasScreen), findsOneWidget);
      expect(_path(tester), '/areas');
    });
  }

  for (final area in _detailAreas) {
    _pageTest('${area.name}: the page shows what the provider gives', (tester) async {
      await _boot(tester, day: _fullDay);
      final detail = await _open(tester, area);
      final lists = area == Area.nutrition || area == Area.routines ? 1 : 0;

      expect(
        _onPage(find.byWidgetPredicate((w) => w is Semantics && w.properties.header == true)),
        findsNWidgets(3 + lists),
      );
      expect(_onPage(find.text(detail.hero)), findsWidgets);
      expect(_onPage(find.text(detail.unit)), findsOneWidget);
      final state = detail.state;
      if (area.hasStateRule) {
        expect(_onPage(find.text(state!.word)), findsOneWidget);
      } else {
        expect(state, isNull);
        _expectNoStateWord();
      }
      expect(_onPage(find.byType(PalLabel)), findsOneWidget);
      expect(_onPage(find.text(detail.palLine)), findsOneWidget);

      expect(detail.contributors, isNotEmpty);
      final bars = tester.widgetList<ContributorBar>(_onPage(find.byType(ContributorBar)));
      expect(
        [for (final b in bars) (b.label, b.value, b.fraction, b.off)],
        [for (final p in detail.contributors) (p.label, p.value, p.fraction, p.off)],
      );

      expect(_onPage(find.text('This week')), findsOneWidget);
      expect(_onPage(find.text(detail.weekNote)), findsOneWidget);
      final week = tester.widget<WeekBars>(_onPage(find.byType(WeekBars)));
      expect(week.values, [for (final b in detail.week) b.value]);
      expect(week.goal, detail.goal);
      expect(week.todayIndex, 0);
      if (detail.goal > 0) {
        expect(_onPage(find.text('Dashed line: ${detail.goalLabel}')), findsOneWidget);
      } else {
        expect(_onPage(find.textContaining('Dashed line')), findsNothing);
      }
    });
  }

  _pageTest('money: the numbers on the page are the seeded day\'s', (tester) async {
    await _boot(tester);
    await _open(tester, Area.money);
    String money(num v) => formatCurrency(v, _currency(tester));

    expect(_onPage(find.text(money(54.25))), findsOneWidget);
    expect(_onPage(find.text('left of ${money(60)} today')), findsOneWidget);
    expect(_onPage(find.text('${money(5.75)} of ${money(60)}')), findsOneWidget);
    expect(_onPage(find.text('Dashed line: ${money(60)} daily budget')), findsOneWidget);

    // today's short bar stands on the same floor as the empty days' stubs.
    final bars = find.descendant(of: find.byType(WeekBars), matching: find.byType(DecoratedBox));
    expect(tester.getSize(bars.at(0)).height, 6);
    expect(tester.getBottomLeft(bars.at(0)).dy, tester.getBottomLeft(bars.at(6)).dy);
  });

  _pageTest('an on-track area shows On track in ink3', (tester) async {
    await _boot(tester);
    final detail = await _open(tester, Area.money);

    expect(detail.state, AreaState.good);
    final word = tester.widget<Text>(_onPage(find.text('On track')));
    expect(word.style!.color, tester.element(find.byType(DetailScreen)).colors.ink3);
  });

  _pageTest('the header shows no + button and no Ask Pal', (tester) async {
    await _boot(tester);
    await _open(tester, Area.move);

    expect(find.bySemanticsLabel('Add entry'), findsNothing);
    expect(find.textContaining('Ask Pal about'), findsNothing);
  });

  _pageTest('nutrition: a meal row opens its detail under the page', (tester) async {
    await _boot(tester, day: _fullDay);
    final detail = await _open(tester, Area.nutrition);

    expect(detail.meals.map((m) => m.name), [mealTitle]);
    expect(_onPage(find.text("Today's meals")), findsOneWidget);
    expect(_onPage(find.text(mealTitle)), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(RegExp('^Breakfast at 06:40, $mealTitle, ')));
    await tester.pumpAndSettle();

    final page = find.byType(NutritionMealDetailScreen);
    expect(page, findsOneWidget);
    // a pushed page keeps the shell's location, so read the page's own state.
    expect(GoRouterState.of(tester.element(page)).uri.path, '/areas/nutrition/meal/meal-today');
  });

  _pageTest('nutrition: Add a meal opens the add sheet', (tester) async {
    await _boot(tester, day: _fullDay);
    await _open(tester, Area.nutrition);

    await tester.tap(find.bySemanticsLabel('Add a meal'));
    await tester.pumpAndSettle();

    expect(find.text('OR PICK A COMMON ONE'), findsOneWidget);
  });

  _pageTest('nutrition with no meals today: zero, the empty line, and Add a meal',
      (tester) async {
    await _boot(tester);
    final detail = await _open(tester, Area.nutrition);

    expect(detail.meals, isEmpty);
    expect(_onPage(find.text('0')), findsOneWidget);
    expect(_onPage(find.text('kcal eaten today')), findsOneWidget);
    expect(_onPage(find.text('No meals logged yet today.')), findsOneWidget);
    expect(
      tester.widgetList<ContributorBar>(_onPage(find.byType(ContributorBar))).map((b) => b.fraction),
      [0, 0, 0],
    );
    expect(_onPage(find.text('Add a meal')), findsOneWidget);
    _expectNoStateWord();
  });

  _pageTest('routines: an open row starts its player, a done row does nothing',
      (tester) async {
    await _boot(tester, day: _fullDay);
    final detail = await _open(tester, Area.routines);
    final done = detail.routines.first;
    final open = detail.routines[1];

    expect(done.done, isTrue);
    expect(open.done, isFalse);
    expect(_onPage(find.text("Today's routines")), findsOneWidget);
    for (final row in detail.routines) {
      expect(_onPage(find.text(row.detail)), findsWidgets, reason: row.name);
    }

    await tester.tap(find.bySemanticsLabel(done.semanticLabel));
    await tester.pumpAndSettle();
    expect(find.byType(RoutinePlayerScreen), findsNothing);
    expect(find.byType(DetailScreen), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(open.semanticLabel));
    await tester.pumpAndSettle();
    final player = find.byType(RoutinePlayerScreen);
    expect(player, findsOneWidget);
    expect(tester.widget<RoutinePlayerScreen>(player).routineId, open.id);
  });

  _pageTest('routines: Manage routines opens the builder under the page', (tester) async {
    await _boot(tester, day: _fullDay);
    await _open(tester, Area.routines);

    await tester.tap(find.bySemanticsLabel('Manage routines'));
    await tester.pumpAndSettle();

    expect(find.byType(RitualsBuilderScreen), findsOneWidget);
    expect(_path(tester), '/areas/routines/manage');
  });

  _pageTest('routines with none set up: no rows, but Manage routines', (tester) async {
    await _boot(tester, day: const TodayDay.empty());
    final detail = await _open(tester, Area.routines);

    expect(detail.routines, isEmpty);
    expect(_onPage(find.text('routines set up')), findsOneWidget);
    expect(_onPage(find.text('No routines set up yet.')), findsOneWidget);
    expect(_onPage(find.byType(ContributorBar)), findsNothing);
    expect(_onPage(find.text('Manage routines')), findsOneWidget);
  });

  _pageTest('mood: the latest check-in, and no recent entries', (tester) async {
    await _boot(tester, day: _fullDay);
    await _open(tester, Area.mood);

    expect(_onPage(find.text('Slightly pleasant')), findsWidgets);
    expect(_onPage(find.text('at 6:50 AM')), findsOneWidget);
    expect(_onPage(find.text('Last check-in at 6:50 AM.')), findsOneWidget);
  });

  _pageTest('mood with no check-in today', (tester) async {
    await _boot(tester);
    final detail = await _open(tester, Area.mood);

    expect(detail.contributors, isEmpty);
    expect(_onPage(find.text('—')), findsOneWidget);
    expect(_onPage(find.text('No check-in yet today')), findsOneWidget);
    expect(_onPage(find.text('No check-in yet today.')), findsOneWidget);
    expect(_onPage(find.text('What is shaping it')), findsNothing);
    _expectNoStateWord();
  });

  _pageTest('sleep shows its empty state and nothing else', (tester) async {
    await _boot(tester, day: _fullDay);
    await _openPage(tester, Area.sleep);

    expect(_onPage(find.text('No sleep data yet')), findsOneWidget);
    expect(_onPage(find.text('Sleep needs a data source, and none is connected yet.')),
        findsOneWidget);
    expect(_onPage(find.byType(WeekBars)), findsNothing);
    expect(_onPage(find.byType(PalLabel)), findsNothing);
    _expectNoStateWord();
  });

  for (final area in [Area.nutrition, Area.mood]) {
    _pageTest('${area.name}: no recent entries list', (tester) async {
      await _boot(tester, day: _fullDay);
      await _open(tester, area);

      expect(_onPage(find.text('Nothing logged yet.')), findsNothing);
      expect(_onPage(find.byType(Dismissible)), findsNothing);
      expect(_onPage(find.text('Today')), findsNothing);
      expect(_onPage(find.text(receiptTitle)), findsNothing);
    });
  }

  _pageTest('money: recent entries are grouped by day, newest day first', (tester) async {
    await _boot(tester);
    await _insert(tester, _spend('y1', DateTime(2026, 9, 27, 12), 'Bookshop', 18));
    await _insert(tester, _spend('o1', DateTime(2026, 9, 20, 12), 'Hardware store', 9));
    await _open(tester, Area.money);
    String money(num v) => formatCurrency(v, _currency(tester));

    double top(String text) => tester.getTopLeft(_onPage(find.text(text)).last).dy;
    expect(_onPage(find.text('Today')), findsOneWidget);
    expect(top('Today'), lessThan(top(receiptTitle)));
    expect(top(receiptTitle), lessThan(top('Yesterday')));
    expect(top('Yesterday'), lessThan(top('Bookshop')));
    expect(top('Bookshop'), lessThan(top('Sep 20')));
    expect(top('Sep 20'), lessThan(top('Hardware store')));
    expect(_onPage(find.text(money(18))), findsOneWidget);
    expect(find.text('Nothing logged yet.'), findsNothing);
  });

  _pageTest('swiping an entry away and confirming deletes it', (tester) async {
    await _boot(tester);
    await _open(tester, Area.money);

    await tester.drag(_onPage(find.text(receiptTitle)), const Offset(-360, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(_onPage(find.text(receiptTitle)), findsNothing);
    expect(_onPage(find.text('Nothing logged yet.')), findsOneWidget);
  });

  _pageTest('with no entries the page says so', (tester) async {
    await _boot(tester);
    await _open(tester, Area.routines);

    expect(_onPage(find.text('Nothing logged yet.')), findsOneWidget);
    expect(_onPage(find.byType(Dismissible)), findsNothing);
  });

  _pageTest('over budget: the hero is the overage, Needs care, the first bar off',
      (tester) async {
    await _boot(tester, day: const TodayDay(spent: 80));
    final detail = await _open(tester, Area.money);
    String money(num v) => formatCurrency(v, _currency(tester));

    expect(detail.hero, money(25.75));
    expect(_onPage(find.text(money(25.75))), findsOneWidget);
    expect(_onPage(find.text('over ${money(60)} today')), findsOneWidget);
    final word = tester.widget<Text>(_onPage(find.text('Needs care')));
    expect(word.style!.color, tester.element(find.byType(DetailScreen)).colors.careInk);
    final bars = tester.widgetList<ContributorBar>(_onPage(find.byType(ContributorBar)));
    expect(bars.first.off, isTrue);
    expect(bars.skip(1).any((b) => b.off), isFalse);
  });

  for (final area in Area.values.where((a) => a.hasStateRule)) {
    _pageTest('${area.name}: with no goal there is no goal caption and no exception',
        (tester) async {
      await _boot(tester, day: const TodayDay.empty(), strictLayout: true);
      final detail = await _open(tester, area);

      expect(tester.takeException(), isNull);
      expect(detail.goal, 0);
      // a hero of zero reads the same as its contributor's value.
      expect(_onPage(find.text(detail.hero)), findsWidgets);
      expect(_onPage(find.text('On track')), findsOneWidget);
      expect(tester.widget<WeekBars>(_onPage(find.byType(WeekBars))).goal, 0);
      expect(find.textContaining('Dashed line'), findsNothing);
      expect(_onPage(find.text('Nothing logged yet.')), findsOneWidget);
    });
  }

  _pageTest('a long entry title at text scale 1.3 on a 390 wide surface does not overflow',
      (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _boot(tester, strictLayout: true);
    await _insert(tester, _spend('long', DateTime(2026, 9, 28, 8), _longTitle, 1234.56));
    // by route: only the page's layout is under test, not the Areas tab's.
    appRouter(tester).go('/today/spending');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final title = _onPage(find.text(_longTitle));
    expect(title, findsOneWidget);
    expect(tester.getSize(title).width, lessThan(390));
  });
}
