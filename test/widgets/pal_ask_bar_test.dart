import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/theme/theme.dart';
import 'package:opal/widgets/glass_surface.dart';
import 'package:opal/widgets/pal_ask_bar.dart';
import 'package:opal/widgets/pal_avatar.dart';

const _askLabel = 'Ask or log anything';

Widget _app(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        extensions: [AppColors.light()],
      ),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: child,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('tapping the bar asks and tapping the mic dictates', (
    tester,
  ) async {
    var asks = 0, mics = 0;
    await tester.pumpWidget(
      _app(PalAskBar(onAsk: () => asks++, onMic: () => mics++)),
    );
    await tester.pump();

    await tester.tap(find.bySemanticsLabel(_askLabel));
    expect((asks, mics), (1, 0));

    await tester.tap(find.bySemanticsLabel('Dictate'));
    expect((asks, mics), (1, 1));
  });

  testWidgets('is a 52 tall glass capsule with the sparkle and placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(_app(PalAskBar(onAsk: () {}, onMic: () {})));
    await tester.pump();

    expect(tester.getSize(find.byType(GlassSurface)).height, 52);
    expect(find.byType(PalAvatar), findsOneWidget);
    final placeholder = tester.widget<Text>(find.text(_askLabel));
    expect(placeholder.style?.color, AppColors.light().ink3);
  });

  testWidgets('every tap target is at least 44 by 44', (tester) async {
    await tester.pumpWidget(_app(PalAskBar(onAsk: () {}, onMic: () {})));
    await tester.pump();

    for (final label in [_askLabel, 'Dictate']) {
      final size = tester.getSize(find.bySemanticsLabel(label));
      expect(size.width, greaterThanOrEqualTo(44), reason: label);
      expect(size.height, greaterThanOrEqualTo(44), reason: label);
    }
  });

  testWidgets('exposes the bar and mic as separate buttons', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(PalAskBar(onAsk: () {}, onMic: () {})));
    await tester.pump();

    expect(
      tester.getSemantics(find.bySemanticsLabel(_askLabel)),
      isSemantics(label: _askLabel, isButton: true, hasTapAction: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Dictate')),
      isSemantics(label: 'Dictate', isButton: true, hasTapAction: true),
    );
    handle.dispose();
  });
}
