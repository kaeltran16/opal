@Tags(['scenario'])
library;

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/analysis/area_state.dart';
import 'package:opal/controllers/pal_composer_controller.dart';
import 'package:opal/controllers/spending_controller.dart' show DetailTracker;
import 'package:opal/controllers/today_controller.dart';
import 'package:opal/screens/pal/pal_composer_screen.dart';
import 'package:opal/screens/reflect/evening_close_out_screen.dart';
import 'package:opal/screens/rituals/routine_player_screen.dart';
import 'package:opal/models/models.dart' show RitualRoutine, RitualTone;
import 'package:opal/screens/shell/plan_undo_toast.dart';
import 'package:opal/screens/today/today_screen.dart';
import 'package:opal/screens/workout/start_workout_screen.dart';
import 'package:opal/services/pal/pal_service.dart'
    show PalProposal, PalRole, rescheduleWorkoutAction;
import 'package:opal/theme/theme.dart';
import 'package:opal/util/mood_scale.dart' show moodWord;
import 'package:opal/widgets/app_icon.dart';
import 'package:opal/widgets/controls.dart';
import 'package:opal/widgets/day_scene.dart';
import 'package:opal/widgets/pal_label.dart';
import 'package:opal/widgets/pal_lead.dart';

import '../support/golden_harness.dart' show appRouter;
import '../support/today_fixture.dart';
import 'scenario_harness.dart';

const _rentTitle = 'Set aside \$40 for rent';
const _capTitle = 'Cap dinner at \$10';
const _legsTitle = 'Move Legs day to Friday';
const _offlineLabel = 'Pal is offline · next on the clock';
const _why = 'Why this first';
const _morningLine = 'Morning is still open. Ease in before the desk.';
const _morningSaid = 'Ease into the day';

const _rent = PalProposal(
  id: 'hold-rent-40',
  tag: 'Money',
  colorToken: 'money',
  icon: 'dollarsign.circle.fill',
  title: _rentTitle,
  body: 'Rent auto-pays Monday. Holding \$40 today clears it.',
  approveLabel: 'Hold \$40',
  approveIcon: 'checkmark',
  doneLabel: 'Held \$40',
);

const _legs = PalProposal(
  id: 'move-legs',
  tag: 'Workout',
  colorToken: 'move',
  icon: 'figure.run',
  title: _legsTitle,
  body: 'Friday is clear and open.',
  approveLabel: 'Move it',
  approveIcon: 'checkmark',
  doneLabel: 'Moved',
  action: rescheduleWorkoutAction,
  slot: (weekday: 5, routineId: 'seed-routine-legs'),
);

const _cap = PalProposal(
  id: 'cap-dinner',
  tag: 'Money',
  colorToken: 'money',
  icon: 'dollarsign.circle.fill',
  title: _capTitle,
  body: 'Money needs care. Cap dinner at \$10 and the day evens out.',
  approveLabel: 'Set the cap',
  approveIcon: 'checkmark',
  doneLabel: 'Capped',
);

/// A routine with no steps yet.
const _stepless = RitualRoutine(
  id: 'stretch',
  name: 'Stretch break',
  time: '3:00 PM',
  tone: RitualTone.midday,
  icon: 'leaf.fill',
  blurb: 'Loosen up',
);

/// Past 21:00, when a routine goal under half done needs care.
final _lateNight = Clock.fixed(DateTime(2026, 9, 28, 21, 30));

/// Early evening: the morning routine is done or missed, the close-out ahead.
final _evening = Clock.fixed(DateTime(2026, 9, 28, 18, 40));

/// Only the mood check-in and Log a meal, so proposals set the count.
const _bare = TodayDay(routines: [], workout: false);

TodayPal _pal() => TodayPal(proposals: const [_rent]);

/// Pal sends the move proposal first; Money over budget must still lead.
TodayPal _carePal() => TodayPal(proposals: const [_legs, _cap]);

String _theme(bool dark) => dark ? 'dark' : 'light';

Finder _onToday(Finder matching) =>
    find.descendant(of: find.byType(TodayScreen), matching: matching);

Finder _label(String text) =>
    find.descendant(of: _onToday(find.byType(PalLabel)), matching: find.text(text));

/// Pal's line above the card.
Finder _lead(String text) =>
    find.descendant(of: _onToday(find.byType(PalLeadText)), matching: find.text(text));

Finder _onCard(Finder matching) => find.descendant(of: find.byKey(todayCardKey), matching: matching);

/// The action card's title.
Finder _card(String title) => _onCard(find.text(title));

/// The card's skip button, whatever it reads.
Finder get _skip => _onCard(find.textContaining(RegExp(r'^Not (now|today)$')));

Finder _whyButton() => _onToday(find.text(_why));

/// [title]'s row in Your day, whatever its verb and detail. A row reads a
/// verb or a detail beside its title; the card's title reads alone.
Finder _row(String title) {
  final t = RegExp.escape(title);
  return find.bySemanticsLabel(RegExp('^([^:]+: $t(, .+)?|$t, .+)\$'));
}

Finder _toast(String text) =>
    find.descendant(of: find.byKey(planUndoToastKey), matching: find.text(text));

Finder get _toastUndo =>
    find.descendant(of: find.byKey(planUndoToastKey), matching: find.text('Undo'));

/// Scrolls [finder] into view and taps it.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _pullToRefresh(WidgetTester tester) async {
  await tester.fling(find.byType(TodayScreen), const Offset(0, 400), 1000);
  await tester.pumpAndSettle();
}

/// Scrolls Today back to its top, so a shot frames the lead.
Future<void> _toTop(WidgetTester tester) async {
  await tester.drag(find.byType(TodayScreen), const Offset(0, 600));
  await tester.pumpAndSettle();
}

/// Scrolls Your day into view, so a shot frames the list.
Future<void> _toYourDay(WidgetTester tester) async {
  await Scrollable.ensureVisible(tester.element(_onToday(find.text('Your day'))));
  await tester.pumpAndSettle();
}

Future<void> _backToToday(WidgetTester tester) async {
  appRouter(tester).go('/today');
  await tester.pumpAndSettle();
}

void main() {
  const phases = {
    'morning': (7, 10, DayPhase.morning, '7:10 AM'),
    'afternoon': (14, 14, DayPhase.afternoon, '2:14 PM'),
    'evening': (18, 40, DayPhase.evening, '6:40 PM'),
  };
  for (final MapEntry(key: name, value: (hour, minute, phase, time)) in phases.entries) {
    scenarioTest('today $name', at: Clock.fixed(DateTime(2026, 9, 28, hour, minute)),
        (tester, dark) async {
      await bootToday(tester, dark: dark, pal: _pal());

      expect(tester.widget<DayScene>(find.byType(DayScene)).phase, phase);
      expect(find.text('MON 28 SEP · $time'), findsOneWidget);
      expect(_lead(_rent.body), findsOneWidget);
      expect(_label('Pal'), findsOneWidget);
      expect(_card(_rentTitle), findsOneWidget);
      expect(_onToday(find.text('Your day')), findsOneWidget);
      expect(find.byKey(todayRailKey), findsOneWidget);
      await shot(tester, 'today_${name}_${_theme(dark)}');
    });
  }

  scenarioTest('today lead line', (tester, dark) async {
    await bootToday(tester,
        dark: dark, pal: TodayPal(proposals: const [], linesByTitle: {'Morning': _morningLine}));

    expect(_label('Pal'), findsOneWidget);
    expect(_card('Morning'), findsOneWidget);
    expect(_lead(_morningLine), findsOneWidget);
    expect(_whyButton(), findsOneWidget);
    // the card: a 40px icon disc, the when line, the title, one pill and skip.
    final icon = _onCard(find.byType(AppIcon));
    expect(tester.getSize(find.ancestor(of: icon, matching: find.byType(Container)).first),
        const Size(40, 40));
    expect(tester.widgetList<Text>(_onCard(find.byType(Text))).map((t) => t.data),
        ['At 7:00 AM · 5 steps', 'Morning', 'Start', 'Not today']);
    await shot(tester, 'today_lead_line_${_theme(dark)}');
  });

  scenarioTest('today offline', (tester, dark) async {
    await bootToday(tester,
        dark: dark, pal: TodayPal(offline: true, linesByTitle: {'Morning': _morningLine}));

    expect(_label(_offlineLabel), findsOneWidget);
    expect(_whyButton(), findsNothing);
    // the overdue morning routine is first on the clock, with its own sentence.
    expect(_card('Morning'), findsOneWidget);
    expect(_lead(_morningSaid), findsOneWidget);
    expect(find.text(_morningLine), findsNothing);
    expect(find.byKey(todayRailKey), findsOneWidget);
    expect(find.textContaining("Couldn't load today"), findsNothing);
    await shot(tester, 'today_offline_${_theme(dark)}');
  });

  scenarioTest('today your day', at: _evening, (tester, dark) async {
    await bootToday(tester,
        dark: dark,
        day: const TodayDay(mood: true, firstRoutineDone: true, moveKcal: 520),
        pal: TodayPal(proposals: const [_rent, _legs]));

    await _tap(tester, find.bySemanticsLabel('Move it: $_legsTitle, Pal suggests'));
    final lead = tester.widget<Text>(_onCard(find.byType(Text)).at(1)).data!;
    await _tap(tester, _skip);

    // every kind of row: open, missed, done, put off, approved and mood.
    expect(find.bySemanticsLabel('Start: Close-out, 4 steps'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Start: Midday reset, Missed · ')), findsOneWidget);
    expect(find.bySemanticsLabel('Morning, Done'), findsOneWidget);
    expect(find.bySemanticsLabel('Bring back: $lead, Put off until tomorrow'), findsOneWidget);
    expect(find.bySemanticsLabel('$_legsTitle, Moved'), findsOneWidget);
    expect(find.bySemanticsLabel('Check in again: Mood check-in, ${moodWord(0.7)}'),
        findsOneWidget);
    expect(_onToday(find.text('· 3 of 8 done')), findsOneWidget);
    // the three done rows are ticked in ink3.
    final ink3 = tester.element(find.byType(TodayScreen)).colors.ink3;
    final ticks = tester
        .widgetList<AppIcon>(_onToday(find.byType(AppIcon)))
        .where((i) => i.name == 'checkmark' && i.color == ink3);
    expect(ticks, hasLength(3));
    await _toYourDay(tester);
    await shot(tester, 'today_your_day_${_theme(dark)}');
  });

  scenarioTest('today row opens', (tester, dark) async {
    await bootToday(tester, dark: dark, pal: _pal());
    expect(_card(_rentTitle), findsOneWidget);

    await _tap(tester, _row('Morning'));
    expect(find.byType(RoutinePlayerScreen), findsOneWidget);
    await shot(tester, 'today_row_opens_${_theme(dark)}');

    // back on today the card keeps its item: a row tap never swaps the lead.
    await _backToToday(tester);
    await _toTop(tester);
    expect(_card(_rentTitle), findsOneWidget);
    expect(_whyButton(), findsOneWidget);

    await _tap(tester, _row('Push Day A'));
    expect(find.byType(StartWorkoutScreen), findsOneWidget);

    await _backToToday(tester);
    await _tap(tester, _row('Close-out'));
    expect(find.byType(EveningCloseOutScreen), findsOneWidget);
  });

  // approving performs the proposal, moving Leg Day to Friday, and the
  // toast's Undo reverses it.
  scenarioTest('today row approve', (tester, dark) async {
    await bootToday(tester, dark: dark, pal: TodayPal(proposals: const [_rent, _legs]));
    expect(_card(_rentTitle), findsOneWidget);

    await _tap(tester, find.bySemanticsLabel('Move it: $_legsTitle, Pal suggests'));

    final planned = find.descendant(
        of: find.byKey(planUndoToastKey), matching: find.textContaining('Planned Leg Day for '));
    expect(planned, findsOneWidget);
    expect(_toastUndo, findsOneWidget);
    expect(find.bySemanticsLabel('$_legsTitle, Moved'), findsOneWidget);
    expect(_card(_rentTitle), findsOneWidget);
    await shot(tester, 'today_row_approve_${_theme(dark)}');

    await _tap(tester, _toastUndo);
    expect(planned, findsNothing);
    expect(find.bySemanticsLabel('Move it: $_legsTitle, Pal suggests'), findsOneWidget);
    expect(_card(_rentTitle), findsOneWidget);
  });

  scenarioTest('today bring back', (tester, dark) async {
    await bootToday(tester, dark: dark, pal: TodayPal(proposals: const []));

    await _tap(tester, _skip);
    expect(_card('Morning'), findsNothing);
    final putOff = find.bySemanticsLabel('Bring back: Morning, Put off until tomorrow');
    expect(putOff, findsOneWidget);

    await _tap(tester, putOff);
    expect(_toast('Morning is back on today'), findsOneWidget);
    expect(_toastUndo, findsNothing);
    expect(find.bySemanticsLabel('Start: Morning, 5 steps'), findsOneWidget);
    await _toTop(tester);
    expect(_card('Morning'), findsOneWidget);
    await shot(tester, 'today_bring_back_${_theme(dark)}');
  });

  scenarioTest('today mood again', (tester, dark) async {
    await bootToday(tester, dark: dark, day: const TodayDay(mood: true), pal: _pal());

    await _tap(tester, find.bySemanticsLabel('Check in again: Mood check-in, ${moodWord(0.7)}'));

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.descendant(of: find.byType(BottomSheet), matching: find.text('Check in')),
        findsOneWidget);
    await shot(tester, 'today_mood_again_${_theme(dark)}');
  });

  scenarioTest('today mood logger', (tester, dark) async {
    await bootToday(tester, dark: dark, pal: _pal());

    // the row tap opens the logger, as the card's pill does.
    await _tap(tester, find.bySemanticsLabel('Check in: Mood check-in'));

    final sheet = find.byType(BottomSheet);
    expect(find.descendant(of: sheet, matching: find.text('Check in')), findsOneWidget);
    expect(
      find.descendant(of: sheet, matching: find.widgetWithText(PillButton, 'Log mood')),
      findsOneWidget,
    );
    await shot(tester, 'today_mood_logger_${_theme(dark)}');
  });

  scenarioTest('today rest', (tester, dark) async {
    await bootToday(tester, dark: dark, day: const TodayDay.empty());

    // nothing is set up, so the mood check-in and a meal are all that is asked.
    await _tap(tester, _skip);
    await _tap(tester, _skip);

    expect(_card('All done'), findsOneWidget);
    expect(_card("That's the day"), findsOneWidget);
    expect(_lead('Nothing is left. Rest up.'), findsOneWidget);
    expect(_skip, findsNothing);
    expect(_whyButton(), findsNothing);
    expect(find.bySemanticsLabel(RegExp(r'^Bring back: ')), findsNWidgets(2));
    // let the put-off's toast leave, so the shot is the rested screen.
    await tester.pump(planToastDuration);
    await tester.pumpAndSettle();
    await shot(tester, 'today_rest_${_theme(dark)}');
  });

  scenarioTest('today online proposal leads', (tester, dark) async {
    await bootToday(tester, dark: dark, pal: _pal());

    expect(_label('Pal'), findsOneWidget);
    expect(_card(_rentTitle), findsOneWidget);
    expect(_lead(_rent.body), findsOneWidget);
    expect(_whyButton(), findsOneWidget);
    await shot(tester, 'today_online_proposal_${_theme(dark)}');
  });

  scenarioTest('today why this first', (tester, dark) async {
    const question = 'Why $_rentTitle first?';
    await bootToday(tester, dark: dark, pal: _pal());

    await _tap(tester, _whyButton());

    final sheet = find.byType(PalComposerSheet);
    expect(sheet, findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text(question)), findsOneWidget);
    final about = tester.widget<PalComposerSheet>(sheet).about;
    // the reason rides with the question, so Pal explains the rule it was given.
    expect(about, contains("Pal proposed it, and Pal's proposals lead while Pal is online."));
    final messages = ProviderScope.containerOf(tester.element(sheet))
        .read(palComposerControllerProvider(seed: question, about: about))
        .messages;
    expect(messages.first.role, PalRole.user);
    expect(messages.first.note, about);
    expect(messages.last.role, PalRole.assistant);
    expect(find.descendant(of: sheet, matching: find.text(messages.last.text)), findsOneWidget);
    await shot(tester, 'today_why_${_theme(dark)}');
  });

  scenarioTest('today money needs care', (tester, dark) async {
    await bootToday(tester, dark: dark, pal: _carePal(), day: const TodayDay(spent: 80));

    expect(_label('Pal'), findsOneWidget);
    expect(_card(_capTitle), findsOneWidget);
    expect(_whyButton(), findsOneWidget);
    await shot(tester, 'today_money_care_${_theme(dark)}');
  });

  scenarioTest('today money needs care offline', (tester, dark) async {
    final pal = _carePal();
    await bootToday(tester, dark: dark, pal: pal, day: const TodayDay(spent: 80));
    expect(_card(_capTitle), findsOneWidget);

    pal.offline = true;
    await _pullToRefresh(tester);

    expect(_label(_offlineLabel), findsOneWidget);
    expect(_card(_capTitle), findsOneWidget);
    expect(_whyButton(), findsNothing);
    await shot(tester, 'today_money_care_offline_${_theme(dark)}');
  });

  scenarioTest('today error', (tester, dark) async {
    await bootToday(tester, dark: dark, overrides: [
      todayStateProvider.overrideWith((ref) => Stream.error(StateError('no database'))),
    ]);

    expect(find.text("Couldn't load today. Try again in a moment."), findsOneWidget);
    expect(find.byKey(todayCardKey), findsNothing);
    await shot(tester, 'today_error_${_theme(dark)}');
  });

  scenarioTest('today loading', (tester, dark) async {
    final never = StreamController<TodayState>();
    addTearDown(never.close);
    await bootToday(tester,
        dark: dark, overrides: [todayStateProvider.overrideWith((ref) => never.stream)]);

    expect(_onToday(find.text('…')), findsOneWidget);
    expect(find.byKey(todayCardKey), findsNothing);
    await shot(tester, 'today_loading_${_theme(dark)}');
  });

  // what the screen it replaces showed (Before.dc.html) is gone.
  scenarioTest('today old shapes gone', (tester, dark) async {
    final pal = _pal();
    await bootToday(tester, dark: dark, pal: pal);
    await _pullToRefresh(tester);

    // no day summary above the card: Pal is never asked for one.
    expect(pal.insightsCalls, 0);
    expect(_onToday(find.textContaining('more later today')), findsNothing);
    expect(find.text('Do this next'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('Do this next')), findsNothing);

    // the only Undo is the toast's, not the header's.
    await _tap(tester, _skip);
    expect(_toastUndo, findsOneWidget);
    expect(_onToday(find.text('Undo')), findsNothing);
    expect(find.text('Undo'), findsOneWidget);
    await _toTop(tester);
    await shot(tester, 'today_old_shapes_gone_${_theme(dark)}');
  });

  // each primary pill, by the kind of item on the card.
  // the destination's finders, each expected once: the screen and its lead.
  final actions = <String, (TodayDay, Clock?, String, List<Finder> Function())>{
    'routine': (
      const TodayDay(),
      null,
      'Start',
      () => [find.byType(RoutinePlayerScreen), find.text('Mark done')],
    ),
    'workout': (
      const TodayDay(routines: []),
      null,
      'Start',
      () => [find.byType(StartWorkoutScreen)],
    ),
    'mood': (
      _bare,
      null,
      'Check in',
      () => [find.byType(BottomSheet)],
    ),
    'meal': (
      const TodayDay(routines: [], workout: false, mood: true),
      null,
      'Log a meal',
      () => [find.byType(PalComposerSheet)],
    ),
    'closeout': (
      const TodayDay(),
      // at its slot, when the close-out leads.
      _lateNight,
      'Start',
      () => [
        find.byType(EveningCloseOutScreen),
        find.text('Close out your day.'),
        find.text('Now'),
      ],
    ),
  };
  for (final MapEntry(key: kind, value: (day, at, pill, destination)) in actions.entries) {
    scenarioTest('today action $kind', at: at, (tester, dark) async {
      await bootToday(tester, dark: dark, day: day);

      // on the meal card the title reads the same as its pill; the pill is last.
      await _tap(tester, _onCard(find.text(pill)).last);

      for (final lead in destination()) {
        expect(lead, findsOneWidget);
      }
      await shot(tester, 'today_action_${kind}_${_theme(dark)}');
    });
  }

  // the mock agenda holds both a close-out and an add-ritual proposal; the
  // close-out row already covers the wind-down, so the add-ritual row goes.
  scenarioTest('today wind-down folded', (tester, dark) async {
    await bootToday(tester, dark: dark, pal: TodayPal());

    expect(_row('Close-out'), findsOneWidget);
    expect(_onToday(find.text('Add a 2-min wind-down ritual', skipOffstage: false)), findsNothing);
    expect(_onToday(find.text('Add ritual', skipOffstage: false)), findsNothing);
    await shot(tester, 'today_wind_down_folded_${_theme(dark)}');
  });

  // routines exist but none has a step, with a step logged before they lost
  // theirs. late in the day a routine still undone would need care, but here
  // there is nothing to complete, so routines force no lead and read no count.
  scenarioTest('today care stepless', at: _lateNight, (tester, dark) async {
    await bootToday(
      tester,
      dark: dark,
      day: const TodayDay(routines: [_stepless], legacyRitual: true),
    );

    final container = ProviderScope.containerOf(tester.element(find.byType(TodayScreen)));
    final glance = container.read(todayStateProvider).requireValue.glance;
    expect(glance.routinesDone, 0);
    expect(glance.routinesTotal, 0);
    expect(glance.hasRoutines, isTrue);
    expect(careAreas(glance, _lateNight.now()), isNot(contains(DetailTracker.rituals)));
    expect(_card(_stepless.name), findsNothing);
    expect(_card('Close-out'), findsNothing);
    expect(_onToday(find.textContaining(RegExp(r'\d+ of 0\b'), skipOffstage: false)),
        findsNothing);
    await shot(tester, 'today_care_stepless_${_theme(dark)}');
  });

  scenarioTest('today pull to refresh', (tester, dark) async {
    final pal = _pal();
    await bootToday(tester, dark: dark, pal: pal);
    final before = pal.plans.length;

    await _pullToRefresh(tester);

    expect(pal.plans.length, before + 1);
    expect(_lead(_rent.body), findsOneWidget);
    await shot(tester, 'today_pull_refresh_${_theme(dark)}');
  });
}
