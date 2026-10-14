import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/controllers/providers.dart';
import 'package:opal/controllers/today_controller.dart';
import 'package:opal/models/models.dart' hide Provider;
import 'package:opal/screens/pal/pal_composer_turns.dart';
import 'package:opal/services/services.dart';
import 'package:opal/theme/theme.dart';

const _ritualsToday = 'Rituals today';
final _now = DateTime(2026, 10, 14, 9);

/// A ritual step logged today, with [ritualId] as its step.
Entry _step(String ritualId) => Entry(
      id: ritualId,
      timestamp: _now,
      type: EntryType.rituals,
      title: ritualId,
      ritualId: ritualId,
      source: EntrySource.manual,
    );

RitualRoutine _routine(String id) => RitualRoutine(
      id: id,
      name: id,
      time: '7:00 AM',
      tone: RitualTone.morning,
      icon: 'x',
      blurb: '',
      steps: [RitualStep(id: '$id-step', title: id, note: '', icon: 'x')],
    );

/// Pumps the turn Pal writes after logging Morning pages, over [today].
Future<void> _pumpLoggedRitual(WidgetTester tester, TodayState today) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      todayStateProvider.overrideWith((_) => Stream.value(today)),
    ],
    child: MaterialApp(
      theme: ThemeData(extensions: [AppColors.light()]),
      home: Scaffold(
        body: ComposerTurn(
          message: PalMessage(
            role: PalRole.assistant,
            text: 'Logged.',
            timestamp: _now,
            actions: const [LogEntryAction(type: EntryType.rituals, title: 'Morning pages')],
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the Rituals today turn with no routines reads the no-routines line',
      (tester) async {
    // the logged step counts as a legacy step, against a stored target of 5.
    await _pumpLoggedRitual(
      tester,
      TodayState(entries: [_step('legacy')], goals: const Goals(dailyRitualTarget: 5)),
    );

    expect(find.text(_ritualsToday), findsOneWidget);
    expect(find.text(kNoRoutinesLine), findsOneWidget);
    expect(find.textContaining(' of '), findsNothing);
  });

  testWidgets('the Rituals today turn with only stepless routines reads the no-steps line',
      (tester) async {
    await _pumpLoggedRitual(
      tester,
      TodayState(
        entries: [_step('legacy')],
        goals: const Goals(dailyRitualTarget: 5),
        routines: [_routine('a').copyWith(steps: const [])],
      ),
    );

    expect(find.text(_ritualsToday), findsOneWidget);
    expect(find.text(kNoStepsLine), findsOneWidget);
    expect(find.text(kNoRoutinesLine), findsNothing);
    expect(find.textContaining(' of '), findsNothing);
  });

  testWidgets('the Rituals today turn counts the tracked routines', (tester) async {
    await _pumpLoggedRitual(
      tester,
      TodayState(
        entries: [_step('a-step')],
        goals: const Goals(dailyRitualTarget: 5),
        routines: [_routine('a'), _routine('b')],
      ),
    );

    expect(find.text(_ritualsToday), findsOneWidget);
    expect(find.text('1 of 2'), findsOneWidget);
    expect(find.text(kNoRoutinesLine), findsNothing);
  });
}
