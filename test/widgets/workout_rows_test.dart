import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/theme/theme.dart';
import 'package:opal/widgets/app_icon.dart';
import 'package:opal/widgets/day_strip.dart';
import 'package:opal/widgets/exercise_row.dart';
import 'package:opal/widgets/session_row.dart';

final _colors = AppColors.light();

const _days = [
  DayMark(letter: 'M', done: true, today: false),
  DayMark(letter: 'T', done: false, today: false),
  DayMark(letter: 'W', done: false, today: true),
  DayMark(letter: 'T', done: false, today: false),
  DayMark(letter: 'F', done: false, today: false),
  DayMark(letter: 'S', done: false, today: false),
  DayMark(letter: 'S', done: false, today: false),
];

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

BoxDecoration? _decoration(Widget w) => switch (w) {
      Container(:final decoration) => decoration as BoxDecoration?,
      DecoratedBox(:final decoration) => decoration as BoxDecoration?,
      _ => null,
    };

void main() {
  group('DayStrip', () {
    testWidgets('a done day paints an ink disc with a check', (tester) async {
      await _pump(tester, const DayStrip(days: _days, semanticLabel: 'This week'));

      final check = find.byWidgetPredicate((w) => w is AppIcon && w.name == 'checkmark');
      expect(check, findsOneWidget);
      expect(tester.widget<AppIcon>(check).color, _colors.bg);
      final disc = tester
          .widgetList(find.ancestor(of: check, matching: find.byType(Container)))
          .map(_decoration)
          .firstWhere((d) => d?.color != null);
      expect(disc!.color, _colors.ink);
    });

    testWidgets('onTap reports the index', (tester) async {
      final taps = <int>[];
      await _pump(tester, DayStrip(days: _days, semanticLabel: 'This week', onTap: taps.add, selected: 2));

      await tester.tap(find.text('F'));
      expect(taps, [4]);
      final column = find.ancestor(of: find.text('F'), matching: find.byType(GestureDetector)).first;
      expect(tester.getSize(column).height, greaterThanOrEqualTo(44));
      expect(tester.getSize(column).width, greaterThanOrEqualTo(44));
    });
  });

  group('SessionRow', () {
    testWidgets('newBest shows New best in thrivingInk', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        SessionRow(when: 'Mon', title: 'Push Day A', detail: '52 min · 4.1 t', newBest: true, onTap: () {}),
      );

      expect(tester.widget<Text>(find.text('New best')).style?.color, _colors.thrivingInk);
      expect(find.bySemanticsLabel('Push Day A, Mon, 52 min · 4.1 t, new best'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('without newBest there is no state word', (tester) async {
      await _pump(tester, const SessionRow(when: 'Yesterday', title: 'Pull Day', detail: '40 min · 3.0 t'));

      expect(find.text('New best'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('ExerciseRow', () {
    testWidgets('the icon has no coloured tile and the row does not overflow at 1.3', (tester) async {
      await _pump(
        tester,
        const ExerciseRow(
          name: 'Barbell bench press with a pause at the bottom',
          detail: 'Chest · Barbell · Bench press, Incline press, +3',
          value: '102.5 kg',
        ),
        scale: 1.3,
      );

      expect(tester.takeException(), isNull);
      final icon = find.byType(AppIcon);
      expect(tester.widget<AppIcon>(icon).color, _colors.ink2);
      final tiles = tester
          .widgetList(find.ancestor(of: icon, matching: find.byWidgetPredicate((w) => w is Container || w is DecoratedBox)))
          .map(_decoration)
          .where((d) => d?.color != null);
      expect(tiles, isEmpty);
    });
  });
}
