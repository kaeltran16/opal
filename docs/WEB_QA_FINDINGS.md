# Opal — Web Build QA Walkthrough

Manual click-through of the Flutter **web** build (`flutter run -d web-server`, prod dart-defines), driven through Chrome. Goal: exercise every flow/button, log errors, UX gaps, and improvement ideas.

- **Date:** 2026-06-11
- **Build:** debug web, port 8080, `dart_defines/prod.json` (PAL backend = https://opal.kael.life)
- **Flutter:** 3.44.1 / Dart SDK ^3.12.1

Severity legend: **[BUG]** broken/error · **[UX]** usability/polish · **[IDEA]** improvement · **[NOTE]** observation (works, context)

---

## Build & Launch

- **[NOTE]** `flutter run -d web-server` (debug) compiles & serves cleanly on first try (~24s to debug-service, full asset serve after). No build errors. Drift (sqlite wasm) + secure storage + notifications resolve on web without crashing.
- **[NOTE]** Runs at a fixed 500px-wide viewport (phone form factor). App is clearly designed mobile-first; see Responsive/Layout section for desktop-width behavior.
- **[IDEA]** `flutter run -d web-server` warns "requires the Dart Debug Chrome extension for debugging." Fine for serving; for true dev workflow `-d chrome` is better. Not a defect.

---

## Onboarding (first-run, `/onboarding`)

- **[NOTE]** 4-page flow: Welcome → Daily budget → Move goal → Choose rituals. Page dots, "Continue"/"Get started"/"Start tracking" CTA, and a "Skip" link all work. Selections **persist** through to Today (picked $120 budget + 60min goal → Today shows "/ $120" and "of 60 min goal"). Good.
- **[UX]** Page 4 "Choose your rituals" subtitle reads **"Five small things you want to do each day"** but **six** rituals are listed (Morning pages, Inbox zero, Language practice, Stretch, Read before bed, Meditate). Copy/content mismatch — either trim to 5 or fix the copy.
- **[UX]** "Skip" link sits directly under the primary CTA with no separation/secondary styling — easy to mis-tap. Consider more visual distance or a lighter treatment.

---

## Today tab

- **[NOTE]** Layout: greeting ("Jun"), bell + search icons, big tri-ring (Spent/Move/Rituals), "DAY" pace bar ("On pace · 2 rituals to close"), three summary cards (Spent/Move/Rituals), "PAL NOTICED" insight card w/ chevron, bottom nav (Today, Move, +FAB, Rituals, You).
- **[BUG]** The **bell ("Notifications") and search ("magnifyingglass") icons in the Today nav bar are dead controls** — they render but do nothing. Confirmed in source: `today_screen.dart:101-103` constructs `NavIconButton(...)` with **no `onTap`** (the param is optional, `nav_bar.dart:69`). Either wire them (notifications → Pal inbox; search → a search surface) or remove them.
- **[NOTE]** Cross-screen reactivity is excellent: adding a $12.80 expense in Spending detail updated Today's ring + Spent card to $73/$120 and flipped the day to "day closed / All rituals done" once rituals hit 5/5, with no manual refresh.
- **[NOTE]** Today summary cards deep-link correctly: Spent → `/today/spending`, Move → `/today/move-detail`, Rituals → `/today/rituals-detail` (`today_screen.dart:203-228`).
- **[NOTE/minor]** Today shows the spend rounded ("$73", "$60") while the detail shows cents ("$73.15", "$60.35"). Intentional-looking but worth confirming the rounding is desired on the hero.
- **[BUG?]** The floating **gear/cog icon** is pinned at the far-left edge (~x=30) overlapping the "Pal Noticed" card — see the Theme "Tweaks" section. Reads as a dev affordance left in the build.
- **[UX]** The **"PAL NOTICED" card is a static placeholder** (`today_screen.dart:236` comment: "static copy until U16 wires the real Pal note"). Its chevron and the three pill chips ("Why?", "Show me the days", "How to keep it up") **look interactive but have no handlers** — they're plain `Container`/`Text`. Either wire them to the Pal composer (seeded) or drop the affordances until wired, to avoid false signals.
- **[UX]** In the **Timeline** section, the **"Week" segment (accent-colored, looks like a toggle) and every timeline row are non-interactive.** Rows show rich data (transactions, workouts, ritual steps) and invite a tap to drill in, but nothing happens. Consider making rows tappable (→ detail) and wiring the Day/Week toggle.
- **[NOTE]** Good: the unified Timeline does include freshly-added entries (my "Expense −$12.80" appears inline), so the data layer is live even though the row interactions aren't.

## Backend / Pal connectivity (web-specific, HIGH impact)

- **[BUG]** With prod dart-defines the app uses the **real `HttpPalService`** (provider gate: `providers.dart:127` — non-empty `PAL_BASE_URL` ⇒ HTTP, else Mock). From the browser, every call to `https://opal.kael.life` **fails**: a direct `fetch('/v1/register')` returns `TypeError: Failed to fetch`, while a `no-cors` probe of the origin returns an opaque 200. **The server is up but sends no CORS headers**, so browser-origin requests are blocked. Net effect on web: all Pal features (workout pick, post-workout note, composer answers, email sync, monthly/weekly narratives) degrade to fallbacks.
- **[UX]** The fallbacks themselves are **well done** — "Freestyle session — Pal couldn't pick one just now", "Pal couldn't write a note just now" — no crashes. But the user waits out the **30s HTTP timeout** (`http_pal_service.dart:49`) staring at a "Thinking…" spinner before the fallback appears. On web specifically, consider a much shorter timeout (or a fast CORS-preflight failure path) so the freestyle fallback shows near-instantly.
- **[FIX]** To make the web build first-class: add CORS (`Access-Control-Allow-Origin` for the deployed web origin, handle `OPTIONS` preflight) on the `opal.kael.life` API. The server lives in `/server`.

## Move tab

- **[NOTE]** Layout: "THIS WEEK" stats (min/kcal/bpm), "Pal's pick" hero (Leg Day + Start), menu rows (My routines 5 ›, Exercise library ›, Weekly plan ›, History & trends ›), Recent sessions / See all, "…" overflow.
- **[NOTE]** Full **workout flow works end-to-end**: Start (freestyle) → Active Session (running timer, set targets, PR callout "Your PR 115kg×5 — Beat it today?") → "Complete set" updates sets/volume reactively and spawns a **rest timer** (2:30 countdown, +30s, Skip) → "Finish" shows a proper confirm dialog → Post-Workout summary (time/volume/PRs, muscles-worked bar, exercises, Pal note w/ graceful fallback) → "Save to timeline" returns to Move. Polished.
- **[BUG?]** **Routine cards on the "Start workout" screen did not navigate** when I tapped the card body or the per-card play button (3 attempts), even though `onTap: () => openSession(r.id)` is wired (`start_workout_screen.dart:98,407`). The freestyle "Start" button (same `openSession` path) *did* work. Possibly the same repaint-lag artifact (see below) rather than a logic bug — but worth a focused retest, since for a user a routine card that "does nothing on tap" is a serious dead-end.
- **[NOTE/automation]** Flutter web **pauses frame painting when the tab isn't the focused foreground** (automation artifact): clicks register but the screen doesn't repaint until the next input event, which made a confirm dialog look "frozen" (timers stuck) for several seconds until a hover forced a frame. Not a real-user defect, but if the app is ever embedded/backgrounded it could surprise. Flagged so future testers don't chase a phantom hang.
- **[BUG]** The Move **"…" overflow button (top-right) did nothing** on click. Likely a dead/un-wired control (or, less likely, repaint lag) — verify it has a handler.
- **[NOTE]** Move home "Pal's pick" resolves instantly to "Leg Day", while the dedicated Start-workout screen does the live (failing) Pal call — confirm the home card isn't silently showing a stale/hardcoded pick.
- **[BUG]** Move menu rows **"My routines" and "History & trends" have no `onTap`** (`move_screen.dart:274-298`) — dead rows. "Exercise library" and "Weekly plan" are correctly wired and navigate fine.
- **[NOTE]** Exercise Library works well: search filters live with a clean empty state ("No exercises match 'row'"), and the filter chips (All/Push/Pull/Legs/Core/Cardio) work. Caveat — **search AND filter combine**, so searching "row" with "Push" active shows zero results and hides the Cardio "Row Erg"; consider hinting that a filter is narrowing results.
- **[BUG]** **Exercise rows are dead** — `_ExerciseRow` builds a `ListRow` with `chevron: true` but **no `onTap`** (`exercise_library_screen.dart:315-324`), so every row shows a "drill-in" chevron that does nothing. No exercise-detail screen appears to exist.

## Systemic: misleading chevrons / dead `ListRow`s

- **[BUG/pattern]** A recurring defect: `ListRow` (and similar) rendered with `chevron: true` (or a visible `chevron.right`) but **no handler**. Confirmed instances: Today nav bell + search, Today "Pal noticed" chevron + chips, Today timeline rows + "Week" toggle, Move "My routines", Move "History & trends", Move "…" overflow, every Exercise-Library row. Users read a chevron as "tap to go deeper"; these all no-op. Recommend an audit: either wire each or drop the chevron/affordance. (Many are clearly "stub until U-xx" per code comments.)

## Theme "Tweaks" sheet (floating gear)

- **[NOTE]** The floating gear (bottom-left) opens a **"Tweaks"** bottom sheet: Light/Dark segmented toggle + 7 accent swatches. Dark mode applies instantly and globally — looks correct across all screens tested.
- **[BUG]** The gear is **pinned over screen content** (overlaps the Pal card on Today, overlaps editor steps on Rituals). It reads as a dev/demo affordance left visible in the build. If intentional, it needs a non-overlapping anchor; if a debug tool, it should be gated out of normal builds.
- **[UX]** Tapping a swatch / toggling theme **also dismisses the sheet on an outside-tap** very easily — during testing a single mis-aimed tap closed the sheet and navigated the underlying tab. The sheet's hit area vs. the barrier is too tight.

### Weekly Plan (`/move/weekly-plan`)

- **[NOTE]** Renders well: week strip with per-day status dots, "TODAY · THU" session card, schedule list with done-checkmarks. "Start workout" → `/move/start` works.
- **[BUG]** **"Swap" button is dead** — it's a `PressScale` with no `onTap` (`weekly_plan_screen.dart:360`), so it gives press feedback but performs no action.
- **[UX]** The **day strip is static** (no tap handlers) — tapping another day (e.g. Fri 25) doesn't change the selected day or the session card. If days are meant to be browsable, wire them; otherwise the selected-state styling oversells interactivity.
- **[NOTE]** Seed/mock data shows "WEEK OF APR 21" while the app's "today" is Thu Jun 11 — the plan isn't aligned to the current date. Fine for a demo, but a real build should anchor to today.

## Rituals tab

- **[NOTE]** Strong, polished flow. Hero "pick up where you left off / up next" card, per-routine color theming (Morning=amber, Midday=green, Evening=purple), inline step checkboxes, timeline rail. All reactive: checking a step updates the day counter ("X of 12"), the per-routine "n/5", the hero card's "steps left/time left", and the progress segments simultaneously.
- **[NOTE]** Routine **player** (`/rituals/player/:id`) resumes at the first incomplete step, "Mark done"/"Back"/"Skip" work, and completion shows a "Morning complete / All 5 steps done / 13-day streak" screen → "Back to routines". On return the routine flips to 5/5 + "Run again" and the hero advances to the next routine. Very clean.
- **[NOTE]** Manage builder (`/rituals/manage`): list with delete (×) + drag handles; tap-to-edit opens a full "Edit routine" form (name, time, tone segmented, icon grid, subtitle, steps with add/reorder). "New step" and "New routine" are nested sheets. Cancel correctly discards (verified: added a test step + test routine, cancelled, neither persisted).
- **[BUG]** In the **routine editor on web, the steps list runs under the persistent bottom navigation bar** and the outer scroll can't bring the last/newly-added step into view — couldn't visually confirm an added 6th step. The modal sheets sit *above* the shell logically but don't cover the bottom nav, so trailing content is occluded. Affects Edit-routine and likely other tall sheets at this viewport.
- **[UX]** "Time" in New/Edit routine is a **free-text field** ("e.g. 7:00 AM") with no time picker or format validation — easy to enter unparseable values. Consider a time picker or input mask.
- **[UX]** The Rituals top-right **"+" opens "Manage"** (a list/editor), not a direct "add routine" — mildly surprising for a "+". Manage then has its *own* top-right "+" for actually adding. Two layers deep for "add a routine."
- **[UX/minor]** "New routine" Save stays disabled until valid input (good), but it wasn't obvious whether name alone or name+time is required — disabled-state reasoning isn't surfaced.

## You / Profile tab

- **[NOTE]** Header (avatar, "Member since 2026"), THIS YEAR stats (Total spent $73 — reflects global state, Hours moved, Rituals kept, Longest streak 12d), then a SETTINGS list: Rituals, Budgets & goals, Notifications, HealthKit, Integrations (Email sync · Off), Subscriptions, Bills, Weekly review, Privacy, Export data, About (Opal 1.0). Avatar/header non-interactive (expected).
- **[NOTE]** **Budgets & goals** steppers work (Budget −/+ in $5, Move, Rituals) and **Save persists** — reopening the screen shows the new values ($130 / Rituals 4).
- **[BUG]** **The Today screen does NOT react to goal changes.** After saving Budget $120→$130 and Rituals target 5→4, Today still shows "SPENT $73 / $120", "of $120 budget", and "RITUALS 5 / 5". The values persist (Budgets & goals reflects them) but the Today hero/cards read a stale source. Onboarding's initial budget *does* reach Today, so they start in sync but diverge after an edit.
  - **Root cause (grounded):** `todayState` streams off `entriesRepo.watchToday()` and only *re-reads* goals on each **entries** tick (`today_controller.dart:89-90`). The goals stream isn't part of the trigger, so a goal edit with no accompanying entry never re-emits. (That's why my earlier $12.80 expense *did* refresh everything — it was an entries event.) Fix: merge/`combineLatest` the goals stream into the trigger, or `ref.watch` a goals provider so the stream re-runs on goal change.
- **[NOTE]** Settings screens that work cleanly: **Notifications** (permission button flips to "Allowed", both reminder toggles flip), **Privacy** (info-only), **Export data** (clipboard copy works on web — "Copied 12 entries to the clipboard"), **About** (info: Opal 1.0 / Flutter / On device).
- **[UX/web]** **iOS-specific copy leaks into the web build:** Notifications says "Opal asks **iOS** for permission…"; Health shows "**Apple Health** · Connected" with mock data even though there's no HealthKit on web. On web these read as wrong/misleading. Consider platform-aware copy, or hide the HealthKit row on non-iOS.
- **[NOTE]** Direct hash-route navigation (e.g. `#/you/health`, `#/subscriptions`) works for deep-linking — good for the web target.

  - **Confirmed live:** after I checked a ritual in Evening Close-out (a ritual *event*), Today re-emitted and **finally showed the saved $130 / Rituals 4**. So the values were always persisted; Today just won't refresh goals until an entry/ritual event fires. Exactly the `today_controller.dart:89` trigger gap above.

## Pal composer / FAB

- **[NOTE]** The center **FAB opens the Pal composer** (`/pal-composer`) as a bottom sheet: "Log, ask, or start anything", a contextual "Start a workout" action, "Try saying" suggestion chips, and a free-text input. Layout and motion are nice.
- **[BUG/web]** **Every composer path depends on the (CORS-blocked) backend.** Tapping a suggestion ("Verve coffee, $5") *sends it straight to Pal* (chat bubble + typing indicator) and spins on the 30s timeout — it does **not** fall back to a local log. So on web you **cannot log even a simple expense through the composer**, even though the keypad-based New Entry sheet logs the same thing instantly offline. The composer's quick-log suggestions should fall back to local NLU/structured logging when Pal is unreachable.
- **[NOTE]** The `?seed=` query param works — Pal-inbox card actions and seeded entries pre-fill + auto-send the composer.

## Modal & focus routes (Handoff #2 + legacy)

- **[NOTE]** Screens that render well but are **presentational mockups with stubbed actions** (`onTap: () {}`): **Subscriptions** (read-only list; "+" and rows no-op — `subscriptions_screen.dart:155`), **Bills** ("Pay now", "Remind", auto-pay toggle all no-op — `bills_screen.dart:172,299,317`). Good that "Pay now" is inert (no real payment), but as buttons they mislead.
- **[NOTE]** **Weekly Review** (`/weekly-review`) and **Monthly Review** (`/monthly-review`) are narrative+stats screens; stats reflect real state. Monthly Review's top Pal narrative card shows a shimmer/loading then a "Regenerate" retry (backend-dependent → fallback on web). Per router comments, monthly-review has **no in-app entry point yet** (deep-link/orphan route).
- **[NOTE]** **Evening Close-out** (`/close-out`) works: aggregates all 12 ritual steps; checking an item updates the count + ring reactively (5→6 of 12).
- **[NOTE]** **Streak Celebration** (`/streak`) renders fully (12-day streak, share card, Share/Keep going).
- **[BUG]** The streak **share card is mis-branded**: it reads "@mira · **ExpensePal**" — wrong app name (should be Opal) and a seed username ("mira") that contradicts the profile's "You". Brand/seed leak; fix before any share goes out.
- **[NOTE]** **Pal Inbox** (`/pal-inbox`) is the richest secondary screen: category filter chips (All/Unread/Money/Move/Rituals) all filter correctly, "Mark all read", per-card actions. Card actions route to the **seeded Pal composer** (e.g. a "View bill" button opened `/pal-composer?seed=Rent…` rather than the Bills screen) — label/behavior mismatch, and again backend-dependent.
- **[NOTE]** **Email Sync** flow (`/email` → `/email/setup`) renders well; "Test connection" fails **gracefully** ("Connection failed — check the password"), though on web the true cause is the unreachable backend, not the password — the message could mislead. (Did not enter credentials, per policy.)
- **[NOTE]** **AI Routine Generator** (`/move/routine-generator`): preset prompt cards fill the input and enable "Generate" without auto-submitting (good); generation is backend-dependent.
- **[NOTE]** **Legacy Quick Actions overlay** (`/quick-actions`, the pre-composer U06 menu) is still reachable and functional — "Log expense" correctly opens the New Entry sheet. Decide whether to keep it now that the FAB uses the Pal composer.
- **[NOTE]** **New Entry sheet** is a highlight: keypad entry, context-aware tabs (Expense=$/decimals/category, Workout="min"/no decimals/no category, Ritual), quick-picks, and a working Add that updates totals reactively. This is the offline-solid logging path.

## Onboarding

(Covered at top — 4-page flow, selections persist, "Five small things" vs six rituals copy mismatch.)

## Responsive / desktop layout (web-specific)

- **[BUG/web]** **No desktop layout / no max-width container.** At 1440×900 the phone UI **stretches edge-to-edge**: the Spent/Move/Rituals cards span the full width with large empty gaps, the activity ring floats in a sea of whitespace on the left, the Pal card becomes a full-width banner, and the bottom nav items spread across the entire width. It's usable but clearly unoptimized for desktop. For a real web target, constrain content to a centered max-width (≈420–600px, phone-shell style) or build a responsive multi-column layout. This is the single biggest "feels like a port" issue on web.
- **[NOTE]** No layout overflow/clipping errors were observed at desktop width — it scales without breaking, just without polish.

---

## Summary

**Overall:** The app is visually polished and the **core local flows are solid** — onboarding, ritual routines + player, the full workout session (start → sets → rest timer → finish → summary), New Entry logging, Exercise Library, Budgets & goals, Export, and the settings screens all work and are reactive across screens.

**The three things most worth fixing:**
1. **Backend is unreachable from the browser (CORS).** `opal.kael.life` is up but sends no CORS headers, so *every* Pal feature on web (workout pick, post-workout note, composer logging/answers, AI routine generator, email sync, review narratives) fails and waits out a 30s timeout before falling back. Fix CORS on the API (`/server`) and/or shorten the web timeout. Critically, make the **Pal composer fall back to local logging** so basic expense/ritual logging works offline on web.
2. **Today doesn't react to goal edits.** `today_controller.dart:89` only re-reads goals on an entries/ritual tick — merge the goals stream into the trigger.
3. **Many chevrons/buttons are dead** (`chevron: true` with no `onTap`, or `onTap: () {}`): Today bell/search + Pal chevron/chips + timeline rows + "Week" toggle; Move "My routines"/"History"/"…"; every Exercise-Library row; Weekly-Plan "Swap" + day strip; Subscriptions "+"/rows; Bills "Pay now"/"Remind"/toggle. Audit and either wire or remove the affordance.

**Smaller fixes:** onboarding "Five small things" vs six rituals; iOS-specific copy + "Apple Health · Connected" on the web build; the "@mira · ExpensePal" share-card brand leak; seed data dated to April while "today" is June 11; routine-editor steps occluded by the bottom nav; free-text time fields with no picker/validation; misleading "check the password" on a backend failure.

**Process note:** Flutter web pauses repaints when the tab isn't foregrounded under automation — clicks register but the screen only catches up on the next input. Several apparent "frozen/dead" moments were this, not real hangs; each was re-verified with a forced repaint. Where I call something dead/static above, it's confirmed in source.

---

## Follow-up (2026-06-11): hardcoded placeholder content (not wired to data)

Observed while verifying the seed-data gate on an **empty (unseeded) DB**. These surfaces render fixed demo-flavored copy regardless of the database, so they do **not** clear when data is empty — a fresh user still sees them. Unrelated to seeding; they need wiring to real data. The stat tiles on these screens *are* live (read $0/0/0 on empty); only the qualitative narrative/wins/patterns are static.

- **[UX] Today — "PAL NOTICED" card.** `today_screen.dart:241` (comment: "static copy until U16 wires the real Pal note"); `today_screen.dart:294` hardcodes "11 days in a row" (+ "spend 32% less on food"). Shows the streak/insight claim even with zero entries.
- **[UX] Weekly Review — Wins + Patterns + hero.** `weekly_review_screen.dart:30-32` static "Wins" ("11-day workout streak", "$160 under budget / $435 of $595", "Morning pages 6/7"); `:41-49` static "Patterns" ("Fridays cost you 2.8×…", etc.); `:108` fixed hero "Your steadiest week this month."
- **[UX] Monthly Review — Patterns (+ narrative).** `monthly_review_screen.dart:34-40` static `_patterns` ("Morning rituals lower food spending", "Friday is your spendiest day"); narrative card is Pal-generated with a hardcoded fallback string (shown when the backend is unreachable, e.g. on web).
