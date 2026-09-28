import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/screens/pal/pal_composer_screen.dart';
import 'package:opal/widgets/glass_tab_bar.dart';

import '../support/flush_provider_timers.dart';
import '../support/golden_harness.dart' show bootApp;

const _tabLabels = ['Today', 'Workout', 'Nutrition', 'You'];

Finder get _todayList => find.byType(Scrollable).first;

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
    ('ask bar', 'Ask or log anything'),
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
