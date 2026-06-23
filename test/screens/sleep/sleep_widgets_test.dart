import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/controllers/sleep_controller.dart';
import 'package:opal/screens/sleep/widgets/sleep_widgets.dart';
import 'package:opal/theme/app_colors.dart';

Widget _wrap(Widget child) {
  final colors = AppColors.light(AppAccent.indigo);
  return ProviderScope(
    child: MaterialApp(
      theme: ThemeData(useMaterial3: true, extensions: [colors]),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  // ─── StageSplitBar ───────────────────────────────────────────────────────────

  testWidgets('StageSplitBar renders stage labels and hmShort values (light)',
      (t) async {
    await t.pumpWidget(_wrap(const StageSplitBar(
      deepMinutes: 90,
      remMinutes: 120,
      coreMinutes: 180,
      awakeMinutes: 30,
      light: true,
    )));
    await t.pump();

    // all four stage labels visible
    expect(find.text('DEEP'), findsOneWidget);
    expect(find.text('REM'), findsOneWidget);
    expect(find.text('CORE'), findsOneWidget);
    expect(find.text('AWAKE'), findsOneWidget);

    // hmShort values: 90m='1h30', 120m='2h', 180m='3h', 30m='0h30'
    expect(find.text('1h30'), findsOneWidget);
    expect(find.text('2h'), findsOneWidget);
    expect(find.text('3h'), findsOneWidget);
    // 30 minutes = 0h30
    expect(find.text('0h30'), findsOneWidget);
  });

  testWidgets('StageSplitBar renders on surface (light=false)', (t) async {
    await t.pumpWidget(_wrap(const StageSplitBar(
      deepMinutes: 60,
      remMinutes: 90,
      coreMinutes: 120,
      awakeMinutes: 20,
      light: false,
    )));
    await t.pump();
    expect(find.text('DEEP'), findsOneWidget);
    expect(find.text('1h'), findsOneWidget);
  });

  // ─── DurationBig ─────────────────────────────────────────────────────────────

  testWidgets('DurationBig shows hours and minutes', (t) async {
    await t.pumpWidget(_wrap(const DurationBig(
      minutes: 450, // 7h 30m
      usualMinutes: 420,
      light: true,
    )));
    await t.pump();

    expect(find.text('7'), findsOneWidget);
    expect(find.text('h'), findsOneWidget);
    // 30 padded to 2 digits
    expect(find.text('30'), findsOneWidget);
    expect(find.text('m'), findsOneWidget);
  });

  testWidgets('DurationBig shows "more than your usual" when above usual',
      (t) async {
    await t.pumpWidget(_wrap(const DurationBig(
      minutes: 450, // 7h30 — 30 more than 7h usual
      usualMinutes: 420,
      light: true,
    )));
    await t.pump();
    expect(find.textContaining('more than your usual'), findsOneWidget);
  });

  testWidgets('DurationBig shows "less than your usual" when below usual',
      (t) async {
    await t.pumpWidget(_wrap(const DurationBig(
      minutes: 390, // 6h30 — 30 less than 7h usual
      usualMinutes: 420,
      light: false,
    )));
    await t.pump();
    expect(find.textContaining('less than your usual'), findsOneWidget);
  });

  testWidgets('DurationBig shows "right on your usual" when equal', (t) async {
    await t.pumpWidget(_wrap(const DurationBig(
      minutes: 420,
      usualMinutes: 420,
      light: false,
    )));
    await t.pump();
    expect(find.text('right on your usual'), findsOneWidget);
  });

  testWidgets('DurationBig shows no delta line when usualMinutes is 0',
      (t) async {
    await t.pumpWidget(_wrap(const DurationBig(
      minutes: 420,
      usualMinutes: 0,
      light: false,
    )));
    await t.pump();
    expect(find.textContaining('your usual'), findsNothing);
  });

  // ─── SleepTrendChart ─────────────────────────────────────────────────────────

  testWidgets('SleepTrendChart builds and shows "Recent nights" header',
      (t) async {
    final week = [
      const SleepBar(dayLetter: 'M', minutes: 420, isToday: false),
      const SleepBar(dayLetter: 'T', minutes: 390, isToday: false),
      const SleepBar(dayLetter: 'W', minutes: 450, isToday: false),
      const SleepBar(dayLetter: 'T', minutes: 400, isToday: false),
      const SleepBar(dayLetter: 'F', minutes: 410, isToday: false),
      const SleepBar(dayLetter: 'S', minutes: 480, isToday: false),
      const SleepBar(dayLetter: 'S', minutes: 430, isToday: true),
    ];
    await t.pumpWidget(_wrap(SleepTrendChart(
      week: week,
      month: const [420, 390, 450, 400, 410, 480, 430],
      usualMinutes: 420,
    )));
    await t.pump();

    expect(find.text('Recent nights'), findsOneWidget);
    expect(find.text('Week'), findsOneWidget);
    expect(find.text('Month'), findsOneWidget);
    // weekday letters shown in week mode
    expect(find.text('M'), findsWidgets); // may appear twice (Mon + Thu)
    expect(find.text('S'), findsWidgets); // Sat + Sun
  });

  testWidgets('SleepTrendChart footer shows usual duration', (t) async {
    await t.pumpWidget(_wrap(SleepTrendChart(
      week: const [
        SleepBar(dayLetter: 'S', minutes: 420, isToday: true),
      ],
      month: const [420],
      usualMinutes: 420,
    )));
    await t.pump();
    // hm(420) = '7h', footer mentions it
    expect(find.textContaining('7h'), findsWidgets);
    expect(find.textContaining('fortnight'), findsOneWidget);
  });
}
