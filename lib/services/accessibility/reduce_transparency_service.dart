import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The iOS Reduce Transparency setting, live. [GlassSurface] swaps its blur
/// for a solid fill while this is `true`.
///
/// Flutter's `MediaQuery` does not expose Reduce Transparency, so iOS reports
/// it over the `opal/accessibility` [MethodChannel] (see `AppDelegate.swift`).
/// Everywhere else wire [NoopReduceTransparencyService].
abstract interface class ReduceTransparencyService {
  /// Emits the current value first, then every change.
  Stream<bool> watch();
}

/// Reduce Transparency is always off (web, tests, desktop, Android).
class NoopReduceTransparencyService implements ReduceTransparencyService {
  const NoopReduceTransparencyService();

  @override
  Stream<bool> watch() => Stream.value(false);
}

/// iOS-backed [ReduceTransparencyService]. Asks `isReduceTransparencyEnabled`
/// for the first value, then relays the native `reduceTransparencyChanged`
/// calls. A missing or failing bridge emits `false` so glass still renders.
class MethodChannelReduceTransparencyService
    implements ReduceTransparencyService {
  const MethodChannelReduceTransparencyService({
    MethodChannel channel = const MethodChannel('opal/accessibility'),
    // Named params can't be private, so an initializing formal isn't possible
    // while keeping `channel` injectable for tests.
    // ignore: prefer_initializing_formals
  }) : _channel = channel;

  final MethodChannel _channel;

  @override
  Stream<bool> watch() {
    final controller = StreamController<bool>();
    // a change that lands before the initial read answers is newer than it.
    var changed = false;
    controller.onListen = () async {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'reduceTransparencyChanged' &&
            call.arguments is bool) {
          changed = true;
          controller.add(call.arguments as bool);
        }
      });
      final initial = await _initial();
      if (!changed) controller.add(initial);
    };
    controller.onCancel = () => _channel.setMethodCallHandler(null);
    return controller.stream;
  }

  Future<bool> _initial() async {
    try {
      return await _channel.invokeMethod<bool>('isReduceTransparencyEnabled') ??
          false;
    } on MissingPluginException catch (e) {
      debugPrint('reduce transparency bridge unavailable: $e');
      return false;
    } on PlatformException catch (e) {
      debugPrint('reduce transparency bridge unavailable: $e');
      return false;
    }
  }
}
