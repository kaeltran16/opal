import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:opal/controllers/pal_suggestions_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/models/models.dart';
import 'package:opal/screens/entry/new_entry_sheet.dart';
import 'package:opal/services/pal/pal_service.dart';
import 'package:opal/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('New Entry renders Pal quick-pick titles when present', (tester) async {
    // Tall viewport so the whole sheet (a lazy ListView) builds its quick-picks.
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final router = GoRouter(
      initialLocation: '/host',
      routes: [
        GoRoute(
          path: '/host',
          builder: (context, state) => const Scaffold(body: SizedBox.shrink()),
          routes: [GoRoute(path: 'new', builder: (context, state) => const NewEntrySheet())],
        ),
      ],
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        loopDatabaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        palSuggestionsProvider(SuggestionSurface.newEntry).overrideWith(
          (ref) async => const [
            PalSuggestion(
              label: 'Oat latte',
              icon: 'cup.and.saucer.fill',
              colorToken: 'money',
              entry: StarterEntry(type: EntryType.money, title: 'Oat latte', amount: -6, category: 'Coffee'),
            ),
          ],
        ),
      ],
      child: MaterialApp.router(
        theme: ThemeData.light().copyWith(extensions: [AppColors.light(AppAccent.blue)]),
        routerConfig: router,
      ),
    ));
    await tester.pumpAndSettle();
    router.go('/host/new');
    await tester.pumpAndSettle();

    expect(find.text('Oat latte'), findsOneWidget);
  });
}
