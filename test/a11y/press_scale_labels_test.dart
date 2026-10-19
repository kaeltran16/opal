import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/screens/pal/pal_composer_screen.dart';
import 'package:opal/widgets/press_scale.dart';

import '../support/flush_provider_timers.dart';
import '../support/golden_harness.dart';

/// Every screen a seeded app reaches by path, tabs and pushed screens alike.
const _paths = [
  '/today',
  '/areas',
  '/areas/money',
  '/areas/move',
  '/areas/routines',
  '/areas/routines/manage',
  '/areas/nutrition',
  '/areas/sleep',
  '/areas/mood',
  '/move',
  '/move/start',
  '/move/history',
  '/move/weekly-plan',
  '/move/routine-generator',
  '/you',
  '/you/budgets',
  '/you/budgets/envelopes',
  '/you/budgets-goals',
  '/you/notifications',
  '/you/appearance',
  '/you/privacy',
  '/you/export',
  '/you/about',
  '/recap',
  '/library',
  '/email',
  '/close-out',
];

/// Screens and states reached by a tap rather than a path.
final _taps = <String, Future<void> Function(WidgetTester tester)>{
  'What Pal remembers': (tester) => _tapThrough(tester, '/you', 'What Pal remembers'),
  'Autopilot': (tester) => _tapThrough(tester, '/you', 'Autopilot'),
  'the composer, idle': (tester) async {
    appRouter(tester).push('/pal-composer');
    await tester.pumpAndSettle();
  },
  'the composer, in a conversation': (tester) async {
    appRouter(tester).push('/pal-composer');
    await tester.pumpAndSettle();
    await tester.enterText(
        find.descendant(of: find.byType(PalComposerSheet), matching: find.byType(TextField)),
        'how am I doing?');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
  },
  'the new envelope sheet': (tester) => _tapThrough(tester, '/you/budgets/envelopes', 'New envelope'),
};

Future<void> _tapThrough(WidgetTester tester, String path, String label) async {
  appRouter(tester).go(path);
  await tester.pumpAndSettle();
  final target = find.text(label).first;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

/// Every string drawn or labelled under [element].
List<String> _ownText(Element element) {
  final parts = <String>[];
  void visit(Element e) {
    switch (e.widget) {
      case Text(:final data?):
        parts.add(data);
      case RichText(:final text):
        parts.add(text.toPlainText());
      case Semantics(:final properties) when properties.label != null:
        parts.add(properties.label!);
      default:
        break;
    }
    e.visitChildren(visit);
  }

  visit(element);
  // a label set on purpose around the button (a tab's spoken state) is its own.
  element.visitAncestorElements((e) {
    if (e.widget case Semantics(:final properties) when properties.label != null) {
      parts.add(properties.label!);
    }
    return true;
  });
  return parts;
}

/// The PressScales on screen whose node reads text from outside them: a
/// labelled one must read its label alone, an unlabelled one only its own text.
List<String> _merged(WidgetTester tester) {
  final merged = <String>[];
  for (final element in find.byType(PressScale).evaluate()) {
    final press = element.widget as PressScale;
    if (press.onTap == null) continue;
    final read = tester.getSemantics(find.byWidget(press)).getSemanticsData().label;
    final label = press.semanticLabel;
    final own = _ownText(element).join('\n');
    final foreign = label != null
        ? read != label
        : read.split('\n').any((line) => line.isNotEmpty && !own.contains(line));
    if (foreign) merged.add('"${label ?? own}" reads "$read"');
  }
  return merged;
}

void _audit(String name, Future<void> Function(WidgetTester tester) reach) {
  testWidgets('$name: every PressScale reads only its own label', (tester) async {
    final handle = tester.ensureSemantics();
    await withClock(goldenClock, () async {
      pinSurface(tester);
      await bootApp(tester);
      await reach(tester);
      expect(_merged(tester), isEmpty);
      await flushProviderTimers(tester);
    });
    handle.dispose();
  });
}

/// A PressScale is read by its own label alone: no neighbouring text may
/// merge into its node.
void main() {
  for (final path in _paths) {
    _audit(path, (tester) async {
      appRouter(tester).go(path);
      await tester.pumpAndSettle();
      expect(appRouter(tester).routerDelegate.currentConfiguration.uri.path, path);
    });
  }
  _taps.forEach(_audit);
}
