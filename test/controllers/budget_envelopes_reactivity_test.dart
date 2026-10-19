import 'dart:async';

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/controllers/budget_advisories_controller.dart';
import 'package:opal/controllers/budget_envelopes_controller.dart';
import 'package:opal/controllers/budget_forecast_controller.dart';
import 'package:opal/controllers/budget_recommendations_controller.dart';
import 'package:opal/controllers/budgets_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/repositories/repositories.dart';
import 'package:opal/models/models.dart';

final _now = DateTime(2026, 6, 20, 12);
const _timeout = Duration(seconds: 5);

Entry _expense(String id, String category, double amount, DateTime ts) => Entry(
      id: id,
      timestamp: ts,
      type: EntryType.money,
      title: category,
      amount: -amount,
      category: category,
      source: EntrySource.manual,
    );

void main() {
  late LoopDatabase db;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    db = LoopDatabase.forTesting(NativeDatabase.memory());
    await BudgetEnvelopeRepository(db).upsert(const BudgetEnvelope(
      id: 'env-groceries',
      category: 'Groceries',
      cap: 500,
      icon: 'basket',
      colorToken: 'money',
      position: 0,
    ));
    final entries = EntryRepository(db);
    // three completed months so a recommendation exists, plus this month's
    // uncovered Coffee spend above the advisory floor.
    for (final (i, month) in [3, 4, 5].indexed) {
      await entries.insert(
          _expense('g$i', 'Groceries', 900, DateTime(2026, month, 10)));
    }
    await entries
        .insert(_expense('g-now', 'Groceries', 100, DateTime(2026, 6, 5)));
    await entries.insert(_expense('c-now', 'Coffee', 600, DateTime(2026, 6, 6)));

    container = ProviderContainer(
        overrides: [
      loopDatabaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ]);
    container.listen(budgetEnvelopesControllerProvider, (_, _) {});
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  BudgetEnvelopesController controller() =>
      container.read(budgetEnvelopesControllerProvider.notifier);

  /// Resolves with the first value of [provider], current or later, that
  /// satisfies [test]. Subscribes before checking so no emission is missed.
  Future<T> firstWhere<T>(
    ProviderListenable<AsyncValue<T>> provider,
    bool Function(T) test,
  ) {
    final done = Completer<T>();
    void check(AsyncValue<T> v) {
      final value = v.asData?.value;
      if (value != null && test(value) && !done.isCompleted) {
        done.complete(value);
      }
    }

    final sub = container.listen(provider, (_, next) => check(next));
    check(container.read(provider));
    return done.future.timeout(_timeout).whenComplete(sub.close);
  }

  Future<void> run(Future<void> Function() body) =>
      withClock(Clock.fixed(_now), body);

  test('budgetsData reflects a cap edit', () => run(() async {
        await firstWhere(budgetsDataProvider,
            (d) => d.envelopes.first.cap == 500);
        await controller().setCap('env-groceries', 750);
        final d = await firstWhere(
            budgetsDataProvider, (d) => d.envelopes.first.cap == 750);
        expect(d.envelopes.first.cap, 750);
      }));

  test('budgetRecommendations reflects a cap edit as currentCap',
      () => run(() async {
            final before = await firstWhere(
                budgetRecommendationsProvider, (l) => l.isNotEmpty);
            expect(before.first.currentCap, 500);
            await controller().setCap('env-groceries', 750);
            final after = await firstWhere(budgetRecommendationsProvider,
                (l) => l.any((r) => r.currentCap == 750));
            expect(after.where((r) => r.currentCap == 750), isNotEmpty);
          }));

  test('budgetAdvisories drops an unbudgeted category once it gets an envelope',
      () => run(() async {
            await firstWhere(budgetAdvisoriesProvider,
                (a) => a.unbudgeted.any((u) => u.category == 'Coffee'));
            await controller().add(category: 'Coffee', icon: 'cup', cap: 800);
            final after = await firstWhere(budgetAdvisoriesProvider,
                (a) => a.unbudgeted.every((u) => u.category != 'Coffee'));
            expect(after.unbudgeted, isEmpty);
          }));

  test('envelopeForecasts reflects a cap edit', () => run(() async {
        await firstWhere(envelopeForecastsProvider,
            (l) => l.any((f) => f.cap == 500));
        await controller().setCap('env-groceries', 750);
        final after = await firstWhere(
            envelopeForecastsProvider, (l) => l.any((f) => f.cap == 750));
        expect(after.single.category, 'Groceries');
      }));
}
