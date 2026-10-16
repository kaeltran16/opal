import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/models/models.dart' hide Provider;
import 'package:opal/screens/pal/pal_composer_screen.dart';
import 'package:opal/services/services.dart';
import 'package:opal/theme/app_colors.dart';

class _MealPal implements PalService {
  @override
  Future<PalChatResult> chat(List<PalMessage> history, String message) async =>
      const PalChatResult(reply: 'In the bank.', actions: [
        LogMealAction(
          name: 'Chicken Burrito', cal: IntRange(520, 820),
          confidence: NutritionConfidence.med, slot: 'Lunch'),
      ]);
  @override
  Future<PalAgenda> agenda({List<PlanFact> plan = const []}) async => const PalAgenda();
  @override
  Future<WorkoutSuggestion> suggestWorkout({bool another = false, String? excludeRoutineId}) =>
      Future.error(const PalException('unreachable'));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('a chat-logged meal shows its kcal range, Undo and Edit; Undo reads Undone',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        loopDatabaseProvider.overrideWithValue(db),
        palServiceProvider.overrideWithValue(_MealPal()),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [AppColors.light()]),
        home: const Scaffold(body: PalComposerSheet(seed: 'had a burrito for lunch')),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Chicken Burrito · 520–820 kcal, fair estimate'), findsOneWidget);
    expect(find.bySemanticsLabel('Undo'), findsOneWidget);
    expect(find.bySemanticsLabel('Edit'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Undo'));
    await tester.pumpAndSettle();

    expect(find.text('Undone'), findsOneWidget);
    expect(find.text('Chicken Burrito · 520–820 kcal, fair estimate'), findsNothing);
    expect(find.bySemanticsLabel('Undo'), findsNothing);
  });
}
