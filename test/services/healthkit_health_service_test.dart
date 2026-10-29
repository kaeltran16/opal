import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/services/health/healthkit_health_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('opal/health');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  /// Answers `requestAuthorization` with success and every other method from
  /// [replies]; returns the calls made, in order.
  List<MethodCall> stubBridge(Map<String, Object?> replies) {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'requestAuthorization' ? null : replies[call.method];
    });
    return calls;
  }

  int ms(DateTime t) => t.millisecondsSinceEpoch;

  Map<String, Object> sample(
          String source, String stage, DateTime start, DateTime end) =>
      {'source': source, 'stage': stage, 'startMs': ms(start), 'endMs': ms(end)};

  const watch = 'com.apple.health.watch';
  const phone = 'com.apple.health.phone';

  // ---------------------------------------------------------------------------
  // fetchDay
  // ---------------------------------------------------------------------------

  test('fetchDay asks for the local calendar day and rounds the totals', () async {
    final calls = stubBridge({
      'day': {'steps': 6012.6, 'activeEnergyKcal': 410.4},
    });

    final day = await HealthKitHealthService().fetchDay(DateTime(2026, 6, 7, 15, 30));

    expect(day.steps, 6013);
    expect(day.activeEnergyKcal, 410);
    final query = calls.singleWhere((c) => c.method == 'day');
    expect(query.arguments, {
      'startMs': ms(DateTime(2026, 6, 7)),
      'endMs': ms(DateTime(2026, 6, 8)),
    });
  });

  test('fetchDay reads missing totals as 0', () async {
    stubBridge({'day': <String, Object>{}});

    final day = await HealthKitHealthService().fetchDay(DateTime(2026, 6, 7));

    expect(day.steps, 0);
    expect(day.activeEnergyKcal, 0);
  });

  // ---------------------------------------------------------------------------
  // authorization
  // ---------------------------------------------------------------------------

  test('asks for Health access once across day and sleep reads', () async {
    final calls = stubBridge({'day': <String, Object>{}, 'sleepSamples': []});
    final service = HealthKitHealthService();

    await Future.wait([
      service.fetchDay(DateTime(2026, 6, 7)),
      service.fetchSleep(DateTime(2026, 6, 1), DateTime(2026, 6, 8)),
    ]);
    await service.fetchDay(DateTime(2026, 6, 8));

    expect(calls.where((c) => c.method == 'requestAuthorization'), hasLength(1));
    expect(calls.first.method, 'requestAuthorization');
  });

  test('a failed authorization fails the read and is asked again next time',
      () async {
    var authAttempts = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'requestAuthorization') {
        authAttempts++;
        if (authAttempts == 1) {
          throw PlatformException(code: 'unavailable');
        }
        return null;
      }
      return <String, Object>{};
    });
    final service = HealthKitHealthService();

    await expectLater(
        service.fetchDay(DateTime(2026, 6, 7)), throwsA(isA<PlatformException>()));
    await service.fetchDay(DateTime(2026, 6, 7));

    expect(authAttempts, 2);
  });

  // ---------------------------------------------------------------------------
  // fetchSleep
  // ---------------------------------------------------------------------------

  test('fetchSleep reads samples from noon on [from] to noon on [to]', () async {
    final calls = stubBridge({'sleepSamples': []});

    await HealthKitHealthService()
        .fetchSleep(DateTime(2026, 6, 1), DateTime(2026, 6, 8));

    final query = calls.singleWhere((c) => c.method == 'sleepSamples');
    expect(query.arguments, {
      'startMs': ms(DateTime(2026, 6, 1, 12)),
      'endMs': ms(DateTime(2026, 6, 8, 12)),
    });
  });

  test('keeps the source with stages instead of adding iPhone and Watch',
      () async {
    DateTime t(int day, int h, int m) => DateTime(2026, 6, day, h, m);
    stubBridge({
      'sleepSamples': [
        // iPhone: more time asleep on paper, but no stages
        sample(phone, 'inBed', t(7, 22, 50), t(8, 7, 10)),
        sample(phone, 'asleep', t(7, 23, 0), t(8, 7, 5)),
        // Watch
        sample(watch, 'core', t(7, 23, 10), t(8, 1, 10)),
        sample(watch, 'awake', t(8, 1, 10), t(8, 1, 20)),
        sample(watch, 'deep', t(8, 1, 20), t(8, 2, 30)),
        sample(watch, 'rem', t(8, 2, 30), t(8, 3, 30)),
        sample(watch, 'core', t(8, 3, 30), t(8, 6, 50)),
        sample(watch, 'awake', t(8, 6, 50), t(8, 7, 0)),
      ],
    });

    final nights = await HealthKitHealthService()
        .fetchSleep(DateTime(2026, 6, 7), DateTime(2026, 6, 8));

    expect(nights, hasLength(1));
    final n = nights.single;
    expect(n.night, DateTime(2026, 6, 7));
    expect(n.asleepMinutes, 450);
    expect(n.coreMinutes, 320);
    expect(n.deepMinutes, 70);
    expect(n.remMinutes, 60);
    expect(n.awakeMinutes, 20);
    // the trailing awake spell after the last sleep isn't a wake-up
    expect(n.wakes, 1);
    // the Watch wrote no in-bed samples, so its span stands in
    expect(n.inBedMinutes, 470);
    expect(n.bedtime, '23:10');
    expect(n.wake, '7:00');
    expect(n.sourceRef, isNull);
  });

  test('a bedtime after midnight counts toward the evening before; nights sort by date',
      () async {
    stubBridge({
      'sleepSamples': [
        sample(watch, 'core', DateTime(2026, 6, 8, 1, 0), DateTime(2026, 6, 8, 7, 0)),
        sample(watch, 'core', DateTime(2026, 6, 6, 23, 0), DateTime(2026, 6, 7, 6, 0)),
      ],
    });

    final nights = await HealthKitHealthService()
        .fetchSleep(DateTime(2026, 6, 6), DateTime(2026, 6, 8));

    expect(nights.map((n) => n.night), [DateTime(2026, 6, 6), DateTime(2026, 6, 7)]);
    expect(nights.last.bedtime, '1:00');
    expect(nights.last.wake, '7:00');
    expect(nights.last.asleepMinutes, 360);
  });

  test('an iPhone-only night without stages uses its asleep and in-bed time',
      () async {
    stubBridge({
      'sleepSamples': [
        sample(phone, 'inBed', DateTime(2026, 6, 7, 22, 30), DateTime(2026, 6, 8, 7, 15)),
        sample(phone, 'asleep', DateTime(2026, 6, 7, 23, 0), DateTime(2026, 6, 8, 7, 0)),
      ],
    });

    final n = (await HealthKitHealthService()
            .fetchSleep(DateTime(2026, 6, 7), DateTime(2026, 6, 8)))
        .single;

    expect(n.asleepMinutes, 480);
    expect(n.inBedMinutes, 525);
    expect(n.deepMinutes + n.remMinutes + n.coreMinutes, 0);
    expect(n.bedtime, '22:30');
    expect(n.wake, '7:15');
  });

  test('a night with only in-bed time is left out', () async {
    stubBridge({
      'sleepSamples': [
        sample(phone, 'inBed', DateTime(2026, 6, 7, 22, 30), DateTime(2026, 6, 8, 7, 0)),
      ],
    });

    final nights = await HealthKitHealthService()
        .fetchSleep(DateTime(2026, 6, 7), DateTime(2026, 6, 8));

    expect(nights, isEmpty);
  });
}
