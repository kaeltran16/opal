/// Today's health metrics read from the server (populated by the iOS Shortcut).
class HealthDay {
  const HealthDay({required this.activeEnergyKcal, required this.steps});
  final int activeEnergyKcal; // 0 when absent
  final int steps;            // 0 when absent
}

abstract interface class HealthService {
  /// GET /v1/health/day?date=YYYY-MM-DD
  Future<HealthDay> fetchDay(DateTime day);
}
