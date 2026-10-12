import 'package:clock/clock.dart';
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
import 'package:opal/theme/theme.dart';
import 'package:opal/util/format.dart';
import 'package:opal/widgets/contributor_bar.dart';
import 'package:opal/widgets/inset_section.dart';
import 'package:opal/widgets/pal_label.dart';
import 'package:opal/widgets/week_bars.dart';

import '../support/flush_provider_timers.dart';
import '../support/golden_harness.dart' show appRouter;
import '../support/today_fixture.dart';

final _monday = Clock.fixed(DateTime(2026, 9, 28, 9, 30));

const _areaTitle = {
  DetailTracker.money: 'Money',
  DetailTracker.move: 'Move',
  DetailTracker.rituals: 'Routines',
};

const _longTitle = 'Groceries for the whole week and the dinner party on Saturday night';

Finder _onPage(Finder matching) =>
    find.descendant(of: find.byType(DetailScreen), matching: matching);

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(LoopApp)));

Currency _currency(WidgetTester tester) =>
    _container(tester).read(appSettingsControllerProvider).currency;

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

/// Opens [tracker]'s page from its row in the You tab's Areas group, and
/// returns what the provider gave the page.
Future<AreaDetail> _open(WidgetTester tester, DetailTracker tracker) async {
  await tester.tap(find.bySemanticsLabel('You'));
  await tester.pumpAndSettle();
  final row = find.widgetWithText(ListRow, _areaTitle[tracker]!);
  await tester.ensureVisible(row);
  await tester.pumpAndSettle();
  await tester.tap(row);
  await tester.pumpAndSettle();
  expect(
    find.byWidgetPredicate((w) => w is DetailScreen && w.tracker == tracker),
    findsOneWidget,
  );
  return _container(tester).read(areaDetailProvider(tracker)).requireValue;
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
  for (final tracker in DetailTracker.values) {
    _pageTest('${tracker.name}: the page shows what buildAreaDetail gives', (tester) async {
      await _boot(tester);
      final detail = await _open(tester, tracker);

      expect(
        _onPage(find.byWidgetPredicate((w) => w is Semantics && w.properties.header == true)),
        findsNWidgets(3),
      );
      expect(_onPage(find.text(_areaTitle[tracker]!)), findsOneWidget);
      expect(_onPage(find.text(detail.hero)), findsOneWidget);
      expect(_onPage(find.text(detail.unit)), findsOneWidget);
      expect(_onPage(find.text(detail.state.word)), findsOneWidget);
      expect(_onPage(find.byType(PalLabel)), findsOneWidget);
      expect(_onPage(find.text(detail.palLine)), findsOneWidget);

      expect(detail.contributors, isNotEmpty);
      final bars = tester.widgetList<ContributorBar>(_onPage(find.byType(ContributorBar)));
      expect(
        [for (final b in bars) (b.label, b.value, b.fraction, b.off)],
        [for (final p in detail.contributors) (p.label, p.value, p.fraction, p.off)],
      );
      for (final part in detail.contributors) {
        expect(_onPage(find.text(part.label)), findsOneWidget);
        // a category's amount can also be an entry's, lower down.
        expect(_onPage(find.text(part.value)), findsWidgets);
      }

      expect(_onPage(find.text('This week')), findsOneWidget);
      expect(_onPage(find.text(detail.weekNote)), findsOneWidget);
      final week = tester.widget<WeekBars>(_onPage(find.byType(WeekBars)));
      expect(week.values, [for (final b in detail.week) b.value]);
      expect(week.goal, detail.goal);
      expect(week.todayIndex, 0);
      expect(detail.goalLabel, isNotEmpty);
      expect(_onPage(find.text('Dashed line: ${detail.goalLabel}')), findsOneWidget);
    });
  }

  _pageTest('money: the numbers on the page are the seeded day\'s', (tester) async {
    await _boot(tester);
    await _open(tester, DetailTracker.money);
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
    final detail = await _open(tester, DetailTracker.money);

    expect(detail.state, AreaState.good);
    final word = tester.widget<Text>(_onPage(find.text('On track')));
    expect(word.style!.color, tester.element(find.byType(DetailScreen)).colors.ink3);
  });

  _pageTest('the header shows the date line and no + button, and back returns to Today',
      (tester) async {
    await _boot(tester);
    await _open(tester, DetailTracker.move);

    expect(_onPage(find.text('MON 28 SEP · 9:30 AM')), findsOneWidget);
    expect(find.bySemanticsLabel('Add entry'), findsNothing);
    expect(find.textContaining('Ask Pal about'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Back to Today'));
    await tester.pumpAndSettle();

    expect(find.byType(DetailScreen), findsNothing);
    expect(find.byType(TodayScreen), findsOneWidget);
    expect(find.text('MON 28 SEP · 9:30 AM'), findsOneWidget);
  });

  _pageTest('recent entries are grouped by day, newest day first', (tester) async {
    await _boot(tester);
    await _insert(tester, _spend('y1', DateTime(2026, 9, 27, 12), 'Bookshop', 18));
    await _insert(tester, _spend('o1', DateTime(2026, 9, 20, 12), 'Hardware store', 9));
    await _open(tester, DetailTracker.money);
    String money(num v) => formatCurrency(v, _currency(tester));

    double top(String text) => tester.getTopLeft(_onPage(find.text(text)).last).dy;
    // the back button also reads Today; the day header is the lower one.
    expect(_onPage(find.text('Today')), findsNWidgets(2));
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
    await _open(tester, DetailTracker.money);

    await tester.drag(_onPage(find.text(receiptTitle)), const Offset(-360, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(_onPage(find.text(receiptTitle)), findsNothing);
    expect(_onPage(find.text('Nothing logged yet.')), findsOneWidget);
  });

  _pageTest('with no entries the page says so', (tester) async {
    await _boot(tester);
    await _open(tester, DetailTracker.rituals);

    expect(_onPage(find.text('Nothing logged yet.')), findsOneWidget);
    expect(_onPage(find.byType(Dismissible)), findsNothing);
  });

  _pageTest('over budget: the hero is the overage, Needs care, the first bar off',
      (tester) async {
    await _boot(tester, day: const TodayDay(spent: 80));
    final detail = await _open(tester, DetailTracker.money);
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

  for (final tracker in DetailTracker.values) {
    _pageTest('${tracker.name}: with no goal there is no goal caption and no exception',
        (tester) async {
      await _boot(tester, day: const TodayDay.empty(), strictLayout: true);
      final detail = await _open(tester, tracker);

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
    // by route: only the page's layout is under test, not the You tab's.
    appRouter(tester).go('/today/spending');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final title = _onPage(find.text(_longTitle));
    expect(title, findsOneWidget);
    expect(tester.getSize(title).width, lessThan(390));
  });
}
