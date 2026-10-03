import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/theme/theme.dart';
import 'package:opal/widgets/glass_surface.dart';

final _colors = AppColors.light();

Widget _app(Stream<bool> reduceTransparency, {bool highContrast = false}) {
  return ProviderScope(
    overrides: [
      reduceTransparencyProvider.overrideWith((ref) => reduceTransparency),
    ],
    child: MaterialApp(
      theme: ThemeData(useMaterial3: true, extensions: [_colors]),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(highContrast: highContrast),
          child: const Center(child: GlassSurface(child: Text('ask pal'))),
        ),
      ),
    ),
  );
}

// the fill box is the one decoration inside GlassSurface that carries a color.
BoxDecoration _fill(WidgetTester tester) {
  return tester
      .widgetList<DecoratedBox>(
        find.descendant(
          of: find.byType(GlassSurface),
          matching: find.byType(DecoratedBox),
        ),
      )
      .map((box) => box.decoration as BoxDecoration)
      .singleWhere((d) => d.color != null);
}

BorderSide _side(BoxDecoration d) => (d.border! as Border).top;

void main() {
  testWidgets('renders glass when reduce transparency is off', (tester) async {
    await tester.pumpWidget(_app(Stream.value(false)));
    await tester.pump();

    expect(find.byType(BackdropFilter), findsOneWidget);
    final fill = _fill(tester);
    expect(fill.color, _colors.glass);
    expect(_side(fill).color, _colors.hair);
    expect(_side(fill).width, 1.0);
    expect(find.text('ask pal'), findsOneWidget);

    expect(GlassSurface.blurSigma, 30);
    final shadows = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(GlassSurface),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((box) => (box.decoration as BoxDecoration).boxShadow)
        .nonNulls
        .single;
    expect(shadows, Elevation.fab(_colors.shadow));
  });

  testWidgets(
    'switches to solid when reduce transparency turns on at runtime',
    (tester) async {
      final controller = StreamController<bool>();
      addTearDown(controller.close);
      await tester.pumpWidget(_app(controller.stream));

      controller.add(false);
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), findsOneWidget);

      controller.add(true);
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), findsNothing);
      final fill = _fill(tester);
      expect(fill.color, _colors.surface);
      expect(_side(fill).color, _colors.hair);
      expect(_side(fill).width, 0.5);
    },
  );

  testWidgets('high contrast uses an opaque fill and a stronger border', (
    tester,
  ) async {
    await tester.pumpWidget(_app(Stream.value(false), highContrast: true));
    await tester.pump();

    expect(find.byType(BackdropFilter), findsNothing);
    final fill = _fill(tester);
    expect(fill.color, _colors.surface);
    expect(fill.color!.a, 1.0);
    expect(_side(fill).color, _colors.ink3);
    expect(_side(fill).width, 1.0);
  });

  testWidgets('renders glass while the setting is still loading', (
    tester,
  ) async {
    final controller = StreamController<bool>();
    addTearDown(controller.close);
    await tester.pumpWidget(_app(controller.stream));
    await tester.pump();

    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(_fill(tester).color, _colors.glass);
  });
}
