import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/theme/theme.dart';
import 'package:opal/widgets/stat_row.dart';

final _colors = AppColors.light();

const _stats = [
  Stat(value: '12.4', unit: 't', label: 'Volume'),
  Stat(value: '245', unit: 'min', label: 'Time'),
  Stat(value: '3', label: 'Records'),
];

Future<void> _pump(WidgetTester tester, {double scale = 1}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(useMaterial3: true, extensions: [_colors]),
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
        child: const Scaffold(
          body: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: StatRow(stats: _stats),
          ),
        ),
      ),
    ),
  ));
}

void main() {
  testWidgets('three stats at 390 wide and text scale 1.3 do not overflow', (tester) async {
    await _pump(tester, scale: 1.3);

    expect(tester.takeException(), isNull);
    for (final label in ['Volume', 'Time', 'Records']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('each column after the first has a left hair border', (tester) async {
    await _pump(tester);

    final borders = tester
        .widgetList<Container>(find.descendant(of: find.byType(StatRow), matching: find.byType(Container)))
        .map((c) => (c.decoration as BoxDecoration?)?.border as Border?)
        .whereType<Border>()
        .toList();
    expect(borders, hasLength(2));
    for (final border in borders) {
      expect(border.left.color, _colors.hair);
      expect(border.left.width, 1);
    }
  });
}
