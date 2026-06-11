# Design: iOS home-screen rings widget

Date: 2026-06-11
Status: Approved (brainstorm)

> Revision (2026-06-11): bridge approach changed from the `home_widget` package
> to a custom `MethodChannel` (`opal/widget_sync`) mirroring `LiveActivityService`,
> after finding the codebase's established native-service pattern. Adds zero
> dependencies. Also: deep-link routing is fully generic
> (`OpalIntentsBridge.routerPath` maps `opal://<host>` -> `/<host>`), so no
> SceneDelegate/Runner change is needed for `opal://pal-composer` or
> `opal://today` — both routes already resolve.

## Goal

Ship an iOS home-screen widget that mirrors the in-app Today header: the three
nested activity rings (money / move / rituals) plus a "+" button that opens the
Pal composer — the home-screen analogue of the in-app center FAB.

## Scope decisions

- **Size:** Medium (4×2) only.
- **Interactivity:** rings are a static snapshot; "+" deep-links into the app.
  No in-widget interactive App Intents (out of scope — that's a different
  feature than "the FAB like the app").
- **"+" behavior:** deep-links `opal://pal-composer`, landing on the Pal
  composer with its text field focused (keyboard up). The composer already sets
  `autofocus: true` (`lib/screens/pal/pal_composer_screen.dart:633`), so no
  focus work is needed beyond routing.
- **Rings tap target:** the rest of the widget deep-links `opal://today`.
- **Target:** iOS 26 (existing `OpalWidgets` deployment target), so multiple tap
  targets at any size are supported.

## Layout

- Left: three nested rings (outer = money `#FF9500`, middle = move `#34C759`,
  inner = rituals `#AF52DE`), drawn as SwiftUI arcs. Snapshot only — no fill
  animation.
- Right: three numeric breakdowns — spent/budget, move minutes/target,
  rituals done/target.
- Bottom-right: blue `#007AFF` "+" FAB → `opal://pal-composer`.

## Architecture

Lives in the existing `OpalWidgets` extension (alongside the workout Live
Activity). No new extension target. New capability required: an App Group
shared between Runner and OpalWidgets.

### Components

| Piece | Location | New? |
|---|---|---|
| `OpalRingsWidget` (`Widget` + `TimelineProvider` + SwiftUI views) | `ios/OpalWidgets/OpalRingsWidget.swift` | new Swift |
| `RingsSnapshot` shared model (App Group id, keys, load/save) — member of BOTH targets | `ios/OpalWidgets/OpalRingsSnapshot.swift` | new Swift |
| Register in `OpalWidgetsBundle` | `ios/OpalWidgets/OpalWidgetsBundle.swift` | 1 line |
| `OpalWidgetSyncBridge` (`opal/widget_sync` channel → save + reload) | `ios/Runner/Widgets/OpalWidgetSyncBridge.swift` | new Swift |
| Register bridge in AppDelegate | `ios/Runner/AppDelegate.swift` | 1 line |
| `WidgetSyncService` interface + Noop + MethodChannel impl + pure payload fn | `lib/services/widget_sync/widget_sync_service.dart` | new Dart |
| `widgetSyncServiceProvider` | `lib/controllers/providers.dart` | new Dart |
| `WidgetSyncController` (listens `todayState` → sync) | `lib/controllers/widget_sync_controller.dart` | new Dart |
| Instantiate controller on app start | `lib/app.dart` | 1 line |
| App Group entitlements (Runner + OpalWidgets) + register new Swift files | `ios/Runner/Runner.entitlements`, `ios/OpalWidgets/OpalWidgets.entitlements`, `ios/configure_native_targets.rb` | new + edit |

### Bridge

Custom **`MethodChannel('opal/widget_sync')`** mirroring `LiveActivityService`
(abstract interface + `NoopWidgetSyncService` + `MethodChannelWidgetSyncService`).
Dart sends the snapshot; the native `OpalWidgetSyncBridge` (Runner target) writes
it to the shared App Group `UserDefaults(suiteName: "group.com.opal.opal")` via the
shared `RingsSnapshot` model and calls `WidgetCenter.shared.reloadAllTimelines()`.
The widget's `TimelineProvider` reads the same `RingsSnapshot`. The App Group id +
UserDefaults keys live once in `OpalRingsSnapshot.swift`, compiled into both
targets (DRY), exactly as `OpalWorkoutAttributes.swift` is shared today.
No new dependency.

### Data flow

```
TodayState (drift, live)
  -> WidgetSyncController (ref.listen todayState)
  -> WidgetSyncService.sync(state)         [Dart]
       MethodChannel('opal/widget_sync').invokeMethod('sync', {
         moneyRing, moveRing, ritualsRing,
         moneySpent, dailyBudget,
         moveMinutes, dailyMoveMinutes,
         ritualsDone, dailyRitualTarget })
  -> OpalWidgetSyncBridge                   [Swift, Runner]
       RingsSnapshot(...).save()  // App Group UserDefaults
       WidgetCenter.shared.reloadAllTimelines()
  -> OpalRingsWidget TimelineProvider       [Swift, OpalWidgets]
       RingsSnapshot.load() -> renders snapshot
```

Sync triggers: every `todayState` emit (entry logged, goal changed); the
controller listens with `fireImmediately` so the widget is seeded on launch. No
polling. The widget never computes — it renders pre-computed fractions and
numbers (matches `TodayState`'s zero-goal guards).

### Deep links (already wired)

`lib/app.dart:51-65` listens on the native `opal/intents` channel and calls
`_router.go(path)`; SceneDelegate already forwards every `opal://` URL to
`OpalIntentsBridge`, whose `routerPath` maps `opal://<host>` -> `/<host>`
generically. `/pal-composer` and `/today` are existing routes, so the widget's
`.widgetURL`/`Link` URLs route with **no native change** — the widget just emits
`opal://pal-composer` (the "+") and `opal://today` (the rest of the widget).

## Edge cases & error handling

- **App Group not provisioned** (free Apple Personal Team — same limitation as
  the HealthKit note in `configure_native_targets.rb`): widget UI builds and
  runs everywhere; live data sync to a physical device may require a paid Apple
  Developer account. Simulator works regardless. Unprovisioned → widget shows
  placeholder/empty rings, no crash.
- **No data yet** (fresh install): TimelineProvider returns a zeroed snapshot
  (empty rings, "—" numbers).
- **Goals = 0:** no widget-side math; fractions arrive pre-guarded from
  `TodayState`.
- **Stale snapshot:** acceptable by design; never staler than the last app
  interaction (reload on every emit + background).
- **Sync failure** (channel error / no App Group): caught and logged in
  `WidgetSyncService`; app continues; widget keeps last good snapshot.

## Testing

- **Dart unit:** pure `widgetSyncPayload(TodayState)` maps to the exact
  key/value map (correct numbers + fractions, zero-goal handling) — no channel
  needed.
- **Dart:** `MethodChannelWidgetSyncService.sync` invokes `opal/widget_sync`
  `sync` with that payload (mock channel handler); swallows `PlatformException` /
  `MissingPluginException`.
- **Dart:** `WidgetSyncController` calls `service.sync` when `todayState` emits
  data (fake service via provider override).
- **Swift:** ring-arc view + TimelineProvider via Xcode preview snapshots
  (consistent with the Live Activity — no Swift unit tests exist for it).
- **Manual (simulator):** log an entry → widget updates after reload; tap "+" →
  composer opens focused; tap rings → Today opens.

## Out of scope

- Small / Large widget sizes.
- In-widget interactive App Intents (e.g. mark a ritual done from the widget).
- Per-ring deep links (tapping a single ring opening its domain).
- Ring fill animation (widgets render snapshots).
