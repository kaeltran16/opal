@Tags(['scenario'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/analysis/area_state.dart';
import 'package:opal/theme/theme.dart';
import 'package:opal/widgets/app_icon.dart';
import 'package:opal/widgets/contributor_bar.dart';
import 'package:opal/widgets/pal_label.dart';
import 'package:opal/widgets/shortcut_ring.dart';
import 'package:opal/widgets/week_bars.dart';

import 'scenario_harness.dart';

const _noneOff = [false, false, false, false, false, false, false];

Future<void> _pump(WidgetTester tester, bool dark, List<Widget> children) {
  final colors = dark ? AppColors.dark() : AppColors.light();
  return tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      brightness: colors.brightness,
      extensions: [colors],
    ),
    home: Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        ),
      ),
    ),
  ));
}

ShortcutRing _ring(String icon, String value, AreaState state, double fraction) => ShortcutRing(
      icon: icon,
      value: value,
      state: state,
      fraction: fraction,
      semanticLabel: '$value. ${state.word}',
      onTap: () {},
    );

void main() {
  scenarioTest('components rings', (tester, dark) async {
    await _pump(tester, dark, [
      const PalLabel(),
      const SizedBox(height: Spacing.xxl),
      Row(
        spacing: Spacing.sm,
        children: [
          Expanded(child: _ring('dollarsign.circle.fill', r'$22 left', AreaState.watch, 22 / 60)),
          Expanded(child: _ring('figure.run', '310 kcal', AreaState.good, 310 / 500)),
          Expanded(child: _ring('sparkles', '4 of 4', AreaState.thriving, 1)),
        ],
      ),
      const SizedBox(height: Spacing.xxxl),
      Row(
        spacing: Spacing.sm,
        children: [
          Expanded(child: _ring('dollarsign.circle.fill', r'$0 left', AreaState.care, 0)),
          Expanded(child: _ring('figure.run', '40 kcal', AreaState.care, 40 / 500)),
          Expanded(child: _ring('sparkles', '0', AreaState.good, 0)),
        ],
      ),
    ]);

    for (final state in AreaState.values) {
      expect(find.text(state.word), findsWidgets);
    }
    expect(find.byType(ShortcutRing), findsNWidgets(6));
    expect(find.byIcon(iconForSf('checkmark')), findsOneWidget);
    expect(find.text('Pal'), findsOneWidget);

    await shot(tester, 'components_rings_${dark ? 'dark' : 'light'}');
  });

  scenarioTest('components bars', (tester, dark) async {
    await _pump(tester, dark, [
      const ContributorBar(label: 'Spent so far', value: r'$38 of $60', fraction: 38 / 60),
      const SizedBox(height: Spacing.xl),
      const ContributorBar(
        label: 'Held for rent',
        value: r'$40 of $22',
        fraction: 40 / 22,
        off: true,
      ),
      const SizedBox(height: Spacing.xxxl),
      const WeekBars(
        values: [48, 72, 35, 38, null, null, null],
        off: [false, true, false, false, false, false, false],
        todayIndex: 3,
        goal: 60,
        semanticLabel: r'Money this week: 1 day over budget. $60 daily budget',
      ),
      const SizedBox(height: Spacing.xxxl),
      const WeekBars(
        values: [48, 72, 35, 38, null, null, null],
        off: _noneOff,
        todayIndex: 3,
        goal: 0,
        semanticLabel: 'Money this week. No budget set',
      ),
    ]);

    expect(find.byType(ContributorBar), findsNWidgets(2));
    expect(find.text(r'$40 of $22'), findsOneWidget);
    expect(find.byType(WeekBars), findsNWidgets(2));
    // only the week with a goal draws its dashed line.
    expect(
      find.descendant(of: find.byType(WeekBars), matching: find.byType(CustomPaint)),
      findsOneWidget,
    );

    await shot(tester, 'components_bars_${dark ? 'dark' : 'light'}');
  });
}
