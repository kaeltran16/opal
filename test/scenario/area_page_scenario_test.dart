@Tags(['scenario'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/analysis/area_state.dart';
import 'package:opal/app.dart';
import 'package:opal/controllers/area_detail_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/controllers/spending_controller.dart' show DetailTracker;
import 'package:opal/models/models.dart';
import 'package:opal/screens/detail/detail_screen.dart';
import 'package:opal/screens/today/today_screen.dart';
import 'package:opal/widgets/contributor_bar.dart';
import 'package:opal/widgets/shortcut_ring.dart';
import 'package:opal/widgets/week_bars.dart';

import '../support/today_fixture.dart';
import 'scenario_harness.dart';

const _areas = {
  'money': (DetailTracker.money, 'Money'),
  'move': (DetailTracker.move, 'Move'),
  'routines': (DetailTracker.rituals, 'Routines'),
};

const _dateLine = 'MON 28 SEP · 9:30 AM';

String _theme(bool dark) => dark ? 'dark' : 'light';

Finder _onPage(Finder matching) =>
    find.descendant(of: find.byType(DetailScreen), matching: matching);

/// Opens an area page the way the user does: by tapping its ring on Today.
Future<void> _open(WidgetTester tester, DetailTracker tracker, String title) async {
  await tester.tap(find.bySemanticsLabel(RegExp('^$title: ')));
  await tester.pumpAndSettle();
  expect(
    find.byWidgetPredicate((w) => w is DetailScreen && w.tracker == tracker),
    findsOneWidget,
  );
}

Future<void> _openMoney(WidgetTester tester) => _open(tester, DetailTracker.money, 'Money');

void main() {
  for (final MapEntry(key: name, value: (tracker, title)) in _areas.entries) {
    scenarioTest('area $name', (tester, dark) async {
      await bootToday(tester, dark: dark, day: const TodayDay(firstRoutineDone: true));
      await _open(tester, tracker, title);

      expect(_onPage(find.text(title)), findsOneWidget);
      expect(_onPage(find.text(_dateLine)), findsOneWidget);
      expect(_onPage(find.text('What is shaping it')), findsOneWidget);
      expect(_onPage(find.byType(ContributorBar)), findsWidgets);
      expect(_onPage(find.byType(WeekBars)), findsOneWidget);
      expect(_onPage(find.textContaining('Dashed line: ')), findsOneWidget);
      await shot(tester, 'area_${name}_${_theme(dark)}');
    });
  }

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

    await tester.scrollUntilVisible(
      find.text('Hardware store'),
      200,
      scrollable: _onPage(find.byType(Scrollable)).first,
    );
    await tester.pumpAndSettle();
    expect(_onPage(find.text('Yesterday')), findsOneWidget);
    expect(_onPage(find.text('Bookshop')), findsOneWidget);
    expect(_onPage(find.text('Hardware store')), findsOneWidget);
    expect(_onPage(find.text(_dateLine)), findsNothing);
    await shot(tester, 'area_money_scrolled_${_theme(dark)}');
  });

  scenarioTest('area move empty', (tester, dark) async {
    await bootToday(tester, dark: dark, day: const TodayDay.empty());
    await _open(tester, DetailTracker.move, 'Move');

    expect(_onPage(find.text('kcal burned')), findsOneWidget);
    expect(_onPage(find.text(AreaState.good.word)), findsOneWidget);
    expect(_onPage(find.text('Nothing logged yet.')), findsOneWidget);
    expect(find.textContaining('Dashed line'), findsNothing);
    await shot(tester, 'area_move_empty_${_theme(dark)}');
  });

  scenarioTest('area error', (tester, dark) async {
    await bootToday(tester, dark: dark, overrides: [
      areaDetailProvider
          .overrideWith((ref, tracker) => Stream.error(StateError('no database'))),
    ]);
    await _openMoney(tester);

    expect(_onPage(find.text("Couldn't load Spending.")), findsOneWidget);
    expect(_onPage(find.text(_dateLine)), findsOneWidget);
    expect(find.bySemanticsLabel('Back to Today'), findsOneWidget);
    expect(_onPage(find.byType(WeekBars)), findsNothing);
    await shot(tester, 'area_error_${_theme(dark)}');
  });

  scenarioTest('area loading', (tester, dark) async {
    final never = StreamController<AreaDetail>();
    addTearDown(never.close);
    await bootToday(tester, dark: dark, overrides: [
      areaDetailProvider.overrideWith((ref, tracker) => never.stream),
    ]);
    await _openMoney(tester);

    expect(_onPage(find.text('…')), findsOneWidget);
    expect(find.bySemanticsLabel('Back to Today'), findsOneWidget);
    expect(_onPage(find.byType(WeekBars)), findsNothing);
    await shot(tester, 'area_loading_${_theme(dark)}');
  });

  scenarioTest('area back', (tester, dark) async {
    await bootToday(tester, dark: dark);
    await _openMoney(tester);

    await tester.tap(find.bySemanticsLabel('Back to Today'));
    await tester.pumpAndSettle();

    expect(find.byType(DetailScreen), findsNothing);
    expect(find.byType(TodayScreen), findsOneWidget);
    expect(find.byType(ShortcutRing), findsNWidgets(3));
    expect(find.text(_dateLine), findsOneWidget);
    await shot(tester, 'area_back_${_theme(dark)}');
  });
}
