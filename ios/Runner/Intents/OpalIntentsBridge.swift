//
//  OpalIntentsBridge.swift
//  Runner
//
//  U26 — bridge between the native AppIntents (OpalAppIntents.swift) and the
//  Flutter app over a `FlutterMethodChannel("opal/intents")`.
//
//  Responsibilities:
//    1. Let Flutter ask whether AppIntents are supported (`isSupported`) and
//       nudge a shortcut refresh (`donateShortcuts`).
//    2. Deliver the deep-link path an intent produced to Flutter so the app can
//       route it through GoRouter — covering both the cold-launch case (path
//       buffered until Flutter sets up the channel) and the warm case (path
//       pushed immediately as an invoke).
//
//  This lives in the app's `Runner` target. AppDelegate constructs the singleton
//  and registers the channel after the Flutter engine is up (see Integration
//  notes), and forwards any incoming `opal://` URL it receives to
//  `handleDeepLink(_:)`.
//

import Flutter
import Foundation
import UIKit

/// The `opal://` custom URL scheme (registered in `Info.plist`). Declared at
/// top level — and not behind an iOS-16 availability guard like
/// `OpalDeepLink` — so the version-agnostic URL parsing below can reference it.
let opalURLScheme = "opal"

/// Singleton bridge owning the `opal/intents` MethodChannel and a small buffer
/// for deep links that arrive before Flutter is listening.
final class OpalIntentsBridge: NSObject {
  /// Shared instance the intents call into (they have no reference to the
  /// AppDelegate). Created lazily; AppDelegate wires the channel on launch.
  static let shared = OpalIntentsBridge()

  /// Name of the MethodChannel; must match `SiriShortcutsService` in Dart.
  static let channelName = "opal/intents"

  /// Flutter -> native / native -> Flutter method channel. Nil until
  /// `register(with:)` runs.
  private var channel: FlutterMethodChannel?

  /// Deep-link path buffered until Flutter has registered. On a cold launch the
  /// intent fires and the URL arrives before Dart calls `donateShortcuts`/sets
  /// up its handler, so we hold the most recent path and flush it on register
  /// (and whenever Flutter explicitly asks via `consumeInitialDeepLink`).
  private var pendingPath: String?

  private override init() {
    super.init()
  }

  // MARK: - Registration

  /// Registers the method channel against the app's Flutter engine. Call from
  /// `AppDelegate` once the engine/registrar is available.
  func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: Self.channelName,
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    self.channel = channel
  }

  // MARK: - Flutter -> native

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isSupported":
      // AppIntents (and thus our shortcuts) require iOS 16+.
      if #available(iOS 16.0, *) {
        result(true)
      } else {
        result(false)
      }

    case "donateShortcuts":
      // AppShortcutsProvider is read automatically by the system, but calling
      // `updateAppShortcutParameters()` re-publishes them after the app's data
      // (e.g. localized phrases / parameter values) may have changed.
      if #available(iOS 16.0, *) {
        OpalAppShortcuts.updateAppShortcutParameters()
      }
      result(nil)

    case "consumeInitialDeepLink":
      // Flutter pulls any path that was buffered before its handler was ready
      // (cold launch from a Siri/Spotlight tap). Returns nil if none.
      let path = pendingPath
      pendingPath = nil
      result(path)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Native -> Flutter

  /// Records a deep-link `URL` produced by an intent. Called from
  /// `OpalAppIntents` inside `perform()`. We store the path and, if Flutter is
  /// already listening, push it straight away.
  func enqueueDeepLink(_ url: URL) {
    handleDeepLink(url)
  }

  /// Normalizes an incoming `opal://` URL into a GoRouter path (host + path +
  /// query) and pushes it to Flutter, buffering if Flutter isn't ready yet.
  ///
  /// AppDelegate/SceneDelegate call this from `application(_:open:options:)` /
  /// `scene(_:openURLContexts:)` for URLs whose scheme is `opal`.
  func handleDeepLink(_ url: URL) {
    guard let path = Self.routerPath(from: url) else { return }
    push(path)
  }

  /// Converts `opal://entry/new?amount=12` -> `/entry/new?amount=12`.
  /// Returns nil for non-`opal` URLs so callers can ignore unrelated opens.
  static func routerPath(from url: URL) -> String? {
    guard url.scheme == opalURLScheme else { return nil }
    let host = url.host ?? ""
    var path = "/" + host + url.path
    if let query = url.query, !query.isEmpty {
      path += "?" + query
    }
    return path
  }

  /// Pushes `path` to Flutter via the channel, or buffers it if the channel
  /// isn't registered yet (cold launch).
  private func push(_ path: String) {
    if let channel {
      // Ensure UI-thread delivery; MethodChannel must be used on the platform
      // (main) thread.
      DispatchQueue.main.async {
        channel.invokeMethod("openDeepLink", arguments: path)
      }
    } else {
      pendingPath = path
    }
  }
}
