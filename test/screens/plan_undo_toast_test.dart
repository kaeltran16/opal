import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/controllers/plan_session_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/screens/shell/plan_undo_toast.dart';
import 'package:opal/screens/today/day_plan.dart';
import 'package:opal/theme/app_colors.dart';

import '../support/golden_harness.dart' show NoHaptics;

const _closeOut = PlanItem(
  id: 'closeout',
  kind: PlanKind.closeOut,
  title: 'Close-out',
  icon: 'moon.fill',
);

const _morning = PlanItem(
  id: 'routine:morning',
  kind: PlanKind.routine,
  title: 'Morning',
  icon: 'sun.max.fill',
);

/// The toast alone under a scaffold, with the container that drives it.
Future<ProviderContainer> _pump(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    hapticsServiceProvider.overrideWithValue(const NoHaptics()),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: ThemeData(useMaterial3: true, extensions: [AppColors.light()]),
      home: const Scaffold(body: Align(alignment: Alignment.bottomCenter, child: PlanUndoToast())),
    ),
  ));
  return container;
}

PlanSessionController _plan(ProviderContainer c) => c.read(planSessionControllerProvider.notifier);

Finder get _toast => find.byKey(planUndoToastKey);

Finder _inToast(Finder matching) => find.descendant(of: _toast, matching: matching);

void main() {
  testWidgets('a put-off names the item and offers Undo', (tester) async {
    final c = await _pump(tester);
    expect(_toast, findsNothing);

    _plan(c).putOff(_closeOut);
    await tester.pump();

    expect(_inToast(find.text('Put off until tomorrow: Close-out')), findsOneWidget);
    expect(_inToast(find.text('Undo')), findsOneWidget);
  });

  testWidgets('Undo restores the plan and hides the toast', (tester) async {
    final c = await _pump(tester);
    _plan(c).putOff(_closeOut);
    await tester.pump();

    await tester.tap(_inToast(find.text('Undo')));
    await tester.pumpAndSettle();

    expect(c.read(planSessionControllerProvider).settled, isEmpty);
    expect(_toast, findsNothing);
  });

  testWidgets('the toast leaves after six seconds', (tester) async {
    final c = await _pump(tester);
    _plan(c).putOff(_closeOut);
    await tester.pump();

    await tester.pump(planToastDuration);

    expect(_toast, findsNothing);
    // leaving drops only the toast, not the change.
    expect(c.read(planSessionControllerProvider).settled, {'closeout': false});
  });

  testWidgets('a second change restarts the timer with its own label', (tester) async {
    final c = await _pump(tester);
    _plan(c).putOff(_closeOut);
    await tester.pump();
    await tester.pump(planToastDuration - const Duration(seconds: 1));

    _plan(c).putOff(_morning);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(_inToast(find.text('Put off until tomorrow: Morning')), findsOneWidget);
    expect(_inToast(find.text('Put off until tomorrow: Close-out')), findsNothing);

    await tester.pump(planToastDuration);
    expect(_toast, findsNothing);
  });

  testWidgets('a bring-back names the item with no Undo', (tester) async {
    final c = await _pump(tester);
    _plan(c).putOff(_closeOut);
    _plan(c).bringBack(_closeOut);
    await tester.pump();

    expect(_inToast(find.text('Close-out is back on today')), findsOneWidget);
    expect(_inToast(find.text('Undo')), findsNothing);
  });

  testWidgets('the toast is a live region with an Undo button', (tester) async {
    final semantics = tester.ensureSemantics();
    final c = await _pump(tester);
    _plan(c).putOff(_closeOut);
    await tester.pump();

    expect(
      tester.getSemantics(_inToast(find.text('Put off until tomorrow: Close-out'))),
      isSemantics(isLiveRegion: true, label: 'Put off until tomorrow: Close-out'),
    );
    final undo = _inToast(find.bySemanticsLabel('Undo'));
    expect(
      tester.getSemantics(undo),
      isSemantics(isButton: true, label: 'Undo', hasTapAction: true),
    );
    expect(tester.getSize(undo).height, greaterThanOrEqualTo(44));
    semantics.dispose();
  });
}
