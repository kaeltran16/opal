import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/controllers/providers.dart';
import 'package:opal/controllers/rituals_builder_controller.dart';
import 'package:opal/controllers/rituals_controller.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/repositories/repositories.dart';
import 'package:opal/models/models.dart';

/// A routines query that always fails, as a broken local table would.
class _FailingRituals extends RitualRepository {
  _FailingRituals(super.db);

  @override
  Stream<List<RitualRoutine>> watchRoutines() =>
      Stream.error(Exception('routines query failed'));
}

ProviderContainer _container() {
  final db = LoopDatabase.forTesting(NativeDatabase.memory());
  final c = ProviderContainer(overrides: [
    loopDatabaseProvider.overrideWithValue(db),
    ritualRepositoryProvider.overrideWithValue(_FailingRituals(db)),
  ]);
  addTearDown(() async {
    c.dispose();
    await db.close();
  });
  return c;
}

void main() {
  // no wait past riverpod's first retry delay: a retried failure would still
  // read as loading here.
  Future<void> settleWithoutRetryDelay() => Future<void>.delayed(Duration.zero);

  test('a failing routines stream is an error at once', () async {
    final c = _container();
    c.listen(ritualRoutinesStreamProvider, (_, _) {});
    await settleWithoutRetryDelay();
    expect(c.read(ritualRoutinesStreamProvider),
        isA<AsyncError<List<RitualRoutine>>>());
  });

  test('the rituals view model is an error at once', () async {
    final c = _container();
    c.listen(ritualsControllerProvider, (_, _) {});
    await settleWithoutRetryDelay();
    expect(c.read(ritualsControllerProvider), isA<AsyncError<RitualsState>>());
  });

  test('the routines builder is an error at once', () async {
    final c = _container();
    c.listen(ritualsBuilderControllerProvider, (_, _) {});
    await settleWithoutRetryDelay();
    expect(c.read(ritualsBuilderControllerProvider),
        isA<AsyncError<List<RitualRoutine>>>());
  });
}
