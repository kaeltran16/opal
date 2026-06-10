import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/app.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/seed/seeder.dart';

void main() {
  testWidgets('App root boots to the Today tab on seeded data',
      (WidgetTester tester) async {
    // onboardingComplete=true so the U17 first-run gate lets the app boot
    // straight to Today (rather than redirecting to onboarding).
    SharedPreferences.setMockInitialValues({
      'settings.onboardingComplete': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    await Seeder(db).seedIfNeeded();
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          loopDatabaseProvider.overrideWithValue(db),
        ],
        child: const LoopApp(),
      ),
    );
    // Resolve the async Today stream + first frame.
    await tester.pumpAndSettle();

    // Nav title + the Today tab label both read "Today".
    expect(find.text('Today'), findsWidgets);
    expect(find.text('PAL NOTICED'), findsOneWidget);
    // The 3-up summary row is present.
    expect(find.text('Spent'), findsWidgets);
    expect(find.text('Move'), findsWidgets);
    expect(find.text('Rituals'), findsWidgets);
  });
}
