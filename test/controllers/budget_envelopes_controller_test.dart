import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/controllers/budget_envelopes_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/repositories/repositories.dart';
import 'package:opal/models/models.dart';

/// Envelope writes that always fail, as a broken local table would.
class _FailingEnvelopes extends BudgetEnvelopeRepository {
  _FailingEnvelopes(super.db);

  @override
  Future<void> upsert(BudgetEnvelope envelope) =>
      Future.error(Exception('upsert failed'));

  @override
  Future<void> deleteById(String id) => Future.error(Exception('delete failed'));

  @override
  Future<void> reorder(List<BudgetEnvelope> envelopes) =>
      Future.error(Exception('reorder failed'));
}

BudgetEnvelope _env(String id, String category, int position,
        {double cap = 100}) =>
    BudgetEnvelope(
      id: id, category: category, cap: cap, icon: 'bag',
      colorToken: 'money', position: position,
    );

final _seed = [
  _env('a', 'Groceries', 0),
  _env('b', 'Transport', 1),
  _env('c', 'Health', 2),
];

void main() {
  late LoopDatabase db;
  late BudgetEnvelopeRepository repo;

  setUp(() async {
    db = LoopDatabase.forTesting(NativeDatabase.memory());
    repo = BudgetEnvelopeRepository(db);
    for (final e in _seed) {
      await repo.upsert(e);
    }
  });
  tearDown(() => db.close());

  BudgetEnvelopesController controller({BudgetEnvelopeRepository? override}) {
    final c = ProviderContainer(overrides: [
      loopDatabaseProvider.overrideWithValue(db),
      if (override != null)
        budgetEnvelopeRepositoryProvider.overrideWithValue(override),
    ]);
    addTearDown(c.dispose);
    // keep the auto-dispose controller alive across the awaited writes.
    c.listen(budgetEnvelopesControllerProvider, (_, _) {});
    return c.read(budgetEnvelopesControllerProvider.notifier);
  }

  Future<List<String>> ids() async =>
      [for (final e in await repo.getEnvelopes()) e.id];

  test('streams the envelopes in position order', () async {
    final c = ProviderContainer(
        overrides: [loopDatabaseProvider.overrideWithValue(db)]);
    addTearDown(c.dispose);
    c.listen(budgetEnvelopesControllerProvider, (_, _) {});
    final list = await c.read(budgetEnvelopesControllerProvider.future);
    expect(list.map((e) => e.id), ['a', 'b', 'c']);
  });

  group('add', () {
    test('appends at the end with a fresh id', () async {
      await controller().add(category: '  Coffee ', icon: 'cup', cap: 50);
      final list = await repo.getEnvelopes();
      expect(list, hasLength(4));
      final added = list.last;
      expect(_seed.map((e) => e.id), isNot(contains(added.id)));
      expect(added.id, isNotEmpty);
      expect(added.category, 'Coffee');
      expect(added.icon, 'cup');
      expect(added.cap, 50);
      expect(added.position, 3);
      expect(added.colorToken, 'money');
    });

    test('starts at position 0 when there are no envelopes', () async {
      for (final e in _seed) {
        await repo.deleteById(e.id);
      }
      await controller().add(category: 'Coffee', icon: 'cup', cap: 50);
      expect((await repo.getEnvelopes()).single.position, 0);
    });

    test('rejects a duplicate that differs only in case or spacing', () async {
      await expectLater(
        controller().add(category: '  gROCERIES ', icon: 'bag', cap: 50),
        throwsArgumentError,
      );
      expect(await ids(), ['a', 'b', 'c']);
    });

    test('rejects an empty or over-long category', () async {
      final ctl = controller();
      await expectLater(
          ctl.add(category: '   ', icon: 'bag', cap: 50), throwsArgumentError);
      await expectLater(
        ctl.add(
            category: 'x' * (kMaxEnvelopeNameLength + 1), icon: 'bag', cap: 50),
        throwsArgumentError,
      );
      expect(await ids(), ['a', 'b', 'c']);
    });

    test('accepts a category of exactly the maximum length', () async {
      await controller()
          .add(category: 'x' * kMaxEnvelopeNameLength, icon: 'bag', cap: 50);
      expect(await ids(), hasLength(4));
    });

    test('rejects a cap that is zero, negative or not finite', () async {
      final ctl = controller();
      for (final cap in [0.0, -5.0, double.nan, double.infinity]) {
        await expectLater(
          ctl.add(category: 'Coffee', icon: 'cup', cap: cap),
          throwsArgumentError,
          reason: 'cap $cap',
        );
      }
      expect(await ids(), ['a', 'b', 'c']);
    });
  });

  group('setCap', () {
    test('changes only that envelope', () async {
      await controller().setCap('b', 250);
      final list = await repo.getEnvelopes();
      expect(list, [_seed[0], _seed[1].copyWith(cap: 250), _seed[2]]);
    });

    test('rejects a cap that is zero, negative or not finite', () async {
      final ctl = controller();
      for (final cap in [0.0, -1.0, double.nan, double.negativeInfinity]) {
        await expectLater(ctl.setCap('b', cap), throwsArgumentError,
            reason: 'cap $cap');
      }
      expect(await repo.getEnvelopes(), _seed);
    });
  });

  test('delete reindexes the survivors', () async {
    await controller().delete('a');
    final list = await repo.getEnvelopes();
    expect([for (final e in list) (e.id, e.position)], [('b', 0), ('c', 1)]);
  });

  group('reorder', () {
    Future<List<(String, int)>> positions() async => [
          for (final e in await repo.getEnvelopes()) (e.id, e.position),
        ];

    test('moves first to last', () async {
      await controller().reorder(0, 2);
      expect(await positions(), [('b', 0), ('c', 1), ('a', 2)]);
    });

    test('moves last to first', () async {
      await controller().reorder(2, 0);
      expect(await positions(), [('c', 0), ('a', 1), ('b', 2)]);
    });
  });

  group('applyCap', () {
    test('updates an existing envelope, case-insensitively', () async {
      await controller().applyCap(' transport ', 320);
      final list = await repo.getEnvelopes();
      expect(list, [_seed[0], _seed[1].copyWith(cap: 320), _seed[2]]);
    });

    test('creates a missing one with the default icon', () async {
      await controller().applyCap('Coffee', 60);
      final added = (await repo.getEnvelopes()).last;
      expect(added.category, 'Coffee');
      expect(added.cap, 60);
      expect(added.icon, kDefaultEnvelopeIcon);
      expect(added.position, 3);
    });
  });

  test('isDuplicateEnvelope matches by normalizeCategory', () {
    expect(isDuplicateEnvelope(_seed, '  HEALTH  '), isTrue);
    expect(isDuplicateEnvelope(_seed, 'Health care'), isFalse);
    expect(isDuplicateEnvelope(const [], 'Health'), isFalse);
  });

  group('a repository that throws', () {
    late BudgetEnvelopesController ctl;
    setUp(() => ctl = controller(override: _FailingEnvelopes(db)));

    test('makes setCap throw', () async {
      await expectLater(ctl.setCap('a', 200), throwsException);
    });
    test('makes add throw', () async {
      await expectLater(
          ctl.add(category: 'Coffee', icon: 'cup', cap: 50), throwsException);
    });
    test('makes delete throw', () async {
      await expectLater(ctl.delete('a'), throwsException);
    });
    test('makes reorder throw', () async {
      await expectLater(ctl.reorder(0, 2), throwsException);
    });
    test('makes applyCap throw, for an existing and a new envelope', () async {
      await expectLater(ctl.applyCap('Groceries', 200), throwsException);
      await expectLater(ctl.applyCap('Coffee', 200), throwsException);
    });
  });
}
