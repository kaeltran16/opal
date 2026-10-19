@Tags(['scenario'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/theme/theme.dart';
import 'package:opal/widgets/contributor_bar.dart';
import 'package:opal/widgets/week_bars.dart';
import 'package:opal/analysis/area_state.dart';

import 'scenario_harness.dart';

const List<AreaState?> _noneOff = [null, null, null, null, null, null, null];

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

void main() {
  scenarioTest('components bars', (tester, dark) async {
    await _pump(tester, dark, [
      const ContributorBar(label: 'Spent so far', value: r'$38 of $60', fraction: 38 / 60),
      const SizedBox(height: Spacing.xl),
      const ContributorBar(
        label: 'Held for rent',
        value: r'$40 of $22',
        fraction: 40 / 22,
        off: AreaState.care,
      ),
      const SizedBox(height: Spacing.xxxl),
      const WeekBars(
        values: [48, 72, 35, 38, null, null, null],
        off: [null, AreaState.care, null, null, null, null, null],
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
