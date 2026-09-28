import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/screens/today/today_logic.dart';
import 'package:opal/theme/theme.dart';
import 'package:opal/util/format.dart';
import 'package:opal/widgets/whats_left_row.dart';

Future<void> _pump(
  WidgetTester tester,
  GlanceNumbers numbers, {
  void Function(TodayArea)? onTap,
}) =>
    tester.pumpWidget(MaterialApp(
      theme: ThemeData(useMaterial3: true, extensions: [AppColors.light(AppAccent.blue)]),
      home: Scaffold(
        body: WhatsLeftRow(numbers: numbers, currency: Currency.usd, onTap: onTap ?? (_) {}),
      ),
    ));

void main() {
  const numbers = GlanceNumbers(
    spent: 38,
    budget: 60,
    moveKcal: 412,
    moveGoal: 500,
    routinesDone: 4,
    routinesTotal: 5,
  );

  testWidgets('shows what is left with exact semantics labels', (tester) async {
    await _pump(tester, numbers);

    expect(find.bySemanticsLabel('Spent \$38 of \$60, \$22 left'), findsOneWidget);
    expect(find.bySemanticsLabel('Workout 412 of 500 kcal, 88 to go'), findsOneWidget);
    expect(find.bySemanticsLabel('Routines 4 of 5, 1 left'), findsOneWidget);
    expect(find.text('left to spend'), findsOneWidget);
    expect(find.text('routine left'), findsOneWidget);
    expect(find.text("Pal's brief is catching up"), findsOneWidget);
  });

  testWidgets('tapping a column reports its area', (tester) async {
    final tapped = <TodayArea>[];
    await _pump(tester, numbers, onTap: tapped.add);

    await tester.tap(find.bySemanticsLabel('Workout 412 of 500 kcal, 88 to go'));

    expect(tapped, [TodayArea.move]);
  });

  testWidgets('over budget never shows a negative amount left', (tester) async {
    await _pump(
      tester,
      const GlanceNumbers(
          spent: 65, budget: 60, moveKcal: 0, moveGoal: 500, routinesDone: 0, routinesTotal: 2),
    );

    expect(find.bySemanticsLabel('Spent \$65 of \$60, \$0 left'), findsOneWidget);
    expect(find.textContaining('−'), findsNothing);
    expect(find.textContaining('-'), findsNothing);
  });

  testWidgets('zero goals show what was done instead of what is left', (tester) async {
    await _pump(
      tester,
      const GlanceNumbers(
          spent: 38, budget: 0, moveKcal: 412, moveGoal: 0, routinesDone: 0, routinesTotal: 0),
    );

    expect(find.bySemanticsLabel('Spent \$38'), findsOneWidget);
    expect(find.bySemanticsLabel('Workout 412 kcal'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Routines')), findsNothing);
  });
}
