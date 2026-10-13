@Tags(['scenario'])
library;

// the canvas is dark-only and draws no error states, so the light shots and the
// error steps are plan-owned. the canvas's composer state (startAt composer) has
// no step because the ask pal sheet is run b's.

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/app.dart';
import 'package:opal/controllers/move_controller.dart';
import 'package:opal/controllers/post_workout_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/controllers/routine_editor_controller.dart';
import 'package:opal/controllers/routine_generator_controller.dart';
import 'package:opal/controllers/start_workout_controller.dart';
import 'package:opal/controllers/weekly_plan_controller.dart';
import 'package:opal/controllers/workout_detail_controller.dart';
import 'package:opal/controllers/workout_session_controller.dart';
import 'package:opal/data/repositories/workout_repository.dart';
import 'package:opal/models/models.dart';
import 'package:opal/router.dart';
import 'package:opal/screens/library/exercise_library_screen.dart';
import 'package:opal/screens/move/move_screen.dart';
import 'package:opal/screens/move/weekly_plan_screen.dart';
import 'package:opal/screens/move/workout_history_screen.dart';
import 'package:opal/screens/reflect/streak_celebration_screen.dart';
import 'package:opal/screens/workout/active_session_screen.dart';
import 'package:opal/screens/workout/post_workout_screen.dart';
import 'package:opal/screens/workout/routine_editor_screen.dart';
import 'package:opal/screens/workout/routine_generator_screen.dart';
import 'package:opal/screens/workout/start_workout_screen.dart';
import 'package:opal/screens/workout/workout_detail_screen.dart';
import 'package:opal/services/pal/mock_pal_service.dart';
import 'package:opal/services/pal/pal_service.dart';
import 'package:opal/widgets/controls.dart';
import 'package:opal/widgets/day_strip.dart';
import 'package:opal/widgets/exercise_row.dart';
import 'package:opal/widgets/inset_section.dart';

import '../support/golden_harness.dart';
import 'scenario_harness.dart';

const _seededToday = 'seed-workout-today-push';
const _seededYesterday = 'seed-workout-yday-legs';
const _pushRoutine = 'seed-routine-push-a';
const _legsRoutine = 'seed-routine-legs';
const _bench = 'Barbell Bench Press';
const _squat = 'Back Squat';
const _newRoutine = 'Scenario Day';
const _note = 'Bench moved well today. Keep the same weight next time.';
const _reading = 'Pal is reading your session…';
const _noteError = "Pal couldn't write a note just now.";
const _ahead = 'Ahead of your best by';
const _minimise = 'Minimise, the session keeps running';
const _restAdded = 30;
// past the collapse range of the large title, so the compact one shows.
const double _collapseDrag = 300;
const double _scrollStep = 200;
// a bound on the set-logging loops, well above any seeded routine's sets.
const _maxTaps = 60;
const _dbTick = Duration(milliseconds: 50);
const _oldSession = Duration(days: 280);

const _legsPick = WorkoutSuggestion(
  title: 'Leg Day',
  rationale: 'Legs have rested three days. Squats go best after a rest.',
  routineId: _legsRoutine,
  estimatedMinutes: 50,
  focus: 'Legs',
);
const _pushPick = WorkoutSuggestion(
  title: 'Push Day A',
  rationale: 'Push is fresh, and bench is close to a new best.',
  routineId: _pushRoutine,
  estimatedMinutes: 45,
  focus: 'Push',
);

/// Pal's pick from [first]; Pick another always lands on [_pushPick].
class _Pick extends PalPickController {
  _Pick(this.first);
  final Future<WorkoutSuggestion> Function() first;

  @override
  Future<WorkoutSuggestion> build() => first();

  @override
  Future<void> another() async {
    state = const AsyncValue.loading();
    await Future<void>.value();
    state = const AsyncData(_pushPick);
  }
}

/// The mock, with routine generation that can be held in flight or fail.
class _ScenarioPal extends MockPalService {
  _ScenarioPal() : super(latency: Duration.zero, seed: 0);

  Completer<void>? hold;
  bool failGenerate = false;

  @override
  Future<GeneratedRoutineDraft> generateRoutine(String goal, List<Exercise> available) async {
    await hold?.future;
    if (failGenerate) throw StateError('scenario');
    return super.generateRoutine(goal, available);
  }
}

/// Holds the save in flight until [gate] completes, then saves for real so
/// the tab settles on the logged workout.
class _GatedSave extends PostWorkoutController {
  _GatedSave(this.gate);
  final Completer<void> gate;

  @override
  Future<void> save(Workout workout) async {
    state = SaveState.saving;
    await gate.future;
    state = SaveState.idle;
    await super.save(workout);
  }
}

String _theme(bool dark) => dark ? 'dark' : 'light';

/// Asserts nothing threw, then shoots [step] in this theme.
Future<void> _shot(WidgetTester tester, String step, bool dark) async {
  expect(tester.takeException(), isNull, reason: step);
  await shot(tester, '${step}_${_theme(dark)}');
}

Future<String> _fixedNote() async => _note;

Future<String> _failedNote() async => throw StateError('scenario');

/// Boots the seeded app on the Workout tab. [freshDay] removes the workout
/// the seed logs today, so the tab shows Pal's pick rather than settling.
Future<void> _boot(
  WidgetTester tester,
  bool dark, {
  Future<WorkoutSuggestion> Function()? pick,
  _ScenarioPal? pal,
  Future<String> Function() summaryNote = _fixedNote,
  Future<String> Function() detailNote = _fixedNote,
  PostWorkoutController Function()? save,
  bool freshDay = false,
  List<Override> overrides = const [],
}) async {
  await bootApp(tester, dark: dark, palService: pal ?? _ScenarioPal(), overrides: [
    palPickControllerProvider.overrideWith(() => _Pick(pick ?? () async => _legsPick)),
    postWorkoutNoteProvider.overrideWith((ref, _) => summaryNote()),
    workoutNoteProvider.overrideWith((ref, _) => detailNote()),
    if (save != null) postWorkoutControllerProvider.overrideWith(save),
    ...overrides,
  ]);
  if (freshDay) await _workouts(tester).deleteById(_seededToday);
  appRouter(tester).go(AppRoute.move.path);
  await _settleDb(tester);
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(LoopApp)));

WorkoutRepository _workouts(WidgetTester tester) => _container(tester).read(workoutRepositoryProvider);

ActiveSessionState _session(WidgetTester tester) =>
    _container(tester).read(workoutSessionControllerProvider(_pushRoutine)).requireValue;

/// Lets Drift's stream notifications run on the real event loop, then settles.
Future<void> _settleDb(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(_dbTick));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _list(Type screen) =>
    find.descendant(of: find.byType(screen), matching: find.byType(Scrollable)).first;

/// Jumps [screen]'s list to its top, then scrolls down until [finder] clears
/// the floating bars.
Future<void> _reveal(WidgetTester tester, Type screen, Finder finder) async {
  tester.state<ScrollableState>(_list(screen)).position.jumpTo(0);
  await tester.pump();
  await tester.scrollUntilVisible(finder.hitTestable(), _scrollStep, scrollable: _list(screen));
  await tester.pumpAndSettle();
}

/// [_reveal]s [finder] on [screen] and taps it.
Future<void> _tapIn(WidgetTester tester, Type screen, Finder finder) async {
  await _reveal(tester, screen, finder);
  await tester.tap(finder.hitTestable());
  await tester.pumpAndSettle();
}

Future<void> _toTop(WidgetTester tester, Type screen) async {
  tester.state<ScrollableState>(_list(screen)).position.jumpTo(0);
  await tester.pumpAndSettle();
}

/// Opens the editor's Add exercise sheet and searches it for [query].
Future<void> _search(WidgetTester tester, String query) async {
  await _tapIn(tester, RoutineEditorScreen, find.text('Add exercise'));
  await tester.enterText(
      find.descendant(of: find.byType(SearchPill), matching: find.byType(TextField)), query);
  await tester.pumpAndSettle();
}

Finder _onTab(Finder matching) => find.descendant(of: find.byType(MoveScreen), matching: matching);

Finder _switch(String label) =>
    find.byWidgetPredicate((w) => w is AppSwitch && w.semanticLabel == label);

String _clock(int seconds) =>
    '${seconds ~/ Duration.secondsPerMinute}:'
    '${(seconds % Duration.secondsPerMinute).toString().padLeft(2, '0')}';

/// Records layout overflows, which the boot harness otherwise swallows.
List<String> _recordOverflows() {
  final overflows = <String>[];
  final inner = FlutterError.onError;
  FlutterError.onError = (details) {
    final message = details.exception.toString();
    if (message.contains('overflowed')) overflows.add(message);
    inner?.call(details);
  };
  return overflows;
}

void main() {
  scenarioTest('workout', (tester, dark) async {
    final noteGate = Completer<String>();
    final saveGate = Completer<void>();
    await _boot(tester, dark,
        freshDay: true,
        summaryNote: () => noteGate.future,
        save: () => _GatedSave(saveGate));

    // workout_tab
    expect(find.text(_legsPick.rationale), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Pick another'), findsOneWidget);
    await _shot(tester, 'workout_tab', dark);

    // workout_tab_collapsed
    await tester.drag(_list(MoveScreen), const Offset(0, -_collapseDrag));
    await tester.pumpAndSettle();
    final compact = _onTab(find.text('Workout'));
    expect(compact, findsOneWidget);
    expect(
        tester.getRect(compact).overlaps(tester.getRect(find.bySemanticsLabel('Start a workout'))),
        isFalse);
    await _shot(tester, 'workout_tab_collapsed', dark);
    await _toTop(tester, MoveScreen);

    // workout_tab_pick_another
    await _tap(tester, find.bySemanticsLabel('Pick another'));
    expect(find.text(_pushPick.rationale), findsOneWidget);
    expect(find.text(_pushPick.title), findsOneWidget);
    expect(find.text(_legsPick.rationale), findsNothing);
    await _shot(tester, 'workout_tab_pick_another', dark);

    // workout_tab_in_progress
    await _tap(tester, find.text('Start'));
    expect(find.byType(ActiveSessionScreen), findsOneWidget);
    await _tap(tester, find.text('Complete set'));
    await _tap(tester, find.text('Skip rest'));
    await _tap(tester, find.bySemanticsLabel(_minimise));
    expect(find.byType(ActiveSessionScreen), findsNothing);
    expect(find.text('In progress'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);
    expect(find.text('Start'), findsNothing);
    await _shot(tester, 'workout_tab_in_progress', dark);

    // session_resumed
    await _tap(tester, find.text('Resume'));
    expect(find.byType(ActiveSessionScreen), findsOneWidget);
    final resumed = _session(tester);
    expect(resumed.sets.first.done, isTrue);
    expect(resumed.sets.where((s) => s.done), hasLength(1));
    expect(find.text('1 of ${resumed.sets.length} sets'), findsOneWidget);
    // the done set's disc carries the check.
    expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Done'),
        findsOneWidget);
    await _shot(tester, 'session_resumed', dark);

    // session_finish_sheet
    await _tap(tester, find.bySemanticsLabel('Finish'));
    expect(find.text('Finish workout?'), findsOneWidget);
    expect(find.descendant(of: find.byType(BottomSheet), matching: find.text('Finish')),
        findsOneWidget);
    expect(find.text('Keep going'), findsOneWidget);
    await _shot(tester, 'session_finish_sheet', dark);
    await _tap(tester, find.text('Keep going'));
    expect(find.text('Finish workout?'), findsNothing);

    // session_entering
    for (var i = 0; i < _maxTaps && find.textContaining(_ahead).evaluate().isEmpty; i++) {
      await _tap(tester, find.bySemanticsLabel('More weight'));
    }
    expect(find.textContaining(_ahead), findsOneWidget);
    await _shot(tester, 'session_entering', dark);

    // session_resting
    await _tap(tester, find.text('Complete set'));
    expect(find.text('Rest'), findsOneWidget);
    expect(find.text('+30 s'), findsOneWidget);
    expect(find.text('Skip rest'), findsOneWidget);
    expect(find.text('Complete set'), findsNothing);
    await _shot(tester, 'session_resting', dark);

    // session_rest_added: a bare pump, so the rest clock cannot tick between reads.
    final before = _session(tester).restRemaining;
    await tester.tap(find.bySemanticsLabel('Add 30 seconds rest'));
    await tester.pump();
    final after = _session(tester).restRemaining;
    expect(after, before + _restAdded);
    expect(find.text(_clock(after)), findsOneWidget);
    await _shot(tester, 'session_rest_added', dark);

    // session_rest_skipped
    await _tap(tester, find.text('Skip rest'));
    expect(find.text('Complete set'), findsOneWidget);
    expect(find.text('Skip rest'), findsNothing);
    await _shot(tester, 'session_rest_skipped', dark);

    // session_skip_exercise
    final next = _session(tester).nextExercise!.name;
    await _tap(tester, find.text('Skip exercise'));
    expect(_session(tester).currentExercise?.name, next);
    expect(find.text(next), findsOneWidget);
    await _shot(tester, 'session_skip_exercise', dark);

    // session_all_logged
    for (var i = 0; i < _maxTaps && find.text('All sets logged').evaluate().isEmpty; i++) {
      final skip = find.text('Skip rest');
      await _tap(tester, skip.evaluate().isEmpty ? find.text('Complete set') : skip);
    }
    expect(find.text('All sets logged'), findsOneWidget);
    expect(find.text('See your summary'), findsOneWidget);
    await _shot(tester, 'session_all_logged', dark);

    // post_workout_reading
    await _tap(tester, find.text('See your summary'));
    expect(find.byType(PostWorkoutScreen), findsOneWidget);
    expect(find.text(_reading), findsOneWidget);
    await _shot(tester, 'post_workout_reading', dark);

    // post_workout
    noteGate.complete(_note);
    await tester.pumpAndSettle();
    expect(find.text(_note), findsOneWidget);
    expect(find.text('kg lifted'), findsOneWidget);
    expect(find.textContaining('New best · $_bench'), findsOneWidget);
    await _shot(tester, 'post_workout', dark);

    // post_workout_saving
    await _reveal(tester, PostWorkoutScreen, find.text('Save to timeline'));
    await tester.tap(find.text('Save to timeline'));
    await tester.pump();
    expect(find.text('Saving…'), findsOneWidget);
    await _shot(tester, 'post_workout_saving', dark);

    // workout_tab_settled
    saveGate.complete();
    await _settleDb(tester);
    expect(find.byType(PostWorkoutScreen), findsNothing);
    expect(find.byType(MoveScreen), findsOneWidget);
    await _toTop(tester, MoveScreen);
    expect(find.textContaining('Push Day A is done.'), findsOneWidget);
    expect(find.text('Start'), findsNothing);
    final strip = tester.widget<DayStrip>(_onTab(find.byType(DayStrip)));
    expect(strip.days.firstWhere((d) => d.today).done, isTrue);
    expect(find.bySemanticsLabel(RegExp(r'^Push Day A, Today, ')), findsOneWidget);
    await _shot(tester, 'workout_tab_settled', dark);
  });

  scenarioTest('workout_tab_thinking', (tester, dark) async {
    final never = Completer<WorkoutSuggestion>();
    await _boot(tester, dark, freshDay: true, pick: () => never.future);

    // workout_tab_thinking
    expect(_onTab(find.text('Thinking…')), findsOneWidget);
    expect(find.text('Start'), findsNothing);
    expect(find.text('Pick another'), findsNothing);
    await _shot(tester, 'workout_tab_thinking', dark);

    // start_workout_thinking
    await _tap(tester, find.bySemanticsLabel('Start a workout'));
    expect(find.descendant(of: find.byType(StartWorkoutScreen), matching: find.text('Thinking…')),
        findsOneWidget);
    expect(find.text('Start'), findsNothing);
    await _shot(tester, 'start_workout_thinking', dark);
  });

  scenarioTest('workout_tab_error', (tester, dark) async {
    await _boot(tester, dark,
        freshDay: true, pick: () => Future<WorkoutSuggestion>.error(StateError('scenario')));

    // workout_tab_error
    expect(find.text("Pal couldn't pick one just now."), findsOneWidget);
    expect(find.bySemanticsLabel('Try again'), findsOneWidget);
    expect(find.text('Start workout'), findsOneWidget);
    await _shot(tester, 'workout_tab_error', dark);

    // start_workout_pick_error
    await _tap(tester, find.bySemanticsLabel('Start a workout'));
    final onPicker = find.byType(StartWorkoutScreen);
    expect(find.descendant(of: onPicker, matching: find.text("Pal couldn't pick one just now.")),
        findsOneWidget);
    expect(find.descendant(of: onPicker, matching: find.text('Pick a routine below')),
        findsOneWidget);
    expect(find.descendant(of: onPicker, matching: find.text('Try again')), findsOneWidget);
    await _shot(tester, 'start_workout_pick_error', dark);
  });

  scenarioTest('workout_tab_no_plan', (tester, dark) async {
    await _boot(tester, dark, overrides: [
      weeklyPlanControllerProvider.overrideWith((ref) => Stream.value(const WeeklyPlan(days: []))),
    ]);
    expect(find.text('No weekly plan yet'), findsOneWidget);
    await _shot(tester, 'workout_tab_no_plan', dark);
  });

  scenarioTest('workout_tab_loading', (tester, dark) async {
    await _boot(tester, dark, overrides: [
      moveStateProvider.overrideWith((ref) => StreamController<MoveState>().stream),
    ]);
    expect(_onTab(find.text('…')), findsOneWidget);
    expect(find.text('This week'), findsNothing);
    await _shot(tester, 'workout_tab_loading', dark);
  });

  scenarioTest('workout_tab_load_error', (tester, dark) async {
    await _boot(tester, dark, overrides: [
      moveStateProvider.overrideWith((ref) => Stream<MoveState>.error(StateError('scenario'))),
    ]);
    expect(find.textContaining("Couldn't load Workout."), findsOneWidget);
    expect(find.text('This week'), findsNothing);
    await _shot(tester, 'workout_tab_load_error', dark);
  });

  scenarioTest('post_workout_no_session', (tester, dark) async {
    await _boot(tester, dark);
    appRouter(tester).pushNamed(AppRoute.postWorkout.name);
    await tester.pumpAndSettle();
    expect(find.text('No active session'), findsOneWidget);
    expect(find.text('Back to Workout'), findsOneWidget);
    await _shot(tester, 'post_workout_no_session', dark);
  });

  scenarioTest('post_workout_note_error', (tester, dark) async {
    await _boot(tester, dark, summaryNote: _failedNote);
    final workout = await _workouts(tester).getById(_seededToday);
    appRouter(tester).pushNamed(AppRoute.postWorkout.name, extra: workout);
    await tester.pumpAndSettle();
    expect(find.byType(PostWorkoutScreen), findsOneWidget);
    expect(find.text(_noteError), findsOneWidget);
    expect(find.text('kg lifted'), findsOneWidget);
    await _shot(tester, 'post_workout_note_error', dark);
  });

  scenarioTest('streak', (tester, dark) async {
    await _boot(tester, dark);

    // streak
    appRouter(tester).pushNamed(AppRoute.streakCelebration.name);
    await tester.pumpAndSettle();
    expect(find.text('Workout streak'), findsOneWidget);
    expect(find.text('Keep going'), findsOneWidget);
    await _shot(tester, 'streak', dark);

    // streak_keep_going
    await _tap(tester, find.text('Keep going'));
    expect(find.byType(StreakCelebrationScreen), findsNothing);
    expect(find.byType(MoveScreen), findsOneWidget);
    await _shot(tester, 'streak_keep_going', dark);
  });

  scenarioTest('start_workout', (tester, dark) async {
    final pal = _ScenarioPal();
    await _boot(tester, dark, pal: pal);
    final overflows = _recordOverflows();

    // start_workout: every row laid out at 390 wide, top to bottom.
    await _tap(tester, find.bySemanticsLabel('Start a workout'));
    expect(find.byType(StartWorkoutScreen), findsOneWidget);
    await _reveal(tester, StartWorkoutScreen,
        find.descendant(of: find.byType(StartWorkoutScreen), matching: find.text('Exercise library')));
    expect(overflows, isEmpty);
    expect(find.text('Freestyle session'), findsNothing);
    await _toTop(tester, StartWorkoutScreen);
    expect(find.text('Strength'), findsOneWidget);
    expect(find.text('Freestyle session'), findsNothing);
    await _shot(tester, 'start_workout', dark);

    // start_workout_delete_confirm
    final legs = find.descendant(of: find.byType(ExerciseRow), matching: find.text('Leg Day'));
    await _reveal(tester, StartWorkoutScreen, legs);
    await tester.longPress(legs.hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('Delete routine?'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    await _shot(tester, 'start_workout_delete_confirm', dark);
    await _tap(tester, find.text('Cancel'));
    expect(find.text('Delete routine?'), findsNothing);
    expect(legs, findsOneWidget);

    // generate
    await _tapIn(tester, StartWorkoutScreen,
        find.descendant(of: find.byType(StartWorkoutScreen), matching: find.text('Generate with Pal')));
    expect(find.byType(RoutineGeneratorScreen), findsOneWidget);
    expect(find.text('Generate'), findsOneWidget);
    expect(find.byType(AppChip), findsWidgets);
    await _shot(tester, 'generate', dark);

    // generate_loading
    final hold = pal.hold = Completer<void>();
    await _tap(tester, find.byType(AppChip).first);
    expect(find.text('Generating…'), findsOneWidget);
    await _shot(tester, 'generate_loading', dark);

    // generate_result
    pal.hold = null;
    hold.complete();
    await tester.pumpAndSettle();
    final result = _container(tester).read(routineGeneratorControllerProvider);
    expect(result, isA<RoutineGeneratorResult>());
    expect(find.text((result as RoutineGeneratorResult).draft.name), findsOneWidget);
    expect(find.text('Save routine'), findsOneWidget);
    await _shot(tester, 'generate_result', dark);

    // generate_error
    await _tap(tester, find.text('Try again'));
    pal.failGenerate = true;
    await _tap(tester, find.byType(AppChip).first);
    expect(find.text("Couldn't generate this routine."), findsOneWidget);
    expect(find.bySemanticsLabel('Try again'), findsOneWidget);
    await _shot(tester, 'generate_error', dark);
    pal.failGenerate = false;
    await _tap(tester, find.text('Cancel'));
    expect(find.byType(RoutineGeneratorScreen), findsNothing);

    // routine_editor_add_exercise
    await _tapIn(tester, StartWorkoutScreen,
        find.descendant(of: find.byType(StartWorkoutScreen), matching: find.text('New routine')));
    expect(find.byType(RoutineEditorScreen), findsOneWidget);
    await tester.enterText(
        find.descendant(of: find.byType(RoutineEditorScreen), matching: find.byType(TextField)).first,
        _newRoutine);
    await tester.pumpAndSettle();
    await _search(tester, 'bench');
    expect(find.widgetWithText(ExerciseRow, _bench), findsOneWidget);
    await _shot(tester, 'routine_editor_add_exercise', dark);

    // routine_editor: two exercises, each its own slot.
    await _tap(tester, find.widgetWithText(ExerciseRow, _bench));
    expect(find.byType(SearchPill), findsNothing);
    await _search(tester, 'squat');
    await _tap(tester, find.widgetWithText(ExerciseRow, _squat));
    expect(find.text('Exercises · 2'), findsOneWidget);
    expect(find.bySemanticsLabel('Edit targets for $_bench'), findsOneWidget);
    expect(find.bySemanticsLabel('Edit targets for $_squat'), findsOneWidget);
    await _shot(tester, 'routine_editor', dark);

    // routine_editor_targets_sheet
    await _tapIn(tester, RoutineEditorScreen, find.bySemanticsLabel('Edit targets for $_bench'));
    final setsLabel = tester.getSemantics(find.bySemanticsLabel(RegExp(r'^Sets, \d+$'))).label;
    final sets = int.parse(setsLabel.split(', ').last);
    await _tap(tester, find.bySemanticsLabel('Increase Sets'));
    expect(find.bySemanticsLabel('Sets, ${sets + 1}'), findsOneWidget);
    await _shot(tester, 'routine_editor_targets_sheet', dark);
    await _tap(tester, find.widgetWithText(PillButton, 'Done'));
    expect(find.text('Targets'), findsNothing);
    final slots = _container(tester)
        .read(routineEditorControllerProvider(null))
        .requireValue
        .draft
        .orderedExercises;
    expect(slots.map((e) => e.targetSets), [sets + 1, isNot(sets + 1)]);

    // routine_editor_toggles
    for (final label in ['Warmup reminder', 'Auto-progress weights']) {
      await _tapIn(tester, RoutineEditorScreen, _switch(label));
      expect(tester.widget<AppSwitch>(_switch(label)).value, isTrue, reason: label);
    }
    await _shot(tester, 'routine_editor_toggles', dark);

    // routine_editor_saved: the picker shows the new routine without reopening.
    await _tapIn(tester, RoutineEditorScreen, find.bySemanticsLabel('Save'));
    await _settleDb(tester);
    expect(find.byType(RoutineEditorScreen), findsNothing);
    expect(find.byType(StartWorkoutScreen), findsOneWidget);
    await _reveal(tester, StartWorkoutScreen,
        find.descendant(of: find.byType(ExerciseRow), matching: find.text(_newRoutine)));
    expect(find.descendant(of: find.byType(ExerciseRow), matching: find.text(_newRoutine)),
        findsOneWidget);
    await _shot(tester, 'routine_editor_saved', dark);
  });

  scenarioTest('weekly_plan', (tester, dark) async {
    await _boot(tester, dark);

    // weekly_plan
    await _tapIn(tester, MoveScreen, _onTab(find.text('Weekly plan')));
    await _settleDb(tester);
    expect(find.byType(WeeklyPlanScreen), findsOneWidget);
    expect(find.text('Your plan'), findsOneWidget);
    expect(find.text('Start workout'), findsOneWidget);
    await _shot(tester, 'weekly_plan', dark);

    // weekly_plan_assign_sheet
    await _tapIn(tester, WeeklyPlanScreen, find.text('Tue'));
    expect(find.text('Assign routine'), findsOneWidget);
    expect(find.text('Rest day'), findsOneWidget);
    await _shot(tester, 'weekly_plan_assign_sheet', dark);

    // weekly_plan_rest_day
    await _tap(tester, find.text('Rest day'));
    await _settleDb(tester);
    expect(find.text('Assign routine'), findsNothing);
    expect(find.bySemanticsLabel(RegExp(r'^Rest, Tue\b')), findsOneWidget);
    await _shot(tester, 'weekly_plan_rest_day', dark);

    // weekly_plan_start_today: the button reads the schedule before it opens.
    await _tapIn(tester, WeeklyPlanScreen, find.text('Start workout'));
    await _settleDb(tester);
    expect(find.byType(ActiveSessionScreen), findsOneWidget);
    expect(find.text('Push Day A'), findsOneWidget);
    await _shot(tester, 'weekly_plan_start_today', dark);
    await _tap(tester, find.bySemanticsLabel(_minimise));
    expect(find.byType(WeeklyPlanScreen), findsOneWidget);

    // weekly_plan_rest_today
    await _tapIn(tester, WeeklyPlanScreen, find.text('Mon'));
    await _tap(tester, find.text('Rest day'));
    await _settleDb(tester);
    await _toTop(tester, WeeklyPlanScreen);
    expect(find.text('Rest day'), findsOneWidget);
    expect(find.text('Start workout'), findsNothing);
    await _shot(tester, 'weekly_plan_rest_today', dark);
  });

  scenarioTest('history', (tester, dark) async {
    await _boot(tester, dark);
    await _tapIn(tester, MoveScreen, _onTab(find.text('History and trends')));
    expect(find.byType(WorkoutHistoryScreen), findsOneWidget);
    expect(find.text('History and trends'), findsOneWidget);
    expect(find.text('Sessions'), findsOneWidget);
    expect(find.text('No sessions in this range.'), findsNothing);
    await _shot(tester, 'history', dark);
  });

  scenarioTest('history_empty_range', (tester, dark) async {
    await _boot(tester, dark);
    final workouts = _workouts(tester);
    await workouts.deleteById(_seededToday);
    await workouts.deleteById(_seededYesterday);
    final startedAt = clock.now().subtract(_oldSession);
    await workouts.insert(Workout(
      id: '',
      name: 'Leg Day',
      startedAt: startedAt,
      endedAt: startedAt.add(const Duration(hours: 1)),
      sets: const [SetLog(id: '', exerciseId: 'squat', weightKg: 100, reps: 5, done: true)],
    ));
    await _settleDb(tester);

    await _tapIn(tester, MoveScreen, _onTab(find.text('History and trends')));
    expect(find.byType(WorkoutHistoryScreen), findsOneWidget);
    expect(find.text('No sessions in this range.'), findsOneWidget);
    await _shot(tester, 'history_empty_range', dark);
  });

  scenarioTest('workout_detail', (tester, dark) async {
    var note = _fixedNote;
    // read at each open, so a step can change what the note does.
    await _boot(tester, dark, detailNote: () => note());
    final row = find.bySemanticsLabel(RegExp(r'^Push Day A, Today, '));

    // workout_detail
    await _tapIn(tester, MoveScreen, row);
    expect(find.byType(WorkoutDetailScreen), findsOneWidget);
    expect(find.text('1,933'), findsOneWidget);
    expect(find.text('kg lifted'), findsOneWidget);
    expect(find.text('New best · $_bench, 92.5 kg'), findsOneWidget);
    await _reveal(tester, WorkoutDetailScreen, find.text(_note));
    expect(find.text(_note), findsOneWidget);
    await _toTop(tester, WorkoutDetailScreen);
    await _shot(tester, 'workout_detail', dark);

    // workout_detail_more_sheet
    await _tap(tester, find.bySemanticsLabel('More options'));
    expect(find.text('Delete workout'), findsOneWidget);
    await _shot(tester, 'workout_detail_more_sheet', dark);

    // workout_detail_delete_confirm
    await _tap(tester, find.text('Delete workout'));
    expect(find.text('Delete workout?'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    await _shot(tester, 'workout_detail_delete_confirm', dark);
    await _tap(tester, find.text('Cancel'));
    expect(find.text('Delete workout?'), findsNothing);
    expect(find.byType(WorkoutDetailScreen), findsOneWidget);

    // workout_detail_note_loading
    final never = Completer<String>();
    note = () => never.future;
    await _tap(tester, find.bySemanticsLabel('Back'));
    await _tapIn(tester, MoveScreen, row);
    await _reveal(tester, WorkoutDetailScreen, find.text(_reading));
    expect(find.text(_reading), findsOneWidget);
    await _shot(tester, 'workout_detail_note_loading', dark);

    // workout_detail_note_error
    note = _failedNote;
    await _tap(tester, find.bySemanticsLabel('Back'));
    await _tapIn(tester, MoveScreen, row);
    await _reveal(tester, WorkoutDetailScreen, find.text(_noteError));
    expect(find.text(_noteError), findsOneWidget);
    await _shot(tester, 'workout_detail_note_error', dark);
  });

  scenarioTest('exercise_library', (tester, dark) async {
    await _boot(tester, dark);
    final sections = find.byType(InsetSection);

    // exercise_library
    await _tapIn(tester, MoveScreen, _onTab(find.text('Exercise library')));
    expect(find.byType(ExerciseLibraryScreen), findsOneWidget);
    expect(find.text('Exercises'), findsOneWidget);
    expect(sections, findsAtLeastNWidgets(2));
    await _shot(tester, 'exercise_library', dark);

    // exercise_library_filtered
    await _tap(tester, find.widgetWithText(AppChip, 'Cardio'));
    expect(sections, findsOneWidget);
    expect(find.descendant(of: sections, matching: find.text('Cardio')), findsOneWidget);
    await _shot(tester, 'exercise_library_filtered', dark);

    // exercise_library_empty
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No exercises match "zzz".'), findsOneWidget);
    await _shot(tester, 'exercise_library_empty', dark);
  });
}
