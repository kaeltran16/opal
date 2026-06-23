import 'health_service.dart';

/// Canned [HealthService] for Windows preview + tests. No network.
class MockHealthService implements HealthService {
  const MockHealthService();

  @override
  Future<HealthDay> fetchDay(DateTime day) async =>
      const HealthDay(activeEnergyKcal: 320, steps: 6000);

  @override
  Future<List<HealthSleep>> fetchSleep(DateTime from, DateTime to) async =>
      const [];
}
