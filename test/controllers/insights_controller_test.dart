import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/controllers/insights_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/repositories/repositories.dart';
import 'package:opal/models/models.dart';
import 'package:opal/services/pal/pal_service.dart';

/// Counts `insights` calls and returns a fixed result (or throws), so we can
/// assert the deterministic gate decides whether to call Pal at all.
class _FakePal implements PalService {
  _FakePal({this.result = const PalInsights(headline: 'hi'), this.fail = false});

  @override
  Future<PalAgenda> agenda() async => const PalAgenda();

  final PalInsights result;
  final bool fail;
  int calls = 0;

  @override
  Future<PalInsights> insights(InsightRange range) async {
    calls++;
    if (fail) throw Exception('unreachable');
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _insert(EntryRepository repo, int count) async {
  final now = DateTime.now();
  for (var i = 0; i < count; i++) {
    await repo.insert(Entry(
      id: 'e$i',
      timestamp: now.subtract(Duration(hours: i + 1)),
      type: EntryType.money,
      title: 'Spend $i',
      amount: -10,
      category: 'Food',
      source: EntrySource.manual,
    ));
  }
}

void main() {
  ProviderContainer containerWith(LoopDatabase db, _FakePal pal) {
    final c = ProviderContainer(overrides: [
      loopDatabaseProvider.overrideWithValue(db),
      palServiceProvider.overrideWithValue(pal),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  test('returns null and skips Pal when below the data threshold', () async {
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await _insert(EntryRepository(db), 2); // < 3

    final pal = _FakePal();
    final container = containerWith(db, pal);

    final result =
        await container.read(insightsProvider(InsightRange.day).future);

    expect(result, isNull);
    expect(pal.calls, 0); // gate short-circuited before the call
  });

  test('calls Pal and returns insights once enough data exists', () async {
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await _insert(EntryRepository(db), 3); // == threshold

    final pal = _FakePal(result: const PalInsights(headline: 'Steady day.'));
    final container = containerWith(db, pal);

    final result =
        await container.read(insightsProvider(InsightRange.day).future);

    expect(pal.calls, 1);
    expect(result?.headline, 'Steady day.');
  });

  test('keeps a produced insight alive so a re-read does not refetch', () async {
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await _insert(EntryRepository(db), 3);

    final pal = _FakePal(result: const PalInsights(headline: 'Steady day.'));
    final container = containerWith(db, pal);
    final provider = insightsProvider(InsightRange.day);

    // resolve once under a listener, then drop it: an auto-dispose provider
    // would tear down and recompute on the next read — keepAlive must prevent that.
    final sub = container.listen(provider, (_, __) {});
    await container.read(provider.future);
    sub.close();
    await Future<void>.delayed(Duration.zero); // let any pending dispose run

    await container.read(provider.future);

    expect(pal.calls, 1); // pinned in memory, not recomputed
  });

  test('does not pin the empty state (re-resolves on next read)', () async {
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await _insert(EntryRepository(db), 3); // clears the gate, so Pal is called

    final pal = _FakePal(result: const PalInsights()); // empty payload → null
    final container = containerWith(db, pal);
    final provider = insightsProvider(InsightRange.day);

    final sub = container.listen(provider, (_, __) {});
    expect(await container.read(provider.future), isNull);
    sub.close();
    await Future<void>.delayed(Duration.zero); // let the un-pinned provider dispose

    await container.read(provider.future);

    expect(pal.calls, 2); // not kept alive → recomputed, called Pal again
  });

  test('returns null when Pal throws (graceful empty state)', () async {
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await _insert(EntryRepository(db), 4);

    final container = containerWith(db, _FakePal(fail: true));

    final result =
        await container.read(insightsProvider(InsightRange.day).future);

    expect(result, isNull);
  });

  test('returns null when Pal yields an empty payload', () async {
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await _insert(EntryRepository(db), 4);

    final container = containerWith(db, _FakePal(result: const PalInsights()));

    final result =
        await container.read(insightsProvider(InsightRange.week).future);

    expect(result, isNull); // empty insights collapse to the empty state
  });
}
