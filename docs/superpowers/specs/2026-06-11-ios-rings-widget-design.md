# Design: iOS home-screen rings widget

Date: 2026-06-11
Status: Approved (brainstorm)

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
| `OpalRingsWidget` (`Widget` + `TimelineProvider`) | `ios/OpalWidgets/` | new Swift |
| Ring-arc SwiftUI view | `ios/OpalWidgets/` | new Swift |
| Register in `OpalWidgetsBundle` | `ios/OpalWidgets/OpalWidgetsBundle.swift` | 1 line |
| `WidgetSyncService` (writes snapshot + reloads timelines) | `lib/services/` | new Dart |
| Riverpod listener: `todayState` change → sync | `lib/` wiring | new Dart |
| App Group capability on Runner + OpalWidgets | `ios/configure_native_targets.rb` | edit |
| `opal://pal-composer` mapping in SceneDelegate | `ios/Runner/` | edit (mirror existing) |

### Bridge

Use the **`home_widget`** package for the App Group read/write + timeline
reload. It replaces App Group `UserDefaults` plumbing on both sides plus
`WidgetCenter.reloadAllTimelines()`. (Alternative considered: a custom
`MethodChannel` reusing the existing native bridge — rejected to avoid
reimplementing exactly what `home_widget` provides.)

### Data flow

```
TodayState (drift, live)
  -> WidgetSyncService.sync(state)
       writes { moneyRing, moveRing, ritualsRing,
                moneySpent, dailyBudget,
                moveMinutes, dailyMoveMinutes,
                ritualsDone, dailyRitualTarget } to App Group
  -> WidgetCenter.reloadAllTimelines()
       -> OpalRingsWidget TimelineProvider reads App Group -> renders snapshot
```

Sync triggers: every `todayState` emit (entry logged, goal changed) and on app
background. No polling. The widget never computes — it renders pre-computed
fractions and numbers (matches `TodayState`'s zero-goal guards).

### Deep links (already wired)

`lib/app.dart:51-65` listens on the native `opal/intents` channel and calls
`_router.go(path)`; SceneDelegate already forwards `opal://` URLs (this is how
the Live Activity's `opal://session/<routineId>` works). `/pal-composer` and
`/today` are existing routes, so the only Runner-side edit is ensuring
SceneDelegate maps the widget URLs to those paths.

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

- **Dart unit:** `WidgetSyncService` maps a given `TodayState` to the exact
  key/value payload (correct numbers + fractions, zero-goal handling); platform
  calls mocked.
- **Dart:** `todayState` listener calls sync on emit, without redundant calls.
- **Swift:** ring-arc view + TimelineProvider via Xcode preview snapshots
  (consistent with the Live Activity — no Swift unit tests exist for it).
- **Manual (simulator):** log an entry → widget updates after reload; tap "+" →
  composer opens focused; tap rings → Today opens.

## Out of scope

- Small / Large widget sizes.
- In-widget interactive App Intents (e.g. mark a ritual done from the widget).
- Per-ring deep links (tapping a single ring opening its domain).
- Ring fill animation (widgets render snapshots).
