/// Today's health metrics read from the server (populated by the iOS Shortcut).
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
  /// GET /v1/health/day?date=YYYY-MM-DD
  Future<HealthDay> fetchDay(DateTime day);

  /// GET /v1/health/sleep?from=YYYY-MM-DD&to=YYYY-MM-DD — nights in [from, to).
  Future<List<HealthSleep>> fetchSleep(DateTime from, DateTime to);
}
