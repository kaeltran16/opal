import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// U26 — the Siri Shortcuts / AppIntents seam.
///
/// Wraps the native `opal/intents` [MethodChannel] (see
/// `ios/Runner/Intents/OpalIntentsBridge.swift`). The native side defines two
/// AppIntents — `LogExpenseIntent` and `StartWorkoutIntent` — and an
/// `AppShortcutsProvider` so Siri/Spotlight surface them ("Hey Siri, log an
/// expense in Opal"). When an intent runs it opens the app and hands a
/// deep-link path back through this channel.
///
/// DEEP-LINK CONTRACT (mirrors `AppRoute` in `lib/router.dart`):
///   * Log expense   -> `/entry/new`  (with optional `?amount=`/`?note=`)
///   * Start workout -> `/move/start`
///
/// The app listens to [deepLinks] and `context.go()`s each incoming path so a
/// Siri invocation or a tap on the in-app Siri-shortcut hint chip both route to
/// the same screen.
///
/// On non-iOS platforms (Android/web/desktop/tests) the [Platform
/// SiriShortcutsService] is a silent no-op — AppIntents only exist on iOS 16+
/// and donation/routing can only be verified on a real device (U27).
abstract interface class SiriShortcutsService {
  /// Whether AppIntents are available (true only on iOS 16+ devices).
  Future<bool> isSupported();

  /// Re-publish the app shortcuts to the system (Siri/Spotlight/Shortcuts app).
  ///
  /// The `AppShortcutsProvider` is read automatically by iOS, so this is mostly
  /// a refresh nudge — call it once at app start (and after locale changes).
  /// A no-op where unsupported.
  Future<void> donateShortcuts();

  /// Stream of GoRouter paths produced by a running intent (e.g. `/entry/new`,
  /// `/move/start`, possibly with a query string). Emits for both warm
  /// invocations and the cold-launch path buffered natively until the app is
  /// ready. Broadcast, so multiple listeners are fine.
  Stream<String> get deepLinks;

  /// Pulls any deep-link path that the native side buffered before this service
  /// began listening (a cold launch from a Siri/Spotlight tap). Returns `null`
  /// when there is nothing pending. Call once during app start, after the
  /// router is ready, then rely on [deepLinks] for subsequent invocations.
  Future<String?> consumeInitialDeepLink();

  /// Release the channel handler and close the stream.
  void dispose();
}

/// iOS-backed [SiriShortcutsService] over `MethodChannel('opal/intents')`.
///
/// Native -> Dart: the bridge invokes `openDeepLink` with a path string, which
/// this class forwards onto [deepLinks].
/// Dart -> native: `isSupported`, `donateShortcuts`, `consumeInitialDeepLink`.
class PlatformSiriShortcutsService implements SiriShortcutsService {
  /// Creates the service and starts listening for native `openDeepLink` calls.
  PlatformSiriShortcutsService()
      : _channel = const MethodChannel('opal/intents') {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  final MethodChannel _channel;
  final StreamController<String> _controller =
      StreamController<String>.broadcast();

  @override
  Stream<String> get deepLinks => _controller.stream;

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method == 'openDeepLink') {
      final path = call.arguments;
      if (path is String && path.isNotEmpty && !_controller.isClosed) {
        _controller.add(path);
      }
    }
    return null;
  }

  @override
  Future<bool> isSupported() async {
    try {
      final ok = await _channel.invokeMethod<bool>('isSupported');
      return ok ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> donateShortcuts() async {
    try {
      await _channel.invokeMethod<void>('donateShortcuts');
    } on PlatformException {
      // Donation is best-effort; surfacing in Siri is not load-bearing.
    } on MissingPluginException {
      // Bridge not registered (e.g. older build) — ignore.
    }
  }

  @override
  Future<String?> consumeInitialDeepLink() async {
    try {
      return await _channel.invokeMethod<String>('consumeInitialDeepLink');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    if (!_controller.isClosed) {
      _controller.close();
    }
  }
}

/// No-op [SiriShortcutsService] for every non-iOS target and tests.
///
/// [isSupported] is `false`, donation/consume do nothing, and [deepLinks] is an
/// empty (but live) broadcast stream so listeners attach safely.
class NoopSiriShortcutsService implements SiriShortcutsService {
  NoopSiriShortcutsService();

  final StreamController<String> _controller =
      StreamController<String>.broadcast();

  @override
  Stream<String> get deepLinks => _controller.stream;

  @override
  Future<bool> isSupported() async => false;

  @override
  Future<void> donateShortcuts() async {}

  @override
  Future<String?> consumeInitialDeepLink() async => null;

  @override
  void dispose() {
    if (!_controller.isClosed) {
      _controller.close();
    }
  }
}

/// Picks the right implementation for the current platform: the real
/// channel-backed service on iOS, the no-op everywhere else. Safe to call from a
/// Riverpod provider — see `siriShortcutsServiceProvider` (added by the
/// orchestrator in `providers.dart`).
SiriShortcutsService createSiriShortcutsService() {
  if (!kIsWeb && Platform.isIOS) {
    return PlatformSiriShortcutsService();
  }
  return NoopSiriShortcutsService();
}
