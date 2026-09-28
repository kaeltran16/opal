import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/screens/today/today_logic.dart';
import 'package:opal/theme/theme.dart';
import 'package:opal/util/format.dart';
import 'package:opal/widgets/brief_text.dart';

const _numbers = GlanceNumbers(
  spent: 38,
  budget: 60,
  moveKcal: 412,
  moveGoal: 500,
  routinesDone: 4,
  routinesTotal: 5,
);

GlanceNumbers _with({double? budget, int? moveGoal, int? routinesTotal}) => GlanceNumbers(
      spent: _numbers.spent,
      budget: budget ?? _numbers.budget,
      moveKcal: _numbers.moveKcal,
      moveGoal: moveGoal ?? _numbers.moveGoal,
      routinesDone: routinesTotal == 0 ? 0 : _numbers.routinesDone,
      routinesTotal: routinesTotal ?? _numbers.routinesTotal,
    );

Future<void> _pump(
  WidgetTester tester,
  GlanceNumbers numbers, {
  void Function(TodayArea)? onChip,
}) =>
    tester.pumpWidget(MaterialApp(
      theme: ThemeData(useMaterial3: true, extensions: [AppColors.light(AppAccent.blue)]),
      home: Scaffold(
        body: BriefText(
          lead: 'Steady start.',
          numbers: numbers,
          currency: Currency.usd,
          onChip: onChip ?? (_) {},
        ),
      ),
    ));

void main() {
  testWidgets('each chip carries its exact semantics label', (tester) async {
    await _pump(tester, _numbers);

    expect(find.bySemanticsLabel('Spent \$38 of \$60, open Money'), findsOneWidget);
    expect(find.bySemanticsLabel('Moved 412 of 500 kcal, open Move'), findsOneWidget);
    expect(find.bySemanticsLabel('4 of 5 routines done, open Routines'), findsOneWidget);
  });

  testWidgets('chips are at least 44 tall', (tester) async {
    await _pump(tester, _numbers);

    for (final label in [
      'Spent \$38 of \$60, open Money',
      'Moved 412 of 500 kcal, open Move',
      '4 of 5 routines done, open Routines',
    ]) {
      expect(tester.getSize(find.bySemanticsLabel(label)).height, greaterThanOrEqualTo(44));
    }
  });

  testWidgets('tapping a chip reports its area', (tester) async {
    final tapped = <TodayArea>[];
    await _pump(tester, _numbers, onChip: tapped.add);

    await tester.tap(find.bySemanticsLabel('Spent \$38 of \$60, open Money'));
    await tester.tap(find.bySemanticsLabel('4 of 5 routines done, open Routines'));

    expect(tapped, [TodayArea.money, TodayArea.routines]);
  });

  testWidgets('no routines omits the routines chip', (tester) async {
    await _pump(tester, _with(routinesTotal: 0));

    expect(find.bySemanticsLabel(RegExp('open Routines')), findsNothing);
    expect(find.bySemanticsLabel('Moved 412 of 500 kcal, open Move'), findsOneWidget);
  });

  testWidgets('no budget reads as amount spent', (tester) async {
    await _pump(tester, _with(budget: 0));

    expect(find.text('\$38 spent'), findsOneWidget);
    expect(find.bySemanticsLabel('Spent \$38, open Money'), findsOneWidget);
    expect(find.textContaining('of \$0'), findsNothing);
  });

  testWidgets('no move goal drops the goal from the label', (tester) async {
    await _pump(tester, _with(moveGoal: 0));

    expect(find.bySemanticsLabel('Moved 412 kcal, open Move'), findsOneWidget);
  });
}
