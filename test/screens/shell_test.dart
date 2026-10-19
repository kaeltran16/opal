import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:opal/analysis/area_state.dart';
import 'package:opal/controllers/areas_controller.dart';
import 'package:opal/screens/areas/areas_screen.dart';
import 'package:opal/screens/detail/detail_screen.dart';
import 'package:opal/screens/move/workout_history_screen.dart';
import 'package:opal/screens/pal/pal_composer_screen.dart';
import 'package:opal/screens/shell/loop_shell.dart';
import 'package:opal/screens/shell/plan_undo_toast.dart';
import 'package:opal/screens/today/today_logic.dart';
import 'package:opal/screens/today/today_screen.dart' show todayCardKey;
import 'package:opal/theme/theme.dart';
import 'package:opal/util/format.dart';
import 'package:opal/widgets/glass_tab_bar.dart';
import 'package:opal/widgets/pal_ask_bar.dart';
import 'package:opal/widgets/session_row.dart';

import '../support/flush_provider_timers.dart';
import '../support/golden_harness.dart' show bootApp;
import '../support/today_fixture.dart';

const _tabLabels = ['Today', 'Areas', 'Workout', 'You'];

Finder get _todayList => find.byType(Scrollable).first;

/// A tab by its label. Areas speaks its off areas after its name.
Finder _tab(String label) => find.descendant(
    of: find.byType(GlassTabBar), matching: find.bySemanticsLabel(RegExp('^$label(,|\$)')));

GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(LoopShell)));

String _path(WidgetTester tester) =>
    _router(tester).routerDelegate.currentConfiguration.uri.path;

// thursday 1 october 2026, half way through the waking day
final _midday = DateTime(2026, 10, 1, 14, 30);

AreasSummary _areas({double spent = 20, int moveKcal = 300}) => buildAreasSummary(
      today: GlanceNumbers(
        spent: spent,
        budget: 60,
        moveKcal: moveKcal,
        moveGoal: 500,
        routinesDone: 2,
        routinesTotal: 4,
        hasRoutines: true,
      ),
      entries: const [],
      meals: const [],
      checkins: const [],
      currency: Currency.usd,
      now: _midday,
    );

Future<void> _bootWith(WidgetTester tester, Stream<AreasSummary> summary) => bootToday(
    tester, overrides: [areasSummaryProvider.overrideWith((ref) => summary)]);

Finder get _areasDot => find.byKey(glassTabDotKey('areas'));

Color? _dotColor(WidgetTester tester) =>
    (tester.widget<DecoratedBox>(_areasDot).decoration as BoxDecoration).color;

AppColors _colors(WidgetTester tester) => tester.element(find.byType(GlassTabBar)).colors;

/// The Areas tab's whole accessible label.
Finder _areasLabel(String label) => find.descendant(
    of: find.byType(GlassTabBar), matching: find.bySemanticsLabel(label));

void main() {
  testWidgets('the tabs carry their semantic labels', (tester) async {
    await bootApp(tester);

    for (final label in _tabLabels) {
      expect(_tab(label), findsOneWidget, reason: label);
    }

    await flushProviderTimers(tester);
  });

  testWidgets('the bar shows Today, Areas, Workout and You in order',
      (tester) async {
    await bootApp(tester);

    final lefts = [for (final label in _tabLabels) tester.getCenter(_tab(label)).dx];
    expect(lefts, orderedEquals([...lefts]..sort()));

    await flushProviderTimers(tester);
  });

  testWidgets('re-tapping Areas on an area page returns to the Areas root',
      (tester) async {
    await bootApp(tester);

    await tester.tap(_tab('Areas'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(RegExp(r'^Money([:,]|$)')));
    await tester.pumpAndSettle();
    expect(find.byType(DetailScreen), findsOneWidget);
    expect(_path(tester), '/areas/money');

    await tester.tap(_tab('Areas'));
    await tester.pumpAndSettle();

    expect(_path(tester), '/areas');
    expect(find.byType(DetailScreen), findsNothing);
    expect(find.byType(AreasScreen), findsOneWidget);

    await flushProviderTimers(tester);
  });

  testWidgets("switching tabs keeps Workout's stack", (tester) async {
    await bootApp(tester);

    await tester.tap(_tab('Workout'));
    await tester.pumpAndSettle();
    _router(tester).go('/move/history');
    await tester.pumpAndSettle();
    expect(find.byType(WorkoutHistoryScreen), findsOneWidget);

    await tester.tap(_tab('Areas'));
    await tester.pumpAndSettle();
    expect(_path(tester), '/areas');
    await tester.tap(_tab('Workout'));
    await tester.pumpAndSettle();

    expect(_path(tester), '/move/history');
    expect(find.byType(WorkoutHistoryScreen), findsOneWidget);

    await flushProviderTimers(tester);
  });

  testWidgets("History and trends' last session row scrolls clear of the ask bar",
      (tester) async {
    await bootApp(tester);
    await tester.tap(_tab('Workout'));
    await tester.pumpAndSettle();
    _router(tester).go('/move/history');
    await tester.pumpAndSettle();

    // a jump, not a drag: the bars stay expanded, the most they cover.
    final list = tester.state<ScrollableState>(find
        .descendant(of: find.byType(WorkoutHistoryScreen), matching: find.byType(Scrollable))
        .first);
    // the lazy list's extent grows as rows build, so jump until it holds.
    var end = -1.0;
    while (list.position.maxScrollExtent != end) {
      end = list.position.maxScrollExtent;
      list.position.jumpTo(end);
      await tester.pumpAndSettle();
    }

    final lastRow = tester.getRect(find
        .descendant(of: find.byType(WorkoutHistoryScreen), matching: find.byType(SessionRow))
        .last);
    expect(lastRow.bottom, lessThanOrEqualTo(tester.getRect(find.byType(PalAskBar)).top));
    expect(kShellOverlay, 132);

    await flushProviderTimers(tester);
  });

  testWidgets('scrolling down minimizes the tab bar and up restores it',
      (tester) async {
    await bootApp(tester);

    await tester.drag(_todayList, const Offset(0, -300));
    await tester.pumpAndSettle();

    // only the active tab's circle is left.
    expect(find.bySemanticsLabel(RegExp('Today tab')), findsOneWidget);
    for (final label in _tabLabels.skip(1)) {
      expect(_tab(label), findsNothing, reason: label);
    }

    await tester.drag(_todayList, const Offset(0, 100));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(RegExp('Today tab')), findsNothing);
    for (final label in _tabLabels) {
      expect(_tab(label), findsOneWidget, reason: label);
    }

    await flushProviderTimers(tester);
  });

  testWidgets('the plan toast sits above the ask bar on Today and on You', (tester) async {
    await bootToday(tester,
        day: const TodayDay(routines: [], workout: false),
        pal: TodayPal(proposals: [proposal('a', 'A'), proposal('b', 'B')]));
    void expectAboveAskBar() {
      expect(find.byKey(planUndoToastKey), findsOneWidget);
      expect(tester.getRect(find.byKey(planUndoToastKey)).bottom,
          lessThan(tester.getRect(find.byType(PalAskBar)).top));
    }

    await tester.tap(find.descendant(of: find.byKey(todayCardKey), matching: find.text('Not now')));
    await tester.pump();
    expectAboveAskBar();

    await tester.tap(_tab('You'));
    await tester.pumpAndSettle();
    final skip = find.bySemanticsLabel('Not now: B');
    await tester.ensureVisible(skip);
    await tester.pumpAndSettle();
    await tester.tap(skip);
    await tester.pump();
    expect(find.text('Put off until tomorrow: B'), findsOneWidget);
    expectAboveAskBar();

    await flushProviderTimers(tester);
  });

  for (final (name, label) in [
    ('ask bar', 'Tell Pal anything'),
    ('mic', 'Dictate'),
  ]) {
    testWidgets('tapping the $name opens the composer sheet', (tester) async {
      await bootApp(tester);
      expect(find.byType(PalComposerSheet), findsNothing);

      await tester.tap(find.bySemanticsLabel(label));
      await tester.pumpAndSettle();

      expect(find.byType(PalComposerSheet), findsOneWidget);

      await flushProviderTimers(tester);
    });
  }

  testWidgets('the ask bar on Workout opens the composer from /move', (tester) async {
    await bootApp(tester);
    await tester.tap(_tab('Workout'));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Tell Pal anything'));
    await tester.pumpAndSettle();

    final sheet = tester.widget<PalComposerSheet>(find.byType(PalComposerSheet));
    expect(sheet.from, '/move');
    expect(find.descendant(of: find.byType(PalComposerSheet), matching: find.text('Workout')),
        findsOneWidget);

    await flushProviderTimers(tester);
  });

  testWidgets('on You the ask bar asks about patterns, and back on Today it does not',
      (tester) async {
    await bootApp(tester);
    await tester.tap(_tab('You'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Ask about your patterns'), findsOneWidget);
    expect(find.bySemanticsLabel('Tell Pal anything'), findsNothing);

    await tester.tap(_tab('Today'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Tell Pal anything'), findsOneWidget);

    await flushProviderTimers(tester);
  });

  testWidgets('the Areas tab shows a watch dot when Money is worth watching',
      (tester) async {
    await _bootWith(tester, Stream.value(_areas(spent: 50)));

    expect(_areasDot, findsOneWidget);
    expect(_dotColor(tester), _colors(tester).watch);
    expect(_areasLabel('Areas, money worth watching'), findsOneWidget);

    await flushProviderTimers(tester);
  });

  testWidgets('the Areas tab shows a care dot when an area needs care',
      (tester) async {
    final summary = _areas(spent: 70, moveKcal: 100);
    expect(summary.tabDot, AreaState.care);
    await _bootWith(tester, Stream.value(summary));

    expect(_dotColor(tester), _colors(tester).care);
    expect(_areasLabel('Areas, money needs care, move worth watching'), findsOneWidget);

    await flushProviderTimers(tester);
  });

  testWidgets('the Areas tab has no dot when every area is on track',
      (tester) async {
    await _bootWith(tester, Stream.value(_areas()));

    expect(_areasDot, findsNothing);
    expect(_areasLabel('Areas'), findsOneWidget);

    await flushProviderTimers(tester);
  });

  for (final (name, summary) in [
    ('loads', () => StreamController<AreasSummary>().stream),
    ('fails', () => Stream<AreasSummary>.error(Exception('db'))),
  ]) {
    testWidgets('while the summary $name the Areas tab is plain', (tester) async {
      await _bootWith(tester, summary());

      expect(_areasDot, findsNothing);
      expect(_areasLabel('Areas'), findsOneWidget);

      await flushProviderTimers(tester);
    });
  }
}
