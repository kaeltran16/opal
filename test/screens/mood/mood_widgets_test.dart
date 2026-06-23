import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/controllers/mood_controller.dart';
import 'package:opal/screens/mood/widgets/mood_widgets.dart';
import 'package:opal/theme/app_colors.dart';

Widget _wrap(Widget child) {
  final colors = AppColors.light(AppAccent.indigo);
  return ProviderScope(
    child: MaterialApp(
      theme: ThemeData(useMaterial3: true, extensions: [colors]),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  // ── MoodMiniScale ──────────────────────────────────────────────────────────

  group('MoodMiniScale', () {
    testWidgets('builds with dark=false, light=false', (tester) async {
      await tester.pumpWidget(_wrap(
        const MoodMiniScale(t: 0.5, dark: false),
      ));
      expect(find.text('Unpleasant'), findsOneWidget);
      expect(find.text('Pleasant'), findsOneWidget);
    });

    testWidgets('builds with light=true (hero variant)', (tester) async {
      await tester.pumpWidget(_wrap(
        const MoodMiniScale(t: 0.75, dark: false, light: true),
      ));
      expect(find.text('Unpleasant'), findsOneWidget);
      expect(find.text('Pleasant'), findsOneWidget);
    });

    testWidgets('builds with dark=true', (tester) async {
      final darkColors = AppColors.dark(AppAccent.indigo);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData(useMaterial3: true, extensions: [darkColors]),
            home: Scaffold(
              body: const MoodMiniScale(t: 0.3, dark: true),
            ),
          ),
        ),
      );
      expect(find.text('Unpleasant'), findsOneWidget);
    });

    testWidgets('t=0 and t=1 extremes build without error', (tester) async {
      await tester.pumpWidget(_wrap(const MoodMiniScale(t: 0.0, dark: false)));
      expect(find.text('Pleasant'), findsOneWidget);

      await tester.pumpWidget(_wrap(const MoodMiniScale(t: 1.0, dark: false)));
      expect(find.text('Unpleasant'), findsOneWidget);
    });
  });

  // ── MoodWeekChart ──────────────────────────────────────────────────────────

  group('MoodWeekChart', () {
    final week = [
      const MoodBar(dayLetter: 'M', value: 0.6, isToday: false),
      const MoodBar(dayLetter: 'T', value: 0.3, isToday: false),
      const MoodBar(dayLetter: 'W', value: null, isToday: false),
      const MoodBar(dayLetter: 'T', value: 0.5, isToday: false),
      const MoodBar(dayLetter: 'F', value: 0.8, isToday: false),
      const MoodBar(dayLetter: 'S', value: 0.4, isToday: false),
      const MoodBar(dayLetter: 'S', value: 0.7, isToday: true),
    ];

    testWidgets('builds and shows footer text', (tester) async {
      await tester.pumpWidget(_wrap(
        MoodWeekChart(week: week, dark: false),
      ));
      expect(
        find.textContaining('Above the line'),
        findsOneWidget,
      );
    });

    testWidgets('renders for all-null week without error', (tester) async {
      final emptyWeek = List.generate(
        7,
        (i) => MoodBar(
          dayLetter: 'M',
          value: null,
          isToday: i == 6,
        ),
      );
      await tester.pumpWidget(_wrap(
        MoodWeekChart(week: emptyWeek, dark: false),
      ));
      expect(find.textContaining('Above the line'), findsOneWidget);
    });
  });

  // ── MoodOrb ────────────────────────────────────────────────────────────────

  group('MoodOrb', () {
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
