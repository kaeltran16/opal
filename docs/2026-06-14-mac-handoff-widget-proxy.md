# Mac Handoff — rings widget data via the proxy (App Group workaround)

**For:** a dev on **macOS + Xcode**.
**Why you:** the iOS app + widget extension can't be compiled on Windows. The
server and Dart sides are done and tested; the Swift + Xcode build-config + signing
+ on-device verification are yours.

**Branch:** `feat/widget-data-via-proxy` (commit `240a480`, off `main`, not pushed).

## The bug this fixes
On a real device the rings widget showed **zeros** — deep links worked, data didn't.
Root cause: the widget read its data from a shared **App Group** (`group.com.opal.opal`),
but a free Apple **Personal Team can't provision App Groups** (the same wall that blocked
HealthKit). The app's write and the widget's read hit isolated containers, so the widget
always loaded the empty snapshot. Deep links are static URLs baked into the widget, need
no entitlement, and kept working — hence the asymmetry.

## The fix (route through the server, like the HealthKit/Shortcut workaround)
The widget is now a **network client** instead of a shared-storage reader:

| Layer | Change | Status |
|-------|--------|--------|
| Server | `WidgetSnapshotStore` + `POST`/`GET /v1/widget/snapshot` (single-tenant JSON blob, like the health store) — `server/src/widget.ts`, `schemas.ts`, `app.ts`, `server.ts` | done, **123 tests pass**, tsc clean |
| App (Dart) | `HttpWidgetSyncService` POSTs the snapshot over the existing authed client, then calls native `reload`; `widgetSyncService` provider gates on iOS + `PAL_BASE_URL` | done, **169 tests pass**, analyze clean |
| Native bridge | `OpalWidgetSyncBridge.swift`: `sync` → `reload`, which calls `WidgetCenter.shared.reloadAllTimelines()` (no entitlement needed) | **unverified** |
| Widget | `OpalRingsSnapshot.swift` (Codable + `RingsSnapshotLoader`: self-register → GET → cache last-good); `OpalRingsWidget.swift` (async fetch, 20-min `.after` fallback) | **unverified** |
| Entitlements | App Group removed from `Runner.entitlements` + `OpalWidgets.entitlements` (now empty dicts) | **unverified** |

> The 3 Swift files + 2 entitlements were edited on **Windows and never compiled.**

## Data flow
```
app TodayState change
  -> HttpWidgetSyncService.sync()  POST /v1/widget/snapshot   (Dart, authed)
  -> MethodChannel 'reload'        WidgetCenter.reloadAllTimelines()  (native, no entitlement)
  -> widget getTimeline()          GET /v1/widget/snapshot    (Swift, self-registered token)
```
Foreground changes refresh the widget within seconds (the reload nudge). With the app
closed it refreshes on the ~20-min timeline fallback (WidgetKit throttles either way).

## YOUR TASKS

### 1. Inject the proxy config into the OpalWidgets target
The widget reads `PAL_BASE_URL` + `PAL_PROVISIONING_KEY` from its **Info.plist**
(`Bundle.main.object(forInfoDictionaryKey:)`). Add both keys to
`ios/OpalWidgets/Info.plist`, mirroring the existing `$(VAR)` pattern:
```xml
<key>PAL_BASE_URL</key>
<string>$(PAL_BASE_URL)</string>
<key>PAL_PROVISIONING_KEY</key>
<string>$(PAL_PROVISIONING_KEY)</string>
```
Then define `PAL_BASE_URL` / `PAL_PROVISIONING_KEY` as **user-defined build settings**
on the OpalWidgets target (or an xcconfig), with the **same values** the app gets via
`--dart-define` (base `https://opal.kael.life`, key = server `.env`). Don't hardcode the
key into the committed plist — but note it ships readable in the bundle either way (same
exposure as the app's dart-define; acceptable for a personal build).

### 2. Drop the App Group capability in Xcode
Signing & Capabilities for **both** Runner and OpalWidgets → remove **App Groups** (the
entitlements files are already emptied). A free-team build should now sign cleanly.
Optional: `OpalRingsSnapshot.swift` no longer belongs to the Runner target (the bridge
doesn't reference `RingsSnapshot` anymore). `configure_native_targets.rb` no longer adds
it to Runner on a fresh run, but the committed `Runner.xcodeproj` may still list it from a
prior run — remove it from Runner's compile sources if so. Harmless if left (it compiles
standalone).

### 3. Build, sign & verify on device
```bash
flutter build ios   # run with the dart-defines from the move-ring handoff §2
```
Confirm on the device:
- [ ] Both targets sign + install with the free Personal Team (no App Groups error).
- [ ] Widget shows **real** money/move/rituals values, not zeros.
- [ ] Logging an entry with the app foregrounded refreshes the widget within seconds.
- [ ] With the app closed, the widget refreshes on the ~20-min fallback.
- [ ] Airplane mode: the widget keeps its last values (cached), doesn't blank.
- [ ] `+` FAB and tile deep links still work.

Manual server check (token from `POST /v1/register` with the provisioning key):
```bash
curl -s https://opal.kael.life/v1/widget/snapshot -H "Authorization: Bearer <token>"
# -> {"moneyRing":...,"moveKcal":...,...}   (404 before the app has posted once)
```

## Trade-offs accepted (decided 2026-06-14)
- Today's money/move/rituals totals now leave the device (health data already did).
  Fine for a personal, single-tenant deployment.
- Background refresh is throttled (not instant when the app is closed).
- To make the widget instant + offline-capable again, provision the App Group with a
  **paid** Apple Developer account — the original code path still works, just re-add the
  entitlement. Decision note: `Obsidian Vault/Decisions/2026-06-14 widget-data-via-proxy.md`.
