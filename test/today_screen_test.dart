import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/controllers/nutrition_controller.dart';
import 'package:opal/controllers/providers.dart' show ritualRepositoryProvider;
import 'package:opal/controllers/rituals_controller.dart';
import 'package:opal/controllers/today_controller.dart';
import 'package:opal/data/seed/seed_data.dart';
import 'package:opal/screens/pal/pal_composer_screen.dart';
import 'package:opal/screens/reflect/evening_close_out_screen.dart';
import 'package:opal/screens/rituals/routine_player_screen.dart';
import 'package:opal/screens/shell/plan_undo_toast.dart';
import 'package:opal/screens/today/today_screen.dart';
import 'package:opal/models/models.dart'
    show Goals, RitualRoutine, RitualTone;
import 'package:opal/screens/workout/start_workout_screen.dart';
import 'package:opal/services/pal/pal_service.dart';
import 'package:opal/theme/theme.dart';
import 'package:opal/util/mood_scale.dart' show moodWord;
import 'package:opal/widgets/app_icon.dart';
import 'package:opal/widgets/pal_label.dart';
import 'package:opal/widgets/pal_lead.dart';

import 'support/flush_provider_timers.dart';
import 'support/golden_harness.dart' show appRouter;
import 'support/today_fixture.dart';

final _monday = Clock.fixed(DateTime(2026, 9, 28, 9, 30));

/// Just past the close-out's slot, when it leads the clock.
final _closeOutTime = Clock.fixed(DateTime(2026, 9, 28, 21, 40));

const _tall = Size(390, 2400);
const _phone = Size(390, 844);
const _longTitle = 'Stretch the hips and shoulders before the long desk session';
const _otherLongTitle = 'Walk around the block and refill the water bottle again';
const _offlineLabel = 'Pal is offline · next on the clock';
const _morningLine = 'Morning is still open. Ease in before the desk.';
const _morningSaid = 'Ease into the day';
const _step = 'Two-minute wind-down';
/// Pal's add-ritual proposal, as the mock sends it.
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

/// Today's meals, held back until [gate] completes, as a slow cold start.
class _GatedNutrition extends NutritionController {
  _GatedNutrition(this.gate);

  final Future<void> gate;

  @override
  Stream<NutritionState> build() async* {
    await gate;
    yield* super.build();
  }
}

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

Finder _onCard(Finder matching) => find.descendant(of: find.byKey(todayCardKey), matching: matching);

/// The action card's title.
Finder _card(String title) => _onCard(find.text(title));

Finder _label(String text) =>
    find.descendant(of: _onToday(find.byType(PalLabel)), matching: find.text(text));

/// Pal's line above the card.
Finder _lead(String text) =>
    find.descendant(of: _onToday(find.byType(PalLeadText)), matching: find.text(text));

Finder _why() => _onToday(find.text('Why this first'));

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

List<String> _eveningSteps(WidgetTester tester) => [
      for (final s in ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
          .read(ritualsControllerProvider)
          .requireValue
          .routines
          .firstWhere((r) => r.id == _emptyEvening.id)
          .steps)
        s.title,
    ];

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
  _todayTest('the header is the date line and a hidden Today heading, with no profile button',
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
  });

  _todayTest('Today carries no ring', (tester) async {
    await _boot(tester, day: const TodayDay(spent: 80));

    expect(find.bySemanticsLabel(RegExp(r'^(Money|Move|Routines): ')), findsNothing);
  });

  group("Pal's line", () {
    _todayTest('online, it is about the card\'s item', (tester) async {
      await _boot(tester, pal: TodayPal(proposals: const [], linesByTitle: {'Morning': _morningLine}));

      expect(_label('Pal'), findsOneWidget);
      expect(_card('Morning'), findsOneWidget);
      expect(_lead(_morningLine), findsOneWidget);
      expect(_why(), findsOneWidget);
    });

    _todayTest('offline, the item\'s own sentence shows and Why is hidden', (tester) async {
      await _boot(tester,
          pal: TodayPal(offline: true, linesByTitle: {'Morning': _morningLine}));

      expect(_label(_offlineLabel), findsOneWidget);
      expect(_card('Morning'), findsOneWidget);
      expect(_lead(_morningSaid), findsOneWidget);
      expect(_onToday(find.text(_morningLine)), findsNothing);
      expect(_why(), findsNothing);
      expect(find.textContaining("Couldn't load today"), findsNothing);
    });

    _todayTest('with no line for the card\'s item, the item\'s own sentence shows',
        (tester) async {
      await _boot(tester,
          pal: TodayPal(proposals: const [], linesByTitle: {'Push Day A': 'Push today.'}));

      expect(_card('Morning'), findsOneWidget);
      expect(_lead(_morningSaid), findsOneWidget);
      expect(_why(), findsOneWidget);
    });

    _todayTest('a failed refresh after a success shows the item\'s sentence and hides Why',
        (tester) async {
      final pal = TodayPal(proposals: const [], linesByTitle: {'Morning': _morningLine});
      await _boot(tester, pal: pal);
      expect(_lead(_morningLine), findsOneWidget);

      pal.offline = true;
      await _pullToRefresh(tester);

      expect(_label(_offlineLabel), findsOneWidget);
      expect(_card('Morning'), findsOneWidget);
      expect(_lead(_morningSaid), findsOneWidget);
      expect(_onToday(find.text(_morningLine)), findsNothing);
      expect(_why(), findsNothing);
    });

    _todayTest('a proposal leads with its own body', (tester) async {
      await _boot(tester, pal: TodayPal(proposals: [proposal('a', 'Rent auto-pays')]));

      expect(_card('Rent auto-pays'), findsOneWidget);
      expect(_lead('Body for Rent auto-pays.'), findsOneWidget);
      // a proposal has no time.
      expect(_onCard(find.text('Any time')), findsOneWidget);
    });

    _todayTest('an item with no sentence leads with its title', (tester) async {
      await _boot(tester, day: _bare, pal: TodayPal(offline: true));

      expect(_lead('Mood check-in'), findsOneWidget);
    });

    _todayTest('no lead reads Nothing is left', (tester) async {
      await _boot(tester, day: const TodayDay(routines: [], workout: false, mood: true, meal: true));

      expect(_lead('Nothing is left. Rest up.'), findsOneWidget);
      expect(_card('All done'), findsOneWidget);
      expect(_card("That's the day"), findsOneWidget);
      expect(_why(), findsNothing);
    });
  });

  _todayTest('Why this first opens the composer asking why the lead is first', (tester) async {
    await _boot(tester, pal: TodayPal(proposals: [proposal('a', 'Rent auto-pays')]));

    await _tap(tester, _why());

    final sheet = tester.widget<PalComposerSheet>(find.byType(PalComposerSheet));
    expect(sheet.seed, 'Why Rent auto-pays first?');
    expect(find.descendant(
            of: find.byType(PalComposerSheet), matching: find.text('Why Rent auto-pays first?')),
        findsOneWidget);
  });

  _todayTest('approving add-ritual on the card adds the step, and the toast Undo removes it',
      (tester) async {
    await _boot(tester,
        day: const TodayDay(routines: [_emptyEvening], workout: false),
        pal: TodayPal(proposals: const [_addRitual]));

    await _tap(tester, find.text('Add ritual'));

    expect(_toast('Added $_step to ${_emptyEvening.name}'), findsOneWidget);
    expect(_eveningSteps(tester), [_step]);

    await _tap(tester, _toastUndo);
    expect(_eveningSteps(tester), isEmpty);
    expect(_card(_addRitual.title), findsOneWidget);
  });

  _todayTest('approved on You, the toast names it and Undo removes the step', (tester) async {
    await _boot(tester,
        day: const TodayDay(routines: [_emptyEvening], workout: false),
        pal: TodayPal(proposals: const [_addRitual]));
    final router = appRouter(tester);

    router.go('/you');
    await tester.pumpAndSettle();
    await _tap(tester, find.bySemanticsLabel('Add ritual: ${_addRitual.title}'));
    expect(_toast('Added $_step to ${_emptyEvening.name}'), findsOneWidget);
    await _tap(tester, _toastUndo);

    expect(_eveningSteps(tester), isEmpty);
    router.go('/today');
    await tester.pumpAndSettle();
    expect(_card(_addRitual.title), findsOneWidget);
  });

  _todayTest('Why shows when Needs care forces the lead, and carries the rule',
      at: Clock.fixed(DateTime(2026, 9, 28, 21, 30)), (tester) async {
    await _boot(tester, day: const TodayDay(moveKcal: 100), pal: TodayPal(proposals: const []));

    expect(_card('Push Day A'), findsOneWidget);
    expect(_why(), findsOneWidget);

    await _tap(tester, _why());
    final sheet = tester.widget<PalComposerSheet>(find.byType(PalComposerSheet));
    expect(sheet.seed, 'Why Push Day A first?');
    expect(sheet.about, contains('Move needs care'));
  });

  _todayTest('the card holds a 40px icon disc, the when line, the title, one pill and skip',
      (tester) async {
    await _boot(tester, pal: TodayPal(proposals: const []));

    final texts = tester.widgetList<Text>(_onCard(find.byType(Text))).map((t) => t.data);
    // no reason line: only the when line, the title and the two buttons.
    expect(texts, ['At 7:00 AM · 5 steps', 'Morning', 'Start', 'Not today']);
    final icon = _onCard(find.byType(AppIcon));
    expect(icon, findsOneWidget);
    expect(tester.widget<AppIcon>(icon).name, 'sunrise.fill');
    expect(tester.getSize(find.ancestor(of: icon, matching: find.byType(Container)).first),
        const Size(40, 40));
  });

  _todayTest('a timed lead reads its time', at: _closeOutTime, (tester) async {
    await _boot(tester);

    expect(_card('Close-out'), findsOneWidget);
    expect(_onToday(find.text('At 9:30 PM · 4 steps')), findsOneWidget);
    expect(_onToday(find.text('Now')), findsNothing);
  });

  group('Your day', () {
    _todayTest('counts what is done or approved of every row', (tester) async {
      await _boot(tester,
          day: const TodayDay(mood: true, firstRoutineDone: true),
          pal: TodayPal(proposals: [proposal('a', 'Rent auto-pays')]));

      expect(_onToday(find.text('Your day')), findsOneWidget);
      expect(_onToday(find.text('· 2 of 7 done')), findsOneWidget);

      await _tap(tester, _onCard(find.text('Got it')));
      expect(_onToday(find.text('· 3 of 7 done')), findsOneWidget);
      expect(_row('Rent auto-pays'), findsOneWidget);
      expect(find.bySemanticsLabel('Rent auto-pays, Rent auto-pays done'), findsOneWidget);
    });

    _todayTest('lists every item, the card\'s too, with no fold', (tester) async {
      await _boot(tester, pal: TodayPal(proposals: const []));

      expect(_card('Morning'), findsOneWidget);
      for (final title in [
        'Morning',
        'Midday reset',
        'Close-out',
        'Push Day A',
        'Mood check-in',
        'Log a meal',
      ]) {
        expect(_row(title), findsOneWidget, reason: title);
      }
      expect(find.bySemanticsLabel('Start: Morning, 5 steps'), findsOneWidget);
      expect(find.bySemanticsLabel('Start: Push Day A, 55 min'), findsOneWidget);
      expect(_onToday(find.textContaining('more later today')), findsNothing);
      expect(find.bySemanticsLabel(RegExp('Do this next')), findsNothing);
      expect(find.byKey(todayRailKey), findsOneWidget);
    });

    _todayTest('a done routine row is inert', (tester) async {
      await _boot(tester, day: const TodayDay(firstRoutineDone: true));

      final done = find.bySemanticsLabel('Morning, Done');
      expect(done, findsOneWidget);
      expect(tester.getSemantics(done), isNot(isSemantics(isButton: true)));
      await _tap(tester, done);
      expect(find.byType(RoutinePlayerScreen), findsNothing);
    });

    _todayTest('a done mood row opens the mood logger', (tester) async {
      await _boot(tester, day: const TodayDay(mood: true));

      final again = find.bySemanticsLabel('Check in again: Mood check-in, ${moodWord(0.7)}');
      expect(again, findsOneWidget);
      await _tap(tester, again);
      expect(find.byType(BottomSheet), findsOneWidget);
    });

    _todayTest('Not today puts the row off, tapping it brings it back; Undo is in the toast',
        (tester) async {
      await _boot(tester, pal: TodayPal(proposals: const []));

      await _tap(tester, _onCard(find.text('Not today')));
      expect(_card('Morning'), findsNothing);
      expect(find.bySemanticsLabel('Bring back: Morning, Put off until tomorrow'), findsOneWidget);
      expect(_toast('Put off until tomorrow: Morning'), findsOneWidget);
      // no header Undo; the toast holds the only one.
      expect(_onToday(find.text('Undo')), findsNothing);
      expect(_toastUndo, findsOneWidget);

      await _tap(tester, find.bySemanticsLabel('Bring back: Morning, Put off until tomorrow'));
      expect(find.bySemanticsLabel('Start: Morning, 5 steps'), findsOneWidget);
      expect(_card('Morning'), findsOneWidget);
      expect(_toast('Morning is back on today'), findsOneWidget);
      expect(_toastUndo, findsNothing);
    });

    _todayTest('the toast\'s Undo brings a put-off back to the card', (tester) async {
      await _boot(tester,
          day: const TodayDay(routines: []), pal: TodayPal(proposals: [proposal('a', 'Rent auto-pays')]));

      await _tap(tester, _onCard(find.text('Not now')));
      expect(_card('Push Day A'), findsOneWidget);
      expect(_onCard(find.text('Any time · 55 min')), findsOneWidget);

      await _tap(tester, _toastUndo);
      expect(_card('Rent auto-pays'), findsOneWidget);
      expect(find.byKey(planUndoToastKey), findsNothing);
    });
  });

  group('while the day loads', () {
    _todayTest('the lead, card and list wait for every store the plan reads', (tester) async {
      tester.view.physicalSize = _tall;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final meals = Completer<void>();
      await bootToday(tester,
          day: const TodayDay(mood: true),
          overrides: [nutritionControllerProvider.overrideWith(() => _GatedNutrition(meals.future))]);

      expect(find.text('MON 28 SEP · 9:30 AM'), findsOneWidget);
      expect(find.byKey(todayCardKey), findsNothing);
      expect(find.byKey(todayRailKey), findsNothing);
      expect(_onToday(find.byType(PalLeadText)), findsNothing);
      expect(_row('Mood check-in'), findsNothing);

      meals.complete();
      await tester.pumpAndSettle();

      expect(find.byKey(todayCardKey), findsOneWidget);
      expect(find.byKey(todayRailKey), findsOneWidget);
      expect(_row('Mood check-in'), findsOneWidget);
    });

    _todayTest('a routine edit keeps the day drawn and the check-in done', (tester) async {
      await _boot(tester, day: const TodayDay(mood: true));
      final again = find.bySemanticsLabel('Check in again: Mood check-in, ${moodWord(0.7)}');
      expect(again, findsOneWidget);

      // a routine edit re-emits Today's state; the stores behind the plan
      // must keep their values through it.
      final repo = ProviderScope.containerOf(tester.element(find.byType(TodayScreen)))
          .read(ritualRepositoryProvider);
      await tester.runAsync(() async {
        final morning = (await repo.getAll()).first;
        await repo.upsertRoutine(morning.copyWith(blurb: 'A new blurb'));
      });
      for (var i = 0; i < 5; i++) {
        await tester.pump();
        expect(again, findsOneWidget, reason: 'frame $i');
        expect(_onToday(find.text('Mood check-in')), findsOneWidget, reason: 'frame $i');
      }
    });
  });

  group('the primary pill opens the flow for', () {
    _todayTest('a routine', (tester) async {
      await _boot(tester);

      await _tap(tester, _onCard(find.text('Start')));
      expect(find.byType(RoutinePlayerScreen), findsOneWidget);
    });

    _todayTest('the workout', (tester) async {
      await _boot(tester, day: const TodayDay(routines: []));

      await _tap(tester, _onCard(find.text('Start')));
      expect(find.byType(StartWorkoutScreen), findsOneWidget);
    });

    _todayTest('the mood check-in', (tester) async {
      await _boot(tester, day: _bare);

      await _tap(tester, _onCard(find.text('Check in')));
      expect(find.byType(BottomSheet), findsOneWidget);
    });

    _todayTest('a meal', (tester) async {
      // the meal nudge rides along a planned day, so a put-off proposal plans it.
      await _boot(tester,
          day: const TodayDay(routines: [], workout: false, mood: true),
          pal: TodayPal(proposals: [proposal('a', 'Rent auto-pays')]));
      await _tap(tester, _onCard(find.text('Not now')));

      // the card's title and its pill read the same.
      await _tap(tester, _onCard(find.text('Log a meal')).last);
      expect(find.byType(PalComposerSheet), findsOneWidget);
    });

    _todayTest('the close-out', at: _closeOutTime, (tester) async {
      await _boot(tester);

      expect(_card('Close-out'), findsOneWidget);
      await _tap(tester, _onCard(find.text('Start')));
      expect(find.byType(EveningCloseOutScreen), findsOneWidget);
    });
  });

  group('a row tap opens its flow and leaves the card as it was, for', () {
    _todayTest('a routine', (tester) async {
      await _boot(tester, pal: TodayPal(proposals: const []));

      await _tap(tester, _row('Midday reset'));
      expect(find.byType(RoutinePlayerScreen), findsOneWidget);
    });

    _todayTest('the workout', (tester) async {
      await _boot(tester, pal: TodayPal(proposals: const []));

      await _tap(tester, _row('Push Day A'));
      expect(find.byType(StartWorkoutScreen), findsOneWidget);
    });

    _todayTest('the close-out', (tester) async {
      await _boot(tester);

      await _tap(tester, _row('Close-out'));
      expect(find.byType(EveningCloseOutScreen), findsOneWidget);
    });

    _todayTest('a meal', (tester) async {
      await _boot(tester);

      await _tap(tester, _row('Log a meal'));
      expect(find.byType(PalComposerSheet), findsOneWidget);
    });

    _todayTest('the mood check-in', (tester) async {
      await _boot(tester, day: _bare, pal: TodayPal(proposals: [proposal('a', 'Rent auto-pays')]));

      await _tap(tester, _row('Mood check-in'));
      expect(find.byType(BottomSheet), findsOneWidget);

      Navigator.pop(tester.element(find.byType(BottomSheet)));
      await tester.pumpAndSettle();
      expect(_card('Rent auto-pays'), findsOneWidget);
      expect(_why(), findsOneWidget);
    });

    _todayTest('a proposal, which it approves in place', (tester) async {
      await _boot(tester,
          pal: TodayPal(proposals: [proposal('a', 'Rent auto-pays'), proposal('b', 'Cap dinner')]));

      await _tap(tester, find.bySemanticsLabel('Got it: Cap dinner, Pal suggests'));
      expect(find.bySemanticsLabel('Cap dinner, Cap dinner done'), findsOneWidget);
      expect(_card('Rent auto-pays'), findsOneWidget);
      expect(_toast('Planned Leg Day for Friday'), findsOneWidget);
      expect(_toastUndo, findsOneWidget);
    });
  });

  _todayTest('an empty day asks only for the mood check-in', (tester) async {
    await _boot(tester, day: const TodayDay.empty());

    expect(_card('Mood check-in'), findsOneWidget);
    expect(find.text('· 0 of 1 done'), findsOneWidget);
    expect(_row('Log a meal'), findsNothing);
  });

  _todayTest('an empty day with the check-in done is all done, 1 of 1', (tester) async {
    await _boot(tester,
        day: const TodayDay(
          goals: Goals(dailyBudget: 0, dailyMoveKcal: 0, dailyRitualTarget: 0),
          routines: [],
          workout: false,
          receipt: false,
          sleep: false,
          moveKcal: 0,
          mood: true,
        ));

    expect(_card('All done'), findsOneWidget);
    expect(find.text('· 1 of 1 done'), findsOneWidget);
    expect(_lead('Nothing is left. Rest up.'), findsOneWidget);
  });

  _todayTest('an empty day ends on the all-done card with no buttons or Why, the put-off listed',
      (tester) async {
    await _boot(tester, day: const TodayDay.empty());

    await _tap(tester, _onCard(find.text('Not today')));

    expect(_card('All done'), findsOneWidget);
    expect(_card("That's the day"), findsOneWidget);
    expect(_onCard(find.byType(AppIcon)), findsOneWidget);
    expect(tester.widget<AppIcon>(_onCard(find.byType(AppIcon))).name, 'checkmark');
    expect(_lead('Nothing is left. Rest up.'), findsOneWidget);
    expect(_onCard(find.text('Not today')), findsNothing);
    expect(find.bySemanticsLabel(RegExp(r'^Bring back: ')), findsOneWidget);
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
    final pal = TodayPal(proposals: [proposal('a', 'Rent auto-pays')]);
    await _boot(tester, pal: pal);
    expect(_card('Rent auto-pays'), findsOneWidget);

    pal.offline = true;
    await _pullToRefresh(tester);

    expect(_label(_offlineLabel), findsOneWidget);
    expect(_card('Morning'), findsOneWidget);
    expect(_lead(_morningSaid), findsOneWidget);
    expect(_why(), findsNothing);
    // the held proposal stays listed.
    expect(_row('Rent auto-pays'), findsOneWidget);
  });

  _todayTest('at text scale 2.0 rows and the when line hold one line and the lead shows in full',
      (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    const longLine = 'Rent is due Monday and forty dollars short, so hold it now and '
        'the evening stays clear for the long walk and an early night.';
    await _boot(
      tester,
      strictLayout: true,
      day: TodayDay(routines: [
        SeedData.ritualRoutines().first,
        SeedData.ritualRoutines()[1].copyWith(name: _longTitle),
      ]),
      pal: TodayPal(proposals: const [], linesByTitle: {'Morning': longLine}),
    );

    // past three serif lines Pal's line drops to body and is never cut.
    final lead = tester.renderObject<RenderParagraph>(_lead(longLine));
    expect(tester.widget<Text>(_lead(longLine)).maxLines, isNull);
    expect(lead.didExceedMaxLines, isFalse);
    final row = tester.renderObject<RenderParagraph>(_onToday(find.text(_longTitle)));
    expect(tester.widget<Text>(_onToday(find.text(_longTitle))).maxLines, 1);
    expect(row.didExceedMaxLines, isTrue);
    final when = tester.widget<Text>(_onCard(find.text('At 7:00 AM · 5 steps')));
    expect(when.maxLines, 1);
    expect(when.overflow, TextOverflow.ellipsis);
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
      await tester.ensureVisible(_onToday(find.text(_otherLongTitle)));
      await tester.pumpAndSettle();

      // the card wraps its title; the rows ellipsise.
      expect(_onToday(find.text(_longTitle)), findsNWidgets(2));
      expect(_onToday(find.text(_otherLongTitle)), findsOneWidget);
      expect(tester.takeException(), isNull);
      await flushProviderTimers(tester);
    });
  });

  testWidgets('a put-off at 11:58 PM is open again after midnight with no relaunch',
      (tester) async {
    var current = DateTime(2026, 9, 28, 23, 58);
    await withClock(Clock(() => current), () async {
      await _boot(tester, day: _bare, pal: TodayPal(proposals: const []));
      expect(_card('Mood check-in'), findsOneWidget);

      await _tap(tester, _onCard(find.text('Not today')));
      expect(_card('Mood check-in'), findsNothing);
      expect(find.bySemanticsLabel('Bring back: Mood check-in, Put off until tomorrow'),
          findsOneWidget);

      current = DateTime(2026, 9, 29, 0, 1);
      await tester.pump(const Duration(minutes: 1));
      await tester.pumpAndSettle();

      expect(find.text('TUE 29 SEP · 12:01 AM'), findsOneWidget);
      expect(_card('Mood check-in'), findsOneWidget);
      expect(find.bySemanticsLabel('Check in: Mood check-in'), findsOneWidget);
      await flushProviderTimers(tester);
    });
  });

  _todayTest('pulling Today down refetches the agenda', (tester) async {
    final pal = TodayPal(proposals: const []);
    await _boot(tester, pal: pal);
    final before = pal.plans.length;

    await _pullToRefresh(tester);

    expect(pal.plans.length, before + 1);
  });

  _todayTest('returning to the app refetches the agenda', (tester) async {
    final pal = TodayPal(proposals: const []);
    await _boot(tester, pal: pal);
    final before = pal.plans.length;

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

    expect(pal.plans.length, before + 1);
  });

  _todayTest('Today never asks Pal for a day summary', (tester) async {
    final pal = TodayPal(proposals: const []);
    await _boot(tester, pal: pal);
    await _pullToRefresh(tester);

    expect(pal.insightsCalls, 0);
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
