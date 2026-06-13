# Mac Handoff — Move Ring → kcal + Apple Watch health sync

**For:** an agent/dev working on a **macOS + Xcode** machine.
**Why you:** this work was implemented on Windows, where the iOS app and the
home-screen widget **cannot be compiled**. Everything else is done and verified;
you own the iOS build, the on-device verification, and the coordinated deploy.

## Where things stand

- Branch `feat/move-ring-kcal` is **merged into `main`** at commit `37a5146`
  (one commit, **not yet pushed** to `origin/main`).
- Verified on Windows: **server 118 tests + `tsc` clean**, **flutter 167 tests +
  `analyze` clean**. A final code review found no critical/important issues.
- **Not verified anywhere:** the 3 iOS Swift files (edited but never compiled) and
  all on-device behaviour.
- Plan: `docs/superpowers/plans/2026-06-12-move-ring-active-energy-kcal.md`.
- Prior related work already live on `origin/main` (`b1d8fbe`): the
  `/v1/health/ingest` server + the iOS Shortcut that POSTs Apple Watch metrics.

## What changed (one paragraph)

The daily **"move" ring was re-based from minutes to active-energy kilocalories**
(Apple Move-ring style), end to end: `Goals.dailyMoveKcal` (Drift schema **v6**
migration), move totals now sum `Entry.calories`, manual + Pal logging capture
kcal, and the Pal LLM wire contract + the iOS rings widget speak kcal. A new
client `HealthService` reads today's Watch active energy from the server
(`GET /v1/health/day`, fed by the existing Shortcut→`/v1/health/ingest`) and
upserts one health-sourced move `Entry`, so the ring reflects the Watch — no paid
Apple Developer account required.

## YOUR TASKS

### 1. Build & compile-verify iOS (the blocker)
```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # if .g.dart not fresh
flutter build ios --no-codesign
# then open ios/Runner.xcworkspace in Xcode and build BOTH targets:
#   - Runner (app)
#   - OpalWidgets (widget extension)
```
The three Swift files edited on Windows (confirm they compile and the keys below
match the Dart side exactly — they're matched by **string**, a mismatch is silent
runtime breakage):
- `ios/OpalWidgets/OpalRingsSnapshot.swift` — struct fields + UserDefaults `Key`
  strings renamed `moveMinutes`→`moveKcal`, `dailyMoveMinutes`→`dailyMoveKcal`.
- `ios/Runner/Widgets/OpalWidgetSyncBridge.swift` — reads `a["moveKcal"]`,
  `a["dailyMoveKcal"]`.
- `ios/OpalWidgets/OpalRingsWidget.swift` — `StatRow` now renders `"\(s.moveKcal)"`
  / `"/ \(s.dailyMoveKcal) kcal"`.
The Dart writer (`lib/services/widget_sync/widget_sync_service.dart`) sends payload
keys `moveKcal` / `dailyMoveKcal`. App Group is `group.com.opal.opal` (entitlement
on both Runner and OpalWidgets).

### 2. On-device verification checklist
Build the app with the server wired up:
```bash
flutter run --dart-define=PAL_BASE_URL=https://opal.kael.life \
            --dart-define=PAL_PROVISIONING_KEY=<same as server .env>
```
Confirm:
- [ ] **Migration:** first launch on an existing install does not crash; the move
      goal reads **500 kcal** (the v6 migration resets it — minutes can't convert).
- [ ] **Today move ring** shows kcal: value `/ 500 kcal`, ring fills as calories accrue.
- [ ] **Manual log:** New-entry → Workout now has a **Calories** field; logging e.g.
      30 min / 240 kcal moves the ring by 240.
- [ ] **Pal:** asking Pal to log a workout with calories (tool `log_movement`
      gained optional `calories`) feeds the ring; "set move goal" sets kcal.
- [ ] **Home-screen widget** renders `X / 500 kcal` (not "min") and the green move ring.
- [ ] **Health sync (the payoff):** with the iOS **Shortcut** having posted today's
      `activeEnergy` to the server, launching the app upserts ONE move entry titled
      "Apple Watch" (id `health:move:<date>`) and the ring reflects the Watch's kcal.
      Re-running is idempotent (overwrites, never duplicates). Note: health sync is
      **iOS-gated** at startup (`lib/app.dart`) and only runs when `PAL_BASE_URL` is set.

Manual server check (needs a token from `POST /v1/register` with the provisioning key):
```bash
curl -s "https://opal.kael.life/v1/health/day?date=$(date +%F)" \
  -H "Authorization: Bearer <token>"   # -> {"date":"...","metrics":{"activeEnergy":{...}}}
```

### 3. Coordinated deploy (DO LAST, together)
The Pal wire contract was renamed (move fields → kcal), so **the new server rejects
an old app and vice-versa**. They MUST ship together:
1. `git push origin main` → the GitHub Action runs server tests, rsyncs, builds, and
   restarts `opal-api` on the droplet (now serving the **kcal** contract).
2. Build + install the iOS app **from this same commit** on the device.
Between (1) and (2) the currently-installed (minutes) app will get HTTP 400 on Pal
chat/insights/review calls — keep that window short.

## Field-name reference (kcal contract)
Chat: `moveGoalKcal`, `movedTodayKcal`, `weekMovedKcal`. Insights: `moveKcal`,
`moveTargetKcal`. Review: `kcalMoved`. Tool: `set_move_goal.dailyMoveKcal`,
`log_movement.calories` (optional). UNCHANGED: `moveStreakDays`, `streakDays`,
`movedDeltaPct`, `Entry.duration` (timeline still shows "30 min"), and
workout-session minutes (`Workout.duration`/`weekMinutes`/`durationMinutes`).

## Gotchas
- Shortcut reads Health only while the **phone is unlocked** — scheduled syncs won't
  fire on a locked phone.
- Defaults chosen: goal 500 kcal; onboarding chips 300/500/700/900; settings stepper
  ±50, range 0–5000. Adjust if undesirable.
- The legacy `daily_move_minutes` DB column is intentionally left in place (SQLite
  drop-column is fragile); harmless, future cleanup candidate.
