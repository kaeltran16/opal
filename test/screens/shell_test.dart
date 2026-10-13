import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:opal/screens/areas/areas_screen.dart';
import 'package:opal/screens/detail/detail_screen.dart';
import 'package:opal/screens/move/workout_history_screen.dart';
import 'package:opal/screens/pal/pal_composer_screen.dart';
import 'package:opal/screens/shell/loop_shell.dart';
import 'package:opal/widgets/glass_tab_bar.dart';
import 'package:opal/widgets/inset_section.dart';

import '../support/flush_provider_timers.dart';
import '../support/golden_harness.dart' show bootApp;

const _tabLabels = ['Today', 'Areas', 'Workout', 'You'];

Finder get _todayList => find.byType(Scrollable).first;

Finder _tab(String label) => find.descendant(
    of: find.byType(GlassTabBar), matching: find.bySemanticsLabel(label));

GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(LoopShell)));

String _path(WidgetTester tester) =>
    _router(tester).routerDelegate.currentConfiguration.uri.path;

void main() {
  testWidgets('the tabs carry their semantic labels', (tester) async {
    await bootApp(tester);

    for (final label in _tabLabels) {
      expect(
        find.descendant(
          of: find.byType(GlassTabBar),
          matching: find.bySemanticsLabel(label),
        ),
        findsOneWidget,
        reason: label,
      );
    }

    await flushProviderTimers(tester);
  });

  testWidgets('the bar shows Today, Areas, Workout and You in order',
      (tester) async {
    await bootApp(tester);

    final lefts = [for (final label in _tabLabels) tester.getCenter(_tab(label)).dx];
    expect(lefts, orderedEquals([...lefts]..sort()));

    await flushProviderTimers(tester);
  });

  testWidgets('re-tapping Areas on an area page returns to the Areas root',
      (tester) async {
    await bootApp(tester);

    await tester.tap(_tab('Areas'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListRow, 'Money'));
    await tester.pumpAndSettle();
    expect(find.byType(DetailScreen), findsOneWidget);
    expect(_path(tester), '/areas/money');

    await tester.tap(_tab('Areas'));
    await tester.pumpAndSettle();

    expect(_path(tester), '/areas');
    expect(find.byType(DetailScreen), findsNothing);
    expect(find.byType(AreasScreen), findsOneWidget);

    await flushProviderTimers(tester);
  });

  testWidgets("switching tabs keeps Workout's stack", (tester) async {
    await bootApp(tester);

    await tester.tap(_tab('Workout'));
    await tester.pumpAndSettle();
    _router(tester).go('/move/history');
    await tester.pumpAndSettle();
    expect(find.byType(WorkoutHistoryScreen), findsOneWidget);

    await tester.tap(_tab('Areas'));
    await tester.pumpAndSettle();
    expect(_path(tester), '/areas');
    await tester.tap(_tab('Workout'));
    await tester.pumpAndSettle();

    expect(_path(tester), '/move/history');
    expect(find.byType(WorkoutHistoryScreen), findsOneWidget);

    await flushProviderTimers(tester);
  });

  testWidgets('scrolling down minimizes the tab bar and up restores it',
      (tester) async {
    await bootApp(tester);

    await tester.drag(_todayList, const Offset(0, -300));
    await tester.pumpAndSettle();

    // only the active tab's circle is left.
    expect(find.bySemanticsLabel(RegExp('Today tab')), findsOneWidget);
    for (final label in _tabLabels.skip(1)) {
      expect(
        find.descendant(
          of: find.byType(GlassTabBar),
          matching: find.bySemanticsLabel(label),
        ),
        findsNothing,
        reason: label,
      );
    }

    await tester.drag(_todayList, const Offset(0, 100));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(RegExp('Today tab')), findsNothing);
    for (final label in _tabLabels) {
      expect(
        find.descendant(
          of: find.byType(GlassTabBar),
          matching: find.bySemanticsLabel(label),
        ),
        findsOneWidget,
        reason: label,
      );
    }

    await flushProviderTimers(tester);
  });

  for (final (name, label) in [
    ('ask bar', 'Tell Pal anything'),
    ('mic', 'Dictate'),
  ]) {
    testWidgets('tapping the $name opens the composer sheet', (tester) async {
      await bootApp(tester);
      expect(find.byType(PalComposerSheet), findsNothing);

      await tester.tap(find.bySemanticsLabel(label));
      await tester.pumpAndSettle();

      expect(find.byType(PalComposerSheet), findsOneWidget);

      await flushProviderTimers(tester);
    });
  }
}
