import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/theme/theme.dart';
import 'package:opal/widgets/week_bars.dart';
import 'package:opal/analysis/area_state.dart';

const _label = 'Money this week: 1 day over budget. \$60 daily budget';
const _chartHeight = 64.0;
const _stub = 2.0;
const List<AreaState?> _noneOff = [null, null, null, null, null, null, null];
const List<double?> _empty = [null, null, null, null, null, null, null];

final _colors = AppColors.light();

Future<void> _pump(
  WidgetTester tester, {
  required List<double?> values,
  List<AreaState?> off = _noneOff,
  int todayIndex = 3,
  double goal = 60,
}) =>
    tester.pumpWidget(MaterialApp(
      theme: ThemeData(useMaterial3: true, extensions: [_colors]),
      home: Scaffold(
        body: WeekBars(
          values: values,
          off: off,
          todayIndex: todayIndex,
          goal: goal,
          semanticLabel: _label,
        ),
      ),
    ));

Finder _in(Type type) =>
    find.descendant(of: find.byType(WeekBars), matching: find.byType(type));

Finder get _bars => _in(DecoratedBox);
Finder get _goalLine => _in(CustomPaint);

Color? _fill(WidgetTester tester, int i) =>
    (tester.widget<DecoratedBox>(_bars.at(i)).decoration as BoxDecoration).color;

void main() {
  testWidgets('draws seven equal columns and the day letters', (tester) async {
    await _pump(tester, values: [48, 61, 35, 20, null, null, null]);

    expect(_bars, findsNWidgets(7));
    final widths = [for (var i = 0; i < 7; i++) tester.getSize(_bars.at(i)).width];
    expect(widths.toSet(), hasLength(1));
    expect(find.text('M'), findsOneWidget);
    expect(find.text('T'), findsNWidgets(2));
    expect(find.text('S'), findsNWidgets(2));
  });

  testWidgets('fills say today, off, past and not yet', (tester) async {
    await _pump(
      tester,
      values: [48, 61, 35, 20, null, null, null],
      off: [null, AreaState.watch, AreaState.care, null, null, null, null],
    );

    expect(_fill(tester, 0), _colors.ink3);
    expect(_fill(tester, 1), _colors.watch);
    expect(_fill(tester, 2), _colors.care);
    expect(_fill(tester, 3), _colors.ink);
    expect(_fill(tester, 4), _colors.track);

    final letters = tester.widgetList<Text>(_in(Text)).toList();
    expect(letters[3].style?.color, _colors.ink);
    expect(letters[3].style?.fontWeight, FontWeight.w600);
    expect(letters[0].style?.color, _colors.ink3);
  });

  testWidgets('all values null renders seven track stubs', (tester) async {
    await _pump(tester, values: _empty);

    expect(_bars, findsNWidgets(7));
    for (var i = 0; i < 7; i++) {
      expect(tester.getSize(_bars.at(i)).height, _stub);
      expect(_fill(tester, i), _colors.track);
    }
  });

  testWidgets('a zero goal draws no goal line and does not throw', (tester) async {
    await _pump(tester, values: [48, 61, 0, 20, null, null, null], goal: 0);
    expect(tester.takeException(), isNull);
    expect(_goalLine, findsNothing);
    expect(tester.getSize(_bars.at(1)).height, _chartHeight);
    expect(tester.getSize(_bars.at(2)).height, _stub);

    await _pump(tester, values: _empty, goal: 0);
    expect(tester.takeException(), isNull);
    expect(_goalLine, findsNothing);

    await _pump(tester, values: [0, 0, 0, 0, null, null, null], goal: 0);
    expect(tester.takeException(), isNull);
    expect(tester.getSize(_bars.at(0)).height, _stub);
  });

  testWidgets('the goal line sits at the top of a bar that meets the goal', (tester) async {
    await _pump(tester, values: [60, 30, null, null, null, null, null], todayIndex: 1);

    expect(_goalLine, findsOneWidget);
    expect(tester.getSize(_bars.at(0)).height, _chartHeight);
    expect(tester.getSize(_bars.at(1)).height, _chartHeight / 2);
    expect(tester.getTopLeft(_goalLine).dy, tester.getTopLeft(_bars.at(0)).dy);
  });

  testWidgets('short bars stand on the chart floor, under the goal line', (tester) async {
    await _pump(tester, values: [30, 6, null, null, null, null, null], todayIndex: 1);

    final chart = find.descendant(
      of: find.byType(WeekBars),
      matching: find.byWidgetPredicate((w) => w is SizedBox && w.height == _chartHeight),
    );
    final floor = tester.getBottomLeft(chart).dy;
    expect(tester.getSize(_bars.at(0)).height, _chartHeight / 2);
    for (var i = 0; i < 7; i++) {
      expect(tester.getBottomLeft(_bars.at(i)).dy, floor);
    }
    expect(tester.getTopLeft(_goalLine).dy, floor - _chartHeight);
  });

  testWidgets('a value above the goal scales the chart to that value', (tester) async {
    await _pump(tester, values: [120, 60, null, null, null, null, null], todayIndex: 1);

    expect(tester.getSize(_bars.at(0)).height, _chartHeight);
    expect(tester.getSize(_bars.at(1)).height, _chartHeight / 2);
    expect(tester.getTopLeft(_goalLine).dy, tester.getTopLeft(_bars.at(1)).dy);
  });

  testWidgets('the chart is one image with the label', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, values: [48, 61, 35, 20, null, null, null]);

    expect(
      tester.getSemantics(find.bySemanticsLabel(_label)),
      isSemantics(label: _label, isImage: true),
    );
    expect(find.bySemanticsLabel('M'), findsNothing);
    handle.dispose();
  });
}
