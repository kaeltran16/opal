import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Wire keys of the Watch link. The Swift side is `OpalWatchMessage.swift`;
/// the two must spell every key the same.
abstract final class WatchKeys {
  // Watch -> phone: a message's `type`, and the method the relay calls here
  static const type = 'type';
  static const log = 'log';
  static const undo = 'undo';
  static const text = 'text';

  // phone -> Watch: a reply carries `error` or a `type` of result / undone
  static const error = 'error';
  static const result = 'result';
  static const undone = 'undone';
  static const title = 'title';
  static const item = 'item';
  static const amount = 'amount';
  static const unit = 'unit';
  static const detail = 'detail';
  static const value = 'value';
  static const fraction = 'fraction';
  static const bars = 'bars';
  static const reply = 'reply';
}

/// A reply to the Watch, display-ready.
typedef WatchReply = Map<String, Object?>;

/// Shown when the handler itself failed, as opposed to Pal failing.
const _phoneFailed = 'Something went wrong on your iPhone';

const watchChannel = MethodChannel('opal/watch');

/// Binds the Dart end of `opal/watch` (the native end is `OpalWatchRelay`)
/// and tells the relay it is ready. The relay calls `log` and `undo` with the
/// Watch's message and sends the returned map back to the Watch.
///
/// The headless engine passes [afterChange] (push the widget snapshot): it runs
/// after the reply has gone, so the Watch doesn't wait on it, and is followed
/// by `idle` so the relay can stop the engine. The app engine passes
/// [onChanged] instead, which the relay calls after the headless engine wrote
/// to the database, so this engine's drift streams pick the write up.
Future<void> bindWatchChannel({
  required Future<WatchReply> Function(String text) log,
  required Future<WatchReply> Function(Object? token) undo,
  Future<void> Function()? afterChange,
  void Function()? onChanged,
  MethodChannel channel = watchChannel,
}) async {
  channel.setMethodCallHandler((call) async {
    switch (call.method) {
      case 'changed':
        onChanged?.call();
        return null;
      case WatchKeys.log || WatchKeys.undo:
        final reply = await _handle(call, log, undo);
        if (afterChange != null) {
          // a timer, not a microtask: the reply must reach the relay before
          // `idle` does, or the relay sees idle while the request is pending
          Timer.run(() => _settle(channel, reply, afterChange));
        }
        return reply;
      default:
        throw MissingPluginException('opal/watch has no method ${call.method}');
    }
  });
  try {
    await channel.invokeMethod<void>('ready');
  } on MissingPluginException {
    // no native side (tests, or a platform without the relay)
  }
}

Future<WatchReply> _handle(
  MethodCall call,
  Future<WatchReply> Function(String text) log,
  Future<WatchReply> Function(Object? token) undo,
) async {
  final args = call.arguments;
  final message = args is Map ? args : const {};
  try {
    if (call.method == WatchKeys.log) {
      final text = message[WatchKeys.text];
      return await log(text is String ? text : '');
    }
    return await undo(message[WatchKeys.undo]);
  } catch (e, s) {
    debugPrint('opal/watch ${call.method} failed: $e\n$s');
    return {WatchKeys.error: _phoneFailed};
  }
}

Future<void> _settle(
  MethodChannel channel,
  WatchReply reply,
  Future<void> Function() afterChange,
) async {
  try {
    if (!reply.containsKey(WatchKeys.error)) await afterChange();
  } catch (e) {
    debugPrint('opal/watch follow-up failed: $e');
  }
  try {
    await channel.invokeMethod<void>('idle');
  } on MissingPluginException {
    // no native side
  }
}
