import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/controllers/pal_suggestions_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/controllers/weekly_plan_controller.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/models/models.dart' hide Provider;
import 'package:opal/screens/pal/pal_composer_screen.dart';
import 'package:opal/services/services.dart';
import 'package:opal/theme/theme.dart';

import '../../support/flush_provider_timers.dart';

const _host = 'host';
const _startWorkout = 'start workout';
const _staticStarters = ['Verve coffee, \$5', 'Finished morning pages', 'How’s my week so far?'];

/// Pal with a scripted pick and chat. A null [pick] fails, as when Pal is
/// unreachable.
class _Pal implements PalService {
  _Pal({this.pick, this.fails = false, this.actions = const []});

  final Future<WorkoutSuggestion> Function()? pick;
  final bool fails;
  final List<PalAction> actions;

  @override
  Future<WorkoutSuggestion> suggestWorkout({bool another = false, String? excludeRoutineId}) =>
      pick?.call() ?? Future.error(const PalException('unreachable'));

  @override
  Future<PalChatResult> chat(List<PalMessage> history, String message) async {
    if (fails) throw const PalException('unreachable');
    return PalChatResult(reply: 'Done.', actions: actions);
  }

  @override
  Future<PalAgenda> agenda() async => const PalAgenda();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Opens the composer over a host page, with a Start workout route to land on.
Future<GoRouter> _open(
  WidgetTester tester, {
  String? from,
  String? seed,
  _Pal? pal,
  List<PalSuggestion> suggestions = const [],
  double textScale = 1,
  bool trainedToday = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final db = LoopDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  final router = GoRouter(initialLocation: '/$_host', routes: [
    GoRoute(path: '/$_host', builder: (_, _) => const Scaffold(body: Text(_host))),
    GoRoute(
      path: '/pal',
      builder: (_, _) => Scaffold(body: PalComposerSheet(seed: seed, from: from)),
    ),
    GoRoute(path: '/move/start', builder: (_, _) => const Scaffold(body: Text(_startWorkout))),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      loopDatabaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs),
      palServiceProvider.overrideWithValue(pal ?? _Pal()),
      palSuggestionsProvider(SuggestionSurface.composer).overrideWith((ref) async => suggestions),
      weeklyPlanControllerProvider.overrideWith((ref) => Stream.value(WeeklyPlan(days: [
            WeekPlanDay(day: 'Thu', date: 15, type: 'Legs', routine: 'Leg Day', colorKey: 'move',
                icon: 'dumbbell.fill', trained: trainedToday, today: true),
          ]))),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      theme: ThemeData(useMaterial3: true, extensions: [AppColors.light()]),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
    ),
  ));
  await tester.pumpAndSettle();
  router.push('/pal');
  await tester.pumpAndSettle();
  return router;
}

Finder _inSheet(Finder f) => find.descendant(of: find.byType(PalComposerSheet), matching: f);

AppColors _colors(WidgetTester tester) => tester.element(find.byType(PalComposerSheet)).colors;

void main() {
  for (final (from, label) in [
    ('/move', 'Workout'),
    ('/areas/money', 'Money'),
    ('/areas/nutrition/meal/7', 'Nutrition'),
    ('/today', 'Today'),
    ('/areas', 'Areas'),
    ('/you', 'You'),
  ]) {
    testWidgets('opened from $from the chip reads $label', (tester) async {
      await _open(tester, from: from);

      expect(_inSheet(find.text(label)), findsOneWidget);
      // only the header names Pal.
      expect(_inSheet(find.text('Pal')), findsOneWidget);

      await flushProviderTimers(tester);
    });
  }

  for (final from in [null, '/nowhere', '']) {
    testWidgets('opened from ${from ?? 'nothing'} the chip falls back to Pal', (tester) async {
      await _open(tester, from: from);

      expect(tester.takeException(), isNull);
      // the header and the chip.
      expect(_inSheet(find.text('Pal')), findsNWidgets(2));

      await flushProviderTimers(tester);
    });
  }

  testWidgets("the first pill starts Pal's pick", (tester) async {
    await _open(tester,
        pal: _Pal(pick: () async => const WorkoutSuggestion(title: 'Push Day A', rationale: 'Fresh')));

    expect(_inSheet(find.text('You could ask')), findsOneWidget);
    expect(_inSheet(find.text('Start Push Day A')), findsOneWidget);

    await tester.tap(find.text('Start Push Day A'));
    await tester.pumpAndSettle();

    expect(find.byType(PalComposerSheet), findsNothing);
    expect(find.text(_startWorkout), findsOneWidget);

    await flushProviderTimers(tester);
  });

  testWidgets('once a workout is done today the first pill offers no second session',
      (tester) async {
    await _open(tester,
        trainedToday: true,
        pal: _Pal(pick: () async => const WorkoutSuggestion(title: 'Push Day A', rationale: 'Fresh')));

    expect(_inSheet(find.text('Start Push Day A')), findsNothing);
    expect(_inSheet(find.text('Start a workout')), findsOneWidget);

    await flushProviderTimers(tester);
  });

  for (final (name, pick) in [
    ('loads', () => Completer<WorkoutSuggestion>().future),
    ('fails', () => Future<WorkoutSuggestion>.error(const PalException('unreachable'))),
  ]) {
    testWidgets('while the pick $name the first pill still starts a workout', (tester) async {
      await _open(tester, pal: _Pal(pick: pick));

      expect(_inSheet(find.text('Start a workout')), findsOneWidget);

      await tester.tap(find.text('Start a workout'));
      await tester.pumpAndSettle();

      expect(find.text(_startWorkout), findsOneWidget);

      await flushProviderTimers(tester);
    });
  }

  testWidgets('with no suggestions the static starters show as pills', (tester) async {
    await _open(tester);

    for (final label in _staticStarters) {
      expect(_inSheet(find.text(label)), findsOneWidget, reason: label);
    }
    expect(find.byKey(const Key('starter-skeleton')), findsNothing);

    await flushProviderTimers(tester);
  });

  testWidgets('a seeded sheet opens on the seed as a headline, with no avatar', (tester) async {
    await _open(tester, seed: 'Why Rent first?');

    final seed = tester.widget<Text>(_inSheet(find.text('Why Rent first?')));
    expect(seed.style?.fontSize, AppType.headline.fontSize);
    expect(seed.style?.fontWeight, AppType.headline.fontWeight);

    await flushProviderTimers(tester);
  });

  testWidgets('Send and Close carry their labels', (tester) async {
    await _open(tester);

    expect(_inSheet(find.bySemanticsLabel('Send')), findsOneWidget);
    expect(_inSheet(find.bySemanticsLabel('Close')), findsOneWidget);

    await flushProviderTimers(tester);
  });

  testWidgets('Close pops the sheet', (tester) async {
    await _open(tester);

    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pumpAndSettle();

    expect(find.byType(PalComposerSheet), findsNothing);
    expect(find.text(_host), findsOneWidget);

    await flushProviderTimers(tester);
  });

  testWidgets('at 1.5x text the idle sheet lays out without overflow', (tester) async {
    await _open(tester,
        textScale: 1.5,
        pal: _Pal(pick: () async => const WorkoutSuggestion(
            title: 'Upper body strength with a long name', rationale: 'Fresh')));

    expect(tester.takeException(), isNull);
    expect(_inSheet(find.text('Start Upper body strength with a long name')), findsOneWidget);

    await flushProviderTimers(tester);
  });

  testWidgets('the sheet is solid surface, with no blur', (tester) async {
    await _open(tester);

    final box = tester.widget<DecoratedBox>(find.byKey(palComposerSheetKey));
    expect((box.decoration as BoxDecoration).color, _colors(tester).surface);
    expect(_inSheet(find.byType(BackdropFilter)), findsNothing);

    await flushProviderTimers(tester);
  });

  testWidgets("a log turn's Edit refills the input with its text, focused", (tester) async {
    await _open(tester,
        seed: 'coffee 5',
        pal: _Pal(actions: const [
          LogEntryAction(type: EntryType.money, title: 'Coffee', amount: -5, category: 'Coffee'),
        ]));
    expect(_inSheet(find.text('Based on')), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Edit'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'coffee 5');
    expect(field.focusNode!.hasFocus, isTrue);

    await flushProviderTimers(tester);
  });

  testWidgets("an offline reply reads in ink3", (tester) async {
    await _open(tester, seed: 'how am I doing?', pal: _Pal(fails: true));

    final reply = tester.widget<Text>(_inSheet(find.textContaining("couldn't reach")));
    expect(reply.style?.color, _colors(tester).ink3);

    await flushProviderTimers(tester);
  });
}
