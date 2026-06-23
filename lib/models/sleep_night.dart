import 'enums.dart';

/// One night's sleep, synced read-only from Apple Health. Attributed to [night]
/// = the calendar date the user woke on. Stage minutes sum to ≈[inBedMinutes].
class SleepNight {
  const SleepNight({
    required this.id,
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
    required this.source,
    this.sourceRef,
  });

  final String id;
  final DateTime night;
  final int asleepMinutes;
  final int inBedMinutes;

  /// Display clock strings, e.g. "11:32" / "7:02".
  final String bedtime, wake;
  final int deepMinutes, remMinutes, coreMinutes, awakeMinutes;
  final int wakes;
  final EntrySource source;

  /// Health sample UUID (dedup key); null for seed/manual.
  final String? sourceRef;

  SleepNight copyWith({
    String? id,
    DateTime? night,
    int? asleepMinutes,
    int? inBedMinutes,
    String? bedtime,
    String? wake,
    int? deepMinutes,
    int? remMinutes,
    int? coreMinutes,
    int? awakeMinutes,
    int? wakes,
    EntrySource? source,
    String? sourceRef,
  }) =>
      SleepNight(
        id: id ?? this.id,
        night: night ?? this.night,
        asleepMinutes: asleepMinutes ?? this.asleepMinutes,
        inBedMinutes: inBedMinutes ?? this.inBedMinutes,
        bedtime: bedtime ?? this.bedtime,
        wake: wake ?? this.wake,
        deepMinutes: deepMinutes ?? this.deepMinutes,
        remMinutes: remMinutes ?? this.remMinutes,
        coreMinutes: coreMinutes ?? this.coreMinutes,
        awakeMinutes: awakeMinutes ?? this.awakeMinutes,
        wakes: wakes ?? this.wakes,
        source: source ?? this.source,
        sourceRef: sourceRef ?? this.sourceRef,
      );

  @override
  bool operator ==(Object other) =>
      other is SleepNight &&
      other.id == id &&
      other.night == night &&
      other.asleepMinutes == asleepMinutes &&
      other.inBedMinutes == inBedMinutes &&
      other.bedtime == bedtime &&
      other.wake == wake &&
      other.deepMinutes == deepMinutes &&
      other.remMinutes == remMinutes &&
      other.coreMinutes == coreMinutes &&
      other.awakeMinutes == awakeMinutes &&
      other.wakes == wakes &&
      other.source == source &&
      other.sourceRef == sourceRef;

  @override
  int get hashCode => Object.hash(id, night, asleepMinutes, inBedMinutes,
      bedtime, wake, deepMinutes, remMinutes, coreMinutes, awakeMinutes, wakes,
      source, sourceRef);
}
