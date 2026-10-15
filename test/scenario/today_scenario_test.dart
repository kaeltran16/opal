@Tags(['scenario'])
library;

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/controllers/pal_composer_controller.dart';
import 'package:opal/controllers/today_controller.dart';
import 'package:opal/screens/pal/pal_composer_screen.dart';
import 'package:opal/screens/reflect/evening_close_out_screen.dart';
import 'package:opal/screens/rituals/routine_player_screen.dart';
import 'package:opal/screens/today/today_screen.dart';
import 'package:opal/screens/workout/start_workout_screen.dart';
import 'package:opal/services/pal/pal_service.dart' show PalProposal, PalRole;
import 'package:opal/theme/theme.dart';
import 'package:opal/widgets/controls.dart';
import 'package:opal/widgets/day_scene.dart';
import 'package:opal/widgets/pal_label.dart';

import '../support/today_fixture.dart';
import 'scenario_harness.dart';

const _headline = 'A steady start. The morning routine is first.';
const _rentTitle = 'Set aside \$40 for rent';
const _capTitle = 'Cap dinner at \$10';
const _offlineLabel = 'Pal is offline · next on the clock';
const _why = 'Why this first';

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
  title: 'Move Legs day to Friday',
  body: 'Friday is clear and open.',
  approveLabel: 'Move it',
  approveIcon: 'checkmark',
  doneLabel: 'Moved',
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

/// Only the mood check-in and Log a meal, so proposals set the count.
const _bare = TodayDay(routines: [], workout: false);

TodayPal _pal() => TodayPal(headline: _headline, proposals: const [_rent]);

/// Pal sends the move proposal first; Money over budget must still lead.
TodayPal _carePal() => TodayPal(headline: _headline, proposals: const [_legs, _cap]);

String _theme(bool dark) => dark ? 'dark' : 'light';

Finder _onToday(Finder matching) =>
    find.descendant(of: find.byType(TodayScreen), matching: matching);

Finder _label(String text) =>
    find.descendant(of: _onToday(find.byType(PalLabel)), matching: find.text(text));

/// The action card's title.
Finder _card(String title) =>
    find.descendant(of: find.byKey(todayCardKey), matching: find.text(title));

Finder _whyButton() => _onToday(find.text(_why));

Finder _later(String title, String when) =>
    find.bySemanticsLabel('$title, $when. Do this next');

Finder _rows() => find.bySemanticsLabel(RegExp(r'\. Do this next$'));

Finder _more([int? n]) => _onToday(n == null
    ? find.textContaining('more later today')
    : find.text('$n more later today'));

Finder _undo() => _onToday(find.text('Undo'));

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
      expect(find.text(_headline), findsOneWidget);
      expect(_label('Pal'), findsOneWidget);
      expect(_card(_rentTitle), findsOneWidget);
      expect(_rows().evaluate().length, lessThanOrEqualTo(2));
      expect(find.byKey(todayRailKey), findsOneWidget);
      await shot(tester, 'today_${name}_${_theme(dark)}');
    });
  }

  scenarioTest('today action card', (tester, dark) async {
    final theme = _theme(dark);
    await bootToday(tester, dark: dark, pal: _pal());

    await _tap(tester, _later('Mood check-in', 'any time'));
    await _toTop(tester);
    expect(_card('Mood check-in'), findsOneWidget);
    expect(_onToday(find.text('Any time')), findsOneWidget);
    expect(_whyButton(), findsNothing);
    await shot(tester, 'today_row_selected_$theme');

    await _tap(tester, find.text('Not today'));
    expect(_card(_rentTitle), findsOneWidget);
    expect(_undo(), findsOneWidget);
    await shot(tester, 'today_after_skip_$theme');

    await _tap(tester, find.text('Hold \$40'));
    expect(find.text(_rentTitle), findsNothing);
    expect(_undo(), findsOneWidget);
    await shot(tester, 'today_after_action_$theme');

    await _tap(tester, _undo());
    expect(_card(_rentTitle), findsOneWidget);
    expect(_onToday(find.text('Now')), findsNothing);
    await shot(tester, 'today_after_undo_$theme');
  });

  scenarioTest('today mood logger', (tester, dark) async {
    await bootToday(tester, dark: dark, pal: _pal());

    // the row tap only selects the check-in; its card pill opens the logger.
    await _tap(tester, _later('Mood check-in', 'any time'));
    await _toTop(tester);
    expect(_card('Mood check-in'), findsOneWidget);
    await _tap(tester, _onToday(find.text('Check in')));

    final sheet = find.byType(BottomSheet);
    expect(find.descendant(of: sheet, matching: find.text('Check in')), findsOneWidget);
    expect(
      find.descendant(of: sheet, matching: find.widgetWithText(PillButton, 'Log mood')),
      findsOneWidget,
    );
    await shot(tester, 'today_mood_logger_${_theme(dark)}');
  });

  scenarioTest('today all done', (tester, dark) async {
    await bootToday(tester, dark: dark, day: const TodayDay.empty());

    // nothing is set up, so the mood check-in and a meal are all that is asked.
    await tester.tap(find.text('Not today'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not today'));
    await tester.pumpAndSettle();

    expect(find.text('All done'), findsOneWidget);
    expect(find.text("That's the day"), findsOneWidget);
    expect(find.text('Nothing is left. Rest up.'), findsOneWidget);
    expect(find.text('Not today'), findsNothing);
    expect(find.byKey(todayRailKey), findsNothing);
    expect(_whyButton(), findsNothing);
    await shot(tester, 'today_all_done_${_theme(dark)}');
  });

  scenarioTest('today offline', (tester, dark) async {
    await bootToday(tester, dark: dark, pal: TodayPal(offline: true));

    expect(_label(_offlineLabel), findsOneWidget);
    expect(_whyButton(), findsNothing);
    // the overdue morning routine is first on the clock.
    expect(_card('Morning'), findsOneWidget);
    expect(find.text('Ease into the day'), findsOneWidget);
    expect(find.byKey(todayRailKey), findsOneWidget);
    expect(find.textContaining("Couldn't load today"), findsNothing);
    await shot(tester, 'today_offline_${_theme(dark)}');
  });

  scenarioTest('today online proposal leads', (tester, dark) async {
    await bootToday(tester, dark: dark, pal: _pal());

    expect(_label('Pal'), findsOneWidget);
    expect(_card(_rentTitle), findsOneWidget);
    expect(find.text(_headline), findsOneWidget);
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

  scenarioTest('today more expanded', (tester, dark) async {
    await bootToday(tester,
        dark: dark,
        day: _bare,
        pal: TodayPal(proposals: [proposal('a', 'A'), proposal('b', 'B'), proposal('c', 'C')]));
    expect(_rows(), findsNWidgets(2));

    await _tap(tester, _more(2));
    expect(_rows(), findsNWidgets(4));
    expect(_more(), findsNothing);

    await _tap(tester, find.text('Not now'));
    expect(_card('B'), findsOneWidget);
    expect(_rows(), findsNWidgets(3));
    expect(_more(), findsNothing);
    await shot(tester, 'today_more_expanded_${_theme(dark)}');
  });

  scenarioTest('today undo restores tapped row', (tester, dark) async {
    await bootToday(tester, dark: dark, day: _bare, pal: _pal());

    await _tap(tester, _later('Mood check-in', 'any time'));
    await _tap(tester, find.text('Not today'));
    expect(_card(_rentTitle), findsOneWidget);
    expect(_whyButton(), findsOneWidget);

    await _tap(tester, _undo());
    expect(_card('Mood check-in'), findsOneWidget);
    expect(_whyButton(), findsNothing);
    await shot(tester, 'today_undo_tapped_${_theme(dark)}');
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

  // each primary pill, by the kind of item on the card.
  // the destination's finders, each expected once: the screen and its lead.
  final actions = <String, (TodayDay, Future<void> Function(WidgetTester)?, String, List<Finder> Function())>{
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
      // the close-out sits behind More.
      (tester) async {
        await _tap(tester, _more());
        await _tap(tester, _later('Close-out', 'at 9:30 PM'));
      },
      'Start',
      () => [
        find.byType(EveningCloseOutScreen),
        find.text('Close out your day.'),
        find.text('Now'),
      ],
    ),
  };
  for (final MapEntry(key: kind, value: (day, select, pill, destination)) in actions.entries) {
    scenarioTest('today action $kind', (tester, dark) async {
      await bootToday(tester, dark: dark, day: day);
      if (select != null) await select(tester);

      // on the meal card the title reads the same as its pill; the pill is last.
      await _tap(tester, _onToday(find.text(pill)).last);

      for (final lead in destination()) {
        expect(lead, findsOneWidget);
      }
      await shot(tester, 'today_action_${kind}_${_theme(dark)}');
    });
  }

  scenarioTest('today pull to refresh', (tester, dark) async {
    final pal = _pal();
    await bootToday(tester, dark: dark, pal: pal);
    final before = pal.insightsCalls;

    await _pullToRefresh(tester);

    expect(pal.insightsCalls, before + 1);
    expect(find.text(_headline), findsOneWidget);
    await shot(tester, 'today_pull_refresh_${_theme(dark)}');
  });
}
