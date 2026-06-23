import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/controllers/sleep_sync_controller.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/services/health/health_service.dart';

class _FakeHealth implements HealthService {
  _FakeHealth(this.nights);
  final List<HealthSleep> nights;
  @override
  Future<HealthDay> fetchDay(DateTime day) async =>
      const HealthDay(activeEnergyKcal: 0, steps: 0);
  @override
  Future<List<HealthSleep>> fetchSleep(DateTime from, DateTime to) async => nights;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('syncs nights from Health into the repo', () async {
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(overrides: [
      loopDatabaseProvider.overrideWithValue(db),
      healthServiceProvider.overrideWithValue(_FakeHealth([
        HealthSleep(
          night: DateTime(2026, 6, 17),
          asleepMinutes: 432,
          inBedMinutes: 450,
          bedtime: '23:32',
          wake: '7:02',
          deepMinutes: 64,
          remMinutes: 98,
          coreMinutes: 270,
          awakeMinutes: 18,
          wakes: 2,
          sourceRef: 'h1',
        ),
      ])),
    ]);
    addTearDown(container.dispose);

    container.read(sleepSyncControllerProvider);
    await container.read(sleepSyncControllerProvider.notifier).syncOnce();

    final nights = await container.read(sleepRepositoryProvider)
        .getNightsInRange(DateTime(2026, 6, 1), DateTime(2026, 7, 1));
    expect(nights, hasLength(1));
    expect(nights.single.asleepMinutes, 432);
    expect(nights.single.sourceRef, 'h1');
  });
}
