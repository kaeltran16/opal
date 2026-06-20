import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opal/controllers/pal_suggestions_controller.dart';
import 'package:opal/screens/pal/pal_composer_screen.dart';
import 'package:opal/services/pal/pal_service.dart';
import 'package:opal/theme/theme.dart';

void main() {
  testWidgets('composer renders Pal-provided starter labels when present', (tester) async {
    final colors = AppColors.light(AppAccent.blue);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        palSuggestionsProvider(SuggestionSurface.composer).overrideWith(
          (ref) async => const [
            PalSuggestion(label: 'Pal-made coffee, \$4', icon: 'cup.and.saucer.fill', colorToken: 'money'),
          ],
        ),
      ],
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [colors]),
        home: const Scaffold(body: PalComposerSheet()),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Pal-made coffee, \$4'), findsOneWidget);
  });
}
