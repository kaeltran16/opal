import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:loop/controllers/providers.dart';
import 'package:loop/data/db/database.dart';
import 'package:loop/screens/email/email_intro_screen.dart';
import 'package:loop/screens/email/email_nav.dart';
import 'package:loop/services/services.dart';
import 'package:loop/theme/app_colors.dart';

/// Pumps a screen inside a minimal GoRouter + ProviderScope harness with the
/// standard overrides (db, prefs, the real mock email service). Uses a local
/// router so the render assertions don't depend on the central route wiring
/// (the orchestrator repoints `/email` → Intro and adds setup/dashboard).
Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  required SharedPreferences prefs,
  required LoopDatabase db,
}) async {
  final router = GoRouter(
    initialLocation: '/email',
    routes: [
      GoRoute(path: '/email', builder: (_, _) => screen),
      // Targets for pushNamed from the Intro CTA; bodies are inert.
      GoRoute(
          path: '/email/setup',
          name: 'emailSetup',
          builder: (_, _) => const SizedBox()),
      GoRoute(
          path: '/email/dashboard',
          name: 'emailDashboard',
          builder: (_, _) => const SizedBox()),
    ],
  );
  final colors = AppColors.light(AppAccent.blue);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        loopDatabaseProvider.overrideWithValue(db),
        emailSyncServiceProvider.overrideWithValue(MockEmailSyncService()),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, extensions: [colors]),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // --- Pure: 16-char app-password auto-formats into 4-char groups -----------
  test('AppPasswordFormatter groups 16 chars into four 4-char blocks', () {
    expect(AppPasswordFormatter.format('abcdefghijklmnop'),
        'abcd efgh ijkl mnop');
    // Spaces are normalized regardless of where they were typed.
    expect(AppPasswordFormatter.format('abcd efgh ijkl mnop'),
        'abcd efgh ijkl mnop');
    // Over-length input is capped at 16 chars (four groups).
    expect(AppPasswordFormatter.format('abcdefghijklmnopqrstuv'),
        'abcd efgh ijkl mnop');
    // Partial input groups as far as it can.
    expect(AppPasswordFormatter.format('abcdef'), 'abcd ef');
  });

  test('AppPasswordFormatter formats live edits via the TextInputFormatter', () {
    const formatter = AppPasswordFormatter();
    final out = formatter.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(text: 'abcdefghijklmnop'),
    );
    expect(out.text, 'abcd efgh ijkl mnop');
    // Caret sits at the end so subsequent typing appends cleanly.
    expect(out.selection.baseOffset, out.text.length);
  });

  // --- Widget: Intro renders the value prop + "How it works" list -----------
  testWidgets('Email Intro renders value prop and provider/how-it-works list',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await _pump(tester, const EmailIntroScreen(), prefs: prefs, db: db);

    // Value prop headline + read-only app-password pitch.
    expect(find.text('Stop logging card charges by hand.'), findsOneWidget);

    // "How it works" section + its three steps.
    expect(find.text('HOW IT WORKS'), findsOneWidget);
    expect(find.text('Your bank sends alerts'), findsOneWidget);
    expect(find.text('Pal reads only those'), findsOneWidget);
    expect(find.text('It lands on Today'), findsOneWidget);

    // Primary CTA + provider/IMAP affordance (below the fold — scroll each in).
    await tester.scrollUntilVisible(find.text('Set up Gmail sync'), 200);
    expect(find.text('Set up Gmail sync'), findsOneWidget);
    await tester.scrollUntilVisible(
        find.text('iCloud, Outlook, any IMAP coming'), 200);
    expect(find.text('iCloud, Outlook, any IMAP coming'), findsOneWidget);
  });
}
