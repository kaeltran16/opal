@Tags(['scenario'])
library;

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/app.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/controllers/rituals_builder_controller.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/repositories/repositories.dart';
import 'package:opal/data/seed/seed_data.dart';
import 'package:opal/models/models.dart';
import 'package:opal/screens/detail/detail_screen.dart';
import 'package:opal/screens/onboarding/onboarding_screen.dart';
import 'package:opal/screens/pal/pal_composer_screen.dart';
import 'package:opal/screens/reflect/evening_close_out_screen.dart';
import 'package:opal/screens/rituals/rituals_builder_screen.dart';
import 'package:opal/screens/rituals/routine_player_screen.dart';
import 'package:opal/screens/today/today_screen.dart';
import 'package:opal/theme/theme.dart';
import 'package:opal/widgets/app_icon.dart';
import 'package:opal/widgets/glass_tab_bar.dart';
import 'package:opal/widgets/pal_label.dart';

import '../support/golden_harness.dart' show appRouter, ignoreOverflowErrors;
import '../support/today_fixture.dart';
import 'scenario_harness.dart';

const _manage = 'Manage routines';
const _manageRoute = '/areas/routines/manage';
const _morningRow = 'Morning, 7:00 AM, 5 steps. Edit';
const _manageError = "Couldn't load routines. Try again in a moment.";
const _firstStep = 'Glass of water';

const _closeOutLead = 'Close out your day.';
const _closeOutFirst = 'Phone on the charger';
const _closeOutError = "Couldn't load your routines. Try again in a moment.";

const _saveFailed = "Couldn't save. Try again.";
const _seedRoutines = ['Morning', 'Midday reset', 'Evening wind-down'];

/// The drag that reorders a row in widget tests: six short moves up.
const _dragMoves = 6;
const _dragStep = Offset(0, -40);
const _dragPause = Duration(milliseconds: 50);

const _emptyRoutine = RitualRoutine(
  id: 'empty',
  name: 'Midday reset',
  time: '1:00 PM',
  tone: RitualTone.midday,
  icon: 'sun.max.fill',
  blurb: 'Break the desk spell',
);

String _theme(bool dark) => dark ? 'dark' : 'light';

/// [text] set in `AppType.title`, the lead of a sheet, card or step.
Finder _title(String text) => find.byWidgetPredicate((w) =>
    w is Text && w.data == text && w.style?.fontSize == AppType.title.fontSize);

/// Scrolls [finder] into view and taps the last match, the top sheet's.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder.last);
  await tester.pumpAndSettle();
  await tester.tap(finder.last);
  await tester.pumpAndSettle();
}

Future<void> _tapLabel(WidgetTester tester, String label) =>
    _tap(tester, find.bySemanticsLabel(label));

Future<void> _push(WidgetTester tester, String path) async {
  appRouter(tester).push(path);
  await tester.pumpAndSettle();
}

// --- manage ---

/// Never emits until the step hands it a list, so the screen stays loading.
class _PendingBuilder extends RitualsBuilderController {
  _PendingBuilder(this.routines);
  final Stream<List<RitualRoutine>> routines;

  @override
  Stream<List<RitualRoutine>> build() => routines;
}

class _FailingBuilder extends RitualsBuilderController {
  // an Exception, not an Error: riverpod's default retry skips Errors, so only
  // an Exception shows whether the provider opts out of retry.
  @override
  Stream<List<RitualRoutine>> build() => throw Exception('no database');
}

Future<void> _bootManage(
  WidgetTester tester,
  bool dark, {
  TodayDay day = const TodayDay(),
  List<Override> overrides = const [],
}) async {
  await bootToday(tester, dark: dark, day: day, overrides: overrides);
  appRouter(tester).go(_manageRoute);
  await tester.pumpAndSettle();
  expect(find.byType(RitualsBuilderScreen), findsOneWidget);
  expect(find.text(_manage), findsOneWidget);
}

Future<void> _openMorning(WidgetTester tester, bool dark) async {
  await _bootManage(tester, dark);
  await _tapLabel(tester, _morningRow);
  expect(find.text('Edit routine'), findsOneWidget);
  expect(find.widgetWithText(TextField, 'Morning'), findsOneWidget);
}

double _top(WidgetTester tester, String text) => tester.getTopLeft(find.text(text)).dy;

// --- player ---

Future<void> _openPlayer(
  WidgetTester tester,
  bool dark, {
  String routineId = 'morning',
  TodayDay day = const TodayDay(),
  List<Override> overrides = const [],
}) async {
  await bootToday(tester, dark: dark, day: day, overrides: overrides);
  await _push(tester, '/rituals/player/$routineId');
  expect(find.byType(RoutinePlayerScreen), findsOneWidget);
}

// --- close-out ---

Future<void> _openCloseOut(
  WidgetTester tester,
  bool dark, {
  TodayDay day = const TodayDay(),
  List<Override> overrides = const [],
}) async {
  await bootToday(tester, dark: dark, day: day, overrides: overrides);
  await _push(tester, '/close-out');
  expect(find.byType(EveningCloseOutScreen), findsOneWidget);
  expect(find.text(_closeOutLead), findsOneWidget);
}

Future<void> _markDone(WidgetTester tester) => _tapLabel(tester, 'Mark done');

// --- onboarding ---

class _FailingGoals extends GoalsRepository {
  _FailingGoals(super.db);

  @override
  Future<void> upsert(Goals goals) async => throw StateError('disk full');
}

/// Boots the app with onboarding not yet complete, the way
/// `test/onboarding_test.dart` pumps it, in [dark]'s theme.
Future<void> _bootOnboarding(
  WidgetTester tester,
  bool dark, {
  List<Override> overrides = const [],
}) async {
  ignoreOverflowErrors();
  SharedPreferences.setMockInitialValues({
    'settings.brightness': dark ? 'dark' : 'light',
  });
  final prefs = await SharedPreferences.getInstance();
  final db = LoopDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        loopDatabaseProvider.overrideWithValue(db),
        palServiceProvider.overrideWithValue(TodayPal(proposals: const [])),
        ...overrides,
      ],
      child: const LoopApp(),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.byType(OnboardingScreen), findsOneWidget);
  expect(find.byType(PalLabel), findsOneWidget);
}

Future<void> _tapText(WidgetTester tester, String text) => _tap(tester, find.text(text));

/// Walks from Welcome to the routines step with the defaults.
Future<void> _toRoutines(WidgetTester tester) async {
  await _tapText(tester, 'Get started');
  await _tapText(tester, 'Continue');
  await _tapText(tester, 'Continue');
  expect(find.text('Choose your routines'), findsOneWidget);
}

void main() {
  // --- manage ---

  scenarioTest('manage list', (tester, dark) async {
    await bootToday(tester, dark: dark);
    await tester.tap(find.descendant(
        of: find.byType(GlassTabBar), matching: find.bySemanticsLabel(RegExp('^Areas'))));
    await tester.pumpAndSettle();
    await _tap(tester, find.bySemanticsLabel(RegExp(r'^Routines([:,]|$)')));
    await _tap(tester, find.descendant(
        of: find.byType(DetailScreen), matching: find.bySemanticsLabel(_manage)));

    expect(find.byType(RitualsBuilderScreen), findsOneWidget);
    expect(find.text(_manage), findsOneWidget);
    expect(find.bySemanticsLabel(_morningRow), findsOneWidget);
    expect(find.text('7:00 AM · 5 steps'), findsOneWidget);
    for (final name in _seedRoutines) {
      expect(find.bySemanticsLabel('Reorder $name'), findsOneWidget, reason: name);
    }
    expect(find.byWidgetPredicate((w) => w is AppIcon && w.name == 'xmark'), findsNothing);
    await shot(tester, 'manage_list_${_theme(dark)}');
  });

  scenarioTest('manage empty', (tester, dark) async {
    await _bootManage(tester, dark, day: const TodayDay(routines: []));

    expect(find.text('No routines yet. Tap + to add one.'), findsOneWidget);
    expect(find.bySemanticsLabel('New routine'), findsOneWidget);
    await shot(tester, 'manage_empty_${_theme(dark)}');
  });

  scenarioTest('manage loading', (tester, dark) async {
    final pending = StreamController<List<RitualRoutine>>();
    addTearDown(pending.close);
    await _bootManage(tester, dark, overrides: [
      ritualsBuilderControllerProvider.overrideWith(() => _PendingBuilder(pending.stream)),
    ]);

    expect(find.text('…'), findsOneWidget);
    expect(find.text('Morning'), findsNothing);
    await shot(tester, 'manage_loading_${_theme(dark)}');

    // emit once so riverpod is not disposed mid-load.
    pending.add(const []);
    await tester.pumpAndSettle();
  });

  scenarioTest('manage error', (tester, dark) async {
    await _bootManage(tester, dark, overrides: [
      ritualsBuilderControllerProvider.overrideWith(_FailingBuilder.new),
    ]);
    await tester.pumpAndSettle();

    expect(find.text(_manageError), findsOneWidget);
    expect(find.text('Morning'), findsNothing);
    await shot(tester, 'manage_error_${_theme(dark)}');
  });

  scenarioTest('manage edit', (tester, dark) async {
    await _openMorning(tester, dark);

    for (final section in ['Tone', 'Icon', 'Steps']) {
      expect(find.text(section), findsOneWidget, reason: section);
    }
    expect(find.bySemanticsLabel('Reorder $_firstStep'), findsOneWidget);
    expect(find.bySemanticsLabel('Remove $_firstStep'), findsOneWidget);
    await shot(tester, 'manage_edit_${_theme(dark)}');
  });

  scenarioTest('manage new', (tester, dark) async {
    await _bootManage(tester, dark);
    await _tapLabel(tester, 'New routine');

    expect(find.text('New routine'), findsOneWidget);
    expect(find.text('Add at least one step.'), findsOneWidget);
    expect(find.text('Delete routine'), findsNothing);
    expect(tester.getSemantics(find.bySemanticsLabel('Save')),
        isSemantics(hasEnabledState: true, isEnabled: false));
    await shot(tester, 'manage_new_${_theme(dark)}');
  });

  scenarioTest('manage step sheet', (tester, dark) async {
    await _openMorning(tester, dark);
    await _tapLabel(tester, '$_firstStep. Edit step');

    expect(find.text('Edit step'), findsOneWidget);
    expect(find.widgetWithText(TextField, _firstStep), findsOneWidget);
    await shot(tester, 'manage_step_sheet_${_theme(dark)}');
  });

  scenarioTest('manage icon selected', (tester, dark) async {
    await _openMorning(tester, dark);
    await _tapLabel(tester, 'Moon');

    expect(tester.getSemantics(find.bySemanticsLabel('Moon')),
        isSemantics(hasSelectedState: true, isSelected: true, isButton: true));
    expect(tester.getSemantics(find.bySemanticsLabel('Sunrise')),
        isSemantics(hasSelectedState: true, isSelected: false, isButton: true));
    await shot(tester, 'manage_icon_selected_${_theme(dark)}');
  });

  scenarioTest('manage step removed', (tester, dark) async {
    await _openMorning(tester, dark);
    await _tapLabel(tester, 'Remove $_firstStep');

    expect(find.text(_firstStep), findsNothing);
    expect(find.bySemanticsLabel('Remove $_firstStep'), findsNothing);
    expect(find.text('Wash my face'), findsOneWidget);
    await shot(tester, 'manage_step_removed_${_theme(dark)}');
  });

  scenarioTest('manage delete confirm', (tester, dark) async {
    await _openMorning(tester, dark);
    await _tapLabel(tester, 'Delete routine');

    expect(_title('Delete Morning?'), findsOneWidget);
    expect(
      find.text('This removes the routine and its 5 steps. '
          'What you checked off before stays in your history.'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Keep it'), findsOneWidget);
    await shot(tester, 'manage_delete_confirm_${_theme(dark)}');
  });

  scenarioTest('manage keep it', (tester, dark) async {
    await _openMorning(tester, dark);
    await _tapLabel(tester, 'Delete routine');
    await _tapLabel(tester, 'Keep it');

    expect(find.text('Delete Morning?'), findsNothing);
    expect(find.text('Edit routine'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Morning'), findsOneWidget);
    await shot(tester, 'manage_keep_it_${_theme(dark)}');
  });

  scenarioTest('manage deleted', (tester, dark) async {
    await _openMorning(tester, dark);
    await _tapLabel(tester, 'Delete routine');
    await _tapLabel(tester, 'Delete');

    expect(find.text('Edit routine'), findsNothing);
    expect(find.text(_manage), findsOneWidget);
    expect(find.text('Morning'), findsNothing);
    expect(find.text('Midday reset'), findsOneWidget);
    await shot(tester, 'manage_deleted_${_theme(dark)}');
  });

  scenarioTest('manage saved', (tester, dark) async {
    await _bootManage(tester, dark);
    await _tapLabel(tester, 'New routine');
    await tester.enterText(find.widgetWithText(TextField, 'Routine name'), 'Wind down');
    await tester.pumpAndSettle();
    await _tapLabel(tester, 'Add step');
    await tester.enterText(find.widgetWithText(TextField, 'Step title'), 'Read');
    await tester.pumpAndSettle();
    await _tapLabel(tester, 'Save');
    await _tapLabel(tester, 'Save');

    expect(find.text('New routine'), findsNothing);
    expect(find.text('Any time · 1 step'), findsOneWidget);
    expect(find.bySemanticsLabel('Wind down, any time, 1 step. Edit'), findsOneWidget);
    expect(_top(tester, 'Wind down'), greaterThan(_top(tester, 'Evening wind-down')));
    await shot(tester, 'manage_saved_${_theme(dark)}');
  });

  scenarioTest('manage reordered', (tester, dark) async {
    await _bootManage(tester, dark);
    final handle = find.bySemanticsLabel('Reorder Evening wind-down');
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump();
    for (var i = 0; i < _dragMoves; i++) {
      await gesture.moveBy(_dragStep);
      await tester.pump(_dragPause);
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(_top(tester, 'Evening wind-down'), lessThan(_top(tester, 'Morning')));
    expect(_top(tester, 'Morning'), lessThan(_top(tester, 'Midday reset')));
    await shot(tester, 'manage_reordered_${_theme(dark)}');
  });

  // --- player ---

  scenarioTest('player step', (tester, dark) async {
    await _openPlayer(tester, dark);

    expect(find.text('Step 1 of 5'), findsOneWidget);
    expect(find.text('0 of 5 done'), findsOneWidget);
    expect(_title(_firstStep), findsOneWidget);
    expect(find.text('Mark done'), findsOneWidget);
    expect(find.text('Up next'), findsOneWidget);
    await shot(tester, 'player_step_${_theme(dark)}');
  });

  scenarioTest('player marked', (tester, dark) async {
    await _openPlayer(tester, dark);
    await _markDone(tester);

    expect(find.text('1 of 5 done'), findsOneWidget);
    expect(find.text('Step 2 of 5'), findsOneWidget);
    expect(_title('Wash my face'), findsOneWidget);
    await shot(tester, 'player_marked_${_theme(dark)}');
  });

  scenarioTest('player next step', (tester, dark) async {
    await _openPlayer(tester, dark);
    await _markDone(tester);
    await _tapLabel(tester, 'Back');

    expect(find.text('Step 1 of 5'), findsOneWidget);
    expect(_title(_firstStep), findsOneWidget);
    expect(find.text('Next step'), findsOneWidget);
    expect(find.text('Mark done'), findsNothing);
    await shot(tester, 'player_next_step_${_theme(dark)}');
  });

  scenarioTest('player skipped', (tester, dark) async {
    await _openPlayer(tester, dark);
    await _tapLabel(tester, 'Skip');

    expect(find.text('Step 2 of 5'), findsOneWidget);
    expect(find.text('0 of 5 done'), findsOneWidget);
    expect(_title('Wash my face'), findsOneWidget);
    expect(find.text('Mark done'), findsOneWidget);
    await shot(tester, 'player_skipped_${_theme(dark)}');
  });

  scenarioTest('player back', (tester, dark) async {
    await _openPlayer(tester, dark);
    await _tapLabel(tester, 'Skip');
    await _tapLabel(tester, 'Back');

    expect(find.text('Step 1 of 5'), findsOneWidget);
    expect(_title(_firstStep), findsOneWidget);
    expect(find.text('Mark done'), findsOneWidget);
    await shot(tester, 'player_back_${_theme(dark)}');
  });

  scenarioTest('player done', (tester, dark) async {
    await _openPlayer(tester, dark);
    for (var i = 0; i < 5; i++) {
      await _markDone(tester);
    }

    expect(find.text('Morning is done.'), findsOneWidget);
    expect(find.text('5 of 5 steps'), findsOneWidget);
    expect(find.text('1-day streak'), findsOneWidget);
    expect(find.bySemanticsLabel('Back to routines'), findsOneWidget);
    await shot(tester, 'player_done_${_theme(dark)}');
  });

  scenarioTest('player partial', (tester, dark) async {
    await _openPlayer(tester, dark);
    for (final label in ['Mark done', 'Skip', 'Mark done', 'Skip', 'Mark done']) {
      await _tapLabel(tester, label);
    }

    expect(find.text('Morning, 3 of 5 done.'), findsOneWidget);
    expect(find.text('3 of 5 steps'), findsOneWidget);
    expect(find.text('Morning is done.'), findsNothing);
    await shot(tester, 'player_partial_${_theme(dark)}');
  });

  scenarioTest('player no steps', (tester, dark) async {
    await _openPlayer(
      tester,
      dark,
      routineId: _emptyRoutine.id,
      day: TodayDay(routines: [...SeedData.ritualRoutines(), _emptyRoutine]),
    );

    expect(_title('No steps yet'), findsOneWidget);
    expect(find.text('Add a step to Midday reset to start it.'), findsOneWidget);
    expect(find.bySemanticsLabel(_manage), findsOneWidget);
    await shot(tester, 'player_no_steps_${_theme(dark)}');
  });

  scenarioTest('player not found', (tester, dark) async {
    await _openPlayer(tester, dark, routineId: 'missing');

    expect(_title('Routine not found'), findsOneWidget);
    expect(find.text('It may have been deleted.'), findsOneWidget);
    expect(find.bySemanticsLabel('Back to routines'), findsOneWidget);
    await shot(tester, 'player_not_found_${_theme(dark)}');
  });

  scenarioTest('player error', (tester, dark) async {
    await _openPlayer(tester, dark, overrides: [
      ritualRoutinesStreamProvider
          .overrideWith((ref) => Stream<List<RitualRoutine>>.error(Exception('db closed'))),
    ]);
    await tester.pumpAndSettle();

    expect(_title("Couldn't load routine"), findsOneWidget);
    expect(find.text('Try again in a moment.'), findsOneWidget);
    expect(find.text('Mark done'), findsNothing);
    await shot(tester, 'player_error_${_theme(dark)}');
  });

  scenarioTest('player loading', (tester, dark) async {
    final pending = StreamController<List<RitualRoutine>>();
    addTearDown(pending.close);
    await _openPlayer(tester, dark, overrides: [
      ritualRoutinesStreamProvider.overrideWith((ref) => pending.stream),
    ]);

    // loading draws nothing but the background.
    expect(find.text('Mark done'), findsNothing);
    expect(find.text('Routine not found'), findsNothing);
    expect(find.textContaining('Step '), findsNothing);
    await shot(tester, 'player_loading_${_theme(dark)}');

    // emit once so riverpod is not disposed mid-load.
    pending.add(const []);
    await tester.pumpAndSettle();
  });

  // --- close-out ---

  scenarioTest('closeout open', (tester, dark) async {
    await bootToday(tester, dark: dark);
    final today = find.byType(TodayScreen);
    await _tap(tester, find.descendant(of: today, matching: find.textContaining('more later today')));
    // the row opens the close-out, as the card's pill does.
    await _tap(tester, find.bySemanticsLabel('Close-out, at 9:30 PM. Do this next'));

    expect(find.byType(EveningCloseOutScreen), findsOneWidget);
    expect(find.text(_closeOutLead), findsOneWidget);
    expect(find.text('Now'), findsOneWidget);
    expect(_title(_closeOutFirst), findsOneWidget);
    expect(find.text('Mark done'), findsOneWidget);
    expect(find.text('0 of 4 steps done. 4 more to close the ring.'), findsOneWidget);
    await shot(tester, 'closeout_open_${_theme(dark)}');
  });

  scenarioTest('closeout marked', (tester, dark) async {
    await _openCloseOut(tester, dark);
    await _markDone(tester);

    expect(find.text('1 of 4 steps done. 3 more to close the ring.'), findsOneWidget);
    expect(_title('Skincare'), findsOneWidget);
    expect(tester.getSemantics(find.bySemanticsLabel(_closeOutFirst)),
        isSemantics(hasCheckedState: true, isChecked: true, isButton: true));
    await shot(tester, 'closeout_marked_${_theme(dark)}');
  });

  scenarioTest('closeout row toggled', (tester, dark) async {
    await _openCloseOut(tester, dark);
    await _markDone(tester);
    await _tapLabel(tester, _closeOutFirst);

    expect(find.text('0 of 4 steps done. 4 more to close the ring.'), findsOneWidget);
    expect(_title(_closeOutFirst), findsOneWidget);
    expect(tester.getSemantics(find.bySemanticsLabel(_closeOutFirst).last),
        isSemantics(hasCheckedState: true, isChecked: false, isButton: true));
    await shot(tester, 'closeout_row_toggled_${_theme(dark)}');
  });

  scenarioTest('closeout done', (tester, dark) async {
    await _openCloseOut(tester, dark);
    for (var i = 0; i < 4; i++) {
      await _markDone(tester);
    }

    expect(find.text('4 of 4 steps done. The ring is closed.'), findsOneWidget);
    expect(find.text('All done'), findsOneWidget);
    expect(_title('Rest easy'), findsOneWidget);
    expect(find.text('Good night'), findsOneWidget);
    expect(find.text('Mark done'), findsNothing);
    await shot(tester, 'closeout_done_${_theme(dark)}');
  });

  scenarioTest('closeout good night', (tester, dark) async {
    await _openCloseOut(tester, dark);
    for (var i = 0; i < 4; i++) {
      await _markDone(tester);
    }
    await _tapLabel(tester, 'Good night');

    expect(find.byType(EveningCloseOutScreen), findsNothing);
    expect(find.byType(TodayScreen), findsOneWidget);
    expect(find.text('MON 28 SEP · 9:30 AM'), findsOneWidget);
    await shot(tester, 'closeout_good_night_${_theme(dark)}');
  });

  scenarioTest('closeout empty', (tester, dark) async {
    await _openCloseOut(tester, dark, day: const TodayDay(routines: []));

    expect(find.text('No wind-down steps yet.'), findsOneWidget);
    expect(find.text('Nothing to close'), findsOneWidget);
    expect(find.text('Good night'), findsOneWidget);
    expect(find.text('Tonight'), findsNothing);
    await shot(tester, 'closeout_empty_${_theme(dark)}');
  });

  scenarioTest('closeout loading', (tester, dark) async {
    final pending = StreamController<List<RitualRoutine>>();
    addTearDown(pending.close);
    await _openCloseOut(tester, dark, overrides: [
      ritualRoutinesStreamProvider.overrideWith((ref) => pending.stream),
    ]);

    expect(find.text('…'), findsOneWidget);
    expect(find.text('Mark done'), findsNothing);
    expect(find.text('Tonight'), findsNothing);
    await shot(tester, 'closeout_loading_${_theme(dark)}');

    // emit once so riverpod is not disposed mid-load.
    pending.add(const []);
    await tester.pumpAndSettle();
  });

  scenarioTest('closeout error', (tester, dark) async {
    await _openCloseOut(tester, dark, overrides: [
      ritualRoutinesStreamProvider
          .overrideWith((ref) => Stream<List<RitualRoutine>>.error(Exception('db closed'))),
    ]);
    await tester.pumpAndSettle();

    expect(find.text(_closeOutError), findsOneWidget);
    expect(find.text('Mark done'), findsNothing);
    expect(find.text('Tonight'), findsNothing);
    await shot(tester, 'closeout_error_${_theme(dark)}');
  });

  scenarioTest('closeout pal', (tester, dark) async {
    await _openCloseOut(tester, dark);
    await _tapLabel(tester, 'Ask Pal for a reflection prompt');

    expect(find.byType(PalComposerSheet), findsOneWidget);
    expect(find.text('Give me a reflection prompt for tonight'), findsWidgets);
    await shot(tester, 'closeout_pal_${_theme(dark)}');
  });

  // --- onboarding ---

  scenarioTest('onboarding welcome', (tester, dark) async {
    await _bootOnboarding(tester, dark);
    await tester.enterText(find.byType(TextField), 'Mira');
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Opal'), findsOneWidget);
    expect(find.text('1 of 4'), findsOneWidget);
    expect(find.text('Mira'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
    await shot(tester, 'onboarding_welcome_${_theme(dark)}');
  });

  scenarioTest('onboarding budget', (tester, dark) async {
    await _bootOnboarding(tester, dark);
    await _tapText(tester, 'Get started');
    await _tapText(tester, '\$120');

    expect(find.text('Set a daily budget'), findsOneWidget);
    expect(find.text('2 of 4'), findsOneWidget);
    expect(find.byType(PalLabel), findsOneWidget);
    expect(find.bySemanticsLabel('\$120 to spend each day'), findsOneWidget);
    await shot(tester, 'onboarding_budget_${_theme(dark)}');
  });

  scenarioTest('onboarding move', (tester, dark) async {
    await _bootOnboarding(tester, dark);
    await _tapText(tester, 'Get started');
    await _tapText(tester, 'Continue');
    await _tapText(tester, '700 kcal');

    expect(find.text('Pick a workout goal'), findsOneWidget);
    expect(find.text('3 of 4'), findsOneWidget);
    expect(find.byType(PalLabel), findsOneWidget);
    expect(find.bySemanticsLabel('700 kcal of active energy each day'), findsOneWidget);
    await shot(tester, 'onboarding_move_${_theme(dark)}');
  });

  scenarioTest('onboarding routines', (tester, dark) async {
    await _bootOnboarding(tester, dark);
    await _toRoutines(tester);

    expect(find.text('4 of 4'), findsOneWidget);
    expect(find.byType(PalLabel), findsOneWidget);
    for (final name in _seedRoutines) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
    expect(tester.getSemantics(find.bySemanticsLabel('Start tracking')),
        isSemantics(isButton: true, hasTapAction: true));
    await shot(tester, 'onboarding_routines_${_theme(dark)}');
  });

  scenarioTest('onboarding none', (tester, dark) async {
    await _bootOnboarding(tester, dark);
    await _toRoutines(tester);
    for (final name in _seedRoutines) {
      await _tapText(tester, name);
    }

    expect(find.text('Pick at least one routine to start.'), findsOneWidget);
    expect(tester.getSemantics(find.bySemanticsLabel('Start tracking')),
        isSemantics(isButton: true, hasEnabledState: true, isEnabled: false));
    await shot(tester, 'onboarding_none_${_theme(dark)}');
  });

  Future<void> failSave(WidgetTester tester, bool dark) async {
    // upsert throws before it touches the database, so any database will do.
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await _bootOnboarding(tester, dark,
        overrides: [goalsRepositoryProvider.overrideWithValue(_FailingGoals(db))]);
    await _toRoutines(tester);
    await _tapText(tester, 'Start tracking');
  }

  scenarioTest('onboarding save failed', (tester, dark) async {
    await failSave(tester, dark);

    expect(find.text(_saveFailed), findsOneWidget);
    expect(find.text('Choose your routines'), findsOneWidget);
    expect(find.byType(TodayScreen), findsNothing);
    await shot(tester, 'onboarding_save_failed_${_theme(dark)}');
  });

  scenarioTest('onboarding error cleared', (tester, dark) async {
    await failSave(tester, dark);
    await _tapText(tester, 'Midday reset');

    expect(find.text(_saveFailed), findsNothing);
    expect(find.text('Choose your routines'), findsOneWidget);
    await shot(tester, 'onboarding_error_cleared_${_theme(dark)}');
  });

  scenarioTest('onboarding finished', (tester, dark) async {
    await _bootOnboarding(tester, dark);
    await _toRoutines(tester);
    await _tapText(tester, 'Start tracking');

    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.byType(TodayScreen), findsOneWidget);
    expect(find.text('MON 28 SEP · 9:30 AM'), findsOneWidget);
    await shot(tester, 'onboarding_finished_${_theme(dark)}');
  });
}
