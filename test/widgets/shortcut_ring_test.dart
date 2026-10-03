import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/analysis/area_state.dart';
import 'package:opal/theme/theme.dart';
import 'package:opal/widgets/app_icon.dart';
import 'package:opal/widgets/shortcut_ring.dart';

const _label = 'Move: 310 of 500 kcal burned. On track';
const _minTarget = 44.0;

final _colors = AppColors.light();

Future<void> _pump(
  WidgetTester tester, {
  AreaState state = AreaState.good,
  double fraction = 0.62,
  VoidCallback? onTap,
}) =>
    tester.pumpWidget(MaterialApp(
      theme: ThemeData(useMaterial3: true, extensions: [_colors]),
      home: Scaffold(
        body: Center(
          child: ShortcutRing(
            icon: 'figure.run',
            value: '310 kcal',
            state: state,
            fraction: fraction,
            semanticLabel: _label,
            onTap: onTap ?? () {},
          ),
        ),
      ),
    ));

Color? _wordColor(WidgetTester tester, AreaState state) =>
    tester.widget<Text>(find.text(state.word)).style?.color;

void main() {
  testWidgets('is one button with the exact semantics label', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);

    expect(find.bySemanticsLabel(_label), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel(_label)),
      isSemantics(label: _label, isButton: true, hasTapAction: true),
    );
    // the value and word are folded into the button, not read separately.
    expect(find.bySemanticsLabel(RegExp('310 kcal\$')), findsNothing);
    handle.dispose();
  });

  testWidgets('tap fires and the target is at least 44 by 44', (tester) async {
    var taps = 0;
    await _pump(tester, onTap: () => taps++);

    final size = tester.getSize(find.byType(ShortcutRing));
    expect(size.width, greaterThanOrEqualTo(_minTarget));
    expect(size.height, greaterThanOrEqualTo(_minTarget));

    await tester.tap(find.byType(ShortcutRing));
    expect(taps, 1);
  });

  testWidgets('shows the state word for every state', (tester) async {
    for (final state in AreaState.values) {
      await _pump(tester, state: state);
      expect(find.text(state.word), findsOneWidget);
    }
  });

  testWidgets('the word is ink3 when on track and the watch ink when watching',
      (tester) async {
    await _pump(tester);
    expect(_wordColor(tester, AreaState.good), _colors.ink3);

    await _pump(tester, state: AreaState.watch);
    expect(_wordColor(tester, AreaState.watch), _colors.watchInk);
  });

  testWidgets('only a thriving ring shows the check', (tester) async {
    await _pump(tester, state: AreaState.thriving, fraction: 1);
    expect(find.byIcon(iconForSf('checkmark')), findsOneWidget);

    await _pump(tester, fraction: 1);
    expect(find.byIcon(iconForSf('checkmark')), findsNothing);
  });

  testWidgets('fractions at and beyond the ends paint without error', (tester) async {
    for (final fraction in [0.0, 1.0, 1.4, double.nan]) {
      for (final state in AreaState.values) {
        await _pump(tester, state: state, fraction: fraction);
        expect(tester.takeException(), isNull);
      }
    }
  });
}
