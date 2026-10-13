import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/theme/theme.dart';
import 'package:opal/widgets/controls.dart';

final _colors = AppColors.light();
final _theme = ThemeData(useMaterial3: true, extensions: [_colors]);

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        theme: _theme,
        home: Scaffold(body: Center(child: child)),
      ),
    ));

Color? _fill(WidgetTester tester, Finder of) {
  final box = tester.widget<Container>(
      find.descendant(of: of, matching: find.byType(Container)).first);
  return (box.decoration! as BoxDecoration).color;
}

void main() {
  group('PillButton', () {
    testWidgets('primary is ink with bg text', (tester) async {
      await _pump(tester, PillButton(label: 'Start', onTap: () {}));

      expect(_fill(tester, find.byType(PillButton)), _colors.ink);
      expect(tester.widget<Text>(find.text('Start')).style?.color, _colors.bg);
      expect(tester.getSize(find.byType(PillButton)).height, greaterThanOrEqualTo(48));
    });

    testWidgets('secondary is surface2 with ink text', (tester) async {
      await _pump(tester, PillButton(label: 'Keep going', primary: false, onTap: () {}));

      expect(_fill(tester, find.byType(PillButton)), _colors.surface2);
      expect(tester.widget<Text>(find.text('Keep going')).style?.color, _colors.ink);
    });

    testWidgets('a null onTap is disabled and not tappable', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, const PillButton(label: 'Generating…', onTap: null));

      expect(tester.widget<Text>(find.text('Generating…')).style?.color, _colors.ink4);
      expect(
        tester.getSemantics(find.byType(PillButton)),
        matchesSemantics(isButton: true, hasEnabledState: true, isEnabled: false, label: 'Generating…'),
      );
      handle.dispose();
    });

    testWidgets('a tap calls onTap', (tester) async {
      var taps = 0;
      await _pump(tester, PillButton(label: 'Start', icon: 'checkmark', onTap: () => taps++));

      await tester.tap(find.byType(PillButton));
      expect(taps, 1);
    });
  });

  testWidgets('AppChip reports selected in its semantics', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, AppChip(label: 'Chest', selected: true, onTap: () {}));

    expect(
      tester.getSemantics(find.byType(AppChip)),
      matchesSemantics(
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
        label: 'Chest',
      ),
    );
    expect(tester.getSize(find.byType(AppChip)).height, greaterThanOrEqualTo(44));
    handle.dispose();
  });

  testWidgets('Segmented calls onChanged and each segment is at least 44 tall', (tester) async {
    String? picked;
    await _pump(
      tester,
      Segmented<String>(
        options: const [('w', 'Week'), ('m', 'Month'), ('y', 'Year')],
        value: 'w',
        onChanged: (v) => picked = v,
      ),
    );

    await tester.tap(find.text('Month'));
    expect(picked, 'm');
    for (final label in ['Week', 'Month', 'Year']) {
      final segment = find.ancestor(of: find.text(label), matching: find.byType(GestureDetector)).first;
      expect(tester.getSize(segment).height, greaterThanOrEqualTo(44));
    }
    expect(tester.widget<Text>(find.text('Week')).style?.color, _colors.ink);
    expect(tester.widget<Text>(find.text('Month')).style?.color, _colors.ink2);
  });

  testWidgets('SearchPill forwards typed text to onChanged', (tester) async {
    final handle = tester.ensureSemantics();
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final typed = <String>[];
    await _pump(tester, SearchPill(controller: controller, placeholder: 'Search exercises', onChanged: typed.add));

    await tester.enterText(find.byType(TextField), 'bench');
    expect(typed.last, 'bench');
    expect(controller.text, 'bench');
    expect(
      tester.getSemantics(find.byType(TextField)),
      isSemantics(label: 'Search exercises', isTextField: true),
    );
    handle.dispose();
  });

  testWidgets('ProgressBar fills ink on track by default', (tester) async {
    await _pump(tester, const SizedBox(width: 200, child: ProgressBar(value: 0.5)));

    final fill = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
    expect((fill.decoration! as BoxDecoration).color, _colors.ink);
    expect(tester.getSize(find.byType(AnimatedContainer)).width, 100);
  });
}
