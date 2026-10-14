import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/repositories/budget_envelope_repository.dart';
import 'package:opal/models/models.dart';

BudgetEnvelope _env(String id, int position) => BudgetEnvelope(
      id: id, category: id, cap: 100, icon: 'bag',
      colorToken: 'money', position: position,
    );

void main() {
  late LoopDatabase db;
  late BudgetEnvelopeRepository repo;
  setUp(() async {
    db = LoopDatabase.forTesting(NativeDatabase.memory());
    repo = BudgetEnvelopeRepository(db);
    for (final e in [_env('a', 0), _env('b', 1), _env('c', 2)]) {
      await repo.upsert(e);
    }
  });
  tearDown(() => db.close());

  Future<List<(String, int)>> positions() async => [
        for (final e in await repo.getEnvelopes()) (e.id, e.position),
      ];

  test('reorder writes each envelope its list index', () async {
    final list = await repo.getEnvelopes();
    await repo.reorder([list[2], list[0], list[1]]);
    expect(await positions(), [('c', 0), ('a', 1), ('b', 2)]);
  });

  test('a reorder that fails mid-way leaves the original positions', () async {
    final list = await repo.getEnvelopes();
    // 'c' and 'a' are written before the missing id throws.
    final reordered = [list[2], list[0], _env('gone', 9), list[1]];
    await expectLater(repo.reorder(reordered), throwsStateError);
    expect(await positions(), [('a', 0), ('b', 1), ('c', 2)]);
  });
}
