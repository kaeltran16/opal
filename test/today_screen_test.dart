import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/controllers/providers.dart';
import 'package:opal/controllers/rituals_controller.dart';
import 'package:opal/controllers/today_controller.dart';
import 'package:opal/data/seed/seed_data.dart';
import 'package:opal/screens/pal/pal_composer_screen.dart';
import 'package:opal/screens/reflect/evening_close_out_screen.dart';
import 'package:opal/screens/rituals/routine_player_screen.dart';
import 'package:opal/screens/today/today_screen.dart';
import 'package:opal/models/models.dart'
    show EntrySource, MoodCheckin, RitualRoutine, RitualStep, RitualTone;
import 'package:opal/screens/workout/start_workout_screen.dart';
import 'package:opal/services/pal/pal_service.dart';
import 'package:opal/theme/theme.dart';
import 'package:opal/widgets/app_icon.dart';
import 'package:opal/widgets/pal_label.dart';

import 'support/flush_provider_timers.dart';
import 'support/golden_harness.dart' show appRouter;
import 'support/today_fixture.dart';

final _monday = Clock.fixed(DateTime(2026, 9, 28, 9, 30));

const _tall = Size(390, 2400);
const _phone = Size(390, 844);
const _longTitle = 'Stretch the hips and shoulders before the long desk session';
const _otherLongTitle = 'Walk around the block and refill the water bottle again';
const _offlineLabel = 'Pal is offline · next on the clock';
const _headline = 'Steady start.';
const _step = 'Two-minute wind-down';
const _legsTitle = 'Move Legs day to Friday';
const _minTap = 44.0;
const _half = 0.5;

/// Pal's two actionable proposals, as the mock sends them.
const _addRitual = PalProposal(
  id: 'add-wind-down-ritual',
  tag: 'Rituals',
  colorToken: 'rituals',
  icon: 'sparkles',
  title: 'Add a 2-min wind-down ritual',
  body: 'A short wind-down could anchor it.',
  approveLabel: 'Add ritual',
  approveIcon: 'plus',
  doneLabel: 'Added',
  action: addRitualAction,
  ritual: (routineId: 'evening', step: _step),
);
const _legs = PalProposal(
  id: 'move-legs-friday',
  tag: 'Workout',
  colorToken: 'move',
  icon: 'figure.run',
  title: _legsTitle,
  body: 'Friday is clear and open.',
  approveLabel: 'Reschedule',
  approveIcon: 'arrow.triangle.2.circlepath',
  doneLabel: 'Moved',
  action: rescheduleWorkoutAction,
  slot: (weekday: 5, routineId: 'seed-routine-legs'),
);

/// An evening routine with no steps yet, so it is no close-out and an
/// add-ritual proposal for it shows on Today.
const _emptyEvening = RitualRoutine(
  id: 'evening',
  name: 'Evening wind-down',
  time: '9:30 PM',
  tone: RitualTone.evening,
  icon: 'moon.stars.fill',
  blurb: 'Close the day gently',
);

/// Only the mood check-in and Log a meal, so proposals set the count.
const _bare = TodayDay(routines: [], workout: false);

/// Boots Today under the fixed Monday clock on a surface tall enough that
/// every row is on screen.
Future<void> _boot(
  WidgetTester tester, {
  TodayDay day = const TodayDay(),
  TodayPal? pal,
  bool strictLayout = false,
}) async {
  tester.view.physicalSize = _tall;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await bootToday(tester, day: day, pal: pal, strictLayout: strictLayout);
}

Finder _onToday(Finder matching) =>
    find.descendant(of: find.byType(TodayScreen), matching: matching);

AppColors _colors(WidgetTester tester) => tester.element(find.byType(TodayScreen)).colors;

/// The action card's title, the only text-bearing header on Today.
Finder _card(String title) => _onToday(find.descendant(
      of: find.byWidgetPredicate((w) => w is Semantics && w.properties.header == true),
      matching: find.text(title),
    ));

Finder _label(String text) =>
    find.descendant(of: _onToday(find.byType(PalLabel)), matching: find.text(text));

Finder _why() => _onToday(find.text('Why this first'));

Finder _row(String title, String when) => find.bySemanticsLabel('$title, $when. Do this next');

Finder _rows() => find.bySemanticsLabel(RegExp(r'\. Do this next$'));

/// The header's Undo, by what it names, or any Undo.
Finder _undo([String? what]) => _onToday(
    what == null ? find.bySemanticsLabel(RegExp(r'^Undo ')) : find.bySemanticsLabel('Undo $what'));

Finder _more([int? n]) => _onToday(n == null
    ? find.textContaining('more later today')
    : find.text('$n more later today'));

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Pulls Today down on a phone, where the indicator arms, then restores the
/// tall surface.
Future<void> _pullToRefresh(WidgetTester tester) async {
  tester.view.physicalSize = _phone;
  await tester.pumpAndSettle();
  await tester.fling(find.byType(TodayScreen), const Offset(0, 400), 1000);
  await tester.pumpAndSettle();
  tester.view.physicalSize = _tall;
  await tester.pumpAndSettle();
}

/// Runs [body] under [at] (the Monday clock by default) and flushes the app's
/// timers after it.
void _todayTest(String name, Future<void> Function(WidgetTester tester) body, {Clock? at}) {
  testWidgets(name, (tester) async {
    await withClock(at ?? _monday, () async {
      await body(tester);
      await flushProviderTimers(tester);
    });
  });
}

void main() {
  _todayTest('the header shows the date line and a hidden Today heading, with no profile button',
      (tester) async {
    await _boot(tester);

    expect(find.text('MON 28 SEP · 9:30 AM'), findsOneWidget);
    expect(
      _onToday(find.byWidgetPredicate((w) =>
          w is Semantics && w.properties.header == true && w.properties.label == 'Today')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Profile and settings'), findsNothing);
    expect(find.bySemanticsLabel('Search'), findsNothing);
    expect(find.textContaining(RegExp(r'^\d+ of \d+ done$')), findsNothing);
  });

  _todayTest('Today carries no ring', (tester) async {
    await _boot(tester, day: const TodayDay(spent: 80));

    expect(find.bySemanticsLabel(RegExp(r'^(Money|Move|Routines): ')), findsNothing);
  });

  _todayTest('online the label reads Pal, a proposal leads and the lead is Pal\'s headline',
      (tester) async {
    await _boot(tester,
        pal: TodayPal(headline: _headline, proposals: [proposal('a', 'Rent auto-pays')]));

    expect(_label('Pal'), findsOneWidget);
    expect(_card('Rent auto-pays'), findsOneWidget);
    expect(_onToday(find.text(_headline)), findsOneWidget);
    expect(_onToday(find.text('Body for Rent auto-pays.')), findsNothing);
    expect(_why(), findsOneWidget);
    // a proposal has no time.
    expect(_onToday(find.text('Any time')), findsOneWidget);
  });

  _todayTest('offline the label says so, the item\'s sentence leads and the order is the clock',
      (tester) async {
    await _boot(tester, pal: TodayPal(headline: _headline, offline: true));

    expect(_label(_offlineLabel), findsOneWidget);
    expect(_card('Morning'), findsOneWidget);
    // the morning routine's own blurb.
    expect(_onToday(find.text('Ease into the day')), findsOneWidget);
    expect(_why(), findsNothing);
    // untimed items first, then by time.
    expect(_row('Push Day A', 'any time'), findsOneWidget);
    expect(_row('Mood check-in', 'any time'), findsOneWidget);
    // the evening routine is the close-out row, not a row of its own.
    expect(_more(3), findsOneWidget);
    expect(find.byKey(todayRailKey), findsOneWidget);
    expect(find.textContaining("Couldn't load today"), findsNothing);
  });

  _todayTest('an item with no sentence leads with its title', (tester) async {
    await _boot(tester, day: _bare, pal: TodayPal(offline: true));

    expect(_onToday(find.text('Mood check-in')), findsNWidgets(2));
  });

  _todayTest('Why this first opens the composer asking why the lead is first', (tester) async {
    await _boot(tester,
        pal: TodayPal(headline: _headline, proposals: [proposal('a', 'Rent auto-pays')]));

    await _tap(tester, _why());

    final sheet = tester.widget<PalComposerSheet>(find.byType(PalComposerSheet));
    expect(sheet.seed, 'Why Rent auto-pays first?');
    expect(find.descendant(
            of: find.byType(PalComposerSheet), matching: find.text('Why Rent auto-pays first?')),
        findsOneWidget);
  });

  _todayTest('the card shows the lead; skip, Undo and the action follow', (tester) async {
    await _boot(
      tester,
      day: const TodayDay(routines: []),
      pal: TodayPal(proposals: const [_legs]),
    );

    expect(_card(_legsTitle), findsOneWidget);
    expect(_undo(), findsNothing);

    await _tap(tester, find.text('Not now'));
    expect(_onToday(find.text(_legsTitle)), findsNothing);
    expect(_card('Push Day A'), findsOneWidget);
    expect(find.text('Any time · 55 min'), findsOneWidget);
    expect(_onToday(find.text('Undo · $_legsTitle skipped')), findsOneWidget);

    await _tap(tester, _undo('$_legsTitle skipped'));
    expect(_card(_legsTitle), findsOneWidget);
    expect(_undo(), findsNothing);

    await _tap(tester, find.text('Reschedule'));
    expect(_onToday(find.text(_legsTitle)), findsNothing);
    expect(_onToday(find.text('Undo · Leg Day on Friday')), findsOneWidget);
  });

  _todayTest('a skipped row names itself in Undo, and Undo brings it back', (tester) async {
    await _boot(tester, day: _bare, pal: TodayPal(proposals: [proposal('a', 'Rent auto-pays')]));

    await _tap(tester, _row('Mood check-in', 'any time'));
    await _tap(tester, find.text('Not today'));

    expect(_onToday(find.text('Undo · Mood check-in skipped')), findsOneWidget);
    expect(_undo('Mood check-in skipped'), findsOneWidget);
    expect(tester.getSize(_undo()).height, greaterThanOrEqualTo(_minTap));

    await _tap(tester, _undo());
    expect(_card('Mood check-in'), findsOneWidget);
    expect(_undo(), findsNothing);
  });

  _todayTest('approving add-ritual on the card adds the step and Undo names it',
      (tester) async {
    await _boot(tester,
        day: const TodayDay(routines: [_emptyEvening], workout: false),
        pal: TodayPal(proposals: const [_addRitual]));

    await _tap(tester, find.text('Add ritual'));

    expect(_onToday(find.text(_addRitual.title)), findsNothing);
    expect(_onToday(find.text('Undo · $_step added')), findsOneWidget);
    expect(_undo('$_step added'), findsOneWidget);

    await _tap(tester, _undo());
    expect(_card(_addRitual.title), findsOneWidget);
    expect(_undo(), findsNothing);
  });

  _todayTest('approved on You, Today names it in Undo and Undo removes the step',
      (tester) async {
    await _boot(tester,
        day: const TodayDay(routines: [_emptyEvening], workout: false),
        pal: TodayPal(proposals: const [_addRitual]));
    final router = appRouter(tester);

    router.go('/you');
    await tester.pumpAndSettle();
    await _tap(tester, find.bySemanticsLabel('Add ritual: ${_addRitual.title}'));
    router.go('/today');
    await tester.pumpAndSettle();

    expect(_onToday(find.text('Undo · $_step added')), findsOneWidget);
    await _tap(tester, _undo('$_step added'));

    final evening = ProviderScope.containerOf(tester.element(find.byType(TodayScreen)))
        .read(ritualsControllerProvider)
        .requireValue
        .routines
        .firstWhere((r) => r.id == _emptyEvening.id);
    expect(evening.steps, isEmpty);
    expect(_card(_addRitual.title), findsOneWidget);
  });

  testWidgets('a 60 character skip ellipsises Undo within half the header at text scale 1.3',
      (tester) async {
    await withClock(_monday, () async {
      final title = _longTitle.padRight(60, '.');
      tester.view.physicalSize = _phone;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await bootToday(tester,
          strictLayout: true, day: _bare, pal: TodayPal(proposals: [proposal('a', title)]));

      await tester.ensureVisible(find.text('Not now'));
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Not now'));
      await tester.ensureVisible(_undo());
      await tester.pumpAndSettle();

      const date = 'MON 28 SEP · 9:30 AM';
      final header = find.ancestor(of: find.text(date), matching: find.byType(Row)).first;
      final width = tester.getSize(header).width;
      expect(tester.getSize(_undo()).width, lessThanOrEqualTo(width * _half));
      expect(tester.getSize(_undo()).height, greaterThanOrEqualTo(_minTap));
      final label = _onToday(find.text('Undo · $title skipped'));
      expect(tester.renderObject<RenderParagraph>(label).didExceedMaxLines, isTrue);
      expect(tester.getSize(find.text(date)).width, greaterThanOrEqualTo(width * _half));
      expect(tester.takeException(), isNull);
      await flushProviderTimers(tester);
    });
  });

  _todayTest('a timed lead reads its time', (tester) async {
    await _boot(tester);

    await _tap(tester, _more());
    await _tap(tester, _row('Close-out', 'at 9:30 PM'));

    expect(_card('Close-out'), findsOneWidget);
    expect(_onToday(find.text('At 9:30 PM')), findsOneWidget);
    expect(_onToday(find.text('Now')), findsNothing);
  });

  group('the primary pill opens the flow for', () {
    _todayTest('a routine', (tester) async {
      await _boot(tester);

      await _tap(tester, find.text('Start'));
      expect(find.byType(RoutinePlayerScreen), findsOneWidget);
    });

    _todayTest('the workout', (tester) async {
      await _boot(tester, day: const TodayDay(routines: []));

      await _tap(tester, find.text('Start'));
      expect(find.byType(StartWorkoutScreen), findsOneWidget);
    });

    _todayTest('the mood check-in', (tester) async {
      await _boot(tester, day: _bare);

      await _tap(tester, find.text('Check in'));
      expect(find.byType(BottomSheet), findsOneWidget);
    });

    _todayTest('a meal', (tester) async {
      await _boot(tester, day: const TodayDay(routines: [], workout: false, mood: true));

      // the card's title and its pill read the same.
      await _tap(tester, _onToday(find.text('Log a meal')).last);
      expect(find.byType(PalComposerSheet), findsOneWidget);
    });

    _todayTest('the close-out', (tester) async {
      await _boot(tester);

      await _tap(tester, _more());
      await _tap(tester, _row('Close-out', 'at 9:30 PM'));
      await _tap(tester, find.text('Start'));
      expect(find.byType(EveningCloseOutScreen), findsOneWidget);
    });
  });

  _todayTest('after a check-in the timeline lists Check in again, and it opens the logger',
      (tester) async {
    await _boot(tester, day: const TodayDay(routines: [], workout: false, mood: true));
    expect(_card('Log a meal'), findsOneWidget);
    expect(_row('Check in again', 'any time'), findsOneWidget);

    await _tap(tester, _row('Check in again', 'any time'));
    expect(_card('Check in again'), findsOneWidget);

    await _tap(tester, find.text('Check in'));
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  group('after Check in again is picked', () {
    // checked in, fed and no workout, with the close-out upcoming at 9:30 PM.
    final closeOutDay = TodayDay(
      routines: [
        _emptyEvening.copyWith(
            steps: const [RitualStep(id: 'wind', title: _step, note: '', icon: 'sparkles')]),
      ],
      workout: false,
      mood: true,
      meal: true,
    );

    Future<void> pick(WidgetTester tester) async {
      await _boot(tester, day: closeOutDay);
      expect(_card('Close-out'), findsOneWidget);
      await _tap(tester, _row('Check in again', 'any time'));
      expect(_card('Check in again'), findsOneWidget);
    }

    _todayTest('logging a check-in hands the lead back to the clock', (tester) async {
      await pick(tester);

      await _tap(tester, find.text('Check in'));
      await _tap(tester, find.bySemanticsLabel('Log mood'));

      expect(_card('Close-out'), findsOneWidget);
      expect(_row('Check in again', 'any time'), findsOneWidget);
    });

    _todayTest('closing the logger without logging keeps it leading', (tester) async {
      await pick(tester);

      await _tap(tester, find.text('Check in'));
      await _tap(tester, find.text('Cancel'));

      expect(_card('Check in again'), findsOneWidget);
    });

    _todayTest('a check-in logged elsewhere hands the lead back', (tester) async {
      await pick(tester);

      final container = ProviderScope.containerOf(tester.element(find.byType(TodayScreen)));
      await tester.runAsync(() => container.read(moodRepositoryProvider).insert(MoodCheckin(
            id: '',
            timestamp: clock.now(),
            pleasantness: 0.4,
            source: EntrySource.manual,
          )));
      await tester.pumpAndSettle();

      expect(_card('Close-out'), findsOneWidget);
    });
  });

  _todayTest('tapping a row makes it the lead and hides Why', (tester) async {
    await _boot(tester, day: _bare, pal: TodayPal(proposals: [proposal('a', 'Rent auto-pays')]));
    expect(_why(), findsOneWidget);

    await _tap(tester, _row('Mood check-in', 'any time'));

    expect(_card('Mood check-in'), findsOneWidget);
    expect(_row('Mood check-in', 'any time'), findsNothing);
    expect(_row('Rent auto-pays', 'any time'), findsOneWidget);
    expect(_why(), findsNothing);
  });

  _todayTest('a tapped row skipped returns the lead to Pal\'s pick; Undo brings it back',
      (tester) async {
    await _boot(tester,
        day: _bare,
        pal: TodayPal(headline: _headline, proposals: [proposal('a', 'Rent auto-pays')]));

    await _tap(tester, _row('Mood check-in', 'any time'));
    expect(_onToday(find.text(_headline)), findsNothing);
    await _tap(tester, find.text('Not today'));

    expect(_card('Rent auto-pays'), findsOneWidget);
    expect(_onToday(find.text(_headline)), findsOneWidget);
    expect(_why(), findsOneWidget);

    await _tap(tester, _undo());
    expect(_card('Mood check-in'), findsOneWidget);
    expect(_why(), findsNothing);
  });

  _todayTest('two open items besides the lead show both rows and no More button',
      (tester) async {
    await _boot(tester, day: _bare, pal: TodayPal(proposals: [proposal('a', 'A')]));

    expect(_rows(), findsNWidgets(2));
    expect(_more(), findsNothing);
  });

  _todayTest('three open items besides the lead show two rows and 1 more', (tester) async {
    await _boot(tester,
        day: _bare, pal: TodayPal(proposals: [proposal('a', 'A'), proposal('b', 'B')]));

    expect(_rows(), findsNWidgets(2));
    expect(_more(1), findsOneWidget);
  });

  _todayTest('More lists the rest of the day, and it stays listed through a skip',
      (tester) async {
    await _boot(tester,
        day: _bare,
        pal: TodayPal(proposals: [proposal('a', 'A'), proposal('b', 'B'), proposal('c', 'C')]));
    expect(_rows(), findsNWidgets(2));
    expect(_more(2), findsOneWidget);

    await _tap(tester, _more(2));
    expect(_rows(), findsNWidgets(4));
    expect(_more(), findsNothing);

    await _tap(tester, find.text('Not now'));
    expect(_card('B'), findsOneWidget);
    expect(_rows(), findsNWidgets(3));
    expect(_more(), findsNothing);
  });

  _todayTest('an empty day ends on the all-done card with no buttons, rail or Why',
      (tester) async {
    await _boot(tester, day: const TodayDay.empty());

    // with nothing set up, the mood check-in and a meal are all that is asked.
    await _tap(tester, find.text('Not today'));
    await _tap(tester, find.text('Not today'));

    expect(find.text('All done'), findsOneWidget);
    expect(find.text("That's the day"), findsOneWidget);
    expect(find.text('Nothing is left. Rest up.'), findsOneWidget);
    expect(find.text('Not today'), findsNothing);
    expect(find.byKey(todayRailKey), findsNothing);
    expect(_why(), findsNothing);
    expect(tester.takeException(), isNull);
  });

  _todayTest('Money over budget leads with the money proposal, and still after a failed refresh',
      (tester) async {
    final pal = TodayPal(proposals: [
      proposal('legs', 'Move Legs day', colorToken: 'move'),
      proposal('cap', r'Cap dinner at $10'),
    ]);
    await _boot(tester, day: const TodayDay(spent: 80), pal: pal);

    expect(_label('Pal'), findsOneWidget);
    expect(_card(r'Cap dinner at $10'), findsOneWidget);
    expect(_why(), findsOneWidget);

    pal.offline = true;
    await _pullToRefresh(tester);

    expect(_label(_offlineLabel), findsOneWidget);
    expect(_card(r'Cap dinner at $10'), findsOneWidget);
    expect(_why(), findsNothing);
  });

  _todayTest('Move under half its goal late in the day leads with the workout offline',
      at: Clock.fixed(DateTime(2026, 9, 28, 21, 30)), (tester) async {
    await _boot(tester, day: const TodayDay(moveKcal: 100), pal: TodayPal(offline: true));

    expect(_label(_offlineLabel), findsOneWidget);
    expect(_card('Push Day A'), findsOneWidget);
  });

  _todayTest('a failed refresh after a success reads offline: clock order and no Why',
      (tester) async {
    final pal = TodayPal(headline: _headline, proposals: [proposal('a', 'Rent auto-pays')]);
    await _boot(tester, pal: pal);
    expect(_card('Rent auto-pays'), findsOneWidget);

    pal.offline = true;
    await _pullToRefresh(tester);

    expect(_label(_offlineLabel), findsOneWidget);
    expect(_card('Morning'), findsOneWidget);
    expect(_onToday(find.text('Ease into the day')), findsOneWidget);
    expect(_why(), findsNothing);
    // the held proposal stays, untimed in clock position.
    expect(_row('Rent auto-pays', 'any time'), findsOneWidget);
  });

  _todayTest('at text scale 2.0 rows and the when line hold one line and the lead shows in full',
      (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    // only Today's own layout is under test; the shell's tab bar is not.
    final inner = FlutterError.onError;
    FlutterError.onError = (details) {
      final overflow = details.exception.toString().contains('A RenderFlex overflowed');
      if (overflow && !details.toString().contains('today_screen.dart')) return;
      inner?.call(details);
    };
    const longHeadline = 'Rent is due Monday and forty dollars short, so hold it now and '
        'the evening stays clear for the long walk and an early night.';
    await _boot(
      tester,
      strictLayout: true,
      day: TodayDay(routines: [SeedData.ritualRoutines().first.copyWith(name: _longTitle)]),
      pal: TodayPal(headline: longHeadline, proposals: [proposal('a', _otherLongTitle)]),
    );
    await _tap(tester, _more());

    // past three serif lines Pal's line drops to body and is never cut.
    final lead = tester.renderObject<RenderParagraph>(_onToday(find.text(longHeadline)));
    expect(tester.widget<Text>(_onToday(find.text(longHeadline))).maxLines, isNull);
    expect(lead.didExceedMaxLines, isFalse);
    final row = tester.renderObject<RenderParagraph>(_onToday(find.text(_longTitle)));
    expect(row.didExceedMaxLines, isTrue);
    final when = tester.widget<Text>(_onToday(find.text('Any time')));
    expect(when.maxLines, 1);
    expect(when.overflow, TextOverflow.ellipsis);
    // the card wraps its title.
    expect(_card(_otherLongTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a 60 character routine title at text scale 1.3 does not overflow',
      (tester) async {
    await withClock(_monday, () async {
      expect(_longTitle.length, greaterThanOrEqualTo(59));
      tester.view.physicalSize = _phone;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final seeded = SeedData.ritualRoutines();

      await bootToday(
        tester,
        strictLayout: true,
        day: TodayDay(routines: [
          seeded[0].copyWith(name: _longTitle),
          seeded[1].copyWith(name: _otherLongTitle),
        ]),
      );
      final more = _more();
      await tester.ensureVisible(more);
      await tester.pumpAndSettle();
      await _tap(tester, more);

      // the card wraps its title; the timeline row ellipsises.
      expect(_onToday(find.text(_longTitle)), findsOneWidget);
      expect(_onToday(find.text(_otherLongTitle)), findsOneWidget);
      expect(tester.takeException(), isNull);
      await flushProviderTimers(tester);
    });
  });

  _todayTest('pulling Today down refetches the brief', (tester) async {
    final pal = TodayPal(headline: _headline, proposals: const []);
    await _boot(tester, pal: pal);
    final before = pal.insightsCalls;

    await _pullToRefresh(tester);

    expect(pal.insightsCalls, before + 1);
  });

  _todayTest('returning to the app refetches the brief', (tester) async {
    final pal = TodayPal(headline: _headline, proposals: const []);
    await _boot(tester, pal: pal);
    final before = pal.insightsCalls;

    // AppLifecycleListener asserts every transition, so walk the real sequence.
    for (final state in const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(pal.insightsCalls, before + 1);
  });

  _todayTest('the date line is the only uppercase text', (tester) async {
    await _boot(
      tester,
      day: const TodayDay(mood: true, meal: true, spent: 80),
      pal: TodayPal(proposals: [proposal('a', 'Rent auto-pays')]),
    );

    final shouting = tester
        .widgetList<Text>(_onToday(find.byType(Text)))
        .map((t) => t.data!)
        .where(RegExp(r'[A-Z]{3,}').hasMatch);
    expect(shouting, ['MON 28 SEP · 9:30 AM']);
  });

  _todayTest('Today reads no area colour: icons and text are neutral', (tester) async {
    // over budget, a goal met and a routine done, so any state colour would show.
    await _boot(
      tester,
      day: const TodayDay(mood: true, meal: true, spent: 80, moveKcal: 520, firstRoutineDone: true),
      pal: TodayPal(proposals: [proposal('a', 'Rent auto-pays')]),
    );
    final c = _colors(tester);
    // the ring colours are the only area hues left in the theme.
    final area = {c.ringMove, c.ringRoutines};

    final used = <Color?>{
      for (final icon in tester.widgetList<AppIcon>(_onToday(find.byType(AppIcon)))) icon.color,
      for (final text in tester.widgetList<Text>(_onToday(find.byType(Text)))) text.style?.color,
      for (final box in tester.widgetList<Container>(_onToday(find.byType(Container))))
        if (box.decoration case final BoxDecoration d) d.color,
    };
    expect(used.intersection(area), isEmpty);
  });

  _todayTest('while today is loading it shows the ellipsis', (tester) async {
    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final never = StreamController<TodayState>();
    addTearDown(never.close);

    await bootToday(tester,
        overrides: [todayStateProvider.overrideWith((ref) => never.stream)]);

    expect(_onToday(find.text('…')), findsOneWidget);
    expect(_onToday(find.byType(PalLabel)), findsNothing);
  });

  _todayTest('when today fails to load it says so', (tester) async {
    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await bootToday(tester, overrides: [
      todayStateProvider.overrideWith((ref) => Stream.error(StateError('no database'))),
    ]);

    expect(find.text("Couldn't load today. Try again in a moment."), findsOneWidget);
    expect(_onToday(find.byType(PalLabel)), findsNothing);
  });
}
