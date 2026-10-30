import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/services/services.dart' show WatchKeys, WatchReply, bindWatchChannel;

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
}
