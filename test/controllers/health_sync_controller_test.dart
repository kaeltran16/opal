import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/controllers/health_sync_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/models/models.dart';
import 'package:opal/services/health/health_service.dart';
import 'package:opal/services/pal/http_pal_service.dart' show PalException;

/// Returns a fixed [HealthDay] each call (latest assigned wins, for re-sync).
class _FakeHealthService implements HealthService {
  _FakeHealthService(this.day);
  HealthDay day;

  @override
  Future<HealthDay> fetchDay(DateTime d) async => day;
}

/// Always throws, mirroring a real network/proxy failure.
class _ThrowingHealthService implements HealthService {
  @override
  Future<HealthDay> fetchDay(DateTime d) async =>
      throw const PalException('proxy returned 500');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LoopDatabase db;

  setUp(() {
    db = LoopDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  String today() {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }

  test('upserts one health move entry from fetched active energy', () async {
    final fake = _FakeHealthService(
      const HealthDay(activeEnergyKcal: 412, steps: 8423),
    );
    final container = ProviderContainer(overrides: [
      loopDatabaseProvider.overrideWithValue(db),
      healthServiceProvider.overrideWithValue(fake),
    ]);
    addTearDown(container.dispose);

    container.read(healthSyncControllerProvider); // instantiate -> triggers sync
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final repo = container.read(entryRepositoryProvider);
    final all = await repo.getAll();
    final move = all.where((e) => e.type == EntryType.move).toList();
    expect(move, hasLength(1));
    expect(move.single.id, 'health:move:${today()}');
    expect(move.single.calories, 412);
    expect(move.single.source, EntrySource.health);
    expect(move.single.detail, '8423 steps');
  });

  test('a second sync upserts (no duplicate), keeping the latest kcal', () async {
    final fake = _FakeHealthService(
      const HealthDay(activeEnergyKcal: 412, steps: 8423),
    );
    final container = ProviderContainer(overrides: [
      loopDatabaseProvider.overrideWithValue(db),
      healthServiceProvider.overrideWithValue(fake),
    ]);
    addTearDown(container.dispose);

    container.read(healthSyncControllerProvider);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // re-sync with a new value
    fake.day = const HealthDay(activeEnergyKcal: 430, steps: 9000);
    container.invalidate(healthSyncControllerProvider);
    container.read(healthSyncControllerProvider);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final repo = container.read(entryRepositoryProvider);
    final move =
        (await repo.getAll()).where((e) => e.type == EntryType.move).toList();
    expect(move, hasLength(1));
    expect(move.single.calories, 430);
  });

  test('does nothing when active energy is 0', () async {
    final fake = _FakeHealthService(
      const HealthDay(activeEnergyKcal: 0, steps: 0),
    );
    final container = ProviderContainer(overrides: [
      loopDatabaseProvider.overrideWithValue(db),
      healthServiceProvider.overrideWithValue(fake),
    ]);
    addTearDown(container.dispose);

    container.read(healthSyncControllerProvider);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final repo = container.read(entryRepositoryProvider);
    expect(await repo.getAll(), isEmpty);
  });

  test('a failed health pull is swallowed: no entry, no error escapes',
      () async {
    final container = ProviderContainer(overrides: [
      loopDatabaseProvider.overrideWithValue(db),
      healthServiceProvider.overrideWithValue(_ThrowingHealthService()),
    ]);
    addTearDown(container.dispose);

    container.read(healthSyncControllerProvider); // triggers fire-and-forget sync
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // The startup sync must tolerate failure: nothing written, and the
    // un-awaited future must not throw into the zone (which would fail here).
    final repo = container.read(entryRepositoryProvider);
    expect(await repo.getAll(), isEmpty);
  });
}
