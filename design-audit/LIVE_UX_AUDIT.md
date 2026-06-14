# Opal — Live UX/UI Audit (browser walkthrough)

Generated 2026-06-15. A click-through pass of the running Flutter **web** build at
`http://127.0.0.1:8090`, at an **iPhone-width viewport** (~390px), in both light and dark themes.
Every named route was visited and interactive elements were exercised (chips, toggles, steppers,
filters, FAB, overflow menus, NL parse, theme switch, export).

## Method & scope

- Walked all ~30 routes in `lib/router.dart` plus modal/overlay flows (onboarding, Pal composer,
  quick actions, new-entry sheet, edit-routine sheet, guided routine player, completion/streak).
- Seeded via `dart_defines/dev.json` (`SEED_DATA: true`), user "mira".
- Interactions verified: onboarding chips/toggles, routine step completion (persisted across reload),
  budget steppers, library filters, inbox filters, theme switch (+ dark-mode render check),
  NL "Log with Pal" parse, JSON export.

## Root-cause note (read first)

The seeded "today" assumes a **mid-week evening** (Friday-spending patterns, "day closed", `DAY · 21:30`,
"30 min before sleep"), but the actual run date is **Monday, June 15 2026, ~02:00**. That single mismatch
generates most of the date/count oddities in the "Data inconsistencies" section — they are largely
**seed-data artifacts**, not logic bugs. The items in "Functional bugs" are independent of that.

---

## 🔴 Functional bugs (UI/logic)

| # | Screen | Issue | Severity |
|---|--------|-------|----------|
| 1 | Move detail (`/today/move-detail`) | Workout tracker shown in **minutes** ("66 min / of 500 **min** daily goal / 13%") while the rest of the app uses **kcal** ("599 / 500 kcal / 119%"). Same "500", wrong unit, opposite progress. Looks like the kcal re-base (per git history) never reached this screen. | **High** |
| 2 | Today + Rituals detail | "Routines" counts completed **steps** but labels them routines. Completing only Morning yields "**Routines 5/5 · All routines done**" / "**5 Routines completed · 100%**" while Midday (0/3) and Evening (0/4) are untouched. | **High** |
| 3 | Email Dashboard (`/email/dashboard`) | Self-contradicting: card says "**Not connected · Never synced**" but shows a green "**● Connected**" badge **and** a "**Disconnect Gmail**" button, with stats "2 This month / 2 All time" under "No imports yet". | **High** |
| 4 | Monthly Review | Prose "**22 active days**" contradicts "By the numbers → Active energy: **1 active day**" on the same screen. | **High** |
| 5 | Gmail Setup | Step 3 says label the app password "**ExpensePal**" — stale pre-rename name (app is Opal). Known rename leftover (see `DESIGN_DIFFERENCES.md`). | Med (clear) |
| 6 | Workout Detail, Monthly Review (≥2 screens) | "**…**" overflow menu produces no menu on tap — dead control, likely app-wide. | Med-High |
| 7 | Streak Celebration (`/streak`) | Shows "**0 days moving / WORKOUT STREAK 0 days**" + "STREAK UNLOCKED" while Today/Weekly correctly show the **11-day** streak. | Med-High |
| 8 | Workout home | "**History & trends**" row does nothing and (unlike rows above it) has no chevron — looks tappable, isn't. | Med |
| 9 | Today header | **Search** icon appears non-functional — no search UI after repeated taps. | Med |
| 10 | Start Workout | "Pal's pick" stuck on "**Thinking… / Pal is picking your session…**" while the picks (5 exercises, 62 min, chips) are already fully rendered. | Med |
| 11 | Today / Move / Workout Detail | Same workout, two durations: "Strength · push" = **42 min** (timeline, Move detail) vs **52 min** (Workout Detail, Move home). Also Push Day A *routine* = 5 ex/16 sets vs *logged* session = 2 ex/5 sets. | Med (confirm intent) |
| 12 | New Entry | NL parse of "spent 18.50 on dinner at Tartine" extracts the amount but leaves **Category empty** (no "dinner"/"Tartine"). | Low-Med |

---

## 🟠 Data inconsistencies (mostly seed-driven, but user-visible)

- **Routines denominator never reconciles:** "3/5"→"5/5" (Today) vs "3 of 12 steps" (Routines tab) vs "5 of 35" (Weekly) vs "5 daily goal" (Budgets / Rituals detail).
- **Pal Inbox dates:** "Fourth Verve this week … since Monday" (today *is* Monday); "skipped lunch **Tuesday**" timestamped "**Yesterday**" (Tuesday is future); "Rent auto-pays **Monday** … on **Apr 28**" timestamped "Fri".
- **Identity:** Profile shows "**You**"/"Y" but Streak/Setup show "**@mira**" / "mira@gmail.com" (onboarding name left blank → default "You"; seed hardcodes mira).
- **Profile review dates stale:** "Weekly · Apr 17–23", "Monthly · April" vs the screens themselves rendering **Jun 15–21 / June**.
- **"Tracking since June 2026 · 0 days"** contradicts the 11-day workout and 12–13-day routine streaks.
- **Close-Out copy:** "0 of 4 rituals done. **One more** to close the ring." (one more implies 3 done).
- **In-progress periods:** Weekly/Monthly "review" shown mid-week / mid-month.
- **Minor numeric drift:** routine streak 12 (Monthly) vs 13 (completion); $60 (rounded, Today/Weekly) vs $60.35 (Spending detail).

---

## 🟡 Terminology

- **"rituals" vs "routines"** interchangeable: tab "Routines" (intentional), but Profile "Daily rituals", Close-Out "rituals", Inbox "routines". Flagging the *rituals* leakage.
- **"steps" vs "rituals"** for the same items (Routines tab "steps" vs Close-Out "rituals").
- **"movement" vs "workout"** (Weekly Review / README say "movement").
- **"×" overloaded:** "74×8" = weight×reps, but "3 × 1288kg" = sets×total-volume.
- **Unit labels drift:** "1.9 tonnes" vs "1.9t"; "52 min" vs "52m" vs "EST"; "599 KCAL" vs "500 kcal" within one card.

---

## 🔵 UX/UI improvements

- **Onboarding name** is optional with no validation; "Get started" proceeds on empty → drives the "You" vs "mira" identity mismatch.
- **Low-contrast buttons:** Routines-tab "Start/Continue" use color-on-tint (e.g. light-green text on near-white) — likely fails WCAG contrast.
- **New Entry quick-chips not filtered by type** — Workout (Run/Walk) and Routine (Morning pages) chips appear under the Expense tab.
- **Inconsistent exercise icons:** some get specific glyphs (Leg Press, Walking Lunge), others fall back to a generic diagonal-arrows icon (Back Squat, RDL) — that fallback also fronts session cards, reading like "expand".
- **Redundant Pal surfaces:** Pal Composer (FAB) + Ask Pal (`/pal`) + Inbox overlap; **Quick Actions overlay (`/quick-actions`) is orphaned** — unreachable from the UI (FAB opens the Composer), matching the router's own "replaces Quick Actions menu" note.
- **Detail "Breakdown"** lumps everything into "Other" on Workout/Routines detail (Spending detail has real categories).
- **Smaller:** Weekly Plan empty state lacks an add/schedule CTA; Exercise Library count stays "21 in library" when filtered; Notifications reminders ON while OS permission "Not set" (no prompt); two add affordances on Routines (top-right "+" and "+ New routine"); routine player "5/5" reads as count but bar shows 4/5; "$0" vs "$5.00" placeholder/filled formatting.
- **Copy nits:** "ordered to keep fresh muscles fresh" (repetition); "your Friday splurges drop the weeks you do" (missing "on"); "paste it into a … spreadsheet" for JSON.
- **Modal not route-tied:** deep-linking under an open Edit-routine sheet orphaned it (Cancel/Escape failed; needed a reload). Edge case, but the sheet isn't bound to the URL.

---

## ✅ Works well

Onboarding flow; **dark mode** (instant, adapts the black↔white accent swatch); reactive step completion +
persistence across reload; budget steppers; JSON export with confirmation; library/inbox filtering; Pal chat;
the Privacy screen; per-routine time-of-day color theming (Morning amber / Midday green / Evening purple).

---

## Open questions

1. Is the **42-vs-52 min** / **Push Day A 2-vs-5 exercises** split intentional (partial logged session vs template), or a data bug?
2. Should the seed-data date issues (Inbox dates, profile review dates, "0 days tracking", in-progress reviews) be treated as bugs or expected dev-seed behavior?

---

## Resolution (2026-06-15)

Fixed via 9 parallel subagents + manual follow-ups. Verified: `flutter analyze` clean, `flutter test` 169/169 pass, and headline fixes confirmed in a live rebuild.

**Fixed & verified:** #1 move detail kcal · #2 routines counted as completed÷total (Today "1/3", detail hero, Budgets, Profile, widget all aligned) · #3 email dashboard single-source state · #5 ExpensePal→Opal · #6 overflow menus implemented · #7 streak reads real value · #8 History&trends wired+chevron · #9 Today search implemented · #10 start-workout loading clears · #12 NL parse extracts category.

**Fixed (analyze/test only, UI not re-shot):** #4 monthly prose de-fabricated · #16 profile review dates computed from `now`.

**Seed re-anchored to run-date:** Inbox day-name/date drift, "tracking since" (added 14-day-ago entry → ~14 days), and a real **11-day move streak** backfilled (today + prior 10 days) so the "11-day workout streak" copy is now truthful. #11 (42→52 min) reconciled in seed; "Push Day A" 5-vs-2 exercises judged **structural** (template vs partial logged session) and left as-is.

**Deferred (copy/design, not bugs — not yet done):** terminology sweep (rituals↔routines, movement↔workout, overloaded "×"), low-contrast tinted buttons, onboarding name validation, New-Entry quick-chip type filtering, exercise-icon fallback, redundant Pal surfaces, "You" vs "@mira" identity, close-out copy.

---

## Deferred pass (2026-06-15)

Picked up the deferred copy/design items. `flutter analyze` clean (one pre-existing unrelated lint in `widget_sync_controller_test.dart`), `flutter test` 169/169 pass.

**Done & verified (analyze + test):**
- **Terminology — rituals→routines:** tab title was already "Routines"; **Close-Out** copy changed from "rituals" → "steps" (these count the Evening routine's *steps*, matching the Routines tab) and made **count-aware** (the always-"One more to close the ring" bug now reads "N more" / "Ring closed").
- **movement→workouts:** Weekly Review lede now "spending, workouts, and routines".
- **kcal casing:** standardized to lowercase "kcal" on Today (fixes the "KCAL / kcal within one card") and Onboarding.
- **Low-contrast buttons:** Routines-tab `_StartButton` label now uses `ink2` (clears WCAG on the ~8% tint); colored icon retained for identity.
- **New-Entry quick-chips:** now filtered by selected entry type (`_picks.where(kind == _kind)`) — no more Workout/Routine chips under Expense.
- **Identity "You" vs "@mira":** Streak share card now uses the real display name (falls back to "You"); Gmail Setup email no longer prefilled with "mira@gmail.com" (empty + "you@gmail.com" hint).
- **Onboarding name:** trimmed before save (whitespace-only → "You" fallback); optional-name design kept intentionally.
- **Redundant Pal surfaces:** removed the orphaned **`/quick-actions`** overlay (route in `router.dart`, overlay set in `app.dart`, and `quick_actions_overlay.dart` deleted). `test/quick_actions_test.dart` is legacy-named but actually tests the FAB→Pal composer — left as-is.

**Still deferred (judged out of scope / not a fix):**
- **Overloaded "×":** semantic (same glyph, "3 × 1288kg" sets×volume vs "74×8" weight×reps), not a glyph inconsistency — would need a relabel.
- **Exercise-icon fallback:** Back Squat/RDL DO map (`figure.strengthtraining.traditional` → barbell); the "generic" look is a Material **preview-substitution** limitation (correct SF Symbols on iOS). App-wide `iconForSf` fallback kept neutral.
- **Unit drift tonnes↔t, EST:** contextual (spelled-out tile label vs inline compact) — left.
- **Redundant Pal surfaces (broader):** Composer + Ask Pal + Inbox overlap is a larger design consolidation, not done.
