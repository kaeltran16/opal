# Rings Widget Rebuild Implementation Plan

> **For agentic workers:** each task below carries its design decisions, owned files, interfaces and acceptance tests; the worker writes the implementation. Steps use checkbox (`- [ ]`) syntax for tracking.

**Verify:** `sh -c 'set -e; c="$ARC_VERIFY_CHANGED"; if [ -z "$c" ] || grep -q "^server/" "$c"; then (cd server/worker && npx vitest run); fi; if [ -z "$c" ] || grep -qE "^(lib/|test/|pubspec)" "$c"; then flutter test --exclude-tags "golden || scenario"; fi'`
**Setup:** `flutter pub get && (cd server && npm ci) && (cd server/worker && npm ci)`
**Check:** `flutter analyze --fatal-infos`
**Final:** `sh scripts/widget_final.sh`
**Prototype:** C:\Users\cktra\Projects\opal\.superpowers\design\oura-ai-first\project\Widget.dc.html

**Goal:** Rebuild the iOS medium rings widget to the Widget board of the oura-ai-first canvas and the "Rings widget" rules in DESIGN.md section 7. It shows Move and Routines rings, Money as a what's-left row, a round ink "+" that opens the Pal composer, and empty tracks with dashes before the first fetch. Every state word comes from `lib/analysis/area_state.dart` and the widget never computes one.

**Architecture:** The app already POSTs a snapshot to the proxy, which stores it as JSON in D1, and the widget GETs it back; a free Apple team has no App Group. This plan swaps the nine raw numbers for a v2 payload of display-ready rows. Each row has a formatted `value`, a ring `fraction`, and a *schedule* of state changes from now until local midnight, worked out in Dart by calling `areaGlances()` once a minute. Swift turns each scheduled change into a WidgetKit timeline entry, so the word flips on time while the app is closed. At `until` (local midnight) the widget falls back to dashes.

**Tech Stack:** Flutter/Dart (Riverpod, `clock`), Cloudflare Worker + zod + vitest, SwiftUI/WidgetKit (iOS 26 target).

**Approved decisions** (Spec review, approved by the human; no spec file because the canvas settles the visuals):
- Payload v2 replaces the nine numeric fields with `{until, move, routines, money}`. Each row has a ready-made `value` (formatted with the app's `formatCurrency`), a ring `fraction` (Move and Routines only), and `states: [{at, state, word}]`.
- State schedule: on each sync Dart calls `areaGlances()` (API unchanged) for every minute from now to local midnight and keeps only the changes. Swift makes one timeline entry per change and shows dashes at `until`.
- The numbers come from a new `TodayState.glance` getter. It counts routines the way Today does: the total is today's routines, and done is 0 when there are none. Today can switch to it after run 95e0ea96 lands; that switch is flagged, not done here.
- Values: Move `310 of 500 kcal` (no goal: `310 kcal`). Routines `2 of 4 done` (none: `None today`). Money `$22 left of $60`, over budget `$4 over $60`, no budget `No budget`.
- Canvas delta: the care board shows `$4 left` with Needs care, but `moneyState` only returns care when spending is over budget. The care fixture is over budget and reads `$4 over $60`.
- The word shows only when the state isn't `good`, in that state's ink. Ring colours: `move` and `rituals` with 20% alpha tracks, light and dark.
- Dashes and empty tracks show before the first fetch, past `until`, or when an old v1 cached snapshot doesn't decode. The accessibility label reads `Opal. Not synced yet. Opens Today`.
- Server: the v2 zod schema replaces the old one. D1 stores the JSON as-is, so there's no migration. Deploy the worker before installing the new build.
- No paid entitlement is used.
- Swift can't be built here: it gets `#Preview` fixtures for the four canvas states. Final writes the Dart payloads, then exits 3 because the widget can't be rendered on Windows.

**Sign-offs after plan review round 1** (answered by the human through AskUserQuestion):
- **The run ends with Final exit 3, approved.** Owner of the Mac render check: the human (repo owner). Due: before the new build is next sideloaded. The checklist is the dated section Task 3 adds to `docs/2026-06-14-mac-handoff-widget-proxy.md`. No macOS CI render job: it would need branch pushes and macOS minutes, and its harness couldn't be tested here either.
- **This run's board set is `Widget.dc.html` only.** `Main.dc.html` (Today, Areas, Workout, You) is out of scope, confirmed by the human. It's owned and verified by run 95e0ea96, and this run's Final has no step for it.

## Global Constraints

- Do not edit `lib/screens/today/**`, `lib/screens/profile/**` or `lib/router.dart`, and do not change any signature or behaviour in `lib/analysis/area_state.dart`. Run 95e0ea96 is editing those files in parallel. Importing them is fine.
- Personal app, sideloaded through AltStore on a free Apple account: no App Group, no new entitlement, no capability that needs a paid team.
- No new dependencies (Dart, npm or Swift).
- Comments explain why, never what; lower case; only when necessary. No emojis.
- Swift can't be compiled on this machine. Keep Swift changes small, idiomatic, and readable without building. Mark the Swift file headers "edited on Windows, compile on a Mac", as the existing files are.

## The v2 wire contract (shared by Tasks 1, 2, 3, 4)

`POST /v1/widget/snapshot` body, which `GET` returns unchanged:

```json
{
  "until": 1760425200,
  "move":     { "fraction": 0.62, "value": "310 of 500 kcal", "states": [ { "at": 1760371260, "state": "good", "word": "On track" } ] },
  "routines": { "fraction": 0.5,  "value": "2 of 4 done",     "states": [ { "at": 1760371260, "state": "good", "word": "On track" } ] },
  "money":    {                   "value": "$22 left of $60", "states": [ { "at": 1760371260, "state": "watch", "word": "Worth watching" } ] }
}
```

- `until`: int, Unix epoch **seconds**, the next local midnight after the sync (`DateTime(y, m, d + 1)` in local time, so it holds across DST).
- `fraction`: finite double in [0, 1]. Present on `move` and `routines`, absent on `money`.
- `value`: non-empty string, at most 64 chars.
- `states`: 1 to 1441 items, sorted by ascending `at`. The first `at` is the sync time truncated to the minute. Neighbouring items have different `state`, and every `at` is before `until`.
- `at`: int epoch seconds. `state`: one of `thriving | good | watch | care` (`AreaState.name`). `word`: `AreaState.word`, at most 32 chars.

## Review Focus

1. **Sync in the last minute before midnight (23:59):** the schedule still holds exactly one state and `until` is the next midnight. Pinned in Task 2.
2. **Over budget, budget unset, goal unset, no routines:** each row reads the decided string and never `$0 left` or `0 of 0`. Pinned in Task 2.
3. **A v1 snapshot in the widget cache, or still on the server, after upgrading:** decoding fails and the widget shows dashes, never zeros and never a crash. Pinned in Task 3's acceptance and preview.
4. **Widget clock before the first `at`** (clock skew, or a timeline entry dated now): the widget uses the first state, not a blank. Pinned in Task 3.
5. **Non-USD currency (for example VND, no decimals, symbol after):** the Money value follows the setting, not a hard-coded `$`. Pinned in Task 2.

---

### Task 1: Server accepts and returns the v2 snapshot
**Depends on:** none
**Files:** `server/src/schemas.ts`, `server/worker/test/widget.test.ts`

Replace `widgetSnapshotBody` in `server/src/schemas.ts` with the v2 contract above. Use zod. Define a `stateChange` object (`at` int, `state` enum of the four names, `word` string 1..32), a ring row (`fraction` finite 0..1, `value` string 1..64, `states` array 1..1441 of `stateChange`) used by `move` and `routines`, and a money row (`value`, `states`, no `fraction`). `until` is an int. Keep the export name `widgetSnapshotBody`: `server/worker/src/worker.ts` and `server/worker/src/stores/widget.ts` already use it and the inferred type, so they need no edits. D1 stores the JSON as-is, so there's no migration.

Acceptance, all in `server/worker/test/widget.test.ts` (replace `SNAP` with a v2 sample):
- [ ] `POST stores and GET reads back the exact snapshot` passes with the v2 sample: a money row without `fraction` round-trips unchanged.
- [ ] New test `rejects the v1 snapshot with 400`: posting the old nine-field body returns 400.
- [ ] New test `rejects an unknown state or an out-of-range fraction with 400`: one case with `state: "great"` and one with `fraction: 1.5`.
- [ ] New test `rejects an empty states list with 400`.
- [ ] Replace the existing `rejects a snapshot with a non-finite ring with 400` test. It posts `{...SNAP, moneyRing: 'x'}`, and zod would strip that unknown key from a v2 body and return 200. Its replacement is the `fraction: 1.5` case above. No test may still reference a v1 field name (`grep -nE "moneyRing|moveRing|ritualsRing|dailyBudget" server/worker/test/widget.test.ts` finds nothing).
- [ ] Keep `GET returns 404 before any snapshot`.
- Note: the worker deploys on its own when merged to `main` (`.github/workflows/worker.yml` runs on `server/worker/**`, and this task edits a file there). That meets "deploy the worker before installing the build" as long as the build is installed after the merge.
- [ ] Run: `cd server/worker && npx vitest run test/widget.test.ts`. All pass.

### Task 2: App builds and syncs the v2 snapshot
**Depends on:** none
**Files:** `lib/services/widget_sync/widget_sync_service.dart`, `lib/controllers/widget_sync_controller.dart`, `lib/controllers/today_controller.dart`, `test/services/widget_sync_service_test.dart`, `test/controllers/widget_sync_controller_test.dart`

**Interfaces (Task 4 relies on these exact names):**
- In `widget_sync_service.dart` (the service owns its wire type and imports nothing from controllers or analysis):
  - `class StateChange { const StateChange({required DateTime at, required String state, required String word}); }`
  - `class WidgetRow { const WidgetRow({double? fraction, required String value, required List<StateChange> states}); }`
  - `class WidgetSnapshot { const WidgetSnapshot({required DateTime until, required WidgetRow move, required WidgetRow routines, required WidgetRow money}); Map<String, Object?> toJson(); }`. `toJson` writes the v2 contract exactly: times as epoch seconds, and `fraction` left out when null.
  - `abstract interface class WidgetSyncService { Future<void> sync(WidgetSnapshot snapshot); }`. `NoopWidgetSyncService` and `HttpWidgetSyncService` implement it. The HTTP constructor stays the same, so `lib/controllers/providers.dart` needs no edit. Keep the POST, the 401 retry, the reload nudge and the swallow-and-`debugPrint` behaviour.
- In `today_controller.dart`: `GlanceNumbers get glance` on `TodayState`. It returns `spent: moneySpent, budget: goals.dailyBudget, moveKcal: moveKcal, moveGoal: goals.dailyMoveKcal, routinesTotal: routines.length, routinesDone: routines.isEmpty ? 0 : ritualsDone`. This copies `lib/screens/today/today_screen.dart` lines 204-218 and is purely additive. Add a one-line doc comment saying Today should switch to it once run 95e0ea96 lands.
- In `widget_sync_controller.dart`: top-level `WidgetSnapshot buildWidgetSnapshot(GlanceNumbers n, Currency currency, DateTime now)`, plus the existing `WidgetSyncController`.

**Design decisions:**
- `buildWidgetSnapshot` reads fractions and states only from `areaGlances(n, currency, t)`, whose list order is money, move, routines. It never calls `moneyState`/`progressState` directly, so the widget and Today can't drift apart. Measure before optimizing: about 1440 calls per sync is fine.
- Schedule: start at `now` truncated to the minute and step one minute at a time while `t` is before `until`. Append a `StateChange` only when the state differs from the previous one. Use `state.name` and `state.word`.
- Values (the widget's own strings; `AreaGlance.value` is a shorter Today form):
  - Move: `'${n.moveKcal} of ${n.moveGoal} kcal'` when `moveGoal > 0`, else `'${n.moveKcal} kcal'`.
  - Routines: `'${n.routinesDone} of ${n.routinesTotal} done'` when `routinesTotal > 0`, else `'None today'`.
  - Money, with `formatCurrency` from `lib/util/format.dart`: budget > 0 and spent <= budget gives `'${left} left of ${budget}'`; spent > budget gives `'${spent - budget} over ${budget}'`; budget <= 0 gives `'No budget'`.
- Move and Routines take `fraction` from their `AreaGlance` at `now`. Money has `fraction: null`.
- The controller listens to `todayStateProvider` (still `fireImmediately: true`) and to `appSettingsControllerProvider` (currency). Whenever either changes and a `TodayState` exists, it syncs `buildWidgetSnapshot(state.glance, currency, clock.now())` using `package:clock`. Only run `build_runner` if the generated `widget_sync_controller.g.dart` actually changes. If it does, it becomes this task's file; say so in the task report.

Acceptance:
- [ ] `test/controllers/widget_sync_controller_test.dart`, new group `buildWidgetSnapshot` (USD unless noted; all times are local `DateTime`s on 2026-10-13):
  - `canvas watch at 11:00`: spent 38/60, kcal 310/500, routines 2/4. Expect values `310 of 500 kcal`, `2 of 4 done`, `$22 left of $60`; move fraction 0.62; routines fraction 0.5; money `states.first.state == 'watch'`; move and routines first state `good`.
  - `canvas care at 11:00`: spent 64/60. Expect money value `$4 over $60` and first state `care`.
  - `canvas ahead at 11:00`: kcal 520/500, routines 4/4, spent 29/60. Expect `520 of 500 kcal` with fraction 1.0 and state `thriving`; `4 of 4 done` with `thriving`; `$31 left of $60` with `good`.
  - `schedule flips at the rule boundaries`: at 07:00, kcal 0/500, routines 0/4, spent 30/60. Expect move and routines states `[good @07:00, watch @10:45, care @21:00]`, money `[watch @07:00, good @10:46]`, and `until == DateTime(2026, 10, 14)`. Derive these from area_state.dart: watch when dayShare minus share is at least 0.25, care from 21:00 under half. If the rules give different minutes, the test follows the rules, not this note.
  - `one minute before midnight`: at 23:59, every row has exactly one state, and `until` is the next midnight.
  - `unset goals`: moveGoal 0, no routines, budget 0. Expect `310 kcal` with fraction 0, `None today` with fraction 0, `No budget`.
  - `currency follows the setting`: with `Currency.vnd` (or another non-USD value in the `Currency` enum), the money value contains that currency's symbol and no `$`.
  - `toJson matches the v2 contract`: epoch-second ints, no `fraction` key on money, and states ascending with no two neighbours equal.
- [ ] Update `maps each todayState emission onto a sync call`: the recorder captures the `WidgetSnapshot`, and with a fixed `clock` (`withClock`) its rows match `buildWidgetSnapshot(state.glance, Currency.usd, now)`. The routines total is `routines.length`, not the stored ritual target.
- [ ] `test/services/widget_sync_service_test.dart`: the POST body equals `snapshot.toJson()` (v2 keys only). Non-2xx never throws and skips the reload. Keep the existing 401-retry and reload cases.
- [ ] Run: `flutter test test/controllers/widget_sync_controller_test.dart test/services/widget_sync_service_test.dart`. All pass. `flutter analyze --fatal-infos` is clean.

### Task 3: SwiftUI widget renders the v2 snapshot to the canvas
**Depends on:** none
**Files:** `ios/OpalWidgets/OpalRingsSnapshot.swift`, `ios/OpalWidgets/OpalRingsWidget.swift`, `docs/2026-06-14-mac-handoff-widget-proxy.md`

Swift can't be built here, so keep the code readable without a compiler. Only use APIs available on iOS 26 (`#Preview(as: .systemMedium)`, `containerBackground`).

**`OpalRingsSnapshot.swift`:**
- `struct RingsSnapshot: Codable { let until: Int; let move: Row; let routines: Row; let money: Row }`, `struct Row: Codable { let fraction: Double?; let value: String; let states: [StateChange] }`, and `struct StateChange: Codable { let at: Int; let state: String; let word: String }`. Keys match the v2 contract.
- `Row.state(at: Date) -> StateChange`: the last change with `at <= date`, or the first change when the date is earlier than all of them (Review Focus 4). Selection only, no rule logic.
- `RingsSnapshot.isExpired(at: Date) -> Bool`: true when `date >= until`.
- Remove `RingsSnapshot.empty`. "Not synced" is now `nil`. `RingsSnapshotLoader.load()` returns `RingsSnapshot?`: fresh, else cached, else nil. A cached v1 blob fails to decode and gives nil (Review Focus 3). Keep the token, register, 401 and cache logic as it is.

**`OpalRingsWidget.swift` (match the canvas Widget board):**
- `RingsEntry { date: Date; snapshot: RingsSnapshot? }`. The view treats `snapshot == nil || snapshot.isExpired(at: date)` as empty.
- `getTimeline`: one entry at now; one entry at each distinct `at` in any row that is after now and before `until`; one entry at `until`. Keep the 20-minute `.after` refetch policy. Placeholder and preview use nil.
- Layout (338 × 158, 16 padding, 14 gap): rings 104 × 104 with the outer radius 46 and inner radius 32, stroke 12, round caps, starting at 12 o'clock. Outer is Move, inner is Routines. The track is the same hue at 20% alpha. The arc trims to `fraction` clamped to [0, 1]. The legend column has spacing 4. Each row has a header line (8pt round swatch, or for Money a 12pt `dollarsign` SF Symbol; the title in 13 medium, tracking 0.3, `ink2`; then the word in its state ink) and the value line (15 regular, tracking -0.23, `monospacedDigit`, one line).
- The word shows only when `state(at: entry.date).state != "good"`. Ink comes from a fixed map (`watch`, `care`, `thriving`). An unknown state string shows no word.
- Empty: tracks only, value `–` (en dash) on all three rows, no words.
- "+": a 38pt circle filled with `ink`, a plus glyph in `onInk` (18pt, semibold), 12pt from the top and right. It's a `Link` to `opal://pal-composer` with the accessibility label `Tell Pal anything`. The rest of the widget uses `.widgetURL(opal://today)`.
- Colours: a small palette picked by `@Environment(\.colorScheme)`, with the hex values from the canvas `THEMES`. Dark: surface #1A1F24, ink #F7F1E8, ink2 #D3D1CE, onInk #101418, move #30D158, routines #BF5AF2, watch #E0B060, care #F58A78, thriving #7FB0F5. Light: surface #FEFAEF, ink #1E2427, ink2 #4A4741, onInk #F7F1E8, move #34C759, routines #AF52DE, watch #86570F, care #B32410, thriving #2056A6. Use `containerBackground(surface, for: .widget)`. Retire the old money, blue FAB and `.fill.tertiary` colours.
- Accessibility: the combined label reads `Opal. Move 310 of 500 kcal. Routines 2 of 4 done. Money $22 left of $60, Worth watching. Opens Today`, with the word only where it shows. Empty reads `Opal. Not synced yet. Opens Today`.
- `configurationDisplayName("Opal")`, `description("Move, routines and what's left to spend.")`, `.systemMedium` only.
- `#Preview(as: .systemMedium)` timelines for the four canvas states, using fixture snapshots that match Task 2's canvas cases at 11:00. Watch: Money `Worth watching`, `$22 left of $60`. Care: `$4 over $60`, `Needs care`. Ahead: both rings full with `Ahead`, `$31 left of $60`. Empty: nil.

**Handoff doc:** add a dated section `## Rings widget v2 (2026-10-13)` to `docs/2026-06-14-mac-handoff-widget-proxy.md`. It's the on-device checklist for someone with a Mac:
1. Build the OpalWidgets target.
2. Compare the four previews against the canvas Widget board in light and dark.
3. Deploy the worker before installing the build.
4. Confirm the "+" opens the composer and the rest opens Today.
5. Confirm a cached v1 snapshot shows dashes.
6. Confirm the word changes at a scheduled minute while the app is closed.

Acceptance (no compiler here; the task reviewer checks these by reading the code):
- [ ] The Swift `CodingKeys` and property names match the v2 contract field for field, and money's `fraction` is optional.
- [ ] No state rule (dayShare, pace, thresholds) exists anywhere in Swift. `grep -nE "dayShare|0\.25|21 \*|paceSlack" ios/OpalWidgets` finds nothing.
- [ ] Each canvas board state maps to a preview and to Final steps `widget render: watch/care/ahead/empty`. Those steps report `skip` because SwiftUI can't be rendered on Windows; Task 4 writes them. Per the sign-off, the human owns the render check on a Mac before the next sideload, using the handoff section this task writes. That section names the owner and the deadline.
- [ ] No entitlement or Info.plist key is added (`git diff --stat` touches only the three listed files).

### Task 4: Final scenario writes the canvas payloads
**Depends on:** Task 2
**Files:** `test/scenario/widget_payload_scenario_test.dart`, `scripts/widget_final.sh`

- `test/scenario/widget_payload_scenario_test.dart`: tag it `@Tags(['scenario'])`, and use plain `test` (no rendering) so it doesn't need `scenarioTest`. Using `buildWidgetSnapshot` from Task 2, build the watch, care and ahead fixtures at 11:00 on 2026-10-13 (the same numbers as Task 2's canvas cases). Write each fixture's `toJson()` as pretty JSON to `$ARC_FINAL_OUT/widget-<state>.json` (default `build/scenario`, matching the harness's `_defaultOut`). Assert each fixture's values and words match the canvas, with the care delta (`$4 over $60`).
- `scripts/widget_final.sh` (POSIX sh, `set -eu`, `ARC_FINAL_OUT` defaulting to `build/scenario`):
  1. Run `flutter test --tags scenario test/scenario/widget_payload_scenario_test.dart` with `ARC_FINAL_OUT` exported. On failure, exit 1.
  2. Write `$ARC_FINAL_OUT/shots.json` with one entry, `name: "Widget board"`. Its `files` list the three JSON files. Its steps: `widget payload: watch|care|ahead` → `pass`; `widget render: watch|care|ahead|empty` → `skip` with detail `SwiftUI widget cannot be built or rendered on Windows (no Xcode); owner: repo owner, on a Mac before the next sideload (docs/2026-06-14-mac-handoff-widget-proxy.md)`. There is no step for `Main.dc.html`: it's out of this run's board set (see Sign-offs).
  3. As the last line, print `could not verify: the SwiftUI widget was not built or rendered (no Xcode on Windows); payloads verified`, then `exit 3`.

Acceptance:
- [ ] `ARC_FINAL_OUT=build/scenario sh scripts/widget_final.sh` writes three JSON files and a valid `shots.json` (check with `node -e "JSON.parse(require('fs').readFileSync('build/scenario/shots.json','utf8'))"`), and exits with 3.
- [ ] Breaking a fixture assertion (temporarily, not committed) makes the script exit 1.
