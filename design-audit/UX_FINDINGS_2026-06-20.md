# Opal — UX findings & prioritized fix list (2026-06-20)

Fresh iPhone-viewport walkthrough (430×932 web build, seed user `mira`), both
themes and both currencies. ~30 routes covered. Companion to
`LIVE_UX_AUDIT.md` (2026-06-15) — most June functional bugs are verified fixed;
this pass surfaces a new dominant theme (totals have no single source of truth)
plus VND-specific findings.

File references are grounded by code search but name the likely site, not a
guaranteed one-line fix. No code changed.

---

## Severity legend
- **P1** — user-visible wrong number / broken core action.
- **P2** — inconsistency or confusing state; not data-destructive.
- **P3** — copy / polish / IA.

---

## P1 — correctness

### 1. VND "50k" natural-language parse is 1000× too small
- **Seen:** "spent 50k on ramen" → `50 đ` (should be `50.000 đ`). The placeholder itself advertises "50k".
- **Where:** `lib/services/pal/mock_pal_service.dart:177` (and the chat path `:108`) — `RegExp(r'(\d+(?:\.\d{1,2})?)')` captures `50` and ignores the `k`. Also `:193` `replaceAll(RegExp(r'[\d.\$]'),'')` leaves the `k` in the title.
- **Fix direction:** extend the amount regex to capture an optional `k`/`m`/`tr`/`nghìn` suffix and multiply. Mirror the same fix in the real `/parse` seam server-side (`PalService.parse`, `pal_service.dart:620`). Add a parse unit test (`50k→50000`, `1.5m→1500000`).
- **Note:** mock-only confirmed; the HTTP backend parser needs the same handling for a real VND deploy.

### 2. Rituals/routines count disagrees across 7 screens
- **Seen:** Today ring & rituals-detail `0/3`; Recap→Day `3/3`; Recap→Week `3/21`; Close-out `0/4`; Pal Home/Inbox `4/5`; Rituals tab `3/12 steps`.
- **Canonical rule** (Budgets & goals copy): the ring counts *completed routines* per day → `0/3` is correct; **Recap `3/3` is wrong**.
- **Where:** `lib/controllers/recap_controller.dart:52–78` — `ritualsKept` = "count of ritual *entries* logged" (steps), but the tile shows it `of <routine target>`. Pal's `4 of 5` copy lives in the Pal note/agenda builders (`pal_context_builder.dart`, inbox/home controllers).
- **Fix direction:** pick one definition (completed-routines) as the single computed value; have Recap, Pal, close-out, and Today all read it. Relabel any screen that genuinely means *steps* as "steps".

### 3. Move-detail hero shows the monthly total against a daily goal
- **Seen:** `3012 kcal / of 500 kcal daily goal / 100%`. 3012 = the *month* total (Recap→Month = 3012); today is 599.
- **Where:** `lib/screens/detail/detail_screen.dart:195–196` hard-labels "daily"; the `data.value` it renders comes from the move-detail provider summing all listed workouts rather than today's.
- **Fix direction:** feed the hero today's active energy (same value the Today ring uses, 599); keep the full list below. Aligns move-detail with spending-detail (the correct template).

### 4. "Spent this month" reads $38.40 / $60 / $60.35 across screens
- **Seen:** Budgets `$38.40 of $2,600`; Insights/Recap `$60.35`; Today `$60`.
- **Root:** category↔envelope taxonomy mismatch. Entries use `Groceries/Dining/Coffee`; budget envelopes are `Food & Drink/Groceries/Bills/Shopping/Transport/Entertainment`. Dining + Coffee ($21.95) map to no envelope → uncounted in Budgets. Monthly budget also computed two ways: $2,600 (envelope sum) vs $2,550 (daily ×30).
- **Where:** `lib/controllers/budgets_controller.dart` + `lib/models/budget_envelope.dart` (envelope categories) vs the entry category set; `insights_money_controller.dart` uses entry categories (totals $60.35).
- **Fix direction:** one category taxonomy shared by entries, envelopes, and insights; map every entry category to exactly one envelope (or an explicit "Uncategorized" envelope so nothing falls through).

---

## P2 — inconsistency / confusing state

### 5. "Pal's pick for today" differs by screen
- Move home = **Leg Day**, Start Workout = **Push Day A**.
- **Where:** `lib/screens/move/move_screen.dart` vs `lib/controllers/start_workout_controller.dart` — two independent pick computations. Share one.

### 6. Push Day A card contradicts itself
- "last done today" (+ list "55 EST today") vs "It's been 3 days since you trained push, and you're fresh."
- **Where:** start-workout suggestion copy/data (`start_workout_controller.dart`, suggestion `WorkoutSuggestion` in `pal_service.dart:211`).

### 7. Streak vs weekly grid
- Today = 11-day streak; Move week strip = only Fri+Sat checked ("2/4"). Reconcile "streak" vs "this week's logged sessions".

### 8. Email connection state contradicts itself across screens
- You-tab row "Email sync — Gmail · On" vs dashboard "Gmail · not connected / Not connected".
- **Where:** the You integrations row (`lib/screens/profile/profile_screen.dart`) vs email dashboard state (`lib/screens/email/email_dashboard_screen.dart`). Drive both from one connection-state source.

### 9. Weekly plan vs Move home
- Weekly plan "0 of 0 done · 0 planned" vs Move home "2/4 workouts this week". Planned vs logged-against-goal never reconcile.

### 10. Pal Inbox date drift
- "You skipped lunch **Sunday**" stamped "**Yesterday**" (yesterday = Fri Jun 19). Seed/relative-date mismatch persists for some inbox items.

### 11. Notifications: reminders ON without permission
- Routine reminders + Budget alerts toggled **ON** while OS permission "Not set". No request-permission affordance reflecting the gap.
- **Where:** `lib/screens/settings/notifications_screen.dart`.

### 12. Recurring main-thread jank
- Renderer froze (screenshot timeout) 4× on heavy reloads / list-tap transitions (start-workout load, post-currency-switch, move-detail row tap, You scroll). Verify on device.

---

## P3 — copy / polish / IA

- **Email disconnected CTA:** primary black button is "Sync now" (unusable when not connected); the connect action is only body text. Make primary = "Connect Gmail". (`email_dashboard_screen.dart`)
- **Weekly plan empty state** lacks an add/schedule CTA (only an overflow "…"). (`lib/screens/move/weekly_plan_screen.dart`)
- **Post-workout** pluralization "1 SETS" / "1 sets in the bank" → "1 set"; unit drift hero "0.5 tonnes" vs row "450 kg"; "0 TIME min" for sub-minute sessions. (`lib/screens/workout/post_workout_screen.dart`)
- **Recap tabs uneven depth:** Day = bare stat cards; Week = Wins+Patterns+One-thing; Month = Patterns only.
- **Pal IA:** three entry points (Composer / Home / Inbox) with overlapping names; "All stats" is a 4th door into Recap. Consider consolidating naming/entry.
- **Two settings entries:** gear icon top-right + Account → "Settings" row on the You tab.
- **Close-out** header renders a tofu/placeholder glyph (SF Symbol → missing-glyph on web; fine on iOS).
- **Insights Categories** footnote "Change shown vs. last month" but no change shown (no history).
- **Detail "Other" breakdown:** move & rituals detail lump everything into a single "Other" row; spending-detail has real categories — bring the other two to parity.
- **VND symbol:** uses `đ` (U+0111), not the formal dong sign `₫` (U+20AB). Acceptable informally.

---

## VND verdict (focused pass) — mostly good
Correctly localized: Vietnamese period-grouping (`50.000 đ`, `2.562 đ`), decimals
dropped, `đ` suffix, decimal key removed from the keypad, localized "50k" hint.
The tiny seed values (`85 đ` budget) are a USD-scale-seed artifact ("amounts not
converted" is by design), **not** a formatter bug — but any VND demo on seed data
looks broken; consider a VND-scale seed. The one real defect is **#1 (50k parse)**.

---

## Verified good / June regressions fixed
Dark mode; spending-detail (correct daily hero + real breakdown); live workout
session (timer, PR, rest, set logging, Finish confirm); post-workout summary;
Pal Home & Inbox; New Entry (incl. VND adaptation); routine player (June "5/5 vs
bar" gone). June bugs confirmed fixed: move-detail kcal unit (#1), streak value
(#7), close-out count copy, NL category extraction (#12), start-workout loading
(#10), email dashboard internal contradiction (#3), Gmail setup "ExpensePal"→
"Opal" (#5).

## Coverage
Not reached: `workout-detail` (`/move/workout/:id`) — no tappable entry point in
this seed (cardio rows & move-detail "today's workouts" rows aren't tappable) and
no valid id to deep-link; covered in June (#11, judged structural).
