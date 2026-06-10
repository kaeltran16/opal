# iOS native setup (U25–U27)

What the Mac environment + agents produced, and the **Xcode-GUI steps that remain**
(the `.pbxproj` target/membership work can't be done safely from the CLI).

## Done & verified (builds for simulator, 94 tests green, analyze clean)

- **Toolchain:** Homebrew, Flutter 3.44.1, Node 22 LTS, CocoaPods, Xcode 26.5 + iOS 26.5 simulator runtime.
- **Deployment target:** bumped to **iOS 26.0** (Podfile + `project.pbxproj`). Dev-only floor; raise the device floor later if shipping.
- **U27a HealthKit:** `lib/services/health/health_kit_service.dart`, `health: ^13.1.1`, `healthServiceProvider` gated to iOS, `Info.plist` usage strings. **Live** (Today/Move read it). Verify real data on a physical device — the simulator returns empty HealthKit data.
  - **Remaining (Xcode):** add the **HealthKit** capability (Signing & Capabilities → + → HealthKit) so the entitlement is present; otherwise auth fails at runtime.
- **U27b Notifications:** `lib/services/notifications/local_notification_service.dart`, `flutter_local_notifications: ^18.0.1` + `timezone` + `flutter_timezone`, tz init in `main.dart`, `notificationServiceProvider` gated to iOS. Impl is ready; no scheduling call-site is wired yet (ritual-reminder scheduling is a separate feature).

## U25 — Live Activities / Dynamic Island (code staged)

Files: `ios/Runner/LiveActivities/OpalWorkoutAttributes.swift`, `…/OpalLiveActivityBridge.swift`,
`ios/OpalWidgets/OpalWorkoutLiveActivity.swift`; Dart `lib/services/live_activity/live_activity_service.dart`
(`liveActivityServiceProvider` is real-on-iOS and **no-ops gracefully** until the native handler exists).

**Xcode steps:**
1. File → New → Target → **Widget Extension** named `OpalWidgets` (uncheck "Include Configuration Intent"), deployment 26.0.
2. Target membership:
   - `OpalWorkoutLiveActivity.swift` → **OpalWidgets** only.
   - `OpalWorkoutAttributes.swift` → **BOTH** Runner and OpalWidgets (shared contract).
   - `OpalLiveActivityBridge.swift` → **Runner** only.
3. In the widget bundle's `@main WidgetBundle`, include `OpalWorkoutLiveActivity()`.
4. `Info.plist` already has `NSSupportsLiveActivities=true` and the `opal` URL scheme. ✓
5. `AppDelegate.swift` — register the bridge on the `opal/live_activity` channel and handle `opal://session/<routineId>` → forward to Flutter (see snippets in the U25 agent report / below).
6. Call-site wiring in `lib/controllers/workout_session_controller.dart`: `start` at session build, `update` on set/rest/exercise changes (not per-tick — the island timer self-ticks via `Text(timerInterval:)`), `end` in `finish()` and the `onDispose`.

## U26 — Siri Shortcuts / AppIntents (code staged)

Files: `ios/Runner/Intents/OpalAppIntents.swift`, `…/OpalIntentsBridge.swift`;
Dart `lib/services/siri/siri_shortcuts_service.dart` (`siriShortcutsServiceProvider` self-gates by platform).

**Xcode steps:**
1. Add both Intents `.swift` files to the **Runner** target's Compile Sources (no separate extension — intents run in-process). No Siri capability needed (modern AppIntents framework).
2. `Info.plist` `opal` URL scheme already present (shared with U25). ✓
3. `AppDelegate.swift` — register `OpalIntentsBridge` on `opal/intents`. **Deep links arrive at the `SceneDelegate`** (this project uses `UIApplicationSceneManifest`): handle `scene(_:openURLContexts:)` and the cold-launch `scene(_:willConnectTo:options:)`, forwarding `opal://entry/new` / `opal://move/start` to Flutter.
4. Wiring: call `siriShortcutsServiceProvider.donateShortcuts()` once at app start; subscribe to its deep-link stream and `router.go(path)` (and `consumeInitialDeepLink()` for cold launch).
5. Optional in-app "Siri shortcut" hint chip on the Move screen, deep-linking the same way.

## Shared deep-link contract

`opal://session/<routineId>` → `/session/:routineId` · `opal://entry/new` → `/entry/new` · `opal://move/start` → `/move/start`.
A single `MethodChannel('opal/deeplink')` (or the `app_links` package) bridges native URL opens into `GoRouter`.

> Full AppDelegate/SceneDelegate Swift snippets are in the agent integration reports for U25/U26.
> All of U25/U26 is **device-only verifiable** (Dynamic Island needs a physical iPhone; "Hey Siri" needs a device).
