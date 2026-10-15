@Tags(['scenario'])
library;

// one step per visible change the oura defects fixes made, each asserted
// before it is shot in light and dark.

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/analysis/area_state.dart';
import 'package:opal/app.dart';
import 'package:opal/controllers/plan_session_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/controllers/recap_controller.dart';
import 'package:opal/controllers/rituals_controller.dart';
import 'package:opal/controllers/today_controller.dart';
import 'package:opal/data/repositories/repositories.dart';
import 'package:opal/data/seed/seed_data.dart';
import 'package:opal/models/models.dart';
import 'package:opal/router.dart';
import 'package:opal/screens/areas/areas_screen.dart';
import 'package:opal/screens/detail/detail_screen.dart';
import 'package:opal/screens/profile/profile_screen.dart';
import 'package:opal/screens/recap/recap_screen.dart';
import 'package:opal/screens/reflect/evening_close_out_screen.dart';
import 'package:opal/screens/rituals/rituals_builder_screen.dart';
import 'package:opal/screens/rituals/routine_player_screen.dart';
import 'package:opal/screens/settings/budgets_goals_screen.dart';
import 'package:opal/screens/today/today_screen.dart';
import 'package:opal/screens/pal/pal_composer_screen.dart';
import 'package:opal/screens/workout/post_workout_screen.dart';
import 'package:opal/screens/workout/routine_generator_screen.dart';
import 'package:opal/theme/theme.dart';
import 'package:opal/widgets/app_icon.dart';
import 'package:opal/widgets/contributor_bar.dart';
import 'package:opal/widgets/controls.dart';
import 'package:opal/widgets/failure_note.dart';
import 'package:opal/widgets/glass_tab_bar.dart';
import 'package:opal/widgets/nav_bar.dart';
import 'package:opal/widgets/week_bars.dart';

import '../support/failing_stream.dart';
import '../support/golden_harness.dart' show appRouter;
import '../support/today_fixture.dart';
import 'scenario_harness.dart';

const _closeOutTitle = 'Close-out';
const _closeOutLoadError = "Couldn't load your routines. Try again in a moment.";
const _manageLoadError = "Couldn't load routines. Try again in a moment.";
const _deleteFailed = "Couldn't delete. Try again.";
const _noSteps = 'No steps in your routines yet.';
const _morningRow = 'Morning, 7:00 AM, 5 steps. Edit';
const _manageRoute = '/areas/routines/manage';
const _morningPagesStarter = 'Finished morning pages';

/// A target the stored goal or a routine-less day would draw: `of 5`, `of 0`.
final _staleTarget = RegExp(r'of [05]');

/// No routines, a stored target of 5, and a step logged that no routine has.
const _noRoutinesDay = TodayDay(routines: [], legacyRitual: true);

/// The stored names of the seed routines' glyphs, all filled forms.
const _routineIcons = ['sunrise.fill', 'sun.max.fill', 'moon.stars.fill'];

/// The Manage icon picker's keys, as `_iconChoices` lists them.
const _pickerIcons = [
  'sparkles', 'sunrise.fill', 'sun.max.fill', 'moon.stars.fill', 'drop.fill', //
  'bolt.fill', 'leaf.fill', 'figure.walk', 'book.closed.fill', 'books.vertical.fill',
  'character.book.closed.fill', 'tray.fill', 'cup.and.saucer.fill', 'heart.fill',
];

/// Late enough that one routine of three done is Needs care.
final _night = Clock.fixed(DateTime(2026, 9, 28, 21));

/// Past the collapse range of You's large title.
const _collapseDrag = Offset(0, -400);

/// The drag that reorders a Manage row: six short moves up.
const _dragMoves = 6;
const _dragStep = Offset(0, -40);
const _dragPause = Duration(milliseconds: 50);
const double _scrollStep = 200;

/// Where a shot puts a You section's heading: just under the collapsed title.
const double _sectionTop = 0.15;

const _stretch = RitualRoutine(
  id: 'stretch',
  name: 'Stretch break',
  time: '3:00 PM',
  tone: RitualTone.midday,
  icon: 'leaf.fill',
  blurb: 'Loosen up',
  order: 3,
);

const _journal = RitualRoutine(
  id: 'journal',
  name: 'Journal',
  time: '',
  tone: RitualTone.evening,
  icon: 'character.book.closed.fill',
  blurb: 'A line a day',
  order: 4,
);

/// An untimed routine with a step, so it sorts after the close-out.
const _anyTime = RitualRoutine(
  id: 'any-time',
  name: 'Any time',
  time: '',
  tone: RitualTone.midday,
  icon: 'sparkles',
  blurb: 'Whenever it fits',
  order: 5,
  steps: [RitualStep(id: 'any-time-step-0', title: 'Breathe', note: '', icon: 'sparkles')],
);

/// One routine with no steps, a stored target of 5, and a step logged that no
/// routine has.
const _steplessDay = TodayDay(routines: [_stretch], legacyRitual: true);

RitualRoutine _seed(String id) => SeedData.ritualRoutines().singleWhere((r) => r.id == id);

/// The morning routine, done, and one routine with no steps.
TodayDay get _fullAndEmpty =>
    TodayDay(routines: [_seed('morning'), _stretch], firstRoutineDone: true);

/// A ritual repository whose load or writes fail. A [gate] holds each failing
/// upsert until it completes, so a step can shoot the write in flight.
class _Rituals extends RitualRepository {
  _Rituals(super.db, {this.failLoad = false, this.failWrites = false, this.gate});

  final bool failLoad, failWrites;
  final Completer<void>? gate;
  int upserts = 0;

  @override
  Stream<List<RitualRoutine>> watchRoutines() => failLoad
      ? failingStream<List<RitualRoutine>>(StateError('routines query failed'))
      : super.watchRoutines();

  @override
  Future<String> upsertRoutine(RitualRoutine routine) async {
    if (!failWrites) return super.upsertRoutine(routine);
    upserts++;
    await gate?.future;
    throw StateError('disk full');
  }

  @override
  Future<void> deleteRoutine(String id) async {
    if (!failWrites) return super.deleteRoutine(id);
    throw StateError('disk full');
  }

  @override
  Future<void> reorderRoutines(List<RitualRoutine> ordered) async {
    if (!failWrites) return super.reorderRoutines(ordered);
    throw StateError('disk full');
  }
}

Override _rituals({bool failLoad = false, bool failWrites = false, Completer<void>? gate}) =>
    ritualRepositoryProvider.overrideWith((ref) => _Rituals(ref.watch(loopDatabaseProvider),
        failLoad: failLoad, failWrites: failWrites, gate: gate));

class _FailingGoals extends GoalsRepository {
  _FailingGoals(super.db);

  @override
  Future<void> upsert(Goals goals) async => throw StateError('disk full');
}

class _FailingWorkouts extends WorkoutRepository {
  _FailingWorkouts(super.db);

  @override
  Future<String> insert(Workout workout) async => throw StateError('disk full');
}

class _FailingRoutines extends RoutineRepository {
  _FailingRoutines(super.db);

  @override
  Future<String> insert(Routine routine) async => throw StateError('disk full');
}

String _theme(bool dark) => dark ? 'dark' : 'light';

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(LoopApp)));

Finder _within(Type screen, Finder matching) =>
    find.descendant(of: find.byType(screen), matching: matching);

Finder _onToday(Finder matching) => _within(TodayScreen, matching);

/// The action card's title.
Finder _card(String title) =>
    find.descendant(of: find.byKey(todayCardKey), matching: find.text(title));

/// The close-out's row, open or done.
Finder get _closeOutRows => find.bySemanticsLabel(RegExp('^([^:]+: )?$_closeOutTitle, '));

Future<void> _settle(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

/// Scrolls [finder] into view and taps the last match, the top sheet's.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _settle(tester, finder.last);
  await tester.tap(finder.last);
  await tester.pumpAndSettle();
}

Future<void> _tapLabel(WidgetTester tester, String label) =>
    _tap(tester, find.bySemanticsLabel(label));

Future<void> _go(WidgetTester tester, String location) async {
  appRouter(tester).go(location);
  await tester.pumpAndSettle();
}

Future<void> _push(WidgetTester tester, String location) async {
  unawaited(appRouter(tester).push(location));
  await tester.pumpAndSettle();
}

/// Scrolls Today back to its top, so a shot frames the lead.
Future<void> _todayToTop(WidgetTester tester) async {
  await tester.drag(find.byType(TodayScreen), const Offset(0, 600));
  await tester.pumpAndSettle();
}

Future<void> _toTab(WidgetTester tester, String tab) async {
  await tester.tap(find.descendant(of: find.byType(GlassTabBar), matching: find.text(tab)));
  await tester.pumpAndSettle();
}

Future<void> _toAreas(WidgetTester tester) async {
  await tester.tap(find.descendant(
      of: find.byType(GlassTabBar), matching: find.bySemanticsLabel(RegExp('^Areas'))));
  await tester.pumpAndSettle();
  expect(find.byType(AreasScreen), findsOneWidget);
}

Finder _onPage(Finder matching) => _within(DetailScreen, matching);

Finder get _pageScrollable => _onPage(find.byType(Scrollable)).first;

/// Opens the routines area page from its card on the Areas tab.
Future<void> _openRoutinesArea(WidgetTester tester) async {
  await _toAreas(tester);
  await _tap(tester, find.bySemanticsLabel(RegExp(r'^Routines([:,]|$)')));
  expect(find.byWidgetPredicate((w) => w is DetailScreen && w.area.title == 'Routines'),
      findsOneWidget);
}

Future<void> _bootManage(WidgetTester tester, bool dark, {List<Override> overrides = const []}) async {
  await bootToday(tester, dark: dark, overrides: overrides);
  await _go(tester, _manageRoute);
  expect(find.byType(RitualsBuilderScreen), findsOneWidget);
}

Future<void> _openMorning(WidgetTester tester) async {
  await _tapLabel(tester, _morningRow);
  expect(find.text('Edit routine'), findsOneWidget);
}

Future<void> _renameMorningAndSave(WidgetTester tester) async {
  await _openMorning(tester);
  await tester.enterText(find.widgetWithText(TextField, 'Morning'), 'Mornings');
  await tester.pumpAndSettle();
  await _tapLabel(tester, 'Save');
}

double _top(WidgetTester tester, String text) => tester.getTopLeft(find.text(text)).dy;

Finder _snack(String text) => find.descendant(of: find.byType(SnackBar), matching: find.text(text));

Finder _onYou(Finder matching) => _within(ProfileScreen, matching);

Future<void> _openYou(WidgetTester tester) async {
  await tester.tap(find.descendant(of: find.byType(GlassTabBar), matching: find.text('You')));
  await tester.pumpAndSettle();
  expect(find.byType(ProfileScreen), findsOneWidget);
}

void main() {
  // --- an empty routine does not count ---

  scenarioTest('empty_routine_today', (tester, dark) async {
    await bootToday(tester, dark: dark, day: _fullAndEmpty);

    final today = _container(tester).read(todayStateProvider).requireValue;
    expect(today.ritualsTarget, 1);
    expect(today.ritualsDone, 1);
    expect(_onToday(find.text(_stretch.name)), findsNothing);
    expect(find.bySemanticsLabel(RegExp('${_stretch.name}, ')), findsNothing);
    // the full routine is done, so it reads done and is not on the card.
    expect(find.bySemanticsLabel('Morning, Done'), findsOneWidget);
    expect(_card('Morning'), findsNothing);
    await _todayToTop(tester);
    await shot(tester, 'empty_routine_today_${_theme(dark)}');
  });

  scenarioTest('routines_area_no_steps', (tester, dark) async {
    await bootToday(tester, dark: dark, day: const TodayDay(routines: [_stretch, _journal]));
    await _openRoutinesArea(tester);

    expect(_onPage(find.text(_noSteps)), findsOneWidget);
    expect(_onPage(find.text('0')), findsOneWidget);
    expect(_onPage(find.text('steps in your routines')), findsOneWidget);
    expect(_onPage(find.byType(ContributorBar)), findsNothing);
    await shot(tester, 'routines_area_no_steps_${_theme(dark)}');
  });

  scenarioTest('routines_area_mixed', (tester, dark) async {
    await bootToday(tester, dark: dark, day: _fullAndEmpty);
    await _toAreas(tester);
    final card =
        find.bySemanticsLabel('Routines, 1 of 1 done, ${AreaState.thriving.word}. Open Routines');
    await _settle(tester, card);
    expect(card, findsOneWidget);
    await _openRoutinesArea(tester);

    expect(_onPage(find.text('1')), findsOneWidget);
    expect(_onPage(find.text('of 1 routines done')), findsOneWidget);
    expect(_onPage(find.text('All 1 done.')), findsOneWidget);
    // only the Done bar: no next contributor names the empty routine.
    expect(_onPage(find.byType(ContributorBar)), findsOneWidget);
    expect(_onPage(find.text('${_stretch.name}, ${_stretch.time}')), findsNothing);
    await shot(tester, 'routines_area_mixed_${_theme(dark)}');
  });

  scenarioTest('rituals_detail_empty_routine', (tester, dark) async {
    await bootToday(tester, dark: dark, day: _fullAndEmpty);
    await _go(tester, '/today/rituals-detail');

    expect(find.byWidgetPredicate((w) => w is DetailScreen && w.area.title == 'Routines'),
        findsOneWidget);
    final chart = _onPage(find.byType(WeekBars));
    await tester.scrollUntilVisible(chart, _scrollStep, scrollable: _pageScrollable);
    await tester.pumpAndSettle();
    expect(tester.widget<WeekBars>(chart).goal, 1);
    expect(_onPage(find.text('Dashed line: all 1 routines')), findsOneWidget);
    await shot(tester, 'rituals_detail_empty_routine_${_theme(dark)}');
  });

  scenarioTest('recap_empty_routine', (tester, dark) async {
    await bootToday(tester, dark: dark, day: _fullAndEmpty, overrides: [
      recapMemoryRefreshProvider.overrideWith((_) async {}),
    ]);
    await _go(tester, '/recap?range=day');
    expect(_within(RecapScreen, find.text('Rituals')), findsOneWidget);
    expect(_within(RecapScreen, find.text('of 1')), findsOneWidget);

    // back to Today first: the recap keeps its range while its page stays up.
    await _go(tester, AppRoute.today.path);
    await _go(tester, '/weekly-review');
    expect(find.byType(RecapScreen), findsOneWidget);
    expect(_within(RecapScreen, find.text('Rituals')), findsOneWidget);
    expect(_within(RecapScreen, find.text('of ${DateTime.daysPerWeek}')), findsOneWidget);
    await shot(tester, 'recap_empty_routine_${_theme(dark)}');
  });

  scenarioTest('budgets_goals_routines_target', (tester, dark) async {
    await bootToday(tester, dark: dark, day: _fullAndEmpty);
    await _go(tester, '/you/budgets-goals');

    expect(find.byType(BudgetsGoalsScreen), findsOneWidget);
    expect(find.text('Routines'), findsOneWidget);
    expect(find.text('1 routine'), findsOneWidget);
    await shot(tester, 'budgets_goals_routines_target_${_theme(dark)}');
  });

  // --- no routines is a target of 0 ---

  scenarioTest('recap_no_routines', (tester, dark) async {
    await bootToday(tester, dark: dark, day: _noRoutinesDay, overrides: [
      recapMemoryRefreshProvider.overrideWith((_) async {}),
    ]);
    await _go(tester, '/recap?range=day');

    expect(_within(RecapScreen, find.text('Rituals')), findsOneWidget);
    expect(_within(RecapScreen, find.text(kNoRoutinesLine)), findsOneWidget);
    expect(_within(RecapScreen, find.textContaining(_staleTarget)), findsNothing);
    await shot(tester, 'recap_no_routines_${_theme(dark)}');
  });

  scenarioTest('weekly_review_no_routines', (tester, dark) async {
    await bootToday(tester, dark: dark, day: _noRoutinesDay, overrides: [
      recapMemoryRefreshProvider.overrideWith((_) async {}),
    ]);
    await _go(tester, '/weekly-review');

    expect(find.byType(RecapScreen), findsOneWidget);
    expect(_within(RecapScreen, find.text('Rituals')), findsOneWidget);
    expect(_within(RecapScreen, find.text(kNoRoutinesLine)), findsOneWidget);
    expect(_within(RecapScreen, find.textContaining(_staleTarget)), findsNothing);
    await shot(tester, 'weekly_review_no_routines_${_theme(dark)}');
  });

  scenarioTest('composer_rituals_turn_no_routines', (tester, dark) async {
    await bootToday(tester, dark: dark, day: _noRoutinesDay,
        pal: TodayPal(offline: true, proposals: const []));
    await _push(tester, AppRoute.palComposer.path);
    final sheet = find.byType(PalComposerSheet);
    await _tap(tester, find.descendant(of: sheet, matching: find.text(_morningPagesStarter)));

    Finder inSheet(Finder matching) => find.descendant(of: sheet, matching: matching);
    expect(inSheet(find.text('Rituals today')), findsOneWidget);
    expect(inSheet(find.text(kNoRoutinesLine)), findsOneWidget);
    expect(inSheet(find.textContaining(_staleTarget)), findsNothing);
    await shot(tester, 'composer_rituals_turn_no_routines_${_theme(dark)}');
  });

  // --- stepless routines read the stepless line ---

  scenarioTest('recap_stepless_routines', (tester, dark) async {
    await bootToday(tester, dark: dark, day: _steplessDay, overrides: [
      recapMemoryRefreshProvider.overrideWith((_) async {}),
    ]);
    await _go(tester, '/recap?range=day');

    expect(_within(RecapScreen, find.text('Rituals')), findsOneWidget);
    expect(_within(RecapScreen, find.text(_noSteps)), findsOneWidget);
    expect(_within(RecapScreen, find.text(kNoRoutinesLine)), findsNothing);
    expect(_within(RecapScreen, find.textContaining(_staleTarget)), findsNothing);
    await shot(tester, 'recap_stepless_routines_${_theme(dark)}');
  });

  scenarioTest('composer_rituals_turn_stepless', (tester, dark) async {
    await bootToday(tester, dark: dark, day: _steplessDay,
        pal: TodayPal(offline: true, proposals: const []));
    await _push(tester, AppRoute.palComposer.path);
    final sheet = find.byType(PalComposerSheet);
    await _tap(tester, find.descendant(of: sheet, matching: find.text(_morningPagesStarter)));

    Finder inSheet(Finder matching) => find.descendant(of: sheet, matching: matching);
    expect(inSheet(find.text('Rituals today')), findsOneWidget);
    expect(inSheet(find.text(_noSteps)), findsOneWidget);
    expect(inSheet(find.text(kNoRoutinesLine)), findsNothing);
    expect(inSheet(find.textContaining(_staleTarget)), findsNothing);
    await shot(tester, 'composer_rituals_turn_stepless_${_theme(dark)}');
  });

  // --- one close-out row on today ---

  scenarioTest('closeout_done_today', (tester, dark) async {
    await bootToday(
      tester,
      dark: dark,
      day: TodayDay(
        routines: [_seed('evening'), _seed('morning'), _seed('midday')],
        firstRoutineDone: true,
      ),
    );

    final rituals = _container(tester).read(ritualsControllerProvider).requireValue;
    expect(rituals.isComplete(rituals.evening!), isTrue);
    // a done close-out stays listed, read as done, and is off the card.
    expect(find.bySemanticsLabel('$_closeOutTitle, Done'), findsOneWidget);
    expect(_card(_closeOutTitle), findsNothing);
    expect(_onToday(find.text('Evening wind-down')), findsNothing);
    expect(find.bySemanticsLabel(RegExp(r'^Start: Midday reset, ')), findsOneWidget);
    await _todayToTop(tester);
    await shot(tester, 'closeout_done_today_${_theme(dark)}');
  });

  scenarioTest('closeout_one_row', (tester, dark) async {
    // the mock agenda, which carries close-out-tonight.
    final pal = TodayPal();
    await bootToday(tester, dark: dark, pal: pal);
    // the mock's agenda completes only on a real async turn.
    final agenda = await tester.runAsync(pal.agenda);
    final proposal = agenda!.proposals.singleWhere((p) => p.id == 'close-out-tonight');

    expect(_closeOutRows, findsOneWidget);
    expect(_onToday(find.text(proposal.title)), findsNothing);
    expect(_onToday(find.text('Evening wind-down')), findsNothing);
    await _todayToTop(tester);
    await shot(tester, 'closeout_one_row_${_theme(dark)}');

    // the one row opens the close-out, as the card's pill does.
    await _tap(tester, _closeOutRows);
    expect(find.byType(EveningCloseOutScreen), findsOneWidget);
  });

  // --- every pending proposal is reachable from You ---

  scenarioTest('you_pal_suggests', (tester, dark) async {
    final pal = TodayPal();
    await bootToday(tester, dark: dark, pal: pal);
    final agenda = await tester.runAsync(pal.agenda);
    final addRitual = agenda!.proposals.singleWhere((p) => p.addsRitual);
    final rent = agenda.proposals.singleWhere((p) => p.id == 'hold-rent-40');
    final closeOut = agenda.proposals.singleWhere((p) => p.navigatesToCloseOut);

    // beside the close-out row, today leaves the add-ritual proposal out.
    expect(_closeOutRows, findsOneWidget);
    expect(_onToday(find.text(addRitual.title)), findsNothing);
    expect(_onToday(find.text(rent.title)), findsOneWidget);

    await _toTab(tester, 'You');
    final approve = _onYou(find.bySemanticsLabel('${addRitual.approveLabel}: ${addRitual.title}'));
    final heading = _onYou(find.text('Pal suggests'));
    await _settle(tester, approve);
    expect(heading, findsOneWidget);
    for (final p in agenda.proposals) {
      expect(_onYou(find.text(p.title)), findsOneWidget, reason: p.id);
    }
    // frame the section from its heading for the shot.
    await Scrollable.ensureVisible(tester.element(heading), alignment: _sectionTop);
    await tester.pumpAndSettle();
    await shot(tester, 'you_pal_suggests_${_theme(dark)}');

    // approved from You through today's handling, so it is settled for both.
    await _tap(tester, approve);
    expect(_onYou(find.text(addRitual.title)), findsNothing);
    expect(_container(tester).read(planSessionControllerProvider).settled,
        containsPair('proposal:${addRitual.id}', true));
    await Scrollable.ensureVisible(tester.element(heading), alignment: _sectionTop);
    await tester.pumpAndSettle();
    await shot(tester, 'you_pal_suggests_approved_${_theme(dark)}');

    // put off from You, it reads put off on today too.
    await _tap(tester, _onYou(find.bySemanticsLabel('Not now: ${rent.title}')));
    expect(_onYou(find.text(rent.title)), findsNothing);
    await _toTab(tester, 'Today');
    expect(find.bySemanticsLabel('Bring back: ${rent.title}, Put off until tomorrow'),
        findsOneWidget);

    // the close-out proposal opens the close-out, as today's row does.
    await _toTab(tester, 'You');
    await _tap(tester,
        _onYou(find.bySemanticsLabel('${closeOut.approveLabel}: ${closeOut.title}')));
    expect(find.byType(EveningCloseOutScreen), findsOneWidget);
  });

  scenarioTest('you_pal_suggests_none', (tester, dark) async {
    await bootToday(tester, dark: dark, pal: TodayPal(proposals: const []));
    await _toTab(tester, 'You');
    expect(_onYou(find.text('Pal suggests')), findsNothing);
    await shot(tester, 'you_pal_suggests_none_${_theme(dark)}');
  });

  scenarioTest('you_pal_suggests_offline', (tester, dark) async {
    await bootToday(tester, dark: dark, pal: TodayPal(offline: true));
    await _toTab(tester, 'You');
    expect(_onYou(find.text('Pal suggests')), findsNothing);
    expect(_onYou(find.text('Add a 2-min wind-down ritual')), findsNothing);
    await shot(tester, 'you_pal_suggests_offline_${_theme(dark)}');
  });

  scenarioTest('closeout_care_lead', at: _night, (tester, dark) async {
    await bootToday(
      tester,
      dark: dark,
      day: TodayDay(
        routines: [_seed('morning'), _seed('evening'), _anyTime],
        firstRoutineDone: true,
      ),
    );

    final today = _container(tester).read(todayStateProvider).requireValue;
    expect(today.ritualsDone, 1);
    expect(today.ritualsTarget, 3);
    expect(_card(_closeOutTitle), findsOneWidget);
    expect(find.descendant(of: find.byKey(todayCardKey), matching: find.text('At 9:30 PM · 4 steps')),
        findsOneWidget);
    await shot(tester, 'closeout_care_lead_${_theme(dark)}');
  });

  // --- routines providers fail at once ---

  scenarioTest('closeout_load_error', (tester, dark) async {
    await bootToday(tester, dark: dark, overrides: [_rituals(failLoad: true)]);
    await _push(tester, '/close-out');

    expect(find.byType(EveningCloseOutScreen), findsOneWidget);
    expect(find.text(_closeOutLoadError), findsOneWidget);
    expect(find.text('…'), findsNothing);
    expect(find.text('Mark done'), findsNothing);
    await shot(tester, 'closeout_load_error_${_theme(dark)}');
  });

  scenarioTest('manage_load_error', (tester, dark) async {
    await _bootManage(tester, dark, overrides: [_rituals(failLoad: true)]);

    expect(find.text(_manageLoadError), findsOneWidget);
    expect(find.text('…'), findsNothing);
    expect(find.text('Morning'), findsNothing);
    await shot(tester, 'manage_load_error_${_theme(dark)}');
  });

  scenarioTest('player_load_error', (tester, dark) async {
    await bootToday(tester, dark: dark, overrides: [_rituals(failLoad: true)]);
    await _push(tester, '/rituals/player/morning');

    expect(find.byType(RoutinePlayerScreen), findsOneWidget);
    expect(find.text("Couldn't load routine"), findsOneWidget);
    expect(find.text('Try again in a moment.'), findsOneWidget);
    expect(find.text('Mark done'), findsNothing);
    await shot(tester, 'player_load_error_${_theme(dark)}');
  });

  // --- routine glyphs draw as lines ---

  scenarioTest('manage_line_glyphs', (tester, dark) async {
    await _bootManage(tester, dark);
    for (final name in _routineIcons) {
      expect(lineIconForSf(name), isNot(iconForSf(name)), reason: name);
      expect(_within(RitualsBuilderScreen, find.byIcon(lineIconForSf(name))), findsOneWidget,
          reason: name);
      expect(_within(RitualsBuilderScreen, find.byIcon(iconForSf(name))), findsNothing,
          reason: name);
    }

    await _openMorning(tester);
    final sheet = find.byType(BottomSheet);
    for (final name in _pickerIcons) {
      expect(find.descendant(of: sheet, matching: find.byIcon(lineIconForSf(name))),
          findsWidgets, reason: name);
      if (name.endsWith('.fill')) {
        expect(find.descendant(of: sheet, matching: find.byIcon(iconForSf(name))), findsNothing,
            reason: name);
      }
    }
    await _settle(tester, find.bySemanticsLabel('Heart'));
    await shot(tester, 'manage_line_glyphs_${_theme(dark)}');
  });

  scenarioTest('player_line_glyph', (tester, dark) async {
    await bootToday(tester, dark: dark);
    await _push(tester, '/rituals/player/morning');

    const icon = 'drop.fill';
    expect(_seed('morning').steps.first.icon, icon);
    expect(find.text('Step 1 of 5'), findsOneWidget);
    expect(lineIconForSf(icon), isNot(iconForSf(icon)));
    expect(_within(RoutinePlayerScreen, find.byIcon(lineIconForSf(icon))), findsWidgets);
    expect(_within(RoutinePlayerScreen, find.byIcon(iconForSf(icon))), findsNothing);
    await shot(tester, 'player_line_glyph_${_theme(dark)}');
  });

  // --- manage routines handles failed writes ---

  scenarioTest('manage_save_failed', (tester, dark) async {
    await _bootManage(tester, dark, overrides: [_rituals(failWrites: true)]);
    await _renameMorningAndSave(tester);

    final note = find.widgetWithText(FailureNote, saveFailedCopy);
    expect(note, findsOneWidget);
    expect(find.text('Edit routine'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Mornings'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _settle(tester, note);
    await shot(tester, 'manage_save_failed_${_theme(dark)}');
  });

  scenarioTest('manage_delete_failed', (tester, dark) async {
    await _bootManage(tester, dark, overrides: [_rituals(failWrites: true)]);
    await _openMorning(tester);
    await _tapLabel(tester, 'Delete routine');
    await _tapLabel(tester, 'Delete');

    final note = find.widgetWithText(FailureNote, _deleteFailed);
    expect(note, findsOneWidget);
    expect(find.text('Edit routine'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Morning'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _settle(tester, note);
    await shot(tester, 'manage_delete_failed_${_theme(dark)}');
  });

  scenarioTest('manage_reorder_failed', (tester, dark) async {
    await _bootManage(tester, dark, overrides: [_rituals(failWrites: true)]);
    final handle = find.bySemanticsLabel('Reorder Evening wind-down');
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump();
    for (var i = 0; i < _dragMoves; i++) {
      await gesture.moveBy(_dragStep);
      await tester.pump(_dragPause);
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(_within(RitualsBuilderScreen, find.widgetWithText(FailureNote, saveFailedCopy)),
        findsOneWidget);
    expect(_top(tester, 'Morning'), lessThan(_top(tester, 'Evening wind-down')));
    expect(tester.takeException(), isNull);
    await shot(tester, 'manage_reorder_failed_${_theme(dark)}');
  });

  scenarioTest('manage_save_in_flight', (tester, dark) async {
    final gate = Completer<void>();
    await _bootManage(tester, dark, overrides: [_rituals(failWrites: true, gate: gate)]);
    final repo = _container(tester).read(ritualRepositoryProvider) as _Rituals;
    await _openMorning(tester);
    final save = find.bySemanticsLabel('Save');
    await _settle(tester, save.last);

    await tester.tap(save.last);
    await tester.pump();
    await tester.tap(save.last);
    await tester.pump();

    expect(repo.upserts, 1);
    expect(tester.getSemantics(save.last), isSemantics(hasEnabledState: true, isEnabled: false));
    expect(find.byType(FailureNote), findsNothing);
    await shot(tester, 'manage_save_in_flight_${_theme(dark)}');

    gate.complete();
    await tester.pumpAndSettle();
  });

  scenarioTest('manage_failure_cleared', (tester, dark) async {
    await _bootManage(tester, dark, overrides: [_rituals(failWrites: true)]);
    await _renameMorningAndSave(tester);
    expect(find.byType(FailureNote), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Mornings'), 'Morning run');
    await tester.pumpAndSettle();

    expect(find.byType(FailureNote), findsNothing);
    expect(find.text('Edit routine'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Morning run'), findsOneWidget);
    await _settle(tester, find.bySemanticsLabel('Save').last);
    await shot(tester, 'manage_failure_cleared_${_theme(dark)}');
  });

  // --- failure copy without the em-dash ---

  scenarioTest('budgets_goals_save_failed', (tester, dark) async {
    await bootToday(tester, dark: dark, overrides: [
      goalsRepositoryProvider.overrideWith((ref) => _FailingGoals(ref.watch(loopDatabaseProvider))),
    ]);
    await _go(tester, '/you/budgets-goals');
    await _tapLabel(tester, 'Save');

    expect(_snack(saveFailedCopy), findsOneWidget);
    expect(find.byType(BudgetsGoalsScreen), findsOneWidget);
    await shot(tester, 'budgets_goals_save_failed_${_theme(dark)}');
  });

  scenarioTest('post_workout_save_failed', (tester, dark) async {
    await bootToday(tester, dark: dark, overrides: [
      workoutRepositoryProvider
          .overrideWith((ref) => _FailingWorkouts(ref.watch(loopDatabaseProvider))),
    ]);
    unawaited(appRouter(tester)
        .pushNamed(AppRoute.postWorkout.name, extra: SeedData.workouts().first));
    await tester.pumpAndSettle();
    expect(find.byType(PostWorkoutScreen), findsOneWidget);
    final save = find.text('Save to timeline');
    await tester.scrollUntilVisible(save.hitTestable(), _scrollStep,
        scrollable: _within(PostWorkoutScreen, find.byType(Scrollable)).first);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(_snack(saveFailedCopy), findsOneWidget);
    expect(find.byType(PostWorkoutScreen), findsOneWidget);
    await shot(tester, 'post_workout_save_failed_${_theme(dark)}');
  });

  scenarioTest('routine_generator_save_failed', (tester, dark) async {
    await bootToday(tester, dark: dark, overrides: [
      routineRepositoryProvider
          .overrideWith((ref) => _FailingRoutines(ref.watch(loopDatabaseProvider))),
    ]);
    await _go(tester, '/move/routine-generator');
    expect(find.byType(RoutineGeneratorScreen), findsOneWidget);
    await _tap(tester, find.byType(AppChip).first);
    await _tap(tester, find.text('Save routine'));

    expect(_snack(saveFailedCopy), findsOneWidget);
    expect(find.byType(RoutineGeneratorScreen), findsOneWidget);
    expect(find.text('Save routine'), findsOneWidget);
    await shot(tester, 'routine_generator_save_failed_${_theme(dark)}');
  });

  // --- you on the shared large-title header ---

  scenarioTest('you_header', (tester, dark) async {
    await bootToday(tester, dark: dark);
    await _openYou(tester);

    final view = tester.widget<LargeTitleScrollView>(_onYou(find.byType(LargeTitleScrollView)));
    expect(view.title, 'You');
    final subtitle = view.subtitle!;
    final title = _onYou(find.text('You'));
    expect(title, findsOneWidget);
    expect(_onYou(find.text(subtitle)), findsOneWidget);
    expect(tester.getRect(_onYou(find.text(subtitle))).top,
        greaterThanOrEqualTo(tester.getRect(title).bottom));
    await shot(tester, 'you_header_${_theme(dark)}');
  });

  scenarioTest('you_header_collapsed', (tester, dark) async {
    await bootToday(tester, dark: dark);
    await _openYou(tester);
    await tester.drag(_onYou(find.byType(CustomScrollView)), _collapseDrag);
    await tester.pumpAndSettle();

    final compact = _onYou(find.text('You'));
    expect(compact, findsOneWidget);
    final rect = tester.getRect(compact);
    final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    expect(rect.center.dx, closeTo(width / 2, 1));
    expect(rect.left, greaterThanOrEqualTo(Spacing.lg));
    await shot(tester, 'you_header_collapsed_${_theme(dark)}');
  });
}
