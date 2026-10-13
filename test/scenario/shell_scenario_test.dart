@Tags(['scenario'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:opal/analysis/area_state.dart';
import 'package:opal/screens/areas/areas_screen.dart';
import 'package:opal/screens/detail/detail_screen.dart';
import 'package:opal/screens/pal/pal_composer_screen.dart';
import 'package:opal/theme/theme.dart';
import 'package:opal/widgets/glass_tab_bar.dart';
import 'package:opal/widgets/pal_ask_bar.dart';
import 'package:opal/widgets/state_colors.dart';

import '../support/golden_harness.dart';
import '../support/today_fixture.dart';
import 'scenario_harness.dart';

const _askLabel = 'Tell Pal anything';
const _tabs = ['Today', 'Areas', 'Workout', 'You'];

/// Hand spends on top of the receipt's 5.75: $30 of $60 by 9:30 is worth
/// watching.
const _spendWatch = 24.25;
const _fullHistory = 14;

Finder _inTabBar(Finder matching) =>
    find.descendant(of: find.byType(GlassTabBar), matching: matching);

Finder get _areasTab => _inTabBar(find.bySemanticsLabel(RegExp('^Areas')));

Finder get _areasDot => find.byKey(glassTabDotKey('areas'));

void main() {
  scenarioTest('shell bars', (tester, dark) async {
    final theme = dark ? 'dark' : 'light';
    await bootApp(tester, dark: dark);

    await tester.tap(_inTabBar(find.text('Workout')));
    await tester.pumpAndSettle();

    final handle = tester.ensureSemantics();
    expect(
      tester.getSemantics(_inTabBar(find.bySemanticsLabel('Workout'))),
      isSemantics(label: 'Workout', isButton: true, isSelected: true),
    );
    handle.dispose();
    for (final tab in _tabs) {
      expect(_inTabBar(find.text(tab)), findsOneWidget, reason: tab);
    }
    final lefts = [for (final tab in _tabs) tester.getTopLeft(_inTabBar(find.text(tab))).dx];
    expect(lefts, orderedEquals([...lefts]..sort()));
    expect(find.byType(PalAskBar), findsOneWidget);
    expect(find.text(_askLabel), findsOneWidget);
    await shot(tester, 'shell_bars_$theme');

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(RegExp('Workout tab')), findsOneWidget);
    expect(_inTabBar(find.text('Today')), findsNothing);
    expect(find.byType(PalAskBar), findsOneWidget);
    await shot(tester, 'shell_minimized_$theme');

    await tester.tap(find.bySemanticsLabel(_askLabel));
    await tester.pumpAndSettle();

    expect(find.byType(PalComposerSheet), findsOneWidget);
    await shot(tester, 'shell_composer_$theme');
  });

  scenarioTest('shell minimized dot', (tester, dark) async {
    final theme = dark ? 'dark' : 'light';
    await bootToday(tester,
        dark: dark, day: const TodayDay(spent: _spendWatch, historyDays: _fullHistory));
    await tester.tap(_areasTab);
    await tester.pumpAndSettle();

    await tester.drag(
      find.descendant(of: find.byType(AreasScreen), matching: find.byType(Scrollable)).first,
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel('Areas, money worth watching tab, expand tab bar'),
      findsOneWidget,
    );
    expect(_inTabBar(find.text('Today')), findsNothing);
    expect(_areasDot, findsOneWidget);
    expect(
      (tester.widget<DecoratedBox>(_areasDot).decoration as BoxDecoration).color,
      tester.element(_areasDot).colors.arcFor(AreaState.watch),
    );
    await shot(tester, 'shell_minimized_dot_$theme');
  });

  scenarioTest('shell retap areas', (tester, dark) async {
    final theme = dark ? 'dark' : 'light';
    await bootToday(tester, dark: dark);
    await tester.tap(_areasTab);
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(RegExp(r'^Move([:,]|$)')));
    await tester.pumpAndSettle();
    expect(find.byType(DetailScreen), findsOneWidget);

    // tapping the active tab returns to its root.
    await tester.tap(_areasTab);
    await tester.pumpAndSettle();

    expect(find.byType(DetailScreen), findsNothing);
    expect(find.byType(AreasScreen), findsOneWidget);
    expect(
      GoRouter.of(tester.element(find.byType(AreasScreen)))
          .routerDelegate
          .currentConfiguration
          .uri
          .path,
      '/areas',
    );
    await shot(tester, 'shell_retap_areas_$theme');
  });
}
