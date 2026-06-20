import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/controllers/pal_memory_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/models/models.dart';
import 'package:opal/screens/pal/pal_home_screen.dart';
import 'package:opal/services/pal/mock_pal_service.dart';
import 'package:opal/services/pal/pal_service.dart';
import 'package:opal/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Pal Home renders a remembered fact and a learned pattern', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final colors = AppColors.light(AppAccent.indigo);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          // the hero's streak reads this stream; an empty list keeps the test
          // hermetic (no DB) and focused on the memory section.
          allEntriesStreamProvider.overrideWith((ref) => Stream.value(const <Entry>[])),
          palServiceProvider.overrideWithValue(MockPalService(latency: Duration.zero)),
          palMemoryProvider.overrideWith((ref) async => const PalMemoryDigest(
                facts: [PalFact(id: 'f-1', text: 'marathon in October')],
                patterns: [InsightPattern(colorToken: 'move', title: 'Mornings', detail: 'before noon')],
              )),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(useMaterial3: true, extensions: [colors]),
          home: const PalHomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // the memory section sits low in the lazy ListView; scroll it into view.
    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('marathon in October'), 300, scrollable: scrollable);
    await tester.pumpAndSettle();

    expect(find.text('marathon in October'), findsOneWidget);
    expect(find.text('Mornings'), findsOneWidget);
  });
}
