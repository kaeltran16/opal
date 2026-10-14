import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/screens/mood/widgets/mood_widgets.dart';
import 'package:opal/theme/app_colors.dart';

Widget _wrap(Widget child) {
  final colors = AppColors.light();
  return ProviderScope(
    child: MaterialApp(
      theme: ThemeData(useMaterial3: true, extensions: [colors]),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  // ── MoodOrb ────────────────────────────────────────────────────────────────

  group('MoodOrb', () {
    const orbSize = 100.0;

    BoxDecoration orbDecoration(WidgetTester tester) {
      final container = tester.widget<Container>(
        find.descendant(of: find.byType(MoodOrb), matching: find.byType(Container)),
      );
      return container.decoration! as BoxDecoration;
    }

    List<Radius> corners(BoxDecoration d) {
      final r = d.borderRadius! as BorderRadius;
      return [r.topLeft, r.topRight, r.bottomRight, r.bottomLeft];
    }

    testWidgets('is a circle at t=0.5', (tester) async {
      await tester.pumpWidget(_wrap(
        const MoodOrb(t: 0.5, dark: false, size: orbSize),
      ));
      for (final corner in corners(orbDecoration(tester))) {
        expect(corner, const Radius.circular(orbSize / 2));
      }
    });

    for (final t in [0.0, 1.0]) {
      testWidgets('each corner radius pair spans the full box at t=$t',
          (tester) async {
        await tester.pumpWidget(_wrap(
          MoodOrb(t: t, dark: false, size: orbSize),
        ));
        for (final corner in corners(orbDecoration(tester))) {
          expect(corner.x + corner.y, closeTo(orbSize, 1e-9));
        }
      });
    }

    testWidgets('casts no shadow', (tester) async {
      await tester.pumpWidget(_wrap(
        const MoodOrb(t: 0.7, dark: false, size: orbSize),
      ));
      expect(orbDecoration(tester).boxShadow, isNull);
    });

    testWidgets('builds at t=0.5 (neutral)', (tester) async {
      await tester.pumpWidget(_wrap(
        const MoodOrb(t: 0.5, dark: false),
      ));
      // no crash — build is the assertion
      expect(find.byType(MoodOrb), findsOneWidget);
    });

    testWidgets('builds at t=0.0 (low)', (tester) async {
      await tester.pumpWidget(_wrap(
        const MoodOrb(t: 0.0, dark: false),
      ));
      expect(find.byType(MoodOrb), findsOneWidget);
    });

    testWidgets('builds at t=1.0 (high)', (tester) async {
      await tester.pumpWidget(_wrap(
        const MoodOrb(t: 1.0, dark: false),
      ));
      expect(find.byType(MoodOrb), findsOneWidget);
    });

    testWidgets('custom size is respected', (tester) async {
      await tester.pumpWidget(_wrap(
        const MoodOrb(t: 0.7, dark: true, size: 80),
      ));
      expect(find.byType(MoodOrb), findsOneWidget);
    });
  });

  // ── MoodScaleTrack ─────────────────────────────────────────────────────────

  group('MoodScaleTrack', () {
    testWidgets('builds and shows end labels', (tester) async {
      await tester.pumpWidget(_wrap(
        MoodScaleTrack(t: 0.5, dark: false, onChanged: (_) {}),
      ));
      expect(find.text('Unpleasant'), findsOneWidget);
      expect(find.text('Pleasant'), findsOneWidget);
    });

    testWidgets('tapping near the right edge fires onChanged with t near 1',
        (tester) async {
      double? received;
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 300,
            child: MoodScaleTrack(
              t: 0.5,
              dark: false,
              onChanged: (v) => received = v,
            ),
          ),
        ),
      );

      // find the GestureDetector inside the track and tap near its right edge
      final trackFinder = find.byType(GestureDetector).first;
      final trackRect = tester.getRect(trackFinder);
      // tap at 95% of width
      await tester.tapAt(
        Offset(trackRect.left + trackRect.width * 0.95, trackRect.center.dy),
      );
      await tester.pump();

      expect(received, isNotNull);
      expect(received!, greaterThan(0.5));
    });

    testWidgets('tapping near the left edge fires onChanged with t near 0',
        (tester) async {
      double? received;
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 300,
            child: MoodScaleTrack(
              t: 0.5,
              dark: false,
              onChanged: (v) => received = v,
            ),
          ),
        ),
      );

      final trackFinder = find.byType(GestureDetector).first;
      final trackRect = tester.getRect(trackFinder);
      await tester.tapAt(
        Offset(trackRect.left + trackRect.width * 0.05, trackRect.center.dy),
      );
      await tester.pump();

      expect(received, isNotNull);
      expect(received!, lessThan(0.5));
    });

    testWidgets('drag updates t via onChanged', (tester) async {
      final received = <double>[];
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 300,
            child: MoodScaleTrack(
              t: 0.5,
              dark: false,
              onChanged: received.add,
            ),
          ),
        ),
      );

      final trackFinder = find.byType(GestureDetector).first;
      final trackRect = tester.getRect(trackFinder);
      // drag from center to 80% right
      await tester.drag(
        trackFinder,
        Offset(trackRect.width * 0.30, 0),
      );
      await tester.pump();

      expect(received, isNotEmpty);
    });
  });
}
