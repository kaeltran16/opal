import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/flush_provider_timers.dart';

import 'package:opal/app.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/seed/seeder.dart';
import 'package:opal/screens/today/today_screen.dart';
import 'package:opal/widgets/pal_label.dart';

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

    // The Today tab label, Today's date line, Pal's label and the action card.
    expect(find.text('Today'), findsWidgets);
    expect(
      find.textContaining(RegExp(r'^[A-Z]{3} \d{1,2} [A-Z]{3} · \d{1,2}:\d{2} [AP]M$')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byType(TodayScreen), matching: find.byType(PalLabel)),
      findsOneWidget,
    );
    expect(find.byKey(todayCardKey), findsOneWidget);

    await flushProviderTimers(tester);
  });
}
