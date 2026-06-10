import 'package:health/health.dart';

import 'health_service.dart';

/// The real, device-only [HealthService] backed by Apple HealthKit via the
/// `health` package (U27a).
///
/// This is the production swap-in behind the same interface [MockHealthService]
/// satisfies on web/Windows/tests. HealthKit has no web/desktop backing, so the
/// provider only wires this on iOS (`!kIsWeb && Platform == iOS`); everywhere
/// else keeps the mock. See `lib/controllers/providers.dart`.
///
/// Type mapping (HealthKit → [HealthSample]):
///   - move/exercise minutes → [HealthDataType.EXERCISE_TIME] (Apple's "exercise
///     minutes" ring), summed per day.
///   - active energy → [HealthDataType.ACTIVE_ENERGY_BURNED], summed (kcal).
///   - heart rate → [HealthDataType.HEART_RATE], averaged over the day (bpm).
///   - steps → [HealthDataType.STEPS], summed.
///
/// Reads only. Days with no readings yield zeros for minutes/energy and `null`
/// for heart rate / steps, matching the nullable shape of [HealthSample].
class HealthKitService implements HealthService {
  HealthKitService({Health? health}) : _health = health ?? Health();

  final Health _health;

  /// HealthKit types this service reads. Order is irrelevant; each is requested
  /// with READ access in [requestPermissions].
  static const List<HealthDataType> _types = <HealthDataType>[
    HealthDataType.EXERCISE_TIME,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.HEART_RATE,
    HealthDataType.STEPS,
  ];

  static final List<HealthDataAccess> _permissions =
      List<HealthDataAccess>.filled(_types.length, HealthDataAccess.READ);

  bool _configured = false;

  /// Configures the plugin once (idempotent). `configure()` wires the native
  /// HealthKit bridge and must run before any authorization / read call.
  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  @override
  Future<bool> requestPermissions() async {
    await _ensureConfigured();
    // HealthKit never reveals READ-denial for privacy reasons, so a `true`
    // here means "the prompt completed", not "data exists". Reads still return
    // gracefully-empty results when the user declined — handled downstream.
    return _health.requestAuthorization(_types, permissions: _permissions);
  }

  @override
  Future<HealthSample> todaySample() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return _aggregateDay(day: start, from: start, to: end);
  }

  @override
  Future<List<HealthSample>> samplesInRange(DateTime from, DateTime to) async {
    await _ensureConfigured();
    final out = <HealthSample>[];
    var d = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day);
    while (d.isBefore(end)) {
      final next = d.add(const Duration(days: 1));
      out.add(await _aggregateDay(day: d, from: d, to: next));
      d = next;
    }
    return out;
  }

  /// Reads every tracked type for the half-open window `[from, to)` and folds
  /// the points into a single [HealthSample] stamped with [day].
  Future<HealthSample> _aggregateDay({
    required DateTime day,
    required DateTime from,
    required DateTime to,
  }) async {
    await _ensureConfigured();

    final points = _health.removeDuplicates(
      await _health.getHealthDataFromTypes(
        types: _types,
        startTime: from,
        endTime: to,
      ),
    );

    var moveMinutes = 0.0;
    var activeEnergy = 0.0;
    var stepsTotal = 0.0;
    var hasSteps = false;
    var hrSum = 0.0;
    var hrCount = 0;

    for (final p in points) {
      final v = _numericValue(p);
      if (v == null) continue;
      switch (p.type) {
        case HealthDataType.EXERCISE_TIME:
          moveMinutes += v;
        case HealthDataType.ACTIVE_ENERGY_BURNED:
          activeEnergy += v;
        case HealthDataType.STEPS:
          stepsTotal += v;
          hasSteps = true;
        case HealthDataType.HEART_RATE:
          hrSum += v;
          hrCount++;
        default:
          break;
      }
    }

    return HealthSample(
      date: day,
      moveMinutes: moveMinutes.round(),
      activeEnergyKcal: activeEnergy.round(),
      avgHeartRate: hrCount == 0 ? null : (hrSum / hrCount).round(),
      steps: hasSteps ? stepsTotal.round() : null,
    );
  }

  /// Extracts the scalar reading from a [HealthDataPoint]; the tracked types are
  /// all numeric. Returns `null` for any non-numeric value so it is skipped.
  double? _numericValue(HealthDataPoint p) {
    final value = p.value;
    return value is NumericHealthValue ? value.numericValue.toDouble() : null;
  }
}
