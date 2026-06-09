import 'health_service.dart';

/// Canned [HealthService] for Windows preview + tests.
///
/// Returns fixed move-minutes / energy / HR so Today (U05) and Move (U10)
/// render a believable movement summary without a real device. Defaults match
/// the prototype's Today hero (66 move-minutes). Tests can inject a fixed
/// [today] sample for deterministic ring math.
class MockHealthService implements HealthService {
  MockHealthService({HealthSample? today}) : today = today ?? _defaultToday();

  final HealthSample today;

  static HealthSample _defaultToday() => HealthSample(
        date: DateTime.now(),
        moveMinutes: 66,
        activeEnergyKcal: 512,
        avgHeartRate: 72,
        steps: 8420,
      );

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<HealthSample> todaySample() async => today;

  @override
  Future<List<HealthSample>> samplesInRange(DateTime from, DateTime to) async {
    final out = <HealthSample>[];
    var d = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day);
    var i = 0;
    while (d.isBefore(end)) {
      out.add(HealthSample(
        date: d,
        moveMinutes: 40 + (i * 7) % 35,
        activeEnergyKcal: 380 + (i * 23) % 240,
        avgHeartRate: 68 + (i * 3) % 12,
        steps: 6000 + (i * 311) % 5000,
      ));
      d = d.add(const Duration(days: 1));
      i++;
    }
    return out;
  }
}
