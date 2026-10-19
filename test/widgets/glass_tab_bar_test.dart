import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/theme/theme.dart';
import 'package:opal/widgets/app_icon.dart';
import 'package:opal/widgets/glass_surface.dart';
import 'package:opal/widgets/glass_tab_bar.dart';

import '../support/semantics_stops.dart';

const _tabs = [
  GlassTab('today', 'Today', 'house.fill'),
  GlassTab('move', 'Workout', 'figure.run'),
  GlassTab('nutrition', 'Nutrition', 'leaf.fill'),
  GlassTab('you', 'You', 'person.crop.circle.fill'),
];

// one instance across pumps, or AnimatedTheme lerps and the reduce motion
// test sees a running animation that isn't the tab bar's.
final _theme = ThemeData(useMaterial3: true, extensions: [AppColors.light()]);

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
  List<GlassTab> tabs = _tabs,
  String activeId = 'today',
  bool minimized = false,
  ValueChanged<String>? onTab,
  VoidCallback? onRestore,
}) {
  return GlassTabBar(
    tabs: tabs,
    activeId: activeId,
    onTab: onTab ?? (_) {},
    minimized: minimized,
    onRestore: onRestore ?? () {},
  );
}

void main() {
  testWidgets('at text scale 2.0 on a 390-wide surface the labels fit the bar',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(_app(_bar()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Nutrition'), findsOneWidget);
  });

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

  testWidgets('a screen reader stops once per tab, never on a blank button', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(_bar()));
    await tester.pump();

    expect(semanticsStops(tester, find.byType(GlassTabBar)), ['Today', 'Workout', 'Nutrition', 'You']);
    expect(tester.getSemantics(find.bySemanticsLabel('Workout')),
        isSemantics(label: 'Workout', isButton: true, hasTapAction: true));
    handle.dispose();
  });

  testWidgets('the active label is semibold ink and the rest are ink3', (
    tester,
  ) async {
    final colors = AppColors.light();
    await tester.pumpWidget(_app(_bar()));
    await tester.pump();

    final active = tester.widget<Text>(find.text('Today')).style!;
    expect(active.fontWeight, FontWeight.w600);
    expect(active.color, colors.ink);
    expect(active.fontSize, AppType.caption.fontSize);
    expect(
      tester.widget<Icon>(find.byIcon(iconForSf('house.fill'))).color,
      colors.ink,
    );

    for (final t in _tabs.skip(1)) {
      final style = tester.widget<Text>(find.text(t.label)).style!;
      expect(style.fontWeight, FontWeight.w400, reason: t.label);
      expect(style.color, colors.ink3, reason: t.label);
      expect(
        tester.widget<Icon>(find.byIcon(iconForSf(t.icon))).color,
        colors.ink3,
        reason: t.label,
      );
    }
  });

  testWidgets('the bar is a 62 tall pill and the active tab sits on surface2', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_bar()));
    await tester.pump();

    expect(tester.getSize(find.byType(GlassSurface)).height, 62);
    final pills = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.bySemanticsLabel('Today'),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((box) => (box.decoration as BoxDecoration).color);
    expect(pills, [AppColors.light().surface2]);
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

  group('dot', () {
    const watch = Color(0xFFE0A030);
    const dotted = [
      GlassTab('today', 'Today', 'house.fill', dot: watch),
      GlassTab('move', 'Workout', 'figure.run'),
    ];

    BoxDecoration dotOf(WidgetTester tester, String id) =>
        tester.widget<DecoratedBox>(find.byKey(glassTabDotKey(id))).decoration
            as BoxDecoration;

    testWidgets('renders only on the tab that sets one, in its colour', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_bar(tabs: dotted)));
      await tester.pump();

      expect(find.byKey(glassTabDotKey('today')), findsOneWidget);
      expect(find.byKey(glassTabDotKey('move')), findsNothing);
      final dot = dotOf(tester, 'today');
      expect(dot.color, watch);
      expect(dot.shape, BoxShape.circle);
      expect(dot.border!.top.color, AppColors.light().surface);
      expect(dot.border!.top.width, 2);
      expect(
        tester.getSize(find.byKey(glassTabDotKey('today'))),
        const Size(8, 8),
      );
    });

    testWidgets('sits at the icon top right', (tester) async {
      await tester.pumpWidget(_app(_bar(tabs: dotted)));
      await tester.pump();

      final icon = tester.getRect(find.byIcon(iconForSf('house.fill')));
      final dot = tester.getRect(find.byKey(glassTabDotKey('today')));
      expect(dot.top, icon.top - 1);
      expect(dot.right, icon.right + 4);
    });

    testWidgets('stays out of semantics', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(_bar(tabs: dotted)));
      await tester.pump();

      expect(
        tester.getSemantics(find.bySemanticsLabel('Today')),
        isSemantics(label: 'Today', isButton: true, isSelected: true),
      );
      handle.dispose();
    });

    testWidgets('the minimized circle carries the active tab dot', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_bar(tabs: dotted, minimized: true)));
      await tester.pumpAndSettle();

      expect(find.byKey(glassTabDotKey('today')), findsOneWidget);
      expect(dotOf(tester, 'today').color, watch);
    });

    testWidgets('the minimized circle has none when the active tab has none', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(_bar(tabs: dotted, activeId: 'move', minimized: true)),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(glassTabDotKey('today')), findsNothing);
    });
  });

  testWidgets('semanticLabel replaces the label but not the visible text', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    const label = 'Areas, money worth watching';
    const tabs = [
      GlassTab('today', 'Today', 'house.fill'),
      GlassTab('areas', 'Areas', 'square.grid.2x2.fill', semanticLabel: label),
    ];
    await tester.pumpWidget(_app(_bar(tabs: tabs)));
    await tester.pump();

    expect(find.text('Areas'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel(label)),
      isSemantics(label: label, isButton: true, isSelected: false),
    );
    expect(find.bySemanticsLabel(RegExp(r'^Areas$')), findsNothing);
    handle.dispose();
  });

  testWidgets('the minimized circle uses the semanticLabel', (tester) async {
    final handle = tester.ensureSemantics();
    const tabs = [
      GlassTab('today', 'Today', 'house.fill', semanticLabel: 'Today, ok'),
    ];
    await tester.pumpWidget(_app(_bar(tabs: tabs, minimized: true)));
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel('Today, ok tab, expand tab bar'),
      findsOneWidget,
    );
    handle.dispose();
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
