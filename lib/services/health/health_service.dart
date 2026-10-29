/// One day's health totals from Apple Health.
class HealthDay {
  const HealthDay({required this.activeEnergyKcal, required this.steps});
  final int activeEnergyKcal; // 0 when absent
  final int steps;            // 0 when absent
}

/// One night of sleep read from Apple Health. Minutes are integer; clock
/// strings are display-ready ("23:32" / "7:02").
class HealthSleep {
  const HealthSleep({
    required this.night,
    required this.asleepMinutes,
    required this.inBedMinutes,
    required this.bedtime,
    required this.wake,
    required this.deepMinutes,
    required this.remMinutes,
    required this.coreMinutes,
    required this.awakeMinutes,
    required this.wakes,
    this.sourceRef,
  });
  final DateTime night;
  final int asleepMinutes, inBedMinutes;
  final String bedtime, wake;
  final int deepMinutes, remMinutes, coreMinutes, awakeMinutes, wakes;
  final String? sourceRef;
}

abstract interface class HealthService {
  /// Totals for the local calendar [day].
  Future<HealthDay> fetchDay(DateTime day);

  /// Nights in [from, to), keyed by the evening each night starts.
  Future<List<HealthSleep>> fetchSleep(DateTime from, DateTime to);
}
