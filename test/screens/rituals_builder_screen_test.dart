import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/controllers/providers.dart';
import 'package:opal/data/repositories/repositories.dart';
import 'package:opal/models/models.dart';
import 'package:opal/screens/rituals/rituals_builder_screen.dart';
import 'package:opal/widgets/app_icon.dart';
import 'package:opal/widgets/failure_note.dart';

import '../support/flush_provider_timers.dart';
import '../support/golden_harness.dart' show appRouter;
import '../support/today_fixture.dart';

final _monday = Clock.fixed(DateTime(2026, 9, 28, 9, 30));

const _iconWords = [
  'Sparkles', 'Sunrise', 'Sun', 'Moon', 'Drop', 'Bolt', 'Leaf', //
  'Walk', 'Book', 'Books', 'Journal', 'Tray', 'Cup', 'Heart',
];

const _deleteFailedCopy = "Couldn't delete. Try again.";

/// A ritual repository whose writes all fail. A set [gate] holds each upsert
/// until it completes, so a test can tap while the write is in flight.
class _FailingRituals extends RitualRepository {
  _FailingRituals(super.db);

  int upserts = 0;
  Completer<void>? gate;

  @override
  Future<String> upsertRoutine(RitualRoutine routine) async {
    upserts++;
    await gate?.future;
    throw StateError('disk full');
  }

  @override
  Future<void> deleteRoutine(String id) async => throw StateError('disk full');

  @override
  Future<void> reorderRoutines(List<RitualRoutine> ordered) async =>
      throw StateError('disk full');
}

final _failingWrites = [
  ritualRepositoryProvider
      .overrideWith((ref) => _FailingRituals(ref.watch(loopDatabaseProvider))),
];

/// Boots Today on a tall surface, then opens Manage routines.
void _manageTest(String name, Future<void> Function(WidgetTester tester) body,
    {List<Override> overrides = const []}) {
  testWidgets(name, (tester) async {
    await withClock(_monday, () async {
      tester.view.physicalSize = const Size(390, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      try {
        await bootToday(tester, overrides: overrides);
        appRouter(tester).go('/areas/routines/manage');
        await tester.pumpAndSettle();
        expect(find.byType(RitualsBuilderScreen), findsOneWidget);
        await body(tester);
      } finally {
        // a failed expectation must still flush, or the next test hangs.
        await flushProviderTimers(tester);
      }
    });
  });
}

RitualRepository _repo(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(RitualsBuilderScreen)))
        .read(ritualRepositoryProvider);

Future<List<RitualRoutine>> _saved(WidgetTester tester) => _repo(tester).getAll();

Future<void> _tapLabel(WidgetTester tester, Pattern label) async {
  await tester.tap(find.bySemanticsLabel(label).last);
  await tester.pumpAndSettle();
}

Future<void> _openMorning(WidgetTester tester) async {
  await _tapLabel(tester, 'Morning, 7:00 AM, 5 steps. Edit');
  expect(find.text('Edit routine'), findsOneWidget);
}

Future<void> _addStep(WidgetTester tester, String title) async {
  await _tapLabel(tester, 'Add step');
  expect(find.text('New step'), findsOneWidget);
  await tester.enterText(find.widgetWithText(TextField, 'Step title'), title);
  await tester.pumpAndSettle();
  await _tapLabel(tester, 'Save');
  expect(find.text('New step'), findsNothing);
}

Future<void> _dragEveningAboveMorning(WidgetTester tester) async {
  final handle = find.bySemanticsLabel('Reorder Evening wind-down');
  final gesture = await tester.startGesture(tester.getCenter(handle));
  await tester.pump();
  for (var i = 0; i < 6; i++) {
    await gesture.moveBy(const Offset(0, -40));
    await tester.pump(const Duration(milliseconds: 50));
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

Future<void> _renameMorningAndSave(WidgetTester tester) async {
  await _openMorning(tester);
  await tester.enterText(find.widgetWithText(TextField, 'Morning'), 'Mornings');
  await tester.pumpAndSettle();
  await _tapLabel(tester, 'Save');
}

void main() {
  _manageTest('rows show name and detail, with no remove on a row', (tester) async {
    expect(find.text('Manage routines'), findsOneWidget);
    expect(find.text('Morning'), findsOneWidget);
    expect(find.text('7:00 AM · 5 steps'), findsOneWidget);
    expect(find.text('Evening wind-down'), findsOneWidget);
    expect(find.bySemanticsLabel('Morning, 7:00 AM, 5 steps. Edit'), findsOneWidget);
    expect(find.bySemanticsLabel('Reorder Morning'), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is AppIcon && w.name == 'xmark'), findsNothing);
  });

  _manageTest('the routine row glyph draws as a line', (tester) async {
    final row = find.bySemanticsLabel('Morning, 7:00 AM, 5 steps. Edit');
    expect(
      find.descendant(of: row, matching: find.byIcon(lineIconForSf('sunrise.fill'))),
      findsOneWidget,
    );
  });

  _manageTest('tapping a row opens Edit routine with labelled step handles', (tester) async {
    await _openMorning(tester);

    expect(find.text('Tone'), findsOneWidget);
    expect(find.text('Icon'), findsOneWidget);
    expect(find.text('Steps'), findsOneWidget);
    expect(find.text('Delete routine'), findsOneWidget);
    for (final title in ['Glass of water', 'Wash my face', 'Morning pages']) {
      expect(find.bySemanticsLabel('Reorder $title'), findsOneWidget);
      expect(find.bySemanticsLabel('Remove $title'), findsOneWidget);
    }
  });

  _manageTest('Delete routine then Delete removes it from the list and the repository',
      (tester) async {
    await _openMorning(tester);
    await _tapLabel(tester, 'Delete routine');

    expect(find.text('Delete Morning?'), findsOneWidget);
    expect(
      find.text('This removes the routine and its 5 steps. '
          'What you checked off before stays in your history.'),
      findsOneWidget,
    );

    await _tapLabel(tester, 'Delete');

    expect(find.text('Edit routine'), findsNothing);
    expect(find.text('Delete Morning?'), findsNothing);
    expect(find.text('Morning'), findsNothing);
    expect((await _saved(tester)).map((r) => r.name), isNot(contains('Morning')));
  });

  _manageTest('Keep it returns to the editor with the draft intact', (tester) async {
    await _openMorning(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Morning'), 'Mornings');
    await tester.pumpAndSettle();
    await _tapLabel(tester, 'Remove Glass of water');

    await _tapLabel(tester, 'Delete routine');
    expect(find.text('Delete Mornings?'), findsOneWidget);
    expect(find.textContaining('its 4 steps.'), findsOneWidget);

    await _tapLabel(tester, 'Keep it');

    expect(find.text('Delete Mornings?'), findsNothing);
    expect(find.text('Edit routine'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Mornings'), findsOneWidget);
    expect(find.text('Glass of water'), findsNothing);
    expect(find.text('Wash my face'), findsOneWidget);
    expect((await _saved(tester)).map((r) => r.name), contains('Morning'));
  });

  _manageTest('New routine has no Delete, and Save waits for a name and a step; '
      'saved with one step it reads 1 step', (tester) async {
    await _tapLabel(tester, 'New routine');

    expect(find.text('New routine'), findsOneWidget);
    expect(find.text('Delete routine'), findsNothing);
    expect(find.text('Add at least one step.'), findsOneWidget);
    expect(tester.getSemantics(find.bySemanticsLabel('Save')),
        isSemantics(hasEnabledState: true, isEnabled: false));

    await tester.enterText(find.widgetWithText(TextField, 'Routine name'), 'Wind down');
    await tester.pumpAndSettle();
    expect(tester.getSemantics(find.bySemanticsLabel('Save')),
        isSemantics(hasEnabledState: true, isEnabled: false));
    await tester.tap(find.bySemanticsLabel('Save'));
    await tester.pumpAndSettle();
    expect(find.text('New routine'), findsOneWidget);

    await _addStep(tester, 'Read');
    expect(find.text('Add at least one step.'), findsNothing);
    await _tapLabel(tester, 'Save');

    expect(find.text('Wind down'), findsOneWidget);
    expect(find.text('Any time · 1 step'), findsOneWidget);
    expect(find.bySemanticsLabel('Wind down, any time, 1 step. Edit'), findsOneWidget);
    final saved = await _saved(tester);
    expect(saved.last.name, 'Wind down');
    expect(saved.last.steps.map((s) => s.title), ['Read']);
    expect(
      tester.getTopLeft(find.text('Wind down')).dy,
      greaterThan(tester.getTopLeft(find.text('Evening wind-down')).dy),
    );
  });

  _manageTest('a step added through the step sheet shows, and Remove takes it out',
      (tester) async {
    await _openMorning(tester);
    await _addStep(tester, 'Stretch');

    expect(find.text('Stretch'), findsOneWidget);
    expect(find.bySemanticsLabel('Reorder Stretch'), findsOneWidget);

    await _tapLabel(tester, 'Remove Stretch');
    expect(find.text('Stretch'), findsNothing);
  });

  _manageTest('selecting an icon marks only that cell selected', (tester) async {
    await _openMorning(tester);
    expect(tester.getSemantics(find.bySemanticsLabel('Sunrise')),
        isSemantics(isSelected: true, isButton: true));

    await _tapLabel(tester, 'Moon');

    for (final word in _iconWords) {
      expect(tester.getSemantics(find.bySemanticsLabel(word)),
          isSemantics(hasSelectedState: true, isSelected: word == 'Moon'),
          reason: word);
    }
  });

  _manageTest('dragging Evening wind-down above Morning persists the order', (tester) async {
    await _dragEveningAboveMorning(tester);

    expect(
      tester.getTopLeft(find.text('Evening wind-down')).dy,
      lessThan(tester.getTopLeft(find.text('Morning')).dy),
    );
    expect((await _saved(tester)).map((r) => r.name),
        ['Evening wind-down', 'Morning', 'Midday reset']);
  });

  _manageTest('a failed save keeps the sheet open with the edit and says so', (tester) async {
    await _renameMorningAndSave(tester);

    expect(find.widgetWithText(FailureNote, saveFailedCopy), findsOneWidget);
    expect(find.text('Edit routine'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Mornings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, overrides: _failingWrites);

  _manageTest('a failed delete keeps the sheet open and says so', (tester) async {
    await _openMorning(tester);
    await _tapLabel(tester, 'Delete routine');
    await _tapLabel(tester, 'Delete');

    expect(find.widgetWithText(FailureNote, _deleteFailedCopy), findsOneWidget);
    expect(find.text('Edit routine'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, overrides: _failingWrites);

  _manageTest('a failed reorder says so and keeps the saved order', (tester) async {
    await _dragEveningAboveMorning(tester);

    expect(find.widgetWithText(FailureNote, saveFailedCopy), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Morning')).dy,
      lessThan(tester.getTopLeft(find.text('Evening wind-down')).dy),
    );
    expect(tester.takeException(), isNull);
  }, overrides: _failingWrites);

  _manageTest('Save is off while a write is in flight, and a second tap makes no second write',
      (tester) async {
    final repo = _repo(tester) as _FailingRituals;
    final gate = repo.gate = Completer<void>();
    await _openMorning(tester);

    await tester.tap(find.bySemanticsLabel('Save').last);
    await tester.tap(find.bySemanticsLabel('Save').last);
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Save').last);
    await tester.pump();

    expect(repo.upserts, 1);
    expect(tester.getSemantics(find.bySemanticsLabel('Save').last),
        isSemantics(hasEnabledState: true, isEnabled: false));

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FailureNote, saveFailedCopy), findsOneWidget);
    expect(tester.getSemantics(find.bySemanticsLabel('Save').last),
        isSemantics(isButton: true, hasTapAction: true));
  }, overrides: _failingWrites);

  _manageTest('editing the name after a failed save clears the note', (tester) async {
    await _renameMorningAndSave(tester);
    expect(find.byType(FailureNote), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Mornings'), 'Morning run');
    await tester.pumpAndSettle();

    expect(find.byType(FailureNote), findsNothing);
  }, overrides: _failingWrites);
}
