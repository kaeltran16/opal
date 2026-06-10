//
//  OpalAppIntents.swift
//  Runner
//
//  U26 — Siri Shortcuts / AppIntents.
//
//  Two AppIntents (`LogExpenseIntent`, `StartWorkoutIntent`) plus an
//  `AppShortcutsProvider` that donates them so Siri and Spotlight surface them
//  ("Hey Siri, log an expense in Opal"). Both intents open the app and hand a
//  deep-link URL to the running `Runner` so the Flutter side can route it.
//
//  DEEP-LINK CONTRACT (mirrors `lib/router.dart`):
//    • Log expense   -> opal://entry/new   (GoRouter path `/entry/new`)
//    • Start workout -> opal://move/start  (GoRouter path `/move/start`)
//
//  These run in the app's `Runner` target (a Flutter app has no separate
//  AppIntents extension), so when the intent runs the app comes to the
//  foreground and the URL is delivered to `AppDelegate`/`SceneDelegate`, which
//  forwards the path to Flutter over the `opal/intents` MethodChannel.
//
//  Requires iOS 16.0+ (the AppIntents framework). All declarations are guarded
//  with `@available(iOS 16.0, *)` so the file compiles for older deployment
//  targets even though the intents are inert there.
//

import AppIntents
import Foundation

// MARK: - Shared deep-link constants

/// Deep-link paths/URLs shared between the intents and the bridge. Keep these
/// in sync with `AppRoute` in `lib/router.dart`.
@available(iOS 16.0, *)
enum OpalDeepLink {
  /// Custom URL scheme registered in `Info.plist` (`CFBundleURLTypes`). Mirrors
  /// the top-level `opalURLScheme` constant in `OpalIntentsBridge.swift`.
  static let scheme = opalURLScheme

  /// GoRouter path for the New Entry sheet (log an expense).
  static let logExpensePath = "/entry/new"

  /// GoRouter path for the Start Workout screen.
  static let startWorkoutPath = "/move/start"

  /// Builds an `opal://` URL for `path`, appending any non-nil query items.
  ///
  /// e.g. `url(for: "/entry/new", queryItems: [.init(name: "amount", value: "12")])`
  /// -> `opal://entry/new?amount=12`. The Flutter router reads these via
  /// `state.uri.queryParameters`.
  static func url(for path: String, queryItems: [URLQueryItem] = []) -> URL {
    var components = URLComponents()
    components.scheme = scheme
    // `URLComponents` treats the segment after the scheme as the host; the
    // leading "/entry/new" becomes host="entry", path="/new". GoRouter only
    // cares about the reconstructed `host + path`, so we set host to the first
    // segment and path to the remainder to keep `opal://entry/new` intact.
    let trimmed = path.hasPrefix("/") ? String(path.dropFirst()) : path
    if let slash = trimmed.firstIndex(of: "/") {
      components.host = String(trimmed[..<slash])
      components.path = String(trimmed[slash...])
    } else {
      components.host = trimmed
    }
    if !queryItems.isEmpty {
      components.queryItems = queryItems
    }
    // Fallback to a hand-built URL if components ever fail to compose.
    return components.url ?? URL(string: "\(scheme)://\(trimmed)")!
  }
}

// MARK: - Log expense

/// "Log expense" — opens Opal on the New Entry sheet so the user can record a
/// spend. Optionally seeds the sheet with an amount/note passed by Siri.
@available(iOS 16.0, *)
struct LogExpenseIntent: AppIntent {
  static var title: LocalizedStringResource = "Log expense"
  static var description = IntentDescription(
    "Opens Opal and starts a new expense entry."
  )

  /// Bring the app to the foreground when Siri/Spotlight runs this.
  static var openAppWhenRun: Bool = true

  /// Optional amount Siri can capture ("log a 12 dollar expense in Opal").
  /// Requesting a value is left to the app UI, so this is non-`requestValueIfMissing`.
  @Parameter(title: "Amount")
  var amount: Double?

  /// Optional free-text note for the entry.
  @Parameter(title: "Note")
  var note: String?

  static var parameterSummary: some ParameterSummary {
    Summary("Log expense of \(\.$amount)")
  }

  @MainActor
  func perform() async throws -> some IntentResult & OpensIntent {
    var items: [URLQueryItem] = []
    if let amount, amount > 0 {
      items.append(URLQueryItem(name: "amount", value: String(amount)))
    }
    if let note, !note.isEmpty {
      items.append(URLQueryItem(name: "note", value: note))
    }
    let url = OpalDeepLink.url(for: OpalDeepLink.logExpensePath, queryItems: items)

    // Note the deep link for the app to route. `OpenURLIntent` (below) brings
    // the app forward; the bridge also records the URL so a foregrounded app
    // that doesn't receive `open url:` still gets routed.
    OpalIntentsBridge.shared.enqueueDeepLink(url)
    return .result(opensIntent: OpenURLIntent(url))
  }
}

// MARK: - Start workout

/// "Start workout" — opens Opal on the Start Workout screen.
@available(iOS 16.0, *)
struct StartWorkoutIntent: AppIntent {
  static var title: LocalizedStringResource = "Start workout"
  static var description = IntentDescription(
    "Opens Opal and begins a new workout."
  )

  static var openAppWhenRun: Bool = true

  static var parameterSummary: some ParameterSummary {
    Summary("Start a workout")
  }

  @MainActor
  func perform() async throws -> some IntentResult & OpensIntent {
    let url = OpalDeepLink.url(for: OpalDeepLink.startWorkoutPath)
    OpalIntentsBridge.shared.enqueueDeepLink(url)
    return .result(opensIntent: OpenURLIntent(url))
  }
}

// MARK: - App Shortcuts (Siri / Spotlight surfacing)

/// Registers both intents as `AppShortcut`s with natural-language phrases so the
/// system surfaces them in Siri, Spotlight, and the Shortcuts app without the
/// user adding them manually. `applicationName` resolves to the app's display
/// name ("Opal") at runtime.
///
/// The orchestrator does NOT need to call anything to register these — the
/// system reads `AppShortcutsProvider` at install/launch. `donateShortcuts()`
/// on the Flutter side just nudges a refresh (see `OpalIntentsBridge`).
@available(iOS 16.0, *)
struct OpalAppShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: LogExpenseIntent(),
      phrases: [
        "Log an expense in \(.applicationName)",
        "Log expense in \(.applicationName)",
        "Add an expense to \(.applicationName)",
        "Record a spend in \(.applicationName)",
      ],
      shortTitle: "Log expense",
      systemImageName: "creditcard"
    )
    AppShortcut(
      intent: StartWorkoutIntent(),
      phrases: [
        "Start a workout in \(.applicationName)",
        "Start workout in \(.applicationName)",
        "Begin a workout in \(.applicationName)",
        "Work out with \(.applicationName)",
      ],
      shortTitle: "Start workout",
      systemImageName: "figure.run"
    )
  }

  /// Surface these prominently in Spotlight/Siri suggestions.
  static var shortcutTileColor: ShortcutTileColor = .navy
}
