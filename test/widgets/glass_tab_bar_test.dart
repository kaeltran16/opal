import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/theme/theme.dart';
import 'package:opal/widgets/app_icon.dart';
import 'package:opal/widgets/glass_tab_bar.dart';

const _tabs = [
  GlassTab('today', 'Today', 'house.fill'),
  GlassTab('move', 'Workout', 'figure.run'),
  GlassTab('nutrition', 'Nutrition', 'leaf.fill'),
  GlassTab('you', 'You', 'person.crop.circle.fill'),
];

// one instance across pumps, or AnimatedTheme lerps and the reduce motion
// test sees a running animation that isn't the tab bar's.
final _theme = ThemeData(
  useMaterial3: true,
  extensions: [AppColors.light()],
);

Widget _app(Widget child, {bool disableAnimations = false}) {
  return ProviderScope(
    child: MaterialApp(
      theme: _theme,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: disableAnimations),
          child: Scaffold(
            body: Align(alignment: Alignment.bottomCenter, child: child),
          ),
        ),
      ),
    ),
  );
}

GlassTabBar _bar({
  bool minimized = false,
  ValueChanged<String>? onTab,
  VoidCallback? onRestore,
}) {
  return GlassTabBar(
    tabs: _tabs,
    activeId: 'today',
    onTab: onTab ?? (_) {},
    minimized: minimized,
    onRestore: onRestore ?? () {},
  );
}

void main() {
  testWidgets('renders every tab label and reports taps by id', (tester) async {
    final tapped = <String>[];
    await tester.pumpWidget(_app(_bar(onTab: tapped.add)));
    await tester.pump();

    for (final t in _tabs) {
      expect(find.text(t.label), findsOneWidget);
    }
    await tester.tap(find.text('Nutrition'));
    expect(tapped, ['nutrition']);
  });

  testWidgets('only the active tab carries the selected flag', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(_bar()));
    await tester.pump();

    expect(
      tester.getSemantics(find.bySemanticsLabel('Today')),
      isSemantics(label: 'Today', isButton: true, isSelected: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Nutrition')),
      isSemantics(label: 'Nutrition', isButton: true, isSelected: false),
    );
    handle.dispose();
  });

  testWidgets('tabs are at least 44 by 44', (tester) async {
    await tester.pumpWidget(_app(_bar()));
    await tester.pump();

    for (final t in _tabs) {
      final size = tester.getSize(find.bySemanticsLabel(t.label));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
    }
  });

  testWidgets('minimized shows only the active icon and restores on tap', (
    tester,
  ) async {
    var restored = 0;
    await tester.pumpWidget(
      _app(_bar(minimized: true, onRestore: () => restored++)),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(iconForSf('house.fill')), findsOneWidget);
    for (final t in _tabs.skip(1)) {
      expect(find.byIcon(iconForSf(t.icon)), findsNothing);
    }
    for (final t in _tabs) {
      expect(find.text(t.label), findsNothing);
    }

    final size = tester.getSize(find.byIcon(iconForSf('house.fill')));
    expect(size.width, lessThan(52));
    await tester.tap(find.byIcon(iconForSf('house.fill')));
    expect(restored, 1);
  });

  testWidgets('the minimized circle is 52 and a 44 pt target', (tester) async {
    await tester.pumpWidget(_app(_bar(minimized: true)));
    await tester.pumpAndSettle();

    final size = tester.getSize(find.bySemanticsLabel(RegExp('Today tab')));
    expect(size, const Size(52, 52));
  });

  testWidgets('reduce motion swaps state in a single frame', (tester) async {
    await tester.pumpWidget(_app(_bar(), disableAnimations: true));
    await tester.pump();
    expect(find.text('Workout'), findsOneWidget);

    await tester.pumpWidget(
      _app(_bar(minimized: true), disableAnimations: true),
    );
    await tester.pump();

    expect(find.text('Workout'), findsNothing);
    expect(find.byIcon(iconForSf('figure.run')), findsNothing);
    expect(
      tester.getSize(find.bySemanticsLabel(RegExp('Today tab'))),
      const Size(52, 52),
    );
    expect(tester.hasRunningAnimations, isFalse);

    await tester.pumpWidget(_app(_bar(), disableAnimations: true));
    await tester.pump();

    expect(find.text('Workout'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('without reduce motion the swap animates', (tester) async {
    await tester.pumpWidget(_app(_bar()));
    await tester.pump();

    await tester.pumpWidget(_app(_bar(minimized: true)));
    await tester.pump();
    expect(tester.hasRunningAnimations, isTrue);

    await tester.pumpAndSettle();
    expect(find.text('Workout'), findsNothing);
  });
}
