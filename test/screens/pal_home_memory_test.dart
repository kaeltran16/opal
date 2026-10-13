import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/controllers/pal_memory_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/router.dart';
import 'package:opal/services/pal/mock_pal_service.dart';
import 'package:opal/services/pal/pal_service.dart';
import 'package:opal/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/flush_provider_timers.dart';

void main() {
  testWidgets('a learned server pattern shows as a finding on You',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    // an empty db leaves Pal's memory as the only finding source.
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final colors = AppColors.light();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          loopDatabaseProvider.overrideWithValue(db),
          palServiceProvider.overrideWithValue(MockPalService(latency: Duration.zero)),
          palMemoryProvider.overrideWith((ref) async => const PalMemoryDigest(
                facts: [PalFact(id: 'f-1', text: 'marathon in October')],
                patterns: [InsightPattern(colorToken: 'move', title: 'Mornings', detail: 'before noon')],
              )),
        ],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(useMaterial3: true, extensions: [colors]),
          routerConfig: createRouter(initialLocation: '/you'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // no comparison, so it is listed under Also seen rather than leading.
    expect(find.text('Also seen'), findsOneWidget);
    expect(find.text('Mornings'), findsOneWidget);
    expect(find.text('Move · before noon'), findsOneWidget);
    // the fact itself lives in What Pal remembers; You counts it.
    expect(find.text('marathon in October'), findsNothing);
    expect(find.text('1 fact'), findsOneWidget);

    await flushProviderTimers(tester);
  });
}
