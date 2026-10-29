import 'package:flutter/services.dart';

import 'health_service.dart';

/// [HealthService] backed by Apple Health on the device, over the native
/// `opal/health` [MethodChannel] (ios/Runner/Health/OpalHealthBridge.swift).
///
/// Day totals are summed natively by HealthKit, which merges overlapping
/// iPhone and Watch samples. Sleep arrives as raw samples and is grouped into
/// nights here. Errors (no bridge, Health unavailable) propagate; the sync
/// controllers treat health as best-effort.
class HealthKitHealthService implements HealthService {
  HealthKitHealthService({
    MethodChannel channel = const MethodChannel('opal/health'),
    // Named params can't be private, so an initializing formal isn't possible
    // while keeping `channel` injectable for tests.
    // ignore: prefer_initializing_formals
  }) : _channel = channel;

  final MethodChannel _channel;
  Future<void>? _authorization;

  /// A night runs noon to noon, so a bedtime after midnight still counts
  /// toward the evening before (the date [HealthSleep.night] carries).
  static const int _nightStartHour = 12;

  static const _asleepStages = {'core', 'deep', 'rem', 'asleep'};
  static const _detailedStages = {'core', 'deep', 'rem'};

  @override
  Future<HealthDay> fetchDay(DateTime day) async {
    await _authorize();
    final totals = await _channel.invokeMapMethod<String, num>('day', {
      'startMs': DateTime(day.year, day.month, day.day).millisecondsSinceEpoch,
      'endMs': DateTime(day.year, day.month, day.day + 1).millisecondsSinceEpoch,
    });
    return HealthDay(
      activeEnergyKcal: (totals?['activeEnergyKcal'] ?? 0).round(),
      steps: (totals?['steps'] ?? 0).round(),
    );
  }

  @override
  Future<List<HealthSleep>> fetchSleep(DateTime from, DateTime to) async {
    await _authorize();
    final rows = await _channel.invokeListMethod<Map<Object?, Object?>>(
      'sleepSamples',
      {
        'startMs': _nightStart(from).millisecondsSinceEpoch,
        'endMs': _nightStart(to).millisecondsSinceEpoch,
      },
    );
    final byNight = <DateTime, List<_Sample>>{};
    for (final row in rows ?? const <Map<Object?, Object?>>[]) {
      final sample = _Sample.fromMap(row);
      final evening = sample.start.subtract(const Duration(hours: _nightStartHour));
      byNight
          .putIfAbsent(DateTime(evening.year, evening.month, evening.day), () => [])
          .add(sample);
    }
    final nights = [
      for (final entry in byNight.entries) ?_night(entry.key, entry.value),
    ]..sort((a, b) => a.night.compareTo(b.night));
    return nights;
  }

  /// Shows the Health permission sheet the first time; afterwards iOS answers
  /// at once. Shared so the day and sleep syncs at launch don't both ask, and
  /// cleared on failure so the next sync asks again.
  Future<void> _authorize() {
    return _authorization ??= _channel
        .invokeMethod<void>('requestAuthorization')
        .then((_) {}, onError: (Object e, StackTrace s) {
      _authorization = null;
      Error.throwWithStackTrace(e, s);
    });
  }

  static DateTime _nightStart(DateTime d) =>
      DateTime(d.year, d.month, d.day, _nightStartHour);

  /// One night from one source: the iPhone and the Watch both record sleep,
  /// and adding them up would double it. Prefers a source with sleep stages
  /// (the Watch), then the one with the most time asleep. Null when no source
  /// recorded time asleep (an in-bed-only night).
  static HealthSleep? _night(DateTime night, List<_Sample> samples) {
    final bySource = <String, List<_Sample>>{};
    for (final s in samples) {
      bySource.putIfAbsent(s.source, () => []).add(s);
    }
    final chosen = bySource.values
        .reduce((a, b) => _compareSources(b, a) > 0 ? b : a)
      ..sort((a, b) => a.start.compareTo(b.start));

    final asleep = chosen.where((s) => _asleepStages.contains(s.stage)).toList();
    if (asleep.isEmpty) return null;
    final inBed = chosen.where((s) => s.stage == 'inBed');
    final awake = chosen.where((s) => s.stage == 'awake');

    final first = chosen.first.start;
    final last = chosen.map((s) => s.end).reduce((a, b) => a.isAfter(b) ? a : b);
    final asleepStart = asleep.first.start;
    final asleepEnd = asleep.map((s) => s.end).reduce((a, b) => a.isAfter(b) ? a : b);

    return HealthSleep(
      night: night,
      asleepMinutes: _minutes(asleep),
      // a Watch-only night has no in-bed samples; its span stands in.
      inBedMinutes: inBed.isEmpty
          ? (last.difference(first).inSeconds / 60).round()
          : _minutes(inBed),
      bedtime: _clock(first),
      wake: _clock(last),
      deepMinutes: _minutes(chosen.where((s) => s.stage == 'deep')),
      remMinutes: _minutes(chosen.where((s) => s.stage == 'rem')),
      coreMinutes: _minutes(chosen.where((s) => s.stage == 'core')),
      awakeMinutes: _minutes(awake),
      // only awake spells between sleep count as waking up; lying awake before
      // falling asleep or after the last sleep doesn't.
      wakes: awake
          .where((s) => s.start.isAfter(asleepStart) && s.end.isBefore(asleepEnd))
          .length,
    );
  }

  /// Orders sources: having detailed stages beats not, then more time asleep.
  static int _compareSources(List<_Sample> a, List<_Sample> b) {
    bool staged(List<_Sample> x) =>
        x.any((s) => _detailedStages.contains(s.stage));
    int asleepSeconds(List<_Sample> x) =>
        _seconds(x.where((s) => _asleepStages.contains(s.stage)));
    if (staged(a) != staged(b)) return staged(a) ? 1 : -1;
    return asleepSeconds(a).compareTo(asleepSeconds(b));
  }

  static int _seconds(Iterable<_Sample> samples) =>
      samples.fold(0, (sum, s) => sum + s.end.difference(s.start).inSeconds);

  static int _minutes(Iterable<_Sample> samples) =>
      (_seconds(samples) / 60).round();

  /// Display clock, 24-hour without a leading zero: "23:14", "7:02".
  static String _clock(DateTime t) =>
      '${t.hour}:${t.minute.toString().padLeft(2, '0')}';
}

/// One sleep sample as the bridge sends it.
class _Sample {
  _Sample.fromMap(Map<Object?, Object?> m)
      : start = DateTime.fromMillisecondsSinceEpoch(m['startMs']! as int),
        end = DateTime.fromMillisecondsSinceEpoch(m['endMs']! as int),
        stage = m['stage']! as String,
        source = m['source']! as String;

  final DateTime start, end;
  final String stage, source;
}
