@Tags(['scenario'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/router.dart';
import 'package:opal/screens/workout/routine_editor_screen.dart';
import 'package:opal/widgets/controls.dart';
import 'package:opal/widgets/exercise_row.dart';
import 'package:opal/widgets/nav_bar.dart';

import '../support/golden_harness.dart';
import 'scenario_harness.dart';

const _plank = 'Plank';
const _minutesToStep = 19;
const _tenthsKmToStep = 30;

String _theme(bool dark) => dark ? 'dark' : 'light';

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _stepper(String label) =>
    find.byWidgetPredicate((w) => w is NavIconButton && w.semanticLabel == label);

Future<void> _shot(WidgetTester tester, String step, bool dark) async {
  expect(tester.takeException(), isNull, reason: step);
  await shot(tester, '${step}_${_theme(dark)}');
}

void main() {
  scenarioTest('timed slot targets', (tester, dark) async {
    await bootApp(tester, dark: dark);
    appRouter(tester).go('${AppRoute.move.path}/${AppRoute.routineEditor.path}');
    await tester.pumpAndSettle();
    expect(find.byType(RoutineEditorScreen), findsOneWidget);

    await _tap(tester, find.text('Add exercise'));
    await tester.enterText(
        find.descendant(of: find.byType(SearchPill), matching: find.byType(TextField)), 'plank');
    await tester.pumpAndSettle();
    await _tap(tester, find.widgetWithText(ExerciseRow, _plank));
    expect(find.text('1 × 1 min'), findsOneWidget);
    await _shot(tester, 'timed_slot_added', dark);

    await _tap(tester, find.bySemanticsLabel('Edit targets for $_plank'));
    expect(find.bySemanticsLabel('Distance, No distance'), findsOneWidget);
    await _shot(tester, 'timed_slot_targets_sheet', dark);

    for (var i = 0; i < _minutesToStep; i++) {
      await tester.tap(_stepper('Increase Minutes'));
    }
    for (var i = 0; i < _tenthsKmToStep; i++) {
      await tester.tap(_stepper('Increase Distance'));
    }
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Minutes, 20 min'), findsOneWidget);
    expect(find.bySemanticsLabel('Distance, 3 km'), findsOneWidget);
    await _tap(tester, find.widgetWithText(PillButton, 'Done'));
    expect(find.text('1 × 20 min · 3 km'), findsOneWidget);
    await _shot(tester, 'timed_slot_targets', dark);
  });
}
