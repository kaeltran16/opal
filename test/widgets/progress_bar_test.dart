import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/theme/theme.dart';
import 'package:opal/widgets/controls.dart';

const _width = 200.0;

final _colors = AppColors.light();

Future<void> _pump(WidgetTester tester, double value) => tester.pumpWidget(MaterialApp(
      theme: ThemeData(useMaterial3: true, extensions: [_colors]),
      home: Scaffold(
        body: Center(
          child: SizedBox(width: _width, child: ProgressBar(value: value)),
        ),
      ),
    ));

Finder get _track => find.byWidgetPredicate((w) => w is ColoredBox && w.color == _colors.track);

Finder get _fill => find.descendant(of: find.byType(ProgressBar), matching: find.byType(AnimatedContainer));

Color? _fillColor(WidgetTester tester) {
  final fill = tester.widget<AnimatedContainer>(_fill);
  return (fill.decoration! as BoxDecoration).color;
}

void main() {
  testWidgets('paints the track and an ink fill at the value', (tester) async {
    await _pump(tester, 0.25);

    expect(_track, findsOneWidget);
    expect(tester.getSize(_track).width, _width);
    expect(_fillColor(tester), _colors.ink);
    expect(tester.getSize(_fill).width, _width * 0.25);
  });

  testWidgets('clamps a value above one to the full width', (tester) async {
    await _pump(tester, 1.5);

    expect(tester.getSize(_fill).width, _width);
  });
}
