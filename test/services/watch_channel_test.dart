import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/services/services.dart'
    show ChannelWatchWorkoutService, WatchKeys, WatchReply, WatchWorkoutStats, bindWatchChannel, noWorkout;

const _channel = MethodChannel('opal/watch.test');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// What the Dart side sent to the relay, in order.
  late List<String> sent;

  setUp(() {
    sent = [];
    messenger.setMockMethodCallHandler(_channel, (call) async {
      sent.add(call.method);
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(_channel, null);
    _channel.setMethodCallHandler(null);
  });

  /// Calls [method] on the Dart side the way the relay does and decodes its reply.
  Future<Object?> relayCalls(String method, [Object? arguments]) async {
    const codec = StandardMethodCodec();
    final reply = Completer<ByteData?>();
    await messenger.handlePlatformMessage(
      _channel.name,
      codec.encodeMethodCall(MethodCall(method, arguments)),
      reply.complete,
    );
    return codec.decodeEnvelope((await reply.future)!);
  }

  Future<WatchReply> logged(String text) async => {WatchKeys.type: WatchKeys.result, WatchKeys.item: text};
  Future<WatchReply> undone(Object? token) async => {WatchKeys.type: WatchKeys.undone, 'token': token};

  test('tells the relay it is ready once bound', () async {
    await bindWatchChannel(log: logged, undo: undone, channel: _channel);

    expect(sent, ['ready']);
  });

  test('a log returns the handler\'s reply for the Watch', () async {
    await bindWatchChannel(log: logged, undo: undone, channel: _channel);

    final reply = await relayCalls(WatchKeys.log, {WatchKeys.type: WatchKeys.log, WatchKeys.text: 'coffee'});

    expect(reply, {WatchKeys.type: WatchKeys.result, WatchKeys.item: 'coffee'});
  });

  test('an undo hands the handler the token from the message', () async {
    await bindWatchChannel(log: logged, undo: undone, channel: _channel);

    final reply = await relayCalls(WatchKeys.undo, {
      WatchKeys.type: WatchKeys.undo,
      WatchKeys.undo: ['t'],
    });

    expect(reply, {WatchKeys.type: WatchKeys.undone, 'token': ['t']});
  });

  test('a handler that throws still answers the Watch with an error', () async {
    await bindWatchChannel(
      log: (_) async => throw StateError('db closed'),
      undo: undone,
      channel: _channel,
    );

    final reply = await relayCalls(WatchKeys.log, {WatchKeys.text: 'coffee'});

    expect((reply as Map)[WatchKeys.error], isA<String>());
  });

  test('the headless follow-up runs after the reply, then idle is sent', () async {
    final followUp = Completer<void>();
    await bindWatchChannel(
      log: logged,
      undo: undone,
      afterChange: () {
        sent.add('afterChange');
        return followUp.future;
      },
      channel: _channel,
    );

    // the follow-up is still pending here, so a reply that waited on it would hang
    await relayCalls(WatchKeys.log, {WatchKeys.text: 'coffee'});

    await pumpEventQueue();
    expect(sent, ['ready', 'afterChange'], reason: 'idle waits for the follow-up');

    followUp.complete();
    await pumpEventQueue();
    expect(sent, ['ready', 'afterChange', 'idle']);
  });

  test('an error reply skips the follow-up but still sends idle', () async {
    await bindWatchChannel(
      log: (_) async => {WatchKeys.error: 'offline'},
      undo: undone,
      afterChange: () async => sent.add('afterChange'),
      channel: _channel,
    );

    await relayCalls(WatchKeys.log, {WatchKeys.text: 'coffee'});
    await pumpEventQueue();

    expect(sent, ['ready', 'idle']);
  });

  test('the app engine sends no idle', () async {
    await bindWatchChannel(log: logged, undo: undone, channel: _channel);

    await relayCalls(WatchKeys.log, {WatchKeys.text: 'coffee'});
    await pumpEventQueue();

    expect(sent, ['ready']);
  });

  test('changed from the relay refreshes the app engine', () async {
    var refreshed = 0;
    await bindWatchChannel(
      log: logged,
      undo: undone,
      onChanged: () => refreshed++,
      channel: _channel,
    );

    await relayCalls('changed');

    expect(refreshed, 1);
  });

  group('workout', () {
    final command = {WatchKeys.type: WatchKeys.workout, WatchKeys.command: WatchKeys.state};

    test('goes to the workout handler, with no follow-up or idle', () async {
      Map<Object?, Object?>? got;
      await bindWatchChannel(
        log: logged,
        undo: undone,
        workout: (message) async {
          got = message;
          return {WatchKeys.type: WatchKeys.workout, WatchKeys.phase: WatchKeys.phaseSet};
        },
        afterChange: () async => sent.add('afterChange'),
        channel: _channel,
      );

      final reply = await relayCalls(WatchKeys.workout, command);
      await pumpEventQueue();

      expect(got, command);
      expect((reply as Map)[WatchKeys.phase], WatchKeys.phaseSet);
      expect(sent, ['ready']);
    });

    test('an engine without the session says no workout is running', () async {
      await bindWatchChannel(log: logged, undo: undone, channel: _channel);

      expect(await relayCalls(WatchKeys.workout, command), noWorkout);
    });

    test('a workout handler that throws answers with an error', () async {
      await bindWatchChannel(
        log: logged,
        undo: undone,
        workout: (_) async => throw StateError('no session'),
        channel: _channel,
      );

      final reply = await relayCalls(WatchKeys.workout, command);

      expect((reply as Map)[WatchKeys.error], isA<String>());
    });
  });

  group('ChannelWatchWorkoutService', () {
    late List<MethodCall> calls;
    late Object? Function(MethodCall call) answer;
    const service = ChannelWatchWorkoutService(
      channel: _channel,
      endTimeout: Duration(milliseconds: 50),
    );

    setUp(() {
      calls = [];
      answer = (_) => null;
      messenger.setMockMethodCallHandler(_channel, (call) async {
        calls.add(call);
        final reply = answer(call);
        return reply is Future ? await reply : reply;
      });
    });

    test('start and push reach the native side with their arguments', () async {
      await service.start(cardio: true);
      await service.push({WatchKeys.rev: 3});

      expect(calls.map((c) => c.method), ['startWorkout', 'pushWorkout']);
      expect(calls[0].arguments, {'cardio': true});
      expect(calls[1].arguments, {WatchKeys.rev: 3});
    });

    test('end returns what the Watch measured', () async {
      answer = (_) => {WatchKeys.heartRate: 127.6, WatchKeys.kcal: 401};

      expect(await service.end(), const WatchWorkoutStats(heartRate: 128, kcal: 401));
    });

    test('end gives up on a Watch that is slow, unreachable or says nothing', () async {
      answer = (_) => Future<Object?>.delayed(const Duration(seconds: 1));
      expect(await service.end(), isNull);

      answer = (_) => throw PlatformException(code: 'unreachable');
      expect(await service.end(), isNull);

      answer = (_) => <String, Object?>{};
      expect(await service.end(), isNull);
    });

    test('a failing push does not throw', () async {
      answer = (_) => throw PlatformException(code: 'inactive');

      await service.push({WatchKeys.rev: 1});
    });
  });
}
