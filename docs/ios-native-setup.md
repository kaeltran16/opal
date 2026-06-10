# iOS native setup (U25–U27)

Status of the iOS-native units and what remains. The Xcode-project wiring that
the original handoff said needed manual GUI work is now **done programmatically**
via `ios/configure_native_targets.rb` (uses the `xcodeproj` gem — re-runnable;
idempotent). Everything builds for the simulator; 96 Flutter tests green; analyze
clean.

## Account constraint (important)

There is **no paid Apple Developer account** — only a free Apple ID / Personal
Team is available. That decides what can be verified:

- **U25 Live Activities / Dynamic Island** and **U26 Siri / AppIntents** need no
  paid entitlement. They build and run on the simulator (Dynamic Island renders
  on iPhone 15/16/17 Pro sims) and sideload on a real device with a free team.
- **U27 HealthKit** requires the `com.apple.developer.healthkit` entitlement,
  which a free Personal Team **cannot provision** — including it breaks device
  signing. So the entitlement is deliberately **NOT** added. `HealthKitService`
  degrades gracefully without it (commit `a03387c`); real HealthKit data stays
  unverifiable until a paid account exists.

## What's wired (done)

**Xcode project** (`ios/configure_native_targets.rb`):
- The four Runner-target Swift files (`OpalWorkoutAttributes`,
  `OpalLiveActivityBridge`, `OpalAppIntents`, `OpalIntentsBridge`) are in Runner's
  compile sources.
- A new **`OpalWidgets`** app-extension target (bundle id
  `com.opal.opal.OpalWidgets`, iOS 26.0, Swift 5.0) builds the Live Activity:
  members `OpalWorkoutLiveActivity.swift`, `OpalWidgetsBundle.swift` (the `@main`
  WidgetBundle), and the shared `OpalWorkoutAttributes.swift`. Its `Info.plist`
  declares the `com.apple.widgetkit-extension` point.
- The extension is embedded in Runner via an **Embed App Extensions** copy phase,
  ordered **before** Flutter's "Thin Binary" phase — this avoids the
  `ExtractAppIntentsMetadata` ↔ embed-appex build dependency cycle.

**Native glue:**
- `AppDelegate.didInitializeImplicitFlutterEngine` registers both bridges on the
  engine messenger (via a borrowed `registrar(forPlugin:)`), so the
  `opal/live_activity` and `opal/intents` MethodChannels resolve.
- `SceneDelegate` overrides `scene(_:willConnectTo:options:)` (cold launch) and
  `scene(_:openURLContexts:)` (warm), calls `super`, and forwards every `opal://`
  URL to `OpalIntentsBridge.handleDeepLink` — covering both Live-Activity taps
  (`opal://session/<id>`) and AppIntent opens (`opal://entry/new`, `opal://move/start`).

**Dart call-sites:**
- `workout_session_controller.dart` starts the Live Activity when a session
  builds, pushes content updates on set-logged / rest start-skip-extend-end (not
  per tick — the island self-ticks from `startedAt`), and ends it on `finish()`
  and `onDispose`.
- `app.dart` subscribes to `SiriShortcutsService.deepLinks` → `router.go(path)`
  with an immediate-duplicate guard, calls `donateShortcuts()` once, and drains
  `consumeInitialDeepLink()` on the first frame (cold-launch tap).
- Providers (`liveActivityServiceProvider`, `siriShortcutsServiceProvider`,
  `healthService`, `notificationService`) were already iOS-gated.

**Tests:** `test/deep_link_routing_test.dart` exercises the deep-link → router
wiring (route + dedup) with a fake Siri service.

## Verified automatically

- `flutter build ios --simulator --debug` succeeds; `OpalWidgets.appex` is
  embedded under `Runner.app/PlugIns/`.
- App launches on the iPhone 17 Pro simulator without crashing; the `opal://`
  scheme is registered (iOS shows the "Open in Opal?" prompt on `simctl openurl`).

## Remaining — manual / device QA only

These are inherently interactive and can't be automated headlessly:

1. **Signing:** open `ios/Runner.xcworkspace` in Xcode → select the Runner *and*
   OpalWidgets targets → Signing & Capabilities → pick your free Personal Team.
   (No `DEVELOPMENT_TEAM` is committed.)
2. **U25 Dynamic Island:** start a workout; confirm the island shows the ticking
   timer, current exercise, set count, and rest countdown; tap it → returns to
   `/session/:routineId`. (Testable in an iPhone Pro simulator.)
3. **U26 Siri/Spotlight:** on a real device, "Hey Siri, log an expense in Opal"
   and "start a workout in Opal" run the intents and deep-link in; Spotlight
   surfaces both shortcuts.
4. **U27 HealthKit:** blocked — needs a paid account (see above).

> `OpalWorkoutAttributes.swift` / `OpalAppIntents.swift` still carry their
> original "add in Xcode" header comments; those steps are now handled by the
> script, so the comments are historical.
