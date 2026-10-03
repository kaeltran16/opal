@Tags(['scenario'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/screens/pal/pal_composer_screen.dart';
import 'package:opal/widgets/glass_tab_bar.dart';
import 'package:opal/widgets/pal_ask_bar.dart';

import '../support/golden_harness.dart';
import 'scenario_harness.dart';

const _askLabel = 'Tell Pal anything';

Finder _inTabBar(Finder matching) =>
    find.descendant(of: find.byType(GlassTabBar), matching: matching);

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
    expect(_inTabBar(find.text('Today')), findsOneWidget);
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
}
