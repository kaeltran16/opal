import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/repositories/repositories.dart';
import 'package:opal/models/models.dart';
import 'package:opal/router.dart';
import 'package:opal/services/pal/pal_service.dart';
import 'package:opal/theme/app_colors.dart';

import '../support/flush_provider_timers.dart';

/// Fake Pal: resolves instantly, returns null-equivalent (empty PalInsights
/// collapses to null in insightsController). Mirrors _FakePal in
/// insights_controller_test.dart.
class _FakePal implements PalService {
  @override
  Future<PalAgenda> agenda() async => const PalAgenda();

  @override
  Future<PalInsights> insights(InsightRange range) async =>
      const PalInsights(headline: 'test');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Seeds 28 days of move+money entries producing a strong correlation — same
/// generator shape as correlations_controller_test.dart.
Future<void> _seedCorrelationData(LoopDatabase db) async {
  final repo = EntryRepository(db);
  final now = DateTime.now();
  for (var i = 0; i < 28; i++) {
    final day =
        DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
    final workout = i % 3 == 0;
    if (workout) {
      await repo.insert(Entry(
          id: 'w$i',
          timestamp: day.add(const Duration(hours: 7)),
          type: EntryType.move,
          title: 'run',
          calories: 300,
          source: EntrySource.manual));
    }
    await repo.insert(Entry(
        id: 'm$i',
        timestamp: day.add(const Duration(hours: 18)),
        type: EntryType.money,
        title: 'spend',
        amount: workout ? -20.0 : -60.0,
        category: 'Food',
        source: EntrySource.manual));
  }
}

void main() {
  testWidgets(
      'Recap surfaces a CorrelationCard when a strong move-money link exists',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    await _seedCorrelationData(db);
    addTearDown(db.close);

    final router = createRouter(initialLocation: '/recap');
    final colors = AppColors.light(AppAccent.indigo);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          loopDatabaseProvider.overrideWithValue(db),
          // fast fake so insightsProvider resolves without a network call
          palServiceProvider.overrideWithValue(_FakePal()),
        ],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(useMaterial3: true, extensions: [colors]),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The strength chip text proves CorrelationCard rendered, independent of narration.
    expect(find.textContaining('Based on'), findsOneWidget);

    await flushProviderTimers(tester);
  });
}
