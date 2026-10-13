import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:opal/controllers/pal_suggestions_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/controllers/routine_generator_controller.dart';
import 'package:opal/models/models.dart';
import 'package:opal/screens/workout/routine_generator_screen.dart';
import 'package:opal/services/pal/mock_pal_service.dart';
import 'package:opal/services/pal/pal_service.dart';
import 'package:opal/theme/app_colors.dart';
import 'package:opal/widgets/controls.dart';

const _bench = Exercise(
  id: 'bench',
  name: 'Bench press',
  group: 'Push',
  muscle: 'Chest',
  icon: 'dumbbell',
);

/// The controller held in one state, recording the goals it is asked for.
class _FixedGenerator extends RoutineGeneratorController {
  _FixedGenerator(this.initial);
  final RoutineGeneratorState initial;
  final goals = <String>[];

  @override
  RoutineGeneratorState build() => initial;

  @override
  Future<void> generate(String goal) async => goals.add(goal);
}

Future<void> _pump(
  WidgetTester tester, {
  List<PalSuggestion> palGoals = const [],
  RoutineGeneratorController Function()? generator,
}) async {
  tester.view.physicalSize = const Size(390, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(ProviderScope(
    overrides: [
      // the controller's build watches exercisesProvider (a live DB stream);
      // a static stream leaves no drift timer behind.
      exercisesProvider.overrideWith((ref) => Stream<List<Exercise>>.value(const [])),
      palSuggestionsProvider(SuggestionSurface.routineGoal)
          .overrideWith((ref) async => palGoals),
      // non-trivial latency so the in-flight frame is observable.
      palServiceProvider.overrideWithValue(
          MockPalService(latency: const Duration(milliseconds: 50))),
      if (generator != null) routineGeneratorControllerProvider.overrideWith(generator),
    ],
    child: MaterialApp(
      theme: ThemeData.light().copyWith(extensions: [AppColors.light()]),
      home: const RoutineGeneratorScreen(),
    ),
  ));
  await tester.pumpAndSettle();
}

PillButton _pill(WidgetTester tester, String label) =>
    tester.widget<PillButton>(find.widgetWithText(PillButton, label));

void main() {
  testWidgets('the title reads Generate with Pal under Pal\'s lead', (tester) async {
    await _pump(tester);

    expect(find.text('Generate with Pal'), findsWidgets);
    expect(find.text('Generate with AI'), findsNothing);
    expect(find.text('Describe the workout you want.'), findsOneWidget);
    // nothing typed yet, so Generate is disabled.
    expect(_pill(tester, 'Generate').onTap, isNull);
  });

  testWidgets('renders Pal goal labels when present', (tester) async {
    await _pump(tester, palGoals: const [
      PalSuggestion(label: 'Mobility + core, 20 min', icon: 'figure.cooldown', colorToken: 'accent'),
    ]);

    expect(find.text('Mobility + core, 20 min'), findsOneWidget);
  });

  testWidgets('a quick goal fills the prompt and generates', (tester) async {
    final gen = _FixedGenerator(const RoutineGeneratorIdle());
    await _pump(tester, generator: () => gen);

    await tester.tap(find.text('Short HIIT cardio'));
    await tester.pump();

    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Short HIIT cardio');
    expect(gen.goals, ['Short HIIT cardio']);
  });

  testWidgets('while generating, Generate reads Generating… and is disabled',
      (tester) async {
    await _pump(tester);

    await tester.tap(find.text('45-min push for strength'));
    await tester.pump(); // the loading rebuild, no time elapsed yet

    expect(find.text('Generating…'), findsOneWidget);
    expect(_pill(tester, 'Generating…').onTap, isNull);

    // let the mock resolve so no timer outlives the test.
    await tester.pumpAndSettle();
    expect(find.text('Save routine'), findsOneWidget);
  });

  testWidgets('a failure reads Couldn\'t generate and Try again retries',
      (tester) async {
    final gen = _FixedGenerator(const RoutineGeneratorError('failed'));
    await _pump(tester, generator: () => gen);

    await tester.enterText(find.byType(TextField), 'Legs at home');
    await tester.pump();
    expect(find.textContaining(RegExp("^Couldn't generate")), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Try again'));
    await tester.pump();
    expect(gen.goals, ['Legs at home']);
  });

  testWidgets('the result lists the exercises as sets × reps with Save as the primary',
      (tester) async {
    final gen = _FixedGenerator(const RoutineGeneratorResult(
      draft: GeneratedRoutineDraft(
        name: 'Generated Push',
        tag: RoutineTag.upper,
        estimatedMinutes: 40,
        exercises: [
          GeneratedExerciseDraft(
            exerciseId: 'bench',
            sets: [
              GeneratedSetDraft(reps: 8, weightKg: 50),
              GeneratedSetDraft(reps: 8, weightKg: 50),
              GeneratedSetDraft(reps: 8, weightKg: 50),
            ],
          ),
        ],
      ),
      catalog: [_bench],
    ));
    await _pump(tester, generator: () => gen);

    expect(find.text('Generated Push'), findsOneWidget);
    expect(find.text('Upper · 1 exercise · ~40 min'), findsOneWidget);
    expect(find.text('Bench press'), findsOneWidget);
    expect(find.text('3 × 8'), findsOneWidget);
    expect(_pill(tester, 'Save routine').primary, isTrue);
    expect(_pill(tester, 'Try again').primary, isFalse);
  });
}
