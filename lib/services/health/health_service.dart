/// The HealthKit seam: move-minutes, active energy, heart rate, workouts.
///
/// Pulled early into U03 (SF-4) because U05's Today screen needs move-minutes
/// and U10's Move tab needs the full movement summary. HealthKit has no
/// web/Windows backing, so [MockHealthService] feeds canned samples; the real
/// `health`-package impl is wired on the borrowed Mac (U27) behind this same
/// interface.
library;

/// A single health metric reading for a day.
class HealthSample {
  const HealthSample({
    required this.date,
    required this.moveMinutes,
    required this.activeEnergyKcal,
    this.avgHeartRate,
    this.steps,
  });

  final DateTime date;

  /// Apple-Health "exercise minutes" equivalent.
  final int moveMinutes;

  /// Active energy burned, kilocalories.
  final int activeEnergyKcal;

  /// Average heart rate over the day, bpm. Nullable (no reading).
  final int? avgHeartRate;

  /// Step count. Nullable.
  final int? steps;

  HealthSample copyWith({
    DateTime? date,
    int? moveMinutes,
    int? activeEnergyKcal,
    int? avgHeartRate,
    int? steps,
  }) =>
      HealthSample(
        date: date ?? this.date,
        moveMinutes: moveMinutes ?? this.moveMinutes,
        activeEnergyKcal: activeEnergyKcal ?? this.activeEnergyKcal,
        avgHeartRate: avgHeartRate ?? this.avgHeartRate,
        steps: steps ?? this.steps,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HealthSample &&
          other.date == date &&
          other.moveMinutes == moveMinutes &&
          other.activeEnergyKcal == activeEnergyKcal &&
          other.avgHeartRate == avgHeartRate &&
          other.steps == steps;

  @override
  int get hashCode =>
      Object.hash(date, moveMinutes, activeEnergyKcal, avgHeartRate, steps);
}

/// Read-only health data source.
abstract interface class HealthService {
  /// Whether the user has granted (mock: always true) health permissions.
  Future<bool> requestPermissions();

  /// Today's movement summary (move-minutes / energy / HR).
  Future<HealthSample> todaySample();

  /// Daily samples in the half-open range [from, to).
  Future<List<HealthSample>> samplesInRange(DateTime from, DateTime to);
}
