import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/theme/theme.dart';
import 'package:opal/widgets/controls.dart';
import 'package:opal/widgets/pal_lead.dart';

final _colors = AppColors.light();

const _line = 'Push today. Your chest has had three days.';

Future<void> _pump(WidgetTester tester, Widget child, {double scale = 1}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(
      theme: ThemeData(useMaterial3: true, extensions: [_colors]),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: Scaffold(
            body: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: child),
          ),
        ),
      ),
    ),
  ));
}

void main() {
  testWidgets('the line is ink in the Newsreader serif', (tester) async {
    await _pump(tester, const PalLead(text: _line));

    final style = tester.widget<Text>(find.text(_line)).style!;
    expect(style.color, _colors.ink);
    expect(style.fontFamily, AppType.serifFamily);
    expect(AppType.serifFamily, 'Newsreader');
    expect(find.text('Pal'), findsOneWidget);
  });

  testWidgets('muted paints the line in ink3', (tester) async {
    await _pump(tester, const PalLead(text: _line, muted: true));

    expect(tester.widget<Text>(find.text(_line)).style?.color, _colors.ink3);
  });

  testWidgets('ActionCard at 390 and text scale 1.3 does not overflow', (tester) async {
    await _pump(
      tester,
      ActionCard(
        meta: '45 min · Chest, shoulders and triceps',
        title: 'Push Day A with a long accessory finisher',
        primary: PillButton(label: 'Start', onTap: () {}),
        secondary: PillButton(label: 'Pick another', primary: false, onTap: () {}),
      ),
      scale: 1.3,
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Pick another'), findsOneWidget);
    final card = tester.getSize(find.byType(ActionCard)).width;
    expect(tester.getSize(find.text('Pick another')).width, lessThanOrEqualTo(card / 2));
  });
}
