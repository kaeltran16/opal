import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:opal/controllers/pal_suggestions_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/models/models.dart';
import 'package:opal/screens/workout/routine_generator_screen.dart';
import 'package:opal/services/pal/pal_service.dart';
import 'package:opal/theme/app_colors.dart';

void main() {
  testWidgets('Routine Generator renders Pal goal labels when present', (tester) async {
    // Tall viewport so the quick-picks grid builds within the scroll view.
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        // The controller's build watches exercisesProvider (a live DB stream).
        // Override it with a static stream so no drift timer outlives the test.
        exercisesProvider.overrideWith((ref) => Stream<List<Exercise>>.value(const [])),
        palSuggestionsProvider(SuggestionSurface.routineGoal).overrideWith(
          (ref) async => const [
            PalSuggestion(label: 'Mobility + core, 20 min', icon: 'figure.cooldown', colorToken: 'accent'),
          ],
        ),
      ],
      child: MaterialApp(
        theme: ThemeData.light().copyWith(extensions: [AppColors.light(AppAccent.blue)]),
        home: const RoutineGeneratorScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Mobility + core, 20 min'), findsOneWidget);
  });
}
