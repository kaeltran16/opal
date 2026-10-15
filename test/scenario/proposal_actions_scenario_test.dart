@Tags(['scenario'])
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/app.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/controllers/rituals_controller.dart';
import 'package:opal/data/repositories/repositories.dart';
import 'package:opal/data/seed/seed_data.dart';
import 'package:opal/models/models.dart';
import 'package:opal/screens/move/weekly_plan_screen.dart';
import 'package:opal/screens/rituals/routine_player_screen.dart';
import 'package:opal/screens/today/today_screen.dart';
import 'package:opal/services/pal/pal_service.dart';

import '../support/golden_harness.dart' show appRouter;
import '../support/today_fixture.dart';
import 'scenario_harness.dart';

const _step = 'Two-minute wind-down';
const _eveningId = 'evening';
const _saveFailed = "Couldn't save. Try again.";

/// Pal's two proposals Approve performs, as the mock sends them.
const _addRitual = PalProposal(
  id: 'add-wind-down-ritual',
  tag: 'Rituals',
  colorToken: 'rituals',
  icon: 'sparkles',
  title: 'Add a 2-min wind-down ritual',
  body: 'Your evening routine tends to slip on busy nights. A short wind-down '
      'could anchor it.',
  approveLabel: 'Add ritual',
  approveIcon: 'plus',
  doneLabel: 'Added to your Evening rituals',
  action: addRitualAction,
  ritual: (routineId: _eveningId, step: _step),
);
const _legs = PalProposal(
  id: 'move-legs-friday',
  tag: 'Workout',
  colorToken: 'move',
  icon: 'figure.run',
  title: 'Move Legs day to Friday',
  body: 'Friday is clear and open.',
  approveLabel: 'Reschedule',
  approveIcon: 'arrow.triangle.2.circlepath',
  doneLabel: 'Legs moved to Friday · plan updated',
  action: rescheduleWorkoutAction,
  slot: (weekday: DateTime.friday, routineId: 'seed-routine-legs'),
);

/// The seed routines with an evening that has no steps yet, so it is no
/// close-out and the add-ritual proposal shows on Today.
TodayDay _emptyEvening() => TodayDay(routines: [
      for (final r in SeedData.ritualRoutines())
        r.id == _eveningId ? r.copyWith(steps: const []) : r,
    ]);

/// A ritual repository whose writes fail.
class _FailingRituals extends RitualRepository {
  _FailingRituals(super.db);

  @override
  Future<String> upsertRoutine(RitualRoutine routine) async => throw StateError('disk full');
}

String _theme(bool dark) => dark ? 'dark' : 'light';

Finder _onToday(Finder matching) =>
    find.descendant(of: find.byType(TodayScreen), matching: matching);

Finder _card(String title) =>
    find.descendant(of: find.byKey(todayCardKey), matching: find.text(title));

Finder _undo(String what) => _onToday(find.bySemanticsLabel('Undo $what'));

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Scrolls Today back to its top, so a shot frames the header and the card.
Future<void> _toTop(WidgetTester tester) async {
  await tester.drag(find.byType(TodayScreen), const Offset(0, 600));
  await tester.pumpAndSettle();
}

List<String> _eveningSteps(WidgetTester tester) => [
      for (final s in ProviderScope.containerOf(tester.element(find.byType(LoopApp)))
          .read(ritualsControllerProvider)
          .requireValue
          .routines
          .firstWhere((r) => r.id == _eveningId)
          .steps)
        s.title,
    ];

Future<void> _approveAddRitual(WidgetTester tester, bool dark, {bool capture = true}) async {
  await bootToday(tester,
      dark: dark, day: _emptyEvening(), pal: TodayPal(proposals: const [_addRitual]));
  expect(_card(_addRitual.title), findsOneWidget);
  if (capture) await shot(tester, 'proposal_add_ritual_card_${_theme(dark)}');

  await _tap(tester, find.text(_addRitual.approveLabel));
  await _toTop(tester);
}

void main() {
  scenarioTest('approve add ritual', (tester, dark) async {
    await _approveAddRitual(tester, dark);

    expect(_onToday(find.text(_addRitual.title)), findsNothing);
    expect(_onToday(find.text('Undo · $_step added')), findsOneWidget);
    expect(_undo('$_step added'), findsOneWidget);
    await shot(tester, 'proposal_add_ritual_undo_${_theme(dark)}');

    unawaited(appRouter(tester).push('/rituals/player/$_eveningId'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(RoutinePlayerScreen), matching: find.text(_step)),
        findsOneWidget);
    await shot(tester, 'proposal_add_ritual_evening_${_theme(dark)}');
  });

  scenarioTest('undo restores', (tester, dark) async {
    await _approveAddRitual(tester, dark, capture: false);
    expect(_eveningSteps(tester), [_step]);

    await _tap(tester, _undo('$_step added'));

    expect(_eveningSteps(tester), isEmpty);
    expect(_card(_addRitual.title), findsOneWidget);
    expect(_onToday(find.bySemanticsLabel(RegExp('^Undo '))), findsNothing);
    await shot(tester, 'proposal_undo_restores_${_theme(dark)}');
  });

  scenarioTest('approve reschedule', (tester, dark) async {
    await bootToday(tester, dark: dark, pal: TodayPal(proposals: const [_legs]));
    expect(_card(_legs.title), findsOneWidget);

    await _tap(tester, find.text(_legs.approveLabel));
    await _toTop(tester);

    expect(_onToday(find.text('Undo · Leg Day on Friday')), findsOneWidget);
    expect(_undo('Leg Day on Friday'), findsOneWidget);
    await shot(tester, 'proposal_reschedule_undo_${_theme(dark)}');

    appRouter(tester).go('/move/weekly-plan');
    await tester.pumpAndSettle();
    final plan = find.byType(WeeklyPlanScreen);
    expect(find.descendant(of: plan, matching: find.text('Leg Day')), findsOneWidget);
    expect(find.descendant(of: plan, matching: find.text('Fri')), findsWidgets);
    await shot(tester, 'proposal_reschedule_weekly_plan_${_theme(dark)}');
  });

  scenarioTest('skip names undo', (tester, dark) async {
    await bootToday(tester, dark: dark, pal: TodayPal(proposals: const [_legs]));

    await _tap(tester, find.bySemanticsLabel('Mood check-in, any time. Do this next'));
    await _tap(tester, find.text('Not today'));
    await _toTop(tester);

    expect(_onToday(find.text('Undo · Mood check-in skipped')), findsOneWidget);
    expect(_undo('Mood check-in skipped'), findsOneWidget);
    await shot(tester, 'proposal_skip_undo_${_theme(dark)}');
  });

  scenarioTest('approve fails', (tester, dark) async {
    await bootToday(tester,
        dark: dark,
        day: _emptyEvening(),
        pal: TodayPal(proposals: const [_addRitual]),
        overrides: [
          ritualRepositoryProvider
              .overrideWith((ref) => _FailingRituals(ref.watch(loopDatabaseProvider))),
        ]);

    await _tap(tester, find.text(_addRitual.approveLabel));

    expect(find.text(_saveFailed), findsOneWidget);
    expect(_card(_addRitual.title), findsOneWidget);
    expect(_onToday(find.bySemanticsLabel(RegExp('^Undo '))), findsNothing);
    await shot(tester, 'proposal_approve_fails_${_theme(dark)}');
  });
}
