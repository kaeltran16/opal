import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/theme/theme.dart';
import 'package:opal/widgets/keypad.dart';

import '../support/semantics_stops.dart';

void main() {
  testWidgets('each key reads its digit once, and taps report it', (tester) async {
    final handle = tester.ensureSemantics();
    final digits = <String>[];
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(extensions: [AppColors.light()]),
      home: Scaffold(
        body: Keypad(onDigit: digits.add, onDecimal: () {}, onDelete: () {}),
      ),
    ));

    final stops = semanticsStops(tester, find.byType(Keypad));
    expect(stops, containsAll(['1', '2', '9', '0', 'delete']));
    expect(stops.where((s) => s.contains('1 1') || s.contains('1\n1')), isEmpty);
    expect(stops, everyElement(isNot(isEmpty)));

    expect(tester.getSemantics(find.bySemanticsLabel('7')),
        isSemantics(label: '7', isButton: true, hasTapAction: true));
    await tester.tap(find.bySemanticsLabel('7'));
    expect(digits, ['7']);
    handle.dispose();
  });
}
