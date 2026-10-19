import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/theme/theme.dart';
import 'package:opal/widgets/contributor_bar.dart';
import 'package:opal/analysis/area_state.dart';

const _value = r'$38 of $60';

final _colors = AppColors.light();

Future<void> _pump(WidgetTester tester, {required double fraction, AreaState? off}) =>
    tester.pumpWidget(MaterialApp(
      theme: ThemeData(useMaterial3: true, extensions: [_colors]),
      home: Scaffold(
        body: ContributorBar(label: 'Spent so far', value: _value, fraction: fraction, off: off),
      ),
    ));

Finder get _bar => find.byType(FractionallySizedBox);

Color? _barColor(WidgetTester tester) {
  final fill = tester.widget<Container>(find.descendant(of: _bar, matching: find.byType(Container)));
  return (fill.decoration! as BoxDecoration).color;
}

void main() {
  testWidgets('is neutral ink by default', (tester) async {
    await _pump(tester, fraction: 0.5);

    expect(tester.widget<Text>(find.text(_value)).style?.color, _colors.ink);
    expect(_barColor(tester), _colors.ink);
    expect(tester.widget<FractionallySizedBox>(_bar).widthFactor, 0.5);
  });

  testWidgets('the value is an amount in regular weight, never bold', (tester) async {
    await _pump(tester, fraction: 0.5);

    final style = tester.widget<Text>(find.text(_value)).style!;
    expect(style.fontWeight, FontWeight.w400);
    expect(style.fontSize, AppType.subhead.fontSize);
  });

  testWidgets('off colours the value and the bar in its state', (tester) async {
    await _pump(tester, fraction: 0.5, off: AreaState.watch);
    expect(tester.widget<Text>(find.text(_value)).style?.color, _colors.watchInk);
    expect(_barColor(tester), _colors.watch);

    await _pump(tester, fraction: 0.5, off: AreaState.care);
    expect(tester.widget<Text>(find.text(_value)).style?.color, _colors.careInk);
    expect(_barColor(tester), _colors.care);
  });

  testWidgets('a fraction outside 0 to 1 is clamped', (tester) async {
    await _pump(tester, fraction: 1.4);
    expect(tester.widget<FractionallySizedBox>(_bar).widthFactor, 1.0);
    expect(tester.getSize(_bar).width, tester.getSize(find.byType(ContributorBar)).width);

    await _pump(tester, fraction: -0.2);
    expect(tester.widget<FractionallySizedBox>(_bar).widthFactor, 0.0);

    await _pump(tester, fraction: double.nan);
    expect(tester.widget<FractionallySizedBox>(_bar).widthFactor, 0.0);
    expect(tester.takeException(), isNull);
  });
}
