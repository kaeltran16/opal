@Tags(['scenario'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/controllers/plan_session_controller.dart';
import 'package:opal/screens/shell/plan_undo_toast.dart';
import 'package:opal/screens/today/today_screen.dart';
import 'package:opal/widgets/failure_note.dart' show saveFailedCopy;
import 'package:opal/widgets/glass_tab_bar.dart';
import 'package:opal/widgets/pal_ask_bar.dart';

import '../support/today_fixture.dart';
import 'scenario_harness.dart';

/// What leads Today at the scenario clock, with Pal online and no proposals.
const _lead = 'Morning';
const _plan = 'Plan tomorrow';

/// A session whose undo cannot save.
class _FailingUndo extends PlanSessionController {
  @override
  Future<void> undo() => Future.error(StateError('disk full'));
}

String _theme(bool dark) => dark ? 'dark' : 'light';

TodayPal _planPal() => TodayPal(proposals: [proposal('a', _plan)]);

Finder get _toast => find.byKey(planUndoToastKey);

Finder _inToast(Finder matching) => find.descendant(of: _toast, matching: matching);

Finder get _toastUndo => _inToast(find.text('Undo'));

Finder _onCard(Finder matching) => find.descendant(of: find.byKey(todayCardKey), matching: matching);

Finder _card(String title) => _onCard(find.text(title));

Finder _tab(String label) => find.descendant(
    of: find.byType(GlassTabBar), matching: find.bySemanticsLabel(RegExp('^$label(,|\$)')));

/// Scrolls [finder] into view and taps it.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _putOffLead(WidgetTester tester) => _tap(tester, _onCard(find.text('Not today')));

void main() {
  scenarioTest('today undo toast', (tester, dark) async {
    await bootToday(tester, dark: dark);
    expect(_card(_lead), findsOneWidget);
    expect(_toast, findsNothing);

    await _putOffLead(tester);
    expect(_card(_lead), findsNothing);
    expect(_inToast(find.text('Put off until tomorrow: $_lead')), findsOneWidget);
    await shot(tester, 'today_undo_toast_${_theme(dark)}');

    await _tap(tester, _toastUndo);
    expect(_card(_lead), findsOneWidget);
    expect(_toast, findsNothing);

    await _putOffLead(tester);
    expect(_toast, findsOneWidget);
    await tester.pump(planToastDuration);
    expect(_toast, findsNothing);
    expect(_card(_lead), findsNothing);

    await relaunchToday(tester);
    expect(find.byKey(todayCardKey), findsOneWidget);
    expect(_card(_lead), findsNothing);
    expect(_toast, findsNothing);
    await shot(tester, 'today_relaunch_${_theme(dark)}');
  });

  scenarioTest('toast approve', (tester, dark) async {
    await bootToday(tester, dark: dark, pal: _planPal());
    expect(_card(_plan), findsOneWidget);

    await _tap(tester, _onCard(find.text('Got it')));
    expect(_card(_plan), findsNothing);
    expect(_inToast(find.text('$_plan done')), findsOneWidget);
    expect(_toastUndo, findsOneWidget);
    await shot(tester, 'toast_approve_${_theme(dark)}');

    await _tap(tester, _toastUndo);
    expect(_card(_plan), findsOneWidget);
    expect(_toast, findsNothing);
  });

  scenarioTest('toast on You', (tester, dark) async {
    final skip = find.bySemanticsLabel('Not now: $_plan');
    await bootToday(tester, dark: dark, pal: _planPal());
    await _tap(tester, _tab('You'));

    await _tap(tester, skip);
    expect(skip, findsNothing);
    expect(_inToast(find.text('Put off until tomorrow: $_plan')), findsOneWidget);
    expect(tester.getRect(_toast).bottom, lessThan(tester.getRect(find.byType(PalAskBar)).top));
    await shot(tester, 'toast_you_${_theme(dark)}');

    await _tap(tester, _toastUndo);
    expect(skip, findsOneWidget);
    expect(_toast, findsNothing);
  });

  scenarioTest('toast undo fails', (tester, dark) async {
    await bootToday(tester,
        dark: dark, overrides: [planSessionControllerProvider.overrideWith(_FailingUndo.new)]);

    await _putOffLead(tester);
    await _tap(tester, _toastUndo);

    expect(find.text(saveFailedCopy), findsOneWidget);
    // the change stands, so the toast stays to offer Undo again.
    expect(_card(_lead), findsNothing);
    expect(_toastUndo, findsOneWidget);
    final snack = find.descendant(of: find.byType(SnackBar), matching: find.byType(Material)).first;
    expect(tester.getRect(snack).bottom, lessThan(tester.getRect(_toast).top));
    await shot(tester, 'toast_undo_failed_${_theme(dark)}');
  });

  scenarioTest('toast minimized ask bar', (tester, dark) async {
    await bootToday(tester, dark: dark);
    await _putOffLead(tester);
    final before = tester.getRect(_toast);

    await tester.drag(find.byType(TodayScreen), const Offset(0, -300));
    await tester.pumpAndSettle();

    // only the active tab's circle is left, with the ask bar beside it.
    expect(find.bySemanticsLabel(RegExp('Today tab')), findsOneWidget);
    expect(tester.getRect(_toast), before);
    expect(tester.getRect(find.byType(PalAskBar)).overlaps(before), isFalse);
    expect(tester.getRect(find.byType(GlassTabBar)).overlaps(before), isFalse);
    await shot(tester, 'toast_minimized_${_theme(dark)}');
  });
}
