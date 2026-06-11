# ExpensePal Design Handoff vs. Opal App — Differences Audit

Generated 2026-06-11. Compares the latest design handoff (`Downloads/expensepal (4)`, the authoritative
"ExpensePal" iOS prototype) against the current Flutter implementation in this repo (`opal`), plus a live
visual pass of the running web build at `http://127.0.0.1:8080`.

## Sources compared

- **Design (source of truth):** `expensepal (4)/src/*.jsx` (React/iPhone-frame prototype, 25 screens),
  `design_handoff_expensepal/README.md` (892-line full spec), and
  `Handoff - Workout Rename & Budget Editor.md` (incremental round: Move→Workout rename, self-logged
  ring, budget editor, HealthKit removal).
- **Current app:** `lib/screens/**` and `lib/widgets/**` (on-disk source).
- **Live build:** running Flutter web app, screenshotted per main tab + the entry composer.

Earlier handoffs (`expensepal`, `(1)`, `(2)`, `(3)`) are older subsets superseded by `(4)`; `(4)` is the
only one carrying the incremental rename/budget doc, so it is treated as canonical.

## Method

Seven parallel agents each audited one domain (design JSX vs. matching Dart), tagging every difference
`[MISSING]` / `[DIFFERENT]` / `[COPY]` / `[LAYOUT]` / `[STYLE]` / `[SUBTAB]`. Their full reports are the
numbered sections below. A live-build visual pass (Chrome) then verified the findings on screen, with
particular attention to subtabs / segmented controls (which are easy to miss in source).

## IMPORTANT caveat — running build is slightly stale vs. on-disk source

The live web build does **not** reflect all uncommitted source edits (git shows ~40 modified `.dart`/`.g.dart`
files). Where the agents (reading current source) and the screenshots (older compiled build) disagree, both
states are recorded. Concretely, the live build still shows `Move` / `Rituals` / `My routines` and the
`287 kcal` timeline badge, while the source has partial renames — so **the Move→Workout rename is in-flux
and applied in neither place completely.** Rebuild before judging copy.

---

## Executive summary — highest-impact gaps

1. **Move→Workout rename not applied (incremental handoff §1).** Live build still labels the tracker
   `Move`, ring stat `MOVE`, tab `Move`, subtitle "Gym, cardio, daily movement", "My routines", and copy
   "You've moved 11 days". The handoff renamed all user-facing strings to Workout/"Workouts, routines &
   sessions"/"worked out". Source has scattered, inconsistent renames (and over-applied `routine`→`workout`
   in the workout flow). Net: neither design state achieved.

2. **HealthKit / calorie content still present (incremental handoff §2 says remove everything).**
   - Move tab "THIS WEEK" card shows `512 kcal ENERGY` and `72 bpm AVG HR` (live build).
   - Today timeline shows `287 kcal` for the run (seed data still `calories: 287/312`); spec says `24 min`/`42 min`.
   - **You ▸ Settings still contains a `HealthKit` row.** Spec: "No HealthKit dependency anywhere."

3. **You tab is the wrong architecture.** Ships the old README-§15 stat-grid + "Member since 2026" + a
   generic settings list. The newer `tab-landings.jsx` redesign (profile card "Mira Okafor / Tracking
   since…", a **Goals** section with the tap-to-edit **Budget editor**, and Reviews/Money/Integrations/Data/
   Account inset groups) is missing.

4. **Budget editor missing / wrong (incremental handoff §3).** Design is a bottom-sheet `BudgetSheet` with a
   **Daily/Weekly segmented control**, 54px amount, circular steppers, preset chips, footnote. Flutter ships
   a flat full-page stepper with no period toggle, and no Goals entry point on the You tab.

5. **Bills & Subscriptions deleted with no replacement.** `bills_screen.dart` and `subscriptions_screen.dart`
   are removed (git `D`). Data layer (models/repos/`money_recurring_controller`) survives as unreachable code.
   The live (stale) build still shows `Subscriptions` and `Bills` rows in You ▸ Settings — i.e. those nav
   links now point at deleted screens (**broken-route regression** once rebuilt).

6. **Workout post-session + PR surfaces gutted.** No standalone "PERSONAL RECORD" card
   ("Bench Press · 90kg × 5 · +5kg from previous best"), 4th "Sets" stat dropped, per-set volume bar chart and
   per-muscle breakdown replaced by flat chips. Rest-timer banner lost its animated spinner/progress-fill.

7. **Email Sync dashboard stripped.** Missing the Stats tiles (This month/All time/Recurring), the
   "Pal noticed" subscriptions card + "Review subscriptions" CTA, the "Sync settings" list, and the Gmail
   brand glyph (generic envelope used instead). Subscriptions therefore has effectively no UI surface left.

8. **Monthly/Weekly review copy & content diverge.** "Patterns Pal found" use entirely different copy and
   drop the design's stat sub-captions (e.g. "↓12% vs March").

9. **Systematic `ritual(s)`→`routine(s)` copy drift** across Today, tab bar, Ask Pal, Weekly Review, and the
   inbox filter chip — a rename the handoff never authorized (it only renamed Move→Workout). Note: the live
   build still shows "Rituals", so this drift is in the uncommitted source only.

---

## Resolution status — Wave 7 reconciliation (2026-06-11, commit `f3817d9`)

Everything below this section is the original point-in-time audit, left intact. This block records
what the Wave 7 pass changed. ✅ resolved · ⊘ resolved by removal · ⏳ deferred.

**Executive-summary gaps**
1. ✅ **Move→Workout** rename completed across all user-facing strings (kept, per user decision).
2. ✅ **HealthKit / calorie UI** removed from the Workout "This week" hero and the Today timeline
   badge (kcal→min). No Settings "HealthKit" row actually existed to remove. The native iOS
   `HealthKitService` stays as intended device-gated dead code (U27).
3. ✅ **You tab** rebuilt as `YouTabScreen` — profile card + Goals/Reviews/Integrations/Data/Account
   inset sections; the old README-era stat grid was dropped.
4. ✅ **Budget editor** added (`lib/widgets/budget_sheet.dart`, Daily/Weekly) wired to the Goals
   "Daily budget" row.
5. ⊘ **Bills & Subscriptions** — per user decision, **removed entirely** (screens + routes + the You
   "Money" section), not restored. No broken routes remain. The `Bill`/`Subscription` models, repos,
   and `money_recurring_controller` now survive as **dormant/unreachable code** (flagged for deletion).
6. ✅ **Workout post-session / PR surfaces** present (PR card, Sets stat, per-set volume chart,
   per-muscle breakdown, rest-timer spinner).
7. ✅ **Email Sync dashboard** rebuilt (Stats tiles, "Pal noticed" card + Review CTA, Sync settings,
   Gmail glyph).
8. ✅ **Monthly/Weekly review** copy aligned to the design.
9. ✅ **ritual→routine drift** confirmed intentional and completed (kept, per user decision).

**Subtabs:** ✅ the one genuinely-missing control — the Budget editor Daily/Weekly toggle — now exists.

**Stale-build caveat (in the header above):** now obsolete — the renames are committed; rebuild to verify.

⏳ **Remaining (Windows-now long-tail, not yet done):** assorted `[STYLE]`/`[LAYOUT]` nits; data-model
gaps (routine `estMin`/`lastDone`, cardio distance/pace, richer Start-workout cards); a few SF-Symbol
map entries (`arrow.right`, `timer`, `list.number`); status-bar style; the Day/Week Today-timeline
toggle (still inert); Pal-insight / timeline-row tap wiring; and removing the dormant Bills/Subs data
layer. Full test suite: **109 green**.

---

## Subtabs / segmented controls — explicit status (per your focus)

| Surface | Design intent | Current state |
|---|---|---|
| New-entry sheet — Expense / Workout / Routine | segmented control | **Present & correct** (source) |
| Appearance — Light / Dark | segmented control | **Present** |
| Onboarding — chip selectors | chip groups | **Present & correct** |
| Pal Inbox — All / Unread / Money / Workout / Rituals | 5 filter chips | **Present & wired** (chip 5 labeled "Routines") |
| Pal Composer — starter chips | 3 "Try saying" chips | **Present** (verified live) |
| Ask Pal — suggestion chips | 3 chips | **Present** |
| Rituals — Cards / Timeline / Minimal switcher | ship ONE (timeline) | **Correctly absent** — Timeline only, per spec |
| Rituals time-of-day — Morning/Midday/Evening | grouped sections | **Present** (verified live) |
| Today — Day/Week timeline toggle | toggle | **Present** ("Week"), but inert in build |
| Move — History & trends period | period value | Present ("All time") |
| **Budget editor — Daily / Weekly** | segmented control | **MISSING** (only missing subtab) |
| Email — provider toggle (Gmail/Outlook/IMAP) | (prototype: none) | Absent in both prototype & app (README-spec picker never built) |
| Weekly / Monthly Review — period segmented | none in design | Correctly absent |

Net subtab finding: only the **Budget editor Daily/Weekly toggle** is a genuinely missing segmented control.
Everything else is present (sometimes mislabeled) or intentionally single-mode.

---

## Live-build visual verification (Chrome, running web app)

Screens walked: Today, Move, Rituals, You, and the `+` composer. Notes confirming/contradicting source reads:

- **Today:** ring legend `SPENT / MOVE / RITUALS`; timeline run badge `287 kcal`; "You've moved 11 days";
  Pal-insight card **does** render the chevron + three reply chips ("Why?", "Show me the days", "How to keep
  it up") — contradicting the source-read claim that chips are absent. Verify against rebuilt source.
- **Move:** title `Move` / "Gym, cardio, daily movement"; `THIS WEEK` card `512 kcal` + `72 bpm`; rows
  "My routines" (5), "Exercise library", "Weekly plan", "History & trends" (All time). "My routines" reads
  correctly here (not "My workouts").
- **Rituals:** title `Rituals`; Timeline layout with Morning(5/5)/Midday(1/3)/Evening(0/4); no layout switcher.
- **You:** `You` / "Member since 2026"; stat grid (Total spent/Hours moved/Rituals kept/Longest streak);
  settings rows incl. **HealthKit**, Subscriptions, Bills, Integrations(Off). Old architecture, no Goals.
- **`+` composer:** "Pal · Log, ask, or start anything", green "Start a workout", 3 try-saying chips, free-text
  input — matches the design's single-input-surface pattern.

> Because the build is stale, treat live copy as the *last-compiled* state, and the numbered source audits
> below as the *current* state. Rebuild (`flutter run -d chrome`) to reconcile the two before fixing copy.

---


---

# Today, Activity Rings & App Chrome

Audit of the Flutter implementation (`opal`) against the ExpensePal design handoff
(React/JSX prototype + README spec + "Workout Rename & Budget Editor" incremental MD).
Design is the source of truth. Severity tags: `[MISSING]` `[DIFFERENT]` `[COPY]` `[LAYOUT]` `[STYLE]`.

Files read:
- Design: `today.jsx`, `ios-frame.jsx`, `tokens.jsx`, `components.jsx`, `README.md`, `Handoff - Workout Rename & Budget Editor.md`
- Flutter: `today_screen.dart`, `activity_rings.dart`, `nav_bar.dart`, `loop_tab_bar.dart`, `loop_shell.dart`, `summary_tile.dart`, `app_colors.dart`, `app_text.dart`, `today_controller.dart`, `seed_data.dart`, `main.dart`, `app.dart`, `Info.plist`, iOS LiveActivity Swift files.

---

## 1. Today screen (`today_screen.dart` vs `today.jsx`)

### Copy / text

- `[COPY]` **kcal→min rename NOT applied in timeline rows.** The incremental handoff (§2) mandates that the two move entries show **minutes, not kcal** ("Run · Mission loop" `287 kcal`→`24 min`; "Strength · push" `312 kcal`→`42 min`). But `_TimelineRow._valueText` prefers calories: `if (entry.calories != null) return '${entry.calories} kcal';`. Seed data (`seed_data.dart`) still carries `calories: 287` (run) and `calories: 312` (strength), so the live timeline renders **"287 kcal"** and **"312 kcal"** — the exact strings the handoff said to remove. This is the single most important regression in this section.
- `[COPY]` **Strength duration wrong: 52 vs 42.** Seed `seed-entry-strength` has `duration: 52` and `detail: '52 min · gym'`. Design (today.jsx entry id 7 / incremental §2) specifies `42 min` and detail **"Push day · gym"**. Both the value and the detail string are off. Consequently the move ring sum is 24+52=76, not the design's 66 (`moveMinutes = 66` vs `moveGoal = 60`).
- `[COPY]` **Run detail differs.** Design today.jsx shows run value badge "24 min" with detail "4.8 km · 24:10". Flutter seed keeps detail "4.8 km · 24:10" (matches) but the badge resolves to kcal (see above), so the rendered run value is wrong.
- `[COPY]` **Ring stat label "Routines" vs design "Rituals".** Flutter `RingStat(label: 'Routines')`. Design today.jsx uses `label="Rituals"` for the third ring stat. Note the incremental handoff renamed *Move*→*Workout* but did **not** rename Rituals→Routines; Flutter has independently renamed the rituals tracker to "Routines" across Today (ring stat, summary tile, close-out copy). This is a divergence from both the prototype and the rename spec. Flag as an app-wide inconsistency, not just here.
- `[COPY]` **Day-progress eyebrow differs.** Design: left label **"Day · 21:30"** (literal time), right text **"On pace · 1 ritual to close"**. Flutter: left label hard-coded **"DAY"** (no time), right text `'On pace · $closePrompt'` where closePrompt is e.g. "1 routine to close" (uses "routine", and "On pace · day closed" / "On pace · …" branch). Time-of-day suffix is dropped; "ritual"→"routine".
- `[COPY]` **Pal-insight body copy differs.** Design: *"On days you finish morning **rituals**, you spend 32% less on food."* Flutter: *"…finish morning **routines**…"*. Same rituals→routines drift.
- `[COPY]` **Close-out subtitle differs.** Design: **"1 ritual left · 30 min before sleep"**. Flutter: `'$closePrompt · 30 min before sleep'` → e.g. "1 routine to close · 30 min before sleep" ("ritual left"→"routine to close").
- `[COPY]` Matches: nav title "Today", "PAL NOTICED" eyebrow, "11 days in a row" bold + "32% less" money-tinted, "Timeline" header, "Week" action, bucket "{n} entry/entries" counter, "Close out your day", Morning/Afternoon/Evening bucket labels — all match.

### Missing components / behaviors

- `[MISSING]` **Pal-insight card is not tappable and has no chip row.** Design wraps the card in a `<button onClick={onOpenStreak…}>` and renders a trailing `chevron.right` plus a row of three reply chips **"Why?"**, **"Show me the days"**, **"How to keep it up"** (each seeds Pal). Flutter renders a plain `Container` with no chevron, no chips, and no tap handler. Both the streak-celebration entry point and the quick-reply chips are absent.
- `[MISSING]` **"Week" toggle is non-interactive.** Design renders it as a `<button>` (week/day timeline switch). Flutter renders a bare `Text('Week')` with no gesture.
- `[MISSING]` **Timeline rows are not tappable.** Design rows have `onClick={() => onOpenDetail(e.type)}`. Flutter `_TimelineRow` is a static `Container` with no tap/route to entry detail.
- `[MISSING]` **Close-out card is not tappable.** Design is a `<button onClick={onOpenCloseout…}>` opening the evening close-out. Flutter is a static `Container`; the trailing `chevron.right` is decorative only.
- `[MISSING]` **Dashed border on close-out card.** Design border: `0.5px dashed ${theme.rituals}55`. Flutter uses `Border.all(... width: 0.5)` — a **solid** border (Flutter `Border.all` cannot dash). Style mismatch.

### Layout / structure

- `[LAYOUT]` **Extra 3-up summary-tile row present in Flutter, not in current design today.jsx.** Flutter renders a `SizedBox(height: 132)` row of three `SummaryTile`s (Spent / Workout / Routines) between the rings card and the Pal card. The design `today.jsx` has **no** such row on Today — `SummaryTile` is defined but unused in today.jsx. (The README §02 step 3 lists "3-up summary tiles," so this reflects an older spec; the current prototype dropped them in favor of the rings+stats card. Flag as design-vs-prototype divergence — the built screen has both the ring stats *and* the tile row, which is redundant.)
- `[LAYOUT]` Day-progress bar, rings hero, ordering (rings → Pal → timeline → close-out) otherwise match design order (aside from the inserted tile row).

### Style / tokens

- `[STYLE]` **Ring stat goal unit:** design move goal string is `/ {moveGoal} MIN` (matches Flutter `/ {…} MIN`). OK.
- `[STYLE]` Rings card radius 18, padding 18/18/16, gap 18; Pal card radius 18 pad 16; timeline card radius 14; close-out radius 14 — all match design values.
- `[STYLE]` `RingStat` widget (`summary_tile.dart`) matches design `RingStat`: 7px dot, 12/700 uppercase color label, 22/700 ink value + 12/600 ink3 goal. OK.

---

## 2. Activity Rings (`activity_rings.dart` vs `components.jsx` ActivityRings + README §"Activity Rings")

- `[STYLE]` **Stroke width uniform 14 vs design's tapered 24/22/20.** README §"Activity Rings (hero on Today)" specifies **Money outer = 24px stroke, Move middle = 22px, Rituals inner = 20px**. Flutter uses a single `strokeWidth = 14` for all three rings (matching the *components.jsx* prototype, which also uses `strokeW = 14`). So Flutter matches the JSX prototype but **not** the README component spec. The prototype is the more recent/concrete artifact; flag the README/prototype contradiction. Net: rings are thinner and untapered vs the README.
- `[STYLE]` **Track opacity 20% vs spec 18%.** Flutter track = `colors[i].withValues(alpha: 0.20)`. README says "track = ring color @ 18%"; JSX prototype uses `+ '33'` (= 20%). Flutter matches prototype, off from README by 2%.
- `[STYLE]` **Hero size 118 vs README ~180 / ~140.** Flutter default `size = 118` and today.jsx passes `size={118}` (match to prototype). README §02 and §"Activity Rings" call for **~180px** (components.jsx default is 140). Flutter matches the *today.jsx call site* (118) but is well under the README's 180. Consistent with prototype, divergent from README.
- `[MATCH]` Clockwise from 12 o'clock (`-math.pi/2`), round caps, color order [money, move, rituals], 2px gap, and the **appear animation (0→current 800ms ease-out, 60ms staggered per ring)** all match the README animation spec and prototype. Flutter additionally animates value *changes* (handoff-compliant). Good.

---

## 3. Nav bar (`nav_bar.dart` vs `components.jsx` NavBar / README §"Large-title nav bar")

- `[DIFFERENT]` **Trailing icons: only 1 of 2 present.** Design today.jsx trailing = two `NavIconButton`s: **`bell.fill`** (→ inbox) **and `magnifyingglass`** (search). Flutter renders only the `bell.fill` button; the **search/magnifyingglass button is missing**.
- `[STYLE]` **letterSpacing 0.37 vs design 0.4 on large title.** Flutter `LargeTitleNavBar` uses `letterSpacing: 0.37` (matches components.jsx NavBar 0.37 and README). ios-frame.jsx IOSNavBar uses 0.4 — minor inconsistency in the design set; Flutter follows the components.jsx value. OK to leave.
- `[MATCH]` 56px top padding, 16px horizontal, 34/700 title, 41px line height, subtitle 15 ink3 -0.24, leading "Apr"/month-abbrev in accent, NavIconButton 32×32 `fill` circle with 17pt accent symbol — all match.
- `[STYLE]` **Static (non-collapsing) nav.** README §"Large-title nav bar" describes a collapsing 96→44pt large title (title shrinks 34/700→17/600 on scroll). Flutter `LargeTitleNavBar` is explicitly the "static, non-collapsing variant" (its own doc comment) inside a `ListView` — no scroll collapse. Behavior gap vs README.

---

## 4. Tab bar (`loop_tab_bar.dart` vs `components.jsx` TabBar / README §"Tab bar")

- `[COPY]` **Rituals tab label "Routines" vs design "Rituals".** Flutter `LoopTab('rituals', 'Routines', …)`. Both components.jsx TabBar and README §"Tab bar" use label **"Rituals"**. The Move→Workout rename (correctly applied: Flutter shows "Workout") did **not** include rituals→routines; Flutter renamed it anyway. Inconsistent with design.
- `[STYLE]` **FAB size 50 vs README 54.** Flutter `_Fab` is `50×50`. README §"Tab bar" and §02 entry-points say **54×54**. (components.jsx prototype uses 50, so Flutter matches the prototype but is under the README's 54.)
- `[STYLE]` **Blur sigma 30 vs spec 24.** Flutter `ImageFilter.blur(sigmaX: 30, sigmaY: 30)`. README says `blur(24px)`; components.jsx prototype uses `blur(30px)`. Flutter matches prototype, off from README.
- `[STYLE]` **No `saturate(180%)`.** Design blur is `blur(…) saturate(180%)`. Flutter `ImageFilter.blur` has no saturation boost (Flutter has no direct saturate filter) — minor fidelity gap.
- `[MATCH]` Tab order Today / Workout / FAB(+) / Rituals(→Routines) / You; icons house.fill / figure.run / plus / sparkles / person.crop.circle.fill; active=accent, inactive=ink3; labels 10/500; FAB accent circle with accent-tinted shadow; FAB opens Pal composer (`palComposer`) per README "→ opens Pal composer". Good.
- `[STYLE]` FAB shadow: Flutter `blurRadius 14, alpha 0.4`; design `0 4px 14px ${accent}66` (alpha 0.4). Match.

---

## 5. App chrome: status bar, Dynamic Island, home indicator

The design `ios-frame.jsx` is a **simulated device frame** (status bar SVGs, Dynamic Island pill, home indicator, Siri shortcut chip) used to present screens in the prototype canvas. On a real iOS app these are system-drawn, so most are not Flutter widgets to build. Differences worth flagging:

- `[MISSING]` **No status-bar style management.** The app never sets `SystemUiOverlayStyle` / `SystemChrome.setSystemUIOverlayStyle` (grep found zero usages in `lib/`), nor `UIStatusBarStyle`/`UIViewControllerBasedStatusBarAppearance` in `Info.plist`. Design `IOSStatusBar` flips content color by `dark` (black in light theme, white in dark). In the Flutter app, dark mode will keep default-dark status-bar glyphs and may render invisible on the black (`#000`) dark background. Recommend an `AnnotatedRegion<SystemUiOverlayStyle>` or per-theme overlay style. (Status-bar *content* only — clock/battery are system-drawn; the SVG battery/wifi/cell glyphs in ios-frame.jsx are prototype chrome, not app responsibility.)
- `[DIFFERENT]` **Dynamic Island Live Activity built, but design intent differs.** Design `IOSDynamicIsland` documents four Live-Activity kinds — **`workout` | `pal` | `log` | `streak`** — with distinct glyphs/accents (workout=red `#FF453A`, pal=accent, log=green `#30D158`, streak=orange `#FF9F0A`). Flutter ships **only the `workout` Live Activity** (`OpalWorkoutLiveActivity.swift` + `live_activity_service.dart`); there is no `pal`, `log`, or `streak` activity. So 3 of the 4 designed island states are `[MISSING]`.
  - `[STYLE]` The implemented workout island uses **accent blue** (`opalAccent = #007AFF`) and SF symbol `figure.strengthtraining.traditional`. Design's workout kind uses a **red** icon tile (`#FF453A`) and a custom workout glyph, with the value text in red `#FF6B6B`. Tint mismatch (blue vs red) for the workout island.
  - Note: the Flutter island is a *richer, real* ActivityKit implementation (live timer, rest countdown, sets, "Pal listening", deep-link `opal://session/<id>`) that goes beyond the static prototype pill — this is an enhancement, not a defect, but it diverges in styling/kinds from `ios-frame.jsx`.
- `[MISSING]` **Siri Shortcut chip not implemented.** Design `IOSShortcutChip` (README §"Siri Shortcut", Today: "Log expense" / "SIRI SHORTCUT" / kind `log`) renders a Siri-suggestion pill above the home indicator. No equivalent App Intents / Siri shortcut surfaced in the Flutter Today chrome. (Prototype chrome; flag as a designed affordance not built.)
- `[N/A]` Home indicator and the device-frame radius/shadow are simulator chrome (system-drawn on device); no action.

---

## Cross-cutting note: "Rituals" → "Routines" rename

The incremental handoff renamed **Move→Workout only** and explicitly left rituals untouched ("Rituals" label retained in tab bar, ring stat, etc.). The Flutter app has additionally renamed the third tracker's user-facing label to **"Routines"** in: tab bar, Today ring stat, Today summary tile, Pal-insight body, day-progress eyebrow, and close-out copy. This is consistent *within* the Flutter app but **diverges from every design artifact** (today.jsx, components.jsx, README, incremental MD all say "Rituals"). Treat as one systemic decision to confirm with design, not a per-string bug.


---

# Tab Landings — Workout, Rituals, You

Audit of the three tab landing screens against the design handoff. Design source of
truth: `src/tab-landings.jsx` (MoveTabScreen, YouTabScreen), `src/rituals.jsx`
(RitualsTabScreen — note: the prompt pointed at tab-landings.jsx but RitualsTabScreen
actually lives in rituals.jsx), `src/components.jsx`, `src/tokens.jsx`, the README spec,
and `Handoff - Workout Rename & Budget Editor.md`.

Current implementation: `lib/screens/move/move_screen.dart`,
`lib/screens/rituals/rituals_screen.dart`, `lib/screens/profile/profile_screen.dart`,
shared widgets in `lib/widgets/`.

Severity tags: [MISSING] absent in Flutter · [DIFFERENT] present but differs ·
[COPY] text/string mismatch · [LAYOUT] ordering/grouping/spacing · [STYLE]
color/typography/token.

---

## A. Workout / Move tab (`move_screen.dart` vs `MoveTabScreen`)

The Flutter hero and overall structure reflect an **older "health summary" design**
(minutes / kcal / heart-rate), not the redesigned `MoveTabScreen` in
`tab-landings.jsx`. This is the most divergent of the three screens.

### Hero ("This week" card)

- **[DIFFERENT] Hero content is an entirely different model.**
  - Design (`tab-landings.jsx` lines 48-140): "This week" eyebrow, then a large
    workouts-vs-goal headline (`3 / 4 workouts`, SFR 48px), a **56px mini progress
    ring** showing `%` (top-right), a **7-day calendar strip** (M–S squares, filled
    white + checkmark when done, dashed border for "today"), and a 3-cell stat row
    **Volume (`12.4t`) · Time (`148m`) · Records (`2 PR`)**.
  - Current (`move_screen.dart` lines 81-140): "THIS WEEK" eyebrow then a 3-cell
    stat row of **WORKOUT (`{moveMinutes} min`) · ENERGY (`{kcal}`) · AVG HR (`{bpm}`)**.
    No workouts-vs-goal headline, no mini ring, no day-calendar strip.

- **[MISSING] Workouts-vs-goal headline.** Design shows `{workouts} / {goal} workouts`
  (e.g. `3 / 4 workouts`) as the hero focal number. Absent in Flutter.

- **[MISSING] Mini progress ring** (56px, `Math.round(workouts/goal*100)%` centered).
  Absent in Flutter.

- **[MISSING] 7-day calendar strip** (`weekDays` M T W T F S S with done/today states
  and checkmarks). Absent in Flutter.

- **[MISSING] Hero stat "Records" / PR cell.** Design hero stat row includes `2 PR` /
  "Records". Flutter shows AVG HR instead.

- **[STYLE/DIFFERENT] kcal & heart-rate stats violate the handoff.** The
  Workout-rename handoff §2 explicitly drops HealthKit/calorie implications: "No
  HealthKit dependency anywhere." Flutter's hero still has `ENERGY`/`kcal` and `AVG HR`/
  `bpm` cells (lines 114-126), backed by `activeEnergyKcal`/`avgHeartRate` in
  `move_controller.dart` (always null → renders "—"). These should not exist.

- **[STYLE] Hero gradient differs.** Design: `linear-gradient(155deg, move 0%, move·ee
  60%, accent·dd 100%)` with a radial light blob, diagonal hatch overlay, and
  `boxShadow 0 10px 30px move33`. Flutter: simple 2-stop `LinearGradient(topLeft→
  bottomRight, [c.move, c.accent])`, no overlay blob, no hatch, no shadow.

- **[STYLE] Hero corner radius.** Design `borderRadius: 18`; Flutter `22`
  (`move_screen.dart` line 91).

- **[STYLE] Eyebrow text.** Design "This week" (mixed case, the CSS uppercases via
  `textTransform`); Flutter hard-codes `'THIS WEEK'`. Equivalent visually but stored
  pre-uppercased.

### Start workout CTA

- **[MISSING] Eyebrow leading dot.** Design eyebrow is `● Pal's pick for today` (lines
  170) with a literal bullet. Flutter: `"PAL'S PICK FOR TODAY"` — no dot.

- **[MISSING] Routine meta sub-line.** Design shows a third line:
  `5 exercises · 58 min · last done 5d ago` (line 177). Flutter omits this entirely —
  only eyebrow + routine name.

- **[COPY] Routine name fallback.** Design hard-codes `Pull Day A`. Flutter uses live
  `routineName ?? 'Freestyle session'`. (Expected, live-data driven — flagging the
  fallback string only.)

- **[STYLE] Play circle.** Design: 52px circle with `radial-gradient` + inset highlight
  + `boxShadow 0 4px 14px move55` (lines 157-163). Flutter: flat `c.move` circle, no
  gradient/shadow (lines 212-217).

- **[STYLE] Card border/shadow.** Design uses `boxShadow: 0 0 0 0.5px hair` (hairline
  ring). Flutter uses a real `Border.all(color: hair, width: 0.5)`. Minor.

### Weekly balance card

- **[MISSING] Entire "Weekly balance" card is absent in Flutter.** Design
  (lines 188-230): surface card titled "Weekly balance" with a
  `Pal says pull more` sparkles hint, a stacked horizontal bar (Push 38% / Pull 12% /
  Legs 35% / Cardio 15% in move/rituals/money/accent colors), and a 2-column legend
  with percentages. No equivalent anywhere in `move_screen.dart`.

### Quick links section

- **[COPY] "Weekly plan" value missing.** Design row: title "Weekly plan", value
  `4 of 5 · Thu` (line 235). Flutter "Weekly plan" row has **no value** (line 290-293).

- **[COPY] "My routines" → "My workouts" + count semantics.** Design row title is
  **"My routines"** with value = routine count (line 237). Flutter renames it to
  **"My workouts"** (line 278). The handoff rename table does NOT rename "My routines"
  (it is not in the rename list); this appears to be an over-application of the rename.

- **[LAYOUT] Quick-links order differs.** Design order: Weekly plan → My routines →
  Exercise library → History & trends. Flutter order: My workouts → Exercise library →
  Weekly plan → History & trends (lines 274-301). Weekly plan moved from 1st to 3rd.

- **[STYLE] "Weekly plan" icon tile color.** Design `iconBg={theme.move}` (green).
  Flutter uses `c.move` — matches. (OK.)

- **[STYLE] "My routines/workouts" icon color.** Design `iconBg={theme.move}` (green,
  line 237). Flutter `c.move` — matches.

- **[MISSING] "History & trends" tap behavior.** Design row has `onClick={onHistory}`
  and value "All time". Flutter sets `chevron: false` and **no onTap** (lines 294-300),
  so the row is non-interactive (the design row is tappable with a chevron).

### Recent sessions

- **[MISSING] Volume "t" stat + sparkline.** Design session card stat row shows
  duration, then `{volume}t volume`, then a **6-bar mini sparkline** (lines 297-324).
  Flutter shows duration + volume (when >0) but **no sparkline** (lines 442-463).

- **[STYLE] PR badge color.** Design PR badge background is `theme.money` (orange,
  line 287). Flutter `c.money` — matches.

- **[COPY] Session date.** Design uses `s.date` (e.g. a formatted date string).
  Flutter uses computed `relativeDate` ("Today"/"Yesterday"/"Nd ago"). Behavioral, but
  a presentation difference.

- **[DIFFERENT] "See all" target.** Design `onHistory` → a History & trends screen.
  Flutter notes "No history-list screen yet" and instead jumps to the first session's
  detail (lines 333-340). [MISSING] History/trends destination.

### Extra section not in design

- **[DIFFERENT] "Other activity" section** (`move_screen.dart` lines 537-563) has no
  counterpart in `MoveTabScreen`. The design has no "Other activity" list; it ends with
  Recent sessions.

### Nav bar

- **[COPY] Subtitle is the OLD string.** Design (post-rename) subtitle is
  **"Workouts, routines & sessions"** (`tab-landings.jsx` line 28; rename handoff §1).
  Flutter still shows the pre-rename **"Gym, cardio, daily movement"**
  (`move_screen.dart` line 60). This is an un-applied rename.

- **[MISSING] Nav trailing button.** Design has a trailing `ellipsis` NavIconButton
  (line 29). Flutter `LargeTitleNavBar` here has no trailing widget.

- **[COPY] Title "Workout"** — correct in Flutter (line 59). ✓ (rename applied to title
  but not subtitle.)

---

## B. Rituals tab (`rituals_screen.dart` vs `RitualsTabScreen`)

Flutter ships the **timeline** body layout, which matches the README's stated current
selection ("The user's current selection in this prototype is timeline", README line
258). So choosing timeline is correct. Differences below.

### Nav bar

- **[COPY] Nav title "Routines" vs design "Rituals".** Design nav `title="Rituals"`
  (`rituals.jsx` line 62; README line 256 "Large-title nav 'Rituals'"). Flutter sets
  `title: 'Routines'` (`rituals_screen.dart` line 56). The tab is named "Rituals" in
  the design; Flutter renamed the large title to "Routines". (Note the rename handoff
  only renames Move→Workout, NOT Rituals→Routines — so this is an undocumented change.)

- **[COPY] Subtitle** "{done} of {total} steps today" — matches design ✓
  (`rituals.jsx` line 62, Flutter line 57).

- **[STYLE] Trailing `+` button** present in both ✓ (semantic label "New routine").

### Up-next hero

- **[STYLE] Gradient stops differ.** Design: `linear-gradient(150deg, c 0%, c·dd 55%,
  c·b0 100%)` (`rituals.jsx` line 124). Flutter: `[tone, tone·0.87, tone·0.69]` at
  stops `[0.0, 0.55, 1.0]` (lines 134-139). Close but the alpha values differ
  (dd≈0.87 ✓, but b0≈0.69 vs design b0=0.69 ✓ — actually matches closely).

- **[MISSING] Decorative overlays.** Design hero has an absolute white radial blob
  (top-right, 170px) and a `repeating-linear-gradient(125deg…)` hatch overlay
  (lines 128-135). Flutter has neither — flat gradient only.

- **[STYLE] Shadow.** Design `0 14px 34px c·40`; Flutter `BoxShadow(tone·0.25, blur 34,
  offset 0,14)` (lines 142-148). Alpha 0.40 vs 0.25 — Flutter shadow is lighter.

- **[COPY] Eyebrow / name / meta / pips / button** all match the design strings
  ("Up next" / "Pick up where you left off", routine name SFR 28, "{time} · {n} steps
  left · ~{n×5} min", per-step pips, white "Begin/Continue routine" button) ✓.

- **[STYLE] "All routines done" empty state** matches design (52px move-tinted
  checkmark circle, "All routines done", "Every step checked off. Rest easy.") ✓.

### Timeline body

- **[COPY] Routine-card start-button labels.** Design timeline start button uses
  `Run again` / `Continue` / **`Start`** (`rituals.jsx` line 361). Flutter matches:
  `Run again` / `Continue` / `Start` (lines 478-483) ✓.

- **[STYLE] Step row tap target.** Design timeline step rows are tappable
  (`onClick={onToggle}`) ✓; Flutter `_StepRow` toggles via controller ✓.

- **[MISSING] Per-step "note" text.** In the timeline layout the design shows step
  **title only** (no note) — Flutter matches (title only) ✓. (Notes appear only in the
  minimal layout and the player, which are out of scope for the shipped timeline.)

- **[STYLE] "YOUR DAY" section header** matches (SF 12/700, ink3, letter-spacing 0.8) ✓.

- **[STYLE] Spine + node geometry** (left 13 spine, 28px node at left -34, 4px bg ring
  halo) matches design closely ✓.

### Footer

- **[STYLE] "New routine" dashed button.** Design uses a CSS `1px dashed hair` border.
  Flutter reimplements with a `DottedBorderBox` CustomPaint (dash 5 / gap 4). Visual
  match; implementation detail only.

- **[COPY] "New routine"** label ✓.

### Overall

The Rituals tab is the **closest match** of the three. The headline issue is the
**nav title "Routines" vs "Rituals"** copy mismatch; everything else is cosmetic
(missing decorative gradient overlays, slightly lighter shadow).

---

## C. You / Profile tab (`profile_screen.dart` vs `YouTabScreen`)

The Flutter screen is a **different information architecture** from the redesigned
`YouTabScreen`. It uses a stat-grid + two settings sections, whereas the design is a
profile card + six inset-grouped sections (Goals, Reviews, Money, Integrations, Data,
Account). Many design rows and the entire Budget editor are missing.

### Nav bar

- **[COPY] Subtitle missing.** Design nav: `title="You"` + subtitle
  **"Reviews, patterns, settings"** + trailing `gearshape.fill` button
  (`tab-landings.jsx` lines 342-343). Flutter: `LargeTitleNavBar(title: 'You')` only —
  no subtitle, no trailing gear button (line 71).

### Profile / header card

- **[DIFFERENT] Profile presentation.** Design: a **surface card** (radius 18) with a
  56px gradient-avatar showing the initial "M", name **"Mira Okafor"**, and
  **"Tracking since October · 182 days"** (lines 346-366). Flutter: a centered 84px
  `person.crop.circle.fill` icon (no card), name hard-coded **"You"**, and
  **"Member since {year}"** (lines 74-101).
  - [COPY] Name: design "Mira Okafor" vs Flutter "You".
  - [COPY] Sub: design "Tracking since October · 182 days" vs Flutter
    "Member since {memberSinceYear}".
  - [LAYOUT] Design is a left-aligned row card; Flutter is a centered column. (Flutter
    matches the README §15 "Avatar + name + 'Member since …'" instead of the newer
    tab-landings card — there is an internal spec conflict; the newer tab-landings.jsx
    is the stated source of truth.)

### "This year" stat grid (Flutter) — NOT in tab-landings design

- **[DIFFERENT] 2×2 stat grid has no place in `YouTabScreen`.** Flutter renders a
  "THIS YEAR" 2×2 grid: Total spent / **Workout hours** / Routines kept / Longest streak
  (lines 104-161). The redesigned `YouTabScreen` has **no stat grid** — it goes
  straight from the profile card to the Goals section. (The grid derives from README
  §15, an older spec; conflicts with tab-landings.jsx.)
  - [COPY] If the grid is kept: label "Workout hours" correctly applies the rename
    ("Time moved"→"Workout time"/"Workout hours" per handoff §1) ✓.
  - [STYLE] "Longest streak" icon uses `c.money` (orange flame); design has no such
    tile to compare.

### Goals section — MISSING (the headline gap)

- **[MISSING] Entire "Goals" inset section is absent.** Design (`tab-landings.jsx`
  lines 369-377; handoff §3) requires a **Goals** section directly under the profile
  card with three rows:
  1. `dollarsign.circle.fill` (money) · **"Daily budget" / "Weekly budget"** · `$85` ·
     **tappable → opens BudgetSheet**
  2. `flame.fill` (move/green) · **"Workout goal"** · `60 min` · not tappable
  3. `sparkles` (rituals) · **"Daily rituals"** · `5` · not tappable
  None of these exist on the Flutter You screen.

- **[MISSING] BudgetSheet (budget editor) entirely absent.** Handoff §3 specifies a new
  bottom sheet: Cancel/Budget/Save nav row, Daily/Weekly segmented control, ±5/±25
  stepper with `$85` (SFR 54/700, money color), preset chips
  (daily `[50,75,100,150]` / weekly `[350,500,700,1000]`), a Pal footnote card, and
  period-rescale math. No equivalent in `profile_screen.dart` (Flutter instead links to
  a separate `budgetsGoals` push route — see below). The tap-to-edit-budget-from-You
  flow described in the handoff is not implemented on this screen.

- **[COPY] "Workout goal" rename check.** Design row title is **"Workout goal"** (post
  rename, handoff §1: "Movement goal"→"Workout goal"). Flutter has no Goals section so
  the string is simply **absent** (cannot verify rename applied; the goal row is
  missing wholesale).

### Reviews section — MISSING as a group

- **[MISSING] "Reviews" inset section.** Design (lines 379-386): Weekly review
  (`Apr 17–23`) · Monthly review (`April`) · Yearly rewind (`Preview`). Flutter has a
  single **"Weekly review"** row buried in the generic "Settings" section (line 202-208)
  and **no Monthly review or Yearly rewind rows**.
  - [MISSING] Monthly review row.
  - [MISSING] Yearly rewind row.
  - [LAYOUT] Weekly review is not grouped under a "Reviews" header.
  - [COPY] Design weekly value `Apr 17–23`; Flutter row has no value.

### Money section — MISSING

- **[MISSING] "Money" inset section.** Design (lines 388-393): **Bills**
  (`$2,400 · Mon`) and **Subscriptions** (`$170/mo`). Neither row exists on the Flutter
  You screen. (Note git status shows `bills_screen.dart` and `subscriptions_screen.dart`
  were deleted — these destinations appear removed.)

### Integrations section

- **[DIFFERENT] Integrations row.** Design (lines 395-398): "Email sync" with value
  **"Gmail · On"** under an **"Integrations"** header. Flutter has an "Integrations" row
  with subtitle "Email sync" and value **"Off"** placed inside the "Settings" section
  (lines 192-201) — different grouping and value, and title/subtitle inverted (design
  title = "Email sync"; Flutter title = "Integrations", subtitle = "Email sync").

### Data section — partially MISSING

- **[MISSING] "Data" inset section grouping.** Design (lines 400-406): **All stats**,
  **Export data**, **Notifications** (`3 new`). Flutter scatters Export data and
  Notifications into other sections and has **no "All stats" row**.
  - [MISSING] "All stats" row (design `onClick={onStats}`).
  - [COPY] Notifications value `3 new` (design) — Flutter Notifications row has no value
    (line 180-185).

### Account section — MISSING

- **[MISSING] "Account" inset section.** Design (lines 408-411): **Settings** and
  **Help & feedback** (red heart icon). Flutter has neither a "Settings" row nor a
  "Help & feedback" row (Flutter's first section is *titled* "Settings" but contains
  different rows).

### Flutter rows with no design counterpart

- **[DIFFERENT] Extra/renamed rows in Flutter** not in `YouTabScreen`: "Budgets &
  goals" (target push route, replacing the inline Goals/BudgetSheet), "Appearance",
  "Privacy", "About" (`Opal 1.0`). These come from the older README §15 settings list,
  not the redesigned tab-landings.jsx.

### Section ordering

- **[LAYOUT] Whole-screen ordering differs.** Design order: Profile card → **Goals** →
  **Reviews** → **Money** → **Integrations** → **Data** → **Account**. Flutter order:
  Header → This-year grid → "Settings" (Routines, Budgets & goals, Notifications,
  Appearance, Integrations, Weekly review) → second unnamed section (Privacy, Export,
  About). The two architectures do not align.

---

## Cross-cutting

- **[COPY] Move→Workout rename status:** Title "Workout" ✓ applied on the Move tab.
  **Subtitle NOT applied** (still "Gym, cardio, daily movement"). Profile stat label
  "Workout hours" ✓ applied. "Workout goal" row is missing (can't confirm). The
  kcal/heart-rate hero stats contradict handoff §2's "no HealthKit/calorie" directive.

- **[STYLE] Hero corner radii** are consistently larger in Flutter (22) than design
  (Move hero 18; rituals hero 22 matches). Minor but systematic on the Move hero.

- **[MISSING] Decorative gradient overlays** (radial light blobs + diagonal hatch
  patterns) are absent from every gradient hero in Flutter (Move hero, Rituals hero),
  present in all design heroes.
</content>
</invoke>


---

# Workout Flow

Audit of the full gym-workout flow: design (React/JSX `ExpensePal` prototype, source of truth) vs. current Flutter (`opal`). Each bullet is tagged `[MISSING]` (design element absent in Flutter), `[DIFFERENT]` (present but behaves/looks differently), `[COPY]` (text mismatch), `[LAYOUT]` (placement/ordering), or `[STYLE]` (color/type/token).

Design files: `workout-screens.jsx`, `workout-screens2.jsx`, `routine-generator.jsx`, `workout-data.jsx`, `more-screens.jsx`, README spec.
Flutter files: `lib/screens/workout/*.dart`, `lib/screens/library/exercise_library_screen.dart`, `lib/screens/move/weekly_plan_screen.dart`.

> Note on the rename handoff: `Handoff - Workout Rename & Budget Editor.md` renames the tracker "Move" → "Workout" (display copy only; data keys like `theme.move` unchanged). Several copy items below are evaluated against that rename, since the Flutter code is mid-migration (router paths are still `/move`, the start screen nav still says "Start workout"/"Pick a workout or freestyle").

---

## 08 · Start Workout (`start_workout_screen.dart` vs `PreWorkoutScreen` in workout-screens.jsx)

- **[COPY] Nav subtitle differs.** Design: `subtitle="Pick a routine or freestyle"` (workout-screens.jsx L31; README L426 "Pick a routine or freestyle"). Flutter: `subtitle: 'Pick a workout or freestyle'` (start_workout_screen.dart L70). "routine" → "workout".
- **[MISSING] Pal's-pick card is far simpler in Flutter.** Design's card (workout-screens.jsx L36-118) contains: two decorative radial blobs, a hardcoded title "Pull Day A", a `5 exercises · 58 min · last done 5 days ago` meta line, the AI suggestion paragraph, **an exercise-preview chip strip** (`['Deadlift','Pull-up','Barbell Row','Face Pull','Bicep Curl']` as rounded pills, L83-92), then Start + "Other" buttons. Flutter renders eyebrow + title + meta + rationale + Start/"Another" only — **no decorative blobs and no exercise-preview chip strip** (start_workout_screen.dart `_PalPickCard` L185-314).
- **[COPY] Regenerate pill label differs.** Design button reads `Other` (idle) / `Thinking…` (loading) (workout-screens.jsx L113). Flutter reads `Another` / `Thinking…` (start_workout_screen.dart L386).
- **[STYLE] Pal-pick card corner radius.** Design `borderRadius: 18` (L39). Flutter `BorderRadius.circular(20)` (L206).
- **[DIFFERENT] Strength card content omits the exercise mini-stack.** Design `RoutineCard` (workout-screens.jsx L167-259) shows a **colored header band with diagonal stripe texture**, then a body listing the **top-3 exercise names with bullet dots** + "+ N more", a divider, and two stats: `estMin` ("est", with an "m" suffix) and **total sets** ("sets"), plus a `lastDone` label ("3d ago"). Flutter `_RoutineCard` (start_workout_screen.dart L398-485) shows the colored band (no stripe texture), and a footer with only **EXERCISES** and **EST** mini-stats. Missing: exercise name mini-stack, "+N more", the **sets** stat, the **lastDone** label, and the diagonal-stripe decoration.
- **[DIFFERENT] EST value is computed, not the routine's `estMin`.** Design uses each routine's hardcoded `estMin` (55/58/62/45). Flutter derives minutes via `_estMinutes()` heuristic (`totalSets * (restSeconds + 35)`, rounded to 5) (start_workout_screen.dart L620-628), so displayed estimates will not match the design's per-routine numbers.
- **[MISSING] Cardio row is much richer in design.** Design `CardioRow` (workout-screens.jsx L262-325): left colored panel uses the **exercise's SF symbol** (`exMeta.sf`) over a 45° stripe texture; body shows the routine name, then **distance (km) or minutes**, a **pace** value ("pace"), and a `lastDone` label. Flutter `_CardioRow` (start_workout_screen.dart L488-574) hardcodes `figure.run`, shows only `{est} min`, and omits distance, pace, and lastDone.
- **[COPY/LAYOUT] Quick-actions section differs in items, order, copy, and icons.** Design `Section` (workout-screens.jsx L152-161), in order:
  1. `sparkles` / **"Generate with AI"** / "Describe the workout you want"
  2. `plus` / **"New routine"** / "Build from scratch"
  3. `books.vertical.fill` / **"Exercise library"** / "{N} exercises"
  4. `bolt.fill` / **"Freestyle session"** / "Log as you go"

  Flutter (start_workout_screen.dart L123-156), in order:
  1. `plus` / **"New workout"** / "Build from scratch"
  2. `sparkles` / **"Generate with Pal"** / "Describe a goal, Pal builds it"
  3. `dumbbell.fill` / **"Exercise library"** / "Browse all exercises"
  4. `play.fill` / **"Freestyle"** / "Log as you go"

  Differences: order (New first vs Generate first), titles ("New routine"→"New workout", "Generate with AI"→"Generate with Pal", "Freestyle session"→"Freestyle"), all three subtitles, and icons (`books.vertical.fill`→`dumbbell.fill`, `bolt.fill`→`play.fill`).
- **[STYLE] Section-header eyebrow casing.** Design renders "Strength · 4" / "Cardio · 1" as written (CSS `textTransform: 'uppercase'`). Flutter uppercases via `.toUpperCase()` (start_workout_screen.dart L172) — matches visually, no issue.

---

## 09 · Active Session (`active_session_screen.dart` vs `ActiveSessionScreen` in workout-screens.jsx)

- **[DIFFERENT] Rest-timer banner has no animated spinner or progress fill.** Design (workout-screens.jsx L428-470): an **animated spinning ring** (`animation: 'spin 1s linear infinite'`) plus a **left-anchored progress fill** whose width is `((120 - restSeconds)/120)*100%` (rgba white 0.12). Flutter `_RestBanner` (active_session_screen.dart L333-428) uses a **static `clock.fill` glyph inside a non-spinning ring** (comment at L364-365 explicitly drops the spinner) and has **no progress-fill bar**.
- **[COPY] Rest time format.** Design prints `0:${padStart(2)}` → e.g. "0:47" (workout-screens.jsx L451). Flutter prints `$m:$s` where `m = restRemaining ~/ 60` with no left-pad, so 47s → "0:47" (matches), but ≥10 min would read e.g. "10:00" — acceptable; minor.
- **[MISSING] Header session-time is the elapsed clock (good), but design shows a fixed mock `28:14`.** Not a defect — Flutter computes real elapsed (L236-242). Noting design used a static value.
- **[DIFFERENT] Header eyebrow text.** Design: `● ${routine.name.toUpperCase()}` e.g. "● PUSH DAY A" (workout-screens.jsx L381). Flutter: `'● ${name.toUpperCase()}'` (active_session_screen.dart L182) — matches. README L440 prefixes "ACTIVE · " ("ACTIVE · PUSH DAY A") — **neither the JSX nor Flutter includes the "ACTIVE · " prefix**; both follow the JSX, so this is a README-only discrepancy, not a Flutter defect.
- **[MISSING] Current-exercise card omits the trailing ellipsis (…) button.** Design has a 32×32 `fill`-bg circular `ellipsis` button at the top-right of the hero card (workout-screens.jsx L503-509). Flutter's `_CurrentExerciseCard` header has no ellipsis button (active_session_screen.dart L464-514).
- **[COPY] "Now" eyebrow casing.** Design: `● Now · exercise ${exIdx+1}` (mixed case, workout-screens.jsx L492). Flutter: `'● NOW · EXERCISE ${...}'` (all caps, active_session_screen.dart L489). Design is "Now · exercise N"; Flutter is "NOW · EXERCISE N".
- **[DIFFERENT] PR chip wording uses real PR; design appends "Beat it today?".** Both show `Your PR: {w}kg × {reps}` + "Beat it today?" — matches (workout-screens.jsx L513-533 vs active_session_screen.dart L537-573). OK.
- **[DIFFERENT] Active set card lacks the per-set "Target" inline + the value boxes are present.** Design active set (workout-screens.jsx L632-693): "SET N" pill + `Target: {weight}kg × {reps} reps` + "ACTIVE" tag, then Weight/Reps value boxes, then "Complete set". Flutter matches this layout (active_session_screen.dart L633-713). **However the weight/reps boxes are read-only display values in both** — neither is an actual input field (design uses static divs; Flutter uses `Text`), so no functional gap vs design.
- **[MISSING] Up-next card "chevron.right" present; design parity OK.** Matches (workout-screens.jsx L555-581 vs active_session_screen.dart L828-901).
- **[DIFFERENT] Header stat cells use a hardcoded translucent-black overlay.** Design cell bg `rgba(0,0,0,0.12)` (workout-screens.jsx L416). Flutter uses `Color(0x1F000000)` = ~12% black (active_session_screen.dart L289) — matches.
- **[DIFFERENT] Volume number formatting.** Design header Volume = `totalVolume.toLocaleString()` (thousands separator, workout-screens.jsx L413). Flutter passes `_trimDouble(volume)` with **no thousands separator** (active_session_screen.dart L229, L961-962). E.g. design "1,250" vs Flutter "1250".
- **[DIFFERENT] "Complete"/finish path.** Design Finish just calls `onFinish` (no confirm in the prototype). Flutter adds a confirm dialog: title **"Finish workout?"**, body **"This ends the session and shows your summary."**, actions "Keep going" / "Finish" (active_session_screen.dart L108-131). README L807 specifies different copy: body *"You'll save {N} sets and {volume}kg of volume."* and action *"Finish & save"*. **[COPY] Flutter's confirm body and button ("Finish") do not match the README spec ("Finish & save", with the sets/volume summary).**
- **[MISSING] `_CompleteCard` state is Flutter-only.** When all sets are logged Flutter shows an "All sets logged" / "Tap Finish to see your summary." card (active_session_screen.dart L904-932). No design equivalent — additive, low concern.
- **[STYLE] Done-set row omits the trailing per-set volume "{vol} kg".** Design done `SetCard` shows a right-aligned `{volume} kg` value (workout-screens.jsx L623-626). Flutter done row shows weight×reps and an optional PR star but **no trailing volume figure** (active_session_screen.dart L597-631).
- **[DIFFERENT] Done-set PR star.** Flutter adds a `star.fill` before the weight×reps when `set.isPR` (active_session_screen.dart L620-623). Design's active-session done card has **no PR star** (PR surfacing happens via the top PR chip only). Minor additive difference.

---

## 10 · Post-Workout Summary (`post_workout_screen.dart` vs `PostWorkoutScreen` in workout-screens.jsx)

- **[DIFFERENT] Hero is structurally different.** Design hero (workout-screens.jsx L734-802): gradient **`move → accent`**, decorative blobs + diagonal stripes, a "COMPLETE" pill, headline **"Nice session."** (SF 34/700), a sub-line **`★ You hit a new PR on bench · {routineName}`**, and a **4-column** stat grid: Time(min) / Volume(tonnes) / Sets(`{reps} reps`) / PRs(records). Flutter hero (post_workout_screen.dart L82-168): gradient **`move → move@0.88`** (not move→accent), a close `xmark`, a centered checkmark circle, headline **"Workout complete"** (SF 26), the workout name, and a **3-column** stat row: Time / Volume(t) / PRs. **Missing: accent gradient, "Nice session." headline, PR sub-line, the Sets stat column (and its "{reps} reps" unit), decorative blobs/stripes.**
- **[COPY] Headline.** Design **"Nice session."**; Flutter **"Workout complete"** (post_workout_screen.dart L136).
- **[COPY] Eyebrow/pill.** Design "COMPLETE" pill; Flutter has no eyebrow pill (replaced by a checkmark circle).
- **[STYLE] Volume unit label.** Design "tonnes"; Flutter "t" (post_workout_screen.dart L159).
- **[MISSING] Dedicated PR highlight card.** Design renders a full **"PERSONAL RECORD"** card after the hero (workout-screens.jsx L804-834): money-gradient star tile + "Personal record" eyebrow + **"Bench Press · 90kg × 5"** + **"+5kg from previous best · Oct 14"**. **Flutter has no PR highlight card at all.**
- **[DIFFERENT] "Muscles worked" rendering.** Design (workout-screens.jsx L836-872): **per-muscle rows**, each with name, a right-aligned volume (e.g. "1,910 kg"), a **percentage** (e.g. "45%"), and an **individual horizontal progress bar** per muscle. Flutter (post_workout_screen.dart L222-289): a **single proportional stacked bar** + a `Wrap` of **pills** (dot + name + "{kg}kg"). **No per-muscle percentages and no per-muscle bars.**
- **[DIFFERENT] Exercise recap loses the per-set bar chart.** Design (workout-screens.jsx L874-944): each exercise shows name + optional PR star + total volume, then a **mini bar chart of set volumes** (bars scaled to max, PR set in money color with a dot marker, "{weight}×{reps}" under each bar). Flutter (post_workout_screen.dart L336-448): name + a `Wrap` of **set chips** ("{kg} kg × {reps}", PR chips money-tinted). **Missing: the per-set volume bar chart / progression visualization; total-volume figure per exercise is also dropped.**
- **[MISSING] Pal's note card is Flutter-only here.** Flutter adds a `_PalNote` card (post_workout_screen.dart L452-500). Design's PostWorkout screen has **no** Pal note (that lives on Workout Detail, screen 12). Additive.
- **[DIFFERENT] Action bar.** Design (workout-screens.jsx L946-963): **Share** (outline, flex 1, `square.and.arrow.up` + "Share") + **"Save to timeline"** (filled move, flex 2). Flutter (post_workout_screen.dart L504-559): a **52px icon-only Share button** (no "Share" label) + "Save to timeline" (with a saving spinner state). **Share label text is missing; button is icon-only.**
- **[LAYOUT] Section header padding/casing.** Design headers "Muscles worked" / "Exercises · N" are eyebrow-styled (uppercase via CSS). Flutter `_SectionHeader` uppercases (post_workout_screen.dart L585-597) — OK.

---

## 11 · Exercise Library (`exercise_library_screen.dart` vs `ExerciseLibraryScreen` in workout-screens2.jsx)

- **[LAYOUT] Header is a plain row, not a NavBar.** Design uses `NavBar` with title **"Exercises"**, subtitle **"{N} in library"**, a **leading back button labeled "Move"** (with chevron), and a **trailing `+` NavIconButton** (workout-screens2.jsx L166-179). Flutter renders a custom `_Header` row: chevron-only back (no "Move" label) + title **"Exercise Library"** + **no subtitle and no trailing `+`** (exercise_library_screen.dart L137-164).
- **[COPY] Title differs.** Design **"Exercises"** (+ "{N} in library" subtitle); Flutter **"Exercise Library"** (exercise_library_screen.dart L154).
- **[MISSING] "{N} in library" count subtitle absent** in Flutter.
- **[MISSING] Trailing "+" add button absent** in Flutter (design L178).
- **[COPY] Back-button label.** Design back button reads "Move" (workout-screens2.jsx L176). Per the rename handoff this should now read "Workout". Flutter shows **no label at all** (chevron only) — so both the label and (per rename) the word are missing.
- **[DIFFERENT] Grouping key.** Design groups by **`e.group`** (Push/Pull/Legs/Core/Cardio) and section headers are the group names, derived from the active filter (workout-screens2.jsx L160-211). Flutter groups by **`e.muscle`** (Chest/Shoulders/Back/…) (exercise_library_screen.dart L57-63, L113-124). README L475 says "Grouped sections (per muscle group)" which is ambiguous, but the JSX source-of-truth groups by `group`, so **section headers differ** (e.g. "Push" vs "Chest"/"Shoulders").
- **[STYLE] Group-tinted icon backgrounds lost.** Design tints each row's icon tile by group: Cardio = solid `move`; Push = `move22`; Pull = `rituals22`; Legs = `money22`; else `accent22`, with matching icon color (workout-screens2.jsx L218-225). Flutter uses a **uniform `c.move` icon background** for every row (exercise_library_screen.dart L319, via `ListRow iconBg: c.move`).
- **[DIFFERENT] PR display.** Design shows the PR value (`{weight}kg` or `{reps} reps`) **with a small "PR" eyebrow under it** (money color), plus a chevron (workout-screens2.jsx L234-248). Flutter shows the PR value as the `ListRow` trailing `value` (ink2) with **no "PR" eyebrow and no chevron** (exercise_library_screen.dart L300-324).
- **[STYLE] Filter chip active color.** Design active chip = `theme.ink` bg, `theme.bg` text (workout-screens2.jsx L200-201). Flutter active chip = `c.ink` bg, `c.bg` text (exercise_library_screen.dart L269-278) — matches. Inactive: design `theme.surface` + hairline; Flutter `c.fill` (no hairline) — minor token difference.

---

## 12 · Workout Detail (`workout_detail_screen.dart` vs `WorkoutDetailScreen` in workout-screens2.jsx)

- **[DIFFERENT] Summary grid layout.** Design = **4 tiles in a 2×2 grid**, each with a decorative offset circle behind the icon, tinted icon chip, label, big value + unit (workout-screens2.jsx L277-321). Stats: Duration(move,`clock.fill`)/Volume(accent,`chart.bar.fill`)/Sets(rituals,`list.number`)/Personal records(money,`star.fill`). Flutter = 2×2 grid of `_SummaryTile` (workout_detail_screen.dart L88-142): Duration(move)/Volume(accent)/Sets(rituals)/PRs(money). Differences: **no decorative offset circle**; Sets icon is `chart.bar.fill` not **`list.number`** (L121); PRs label "PRs" not **"Personal records"** (L132); PR unit "new best" matches.
- **[STYLE] Summary value type size.** Design big value SF Rounded 26 (workout-screens2.jsx L310). README L484 says "SF Rounded 20/700". Flutter uses size 26 (workout_detail_screen.dart L257) — follows JSX.
- **[DIFFERENT] Volume chart.** Design = 8 hardcoded bars `[30,42,38,45,52,48,58,68]`, last bar highlighted with a **"4.3t" value label above it** and a **"+15% in 4 wks" trend pill** next to the "34.2t total" headline (workout-screens2.jsx L323-376). Flutter = `fl_chart` `BarChart` driven by `state.weeklyVolume`, last bar highlighted, **no per-bar value label and no "+X% in N wks" trend pill** (workout_detail_screen.dart L276-370). **Missing: trend pill, highlighted-bar value label.**
- **[DIFFERENT] Exercise set table header.** Design header row = `SET / KG / REPS / (PR col)` (workout-screens2.jsx L398-406). Flutter matches (`SET/KG/REPS/_`) (workout_detail_screen.dart L427-453). OK.
- **[DIFFERENT] Per-exercise volume label.** Design shows `{sets.length} × {vol}kg` (workout-screens2.jsx L392-395). Flutter shows `{sets.length} × {vol}kg` (workout_detail_screen.dart L405). OK.
- **[COPY] PR badge.** Design "PR" pill (money bg, white) (workout-screens2.jsx L426-431). Flutter `_PrTag` = star + "PR" (money bg, white) (workout_detail_screen.dart L501-529) — Flutter **adds a star icon** the design badge doesn't have. Minor.
- **[DIFFERENT] Pal's note copy is dynamic vs static.** Design hardcodes the note: *"New PR on bench at 90kg × 5 — that's 5kg up from last month. Next push day, try 92.5kg top set."* (workout-screens2.jsx L452-454). Flutter fetches via `workoutNoteProvider` with loading/error fallbacks (workout_detail_screen.dart L532-580). Functionally richer; content will differ.
- **[COPY] Back-button label.** Design back reads "Today" (workout-screens2.jsx L271). Flutter shows chevron-only (no label) via `LargeTitleNavBar` leading (workout_detail_screen.dart L80-84).

---

## Routine Editor (`routine_editor_screen.dart` vs `RoutineEditorScreen` in workout-screens2.jsx)

- **[COPY] Title.** Design **"Edit routine"** (workout-screens2.jsx L14). Flutter **"Edit workout"** / **"New workout"** (routine_editor_screen.dart L84). (Rename handoff would justify "Workout", but design says "routine".)
- **[DIFFERENT] Cancel affordance.** Design leading = chevron + **"Cancel"** text (workout-screens2.jsx L15-25). Flutter leading = chevron-only, no "Cancel" label (routine_editor_screen.dart L86-90).
- **[DIFFERENT] Save button styling.** Design Save = plain accent **text** button (no fill) (workout-screens2.jsx L27-32). Flutter Save = **accent-filled pill** (routine_editor_screen.dart L149-178).
- **[DIFFERENT] Name + Tag use a different control set.** Design: a read-only Name row showing `routine.name` and a **Tag chip row** `[Upper, Lower, Full, Cardio, Custom]` (workout-screens2.jsx L36-62). Flutter: an **editable `TextField` name** + a **`Segmented` tag control** (routine_editor_screen.dart L97-104, L248-276). Functionally improved (editable), structurally different.
- **[MISSING] Per-exercise set chips + drag-handle + "+ set" chip.** Design exercise rows (workout-screens2.jsx L66-111): a `≡` **drag handle glyph**, icon tile, name, `{muscle} · {N} sets` meta, a chevron, then a row of **set chips** (`{weight}×{reps}` or "{reps} reps") plus a dashed **"+ set"** chip. Flutter `_ExerciseTile` (routine_editor_screen.dart L461-553): icon tile, name, a single `{sets}×{reps} · {kg}` target string, an `xmark` delete, and a `slider.horizontal.3` edit glyph. **Missing: visible drag handle, per-set chips, the "+ set" affordance, the `{muscle}` in the subtitle, and the chevron.** (Reorder is implemented via `ReorderableListView` long-press, but there's no visible `≡` handle.)
- **[DIFFERENT] Section footer hint absent.** Design Exercises section has footer **"Drag ≡ to reorder · swipe left to remove · tap a set to edit targets"** (workout-screens2.jsx L67). Flutter has **no footer hint** (routine_editor_screen.dart L431).
- **[MISSING] "Generate routine with AI" gradient button absent.** Design places a prominent **move→accent gradient "Generate routine with AI"** button below the exercise list, plus an outline "Add exercise from library" (workout-screens2.jsx L114-134). Flutter has only the inset **"Add exercise"** ListRow (routine_editor_screen.dart L556-577) — **no in-editor AI-generate CTA**.
- **[COPY] "Add exercise" subtitle.** Design has no subtitle on that action (it's a button "Add exercise from library"). Flutter ListRow subtitle = "Pick from the library" (routine_editor_screen.dart L569). Minor.
- **[DIFFERENT] Session-settings section differs.** Design "Session settings" inset (workout-screens2.jsx L137-141): **"Rest timer default" = "2:00"**, **"Warm-up reminder" = "Off"** (`bell.fill`, #FF9500), **"Auto-progress weights" = "On"** (`arrow.triangle.2.circlepath`, move) — all **value rows**. Flutter splits this: a **"Rest between sets" `Segmented` control** with presets `[60,90,120,180]s` (routine_editor_screen.dart L278-306), and a **"Warmup reminder"/"Auto-progress" toggle section** with `Switch.adaptive` (L308-343). Differences: rest is a segmented picker (60/90/120/180s) not a "2:00" value row; warmup icon `flame.fill` (money) not `bell.fill` (#FF9500); auto-progress titled "Auto-progress" not "Auto-progress weights", icon `chart.bar.fill` not `arrow.triangle.2.circlepath`.
- **[MISSING] "Delete routine" button absent.** Design ends with a red **"Delete routine"** text button (workout-screens2.jsx L143-150). Flutter has **no delete action**.
- **[MISSING] Exercise targets editing UI is a Flutter-only sheet.** Flutter adds `_TargetsSheet` (sets/reps/weight steppers) + `_ExercisePickerSheet` (searchable catalog) (routine_editor_screen.dart L594-883). Design edits targets inline via the set chips. Functionally improved; structurally different.

---

## Routine Generator (`routine_generator_screen.dart` vs `RoutineGeneratorScreen` in routine-generator.jsx)

- **[COPY] Hero eyebrow.** Design **"Pal builds your routine"** (routine-generator.jsx L122). Flutter **"PAL BUILDS YOUR WORKOUT"** (routine_generator_screen.dart L197). "routine" → "workout".
- **[COPY] Hero example sub-line.** Design: *"A 30-min pull day I can do at the gym" or "legs at home with dumbbells."* (two examples, routine-generator.jsx L130). Flutter: *"A 30-min pull day I can do at the gym."* (single example, routine_generator_screen.dart L214). Second example dropped.
- **[COPY] Loading pill text.** Design **"Pal is building your routine…"** (routine-generator.jsx L230). Flutter **"Pal is building your workout…"** (routine_generator_screen.dart L497). "routine"→"workout".
- **[COPY] Save button.** Design **"Save routine"** (routine-generator.jsx L354). Flutter **"Save workout"** (routine_generator_screen.dart L828). "routine"→"workout".
- **[STYLE] Hero radial-tint alpha.** Design top tint `${theme.move}44` (~0.27), bottom `${theme.accent}33` (~0.2) (routine-generator.jsx L106-110). Flutter: move alpha 0.27, accent alpha 0.2 (routine_generator_screen.dart L174-179) — matches.
- **[DIFFERENT] Exercise-row subtitle uses group, not muscle.** Design result rows show `{muscle} · {equipment}` (routine-generator.jsx L313-315). Flutter shows `{group} · {equipment}` (routine_generator_screen.dart L667-675, prefers `exercise.group`). Muscle vs group mismatch.
- **[DIFFERENT] Result actions match well.** "Try again" (flex 1, `arrow.clockwise`) + "Save …" (move, flex 2) — parity (routine-generator.jsx L336-356 vs routine_generator_screen.dart L777-840). Only the save label copy differs (above).
- **[DIFFERENT] Quick-pick goals match (labels, icons, colors).** All six goals + icons + colors are 1:1 (routine-generator.jsx L11-18 vs routine_generator_screen.dart L50-57). OK. Note quick-pick label "Pull day focused on back" matches (design L14).
- **[COPY] Quick-pick header.** Design "Or try one of these" (routine-generator.jsx L185). Flutter "OR TRY ONE OF THESE" (uppercased, routine_generator_screen.dart L382) — visual match.
- **[DIFFERENT] Generated badge + result header.** Design "GENERATED" badge + name + tag pill + "{N} exercises · ~{estMin} min" + rationale, on a `move→accent` gradient (routine-generator.jsx L249-292). Flutter matches structurally (routine_generator_screen.dart L531-632). OK.

---

## 24 · Weekly Plan (`weekly_plan_screen.dart` vs `WeeklyPlanScreen` in more-screens.jsx)

- **[MISSING] Today-spotlight "Swap" CTA absent.** Design spotlight has **two** buttons: "Start workout" (colored, flex 1) **and a "Swap" outline button** (more-screens.jsx L373-389; README L326 lists both "Start workout" + "Swap"). Flutter renders **only** "Start workout" (full width) (weekly_plan_screen.dart L344-374). **"Swap" CTA missing.**
- **[COPY] Back-button label.** Design back reads "Move" (more-screens.jsx area). Flutter reads **"Workout"** (weekly_plan_screen.dart L66) — Flutter already applied the rename here (inconsistent with start_workout / router which still say "Move"/"/move").
- **[DIFFERENT] Title-block subtitle wording.** Design: "{done} of {total} done · {min} min planned" (README L324; more-screens.jsx). Flutter: `'{doneCount} of {totalCount} done · {totalMinutes} min planned'` (weekly_plan_screen.dart L103) — matches.
- **[DIFFERENT] `totalMinutes` counts rest days as 0 (OK), but design sums `est || 0` across all days incl. the planned ones.** Design `totalMin = WEEK_PLAN.reduce((s,d)=>s+(d.est||0),0)` = 55+58+62+30+45 = **250** (more-screens.jsx L255). Flutter `totalMinutes` folds `est ?? 0` identically (weekly_plan_controller.dart L76-77) = **250**. Matches. (README L324 example "290 min" in the docstring comment at controller L88 is stale — actual data sums to 250.)
- **[STYLE] Week-strip "planned" chip ring.** Design planned (not-done, not-rest, not-today) = **dashed ring**; Flutter uses a **solid 1.5px ring** at `color@0.33` (weekly_plan_screen.dart L198-200). README L325 says "planned = dashed ring" — **Flutter ring is solid, not dashed.**
- **[DIFFERENT] Week-strip completion dot.** Design: a completion dot under each chip (filled when done). Flutter renders the dot (weekly_plan_screen.dart L233-244): done = filled, rest/planned handling. Parity OK.
- **[DIFFERENT] Pal coach note copy.** Design "Pal · Weekly coach" gradient note (more-screens.jsx L328). Flutter hardcodes: *"You're on a **2-week 5/7 streak**. Legs day usually slips — want me to shorten it to 45 min?"* (weekly_plan_screen.dart L587-594). Design's exact note text was not in the read range; Flutter's is a plausible match but should be verified against the JSX body. Label "PAL · WEEKLY COACH" matches.
- **[STYLE] Today spotlight uses `c.surface` bg + radial wash; design uses a tone-tinted card.** Flutter spotlight is `c.surface` with a faint radial gradient at top-left `color@0.12` and a `color@0.27` hairline border (weekly_plan_screen.dart L260-279). Design "tone-tinted card" (README L326) — close; the dominant tint may read lighter than design.

---

## Cross-cutting / data-model notes

- **[COPY] "Workout" rename partially applied.** Per `Handoff - Workout Rename & Budget Editor.md`, user-facing "Move"/"routine" copy should read "Workout". Flutter is **inconsistent**: Weekly Plan back button says "Workout" (good), but Start Workout nav subtitle still says "Pick a workout or freestyle" (design wanted "routine"), router/path is still `/move`, and several screens that the design labels "routine" now say "workout" (New workout, Save workout, Edit workout, "Pal builds your workout") — these go **beyond** the rename scope (which targeted "Move"→"Workout", not "routine"→"workout"). Net: the word "routine" has been broadly swapped to "workout" across editor/generator, which the design copy did not ask for.
- **[DIFFERENT] PR detection / `isPR` flag.** Design marks PR sets statically in `PAST_SESSIONS` (`pr: true` on a set, workout-data.jsx L106). Flutter uses a `set.isPR` flag surfaced in active session (done-row star), post-workout (chip), and detail (PR tag). The detection logic lives in controllers (not in scope here) — UI surfaces exist in all three screens, matching design intent.
- **[DIFFERENT] Cardio set data (distance/pace) is under-surfaced.** Design routines carry `{ duration, distance, pace }` for cardio (workout-data.jsx L85, L92) and the Start screen's `CardioRow` displays distance/pace. Flutter's cardio rows show only minutes (see §08). The active-session/detail screens are strength-oriented in both.
- **[STYLE] `move` gradient direction.** Several Flutter headers use a top→bottom `[move, move@0.93/0.88]` gradient (active L162-166, post-workout L97-101), whereas design uses a diagonal `175deg`/`160deg move→accent` gradient with stripe/blob decorations. Flutter consistently drops the decorative stripe/blob layers and the accent endpoint.


---

# Rituals (Tab, Builder, Player, Layout Styles)

Design source of truth: `src/rituals.jsx`, `src/tokens.jsx`, `design_handoff_expensepal/README.md` (lines 248-273, 855, 863, 885).
Flutter under audit: `lib/screens/rituals/rituals_screen.dart`, `rituals_builder_screen.dart`, `routine_player_screen.dart`, `lib/widgets/controls.dart`.

Scope note on the layout switcher (read first): The README is explicit that the three layout styles are a *design exploration*, not three shippable modes — line 258: "**Three body layouts**, switched by the `ritualStyle` tweak (`cards` / `timeline` / `minimal`) — **ship one; the tweak exists so the team can choose.** The user's current selection in this prototype is **timeline**." Line 885: "tab (pick ONE of the 3 layouts)". The Flutter app ships **Timeline** and only Timeline. That is design-sanctioned, NOT a defect. The Cards and Minimal bodies, and the layout switcher itself, are therefore catalogued below as "intentionally omitted" rather than as missing features. Each is still listed so the omission is explicit and verifiable.

---

## 0. Subtabs / Segmented controls / Layout switchers (CRITICAL CHECK)

- **[SUBTAB] No Cards/Timeline/Minimal layout switcher in Flutter — and this is correct.** Design `RitualsTabScreen` dispatches on a `ritualStyle` prop (`rituals.jsx` lines 66-75) but the README (line 258, 885) instructs shipping exactly one. Flutter hard-codes the Timeline layout (`rituals_screen.dart` `_Timeline`, lines 254-310). Verified via repo-wide grep: no `ritualStyle`, `CardsBody`, `TimelineBody`, `MinimalBody`, `layoutStyle`, or `LayoutStyle` symbol exists anywhere in `lib/`. Status: **switcher intentionally absent; Timeline correctly chosen.**
- **[SUBTAB] Time-of-day grouping (Morning / Midday / Evening) IS present**, but as a per-routine tone, not as section grouping. Design models the three routines as discrete items (`RITUAL_ROUTINES` ids `morning`/`midday`/`evening`, `rituals.jsx` lines 6-37); the Flutter Timeline renders one node+card per routine in order (`_Timeline` → `_TimelineNode`). There is no separate "Morning/Midday/Evening" section header in either design or Flutter — the routine name carries it. No discrepancy.
- **[SUBTAB] The only segmented control in the feature is the builder's TONE picker**, and it is present and faithful — `Segmented<RitualTone>` with options Morning/Midday/Evening (`rituals_builder_screen.dart` lines 32-36, 419-423; widget in `controls.dart` lines 112-166). No design segmented control is missing.

---

## 1. Rituals Tab landing (Screen 13)

### Copy

- **[COPY] Nav large-title is "Routines", design is "Rituals".** Design: `<NavBar ... title="Rituals" ...>` (`rituals.jsx` line 62) and README line 256 ("Large-title nav 'Rituals'"). Flutter: `LargeTitleNavBar(title: 'Routines', ...)` (`rituals_screen.dart` line 56). Note the Flutter file's own doc comment (line 15) claims 'Rituals', so the rendered string contradicts both the design and the code's own documentation. The bottom tab label for this destination should also be checked against this (README line 669 lists the tab item as "Rituals").
- **[COPY] Subtitle matches.** Both render `'{done} of {total} steps today'` (design line 62; Flutter line 57).
- **[COPY] Up-next eyebrow matches.** "Up next" / "Pick up where you left off" (design lines 143; Flutter lines 159-161). Flutter uppercases via `.toUpperCase()`; design uses CSS `textTransform: 'uppercase'`. Equivalent.
- **[COPY] Hero meta line matches.** `'{time} · {left} step(s) left · ~{left*5} min'` with correct singular/plural (design lines 148-150; Flutter lines 183-184).
- **[COPY] Hero button label matches.** "Continue routine" / "Begin routine" (design line 169; Flutter line 233).
- **[COPY] "All routines done" empty state matches.** Title "All routines done" + "Every step checked off. Rest easy." (design lines 108-112; Flutter lines 104-111).
- **[COPY] "YOUR DAY" timeline header matches** (design "Your day" via `textTransform: uppercase`, line 284; Flutter literal `'YOUR DAY'`, line 279).
- **[COPY] Footer "New routine" matches** (design lines 84-86; Flutter line 536).

### Up-next hero — layout / style

- **[STYLE] Empty-state tick uses move-green tint in both** — design `${theme.move}1f` (line 103); Flutter `c.moveTint` (line 99). Match. (Note: `moveTint` token is 0.14 alpha vs design hex `1f`=0.12; minor, see Token section.)
- **[STYLE] Gradient direction differs slightly.** Design: `linear-gradient(150deg, c 0%, c+dd 55%, c+b0 100%)` (line 124) — 150° with alpha stops 1.0/0.87(`dd`)/0.69(`b0`). Flutter: `topLeft→bottomRight` LinearGradient with alphas 1.0/0.87/0.69 (lines 131-139). Alpha stops match; angle is approximated (135° vs 150°). Minor.
- **[STYLE] Decorative overlays MISSING.** Design hero has two decorative layers: a 170×170 translucent white circle offset top/right (`rgba(255,255,255,0.10)`, lines 128-131) and a repeating diagonal hairline stripe pattern (`repeating-linear-gradient(125deg, ...)`, lines 132-135). Flutter renders neither — flat gradient only. [STYLE]
- **[STYLE] Hero shadow alpha differs.** Design `0 14px 34px ${c}40` (0x40 = 0.25 alpha) (line 126); Flutter `tone.withValues(alpha: 0.25)`, blur 34, offset (0,14) (lines 143-147). Match.
- **[STYLE] Hero white CTA button shadow matches** — design `0 6px 16px rgba(0,0,0,0.14)` (line 166); Flutter `Color(0x24000000)` (0.14) blur 16 offset (0,6) (lines 218-223). Match.
- **[LAYOUT] Hero is tappable as a whole in Flutter (PressScale → player) in addition to the button** (lines 125-126). Design only wires the inner button's `onClick` (line 162); tapping the card body does nothing. Minor behavioral add, harmless.

### Timeline body — layout / style

- **[STYLE] Vertical spine matches** — design `left:13, top:8, bottom:24, width:2, background hair` (lines 288-291); Flutter `Positioned(left:13, top:8, bottom:24)` width 2 color hair (lines 289-293). Match.
- **[STYLE] Node matches** — 28×28 circle, filled tone when complete else `surface` with 2px tone border, `0 0 0 4px bg` ring (design lines 298-305); Flutter `boxShadow spreadRadius:4 color bg` (lines 333-341). Match.
- **[STYLE] Card header row matches** — name (16/700, ink, -0.3), time (SFR 12/600, tone, -0.1), spacer, `{done}/{total}` (SFR 13/700, ink3) (design lines 315-326; Flutter lines 359-383). Match. Flutter omits the design's `fontVariantNumeric: 'tabular-nums'` on the `{done}/{total}` count (design line 323) — minor [STYLE].
- **[STYLE] Step rows match** — 20×20 circle checkbox (tone-filled+white ✓ when done, else 1.5px ink4 border), title 14.5, `ink3` strike-through when done else `ink2` (design lines 330-349; Flutter `_StepRow` lines 403-461). Match, including 6px vertical padding.
- **[LAYOUT] Step note is NOT shown in Timeline rows in either design or Flutter.** Design Timeline shows only `st.title` (line 348); the note text appears only in the Minimal layout and the player. Flutter matches (shows `routine.steps[index].title` only). No discrepancy.
- **[STYLE] Start button matches** — full-width, `tone @ 0.08` bg (design `${c}14` = 0.078; Flutter `withValues(alpha:0.08)`), radius 10, icon + label, label "Run again"/"Continue"/"Start" with `arrow.triangle.2.circlepath`/`play.fill` icon (design lines 354-362; Flutter `_StartButton` lines 463-511). Match.

### Footer

- **[STYLE] Dashed "New routine" button matches** — dashed hair border, radius 14, plus icon + "New routine" 15/600 ink3 (design lines 77-87; Flutter `_NewRoutineButton` + `DottedBorderBox` lines 515-610). Design dash uses CSS `1px dashed`; Flutter paints dash 5 / gap 4 (lines 593-594) — visual approximation, acceptable.

### Behavior

- **[OK] Step toggle writes/removes a ritual entry** via `toggleStep` (Flutter line 421-423), matching design `onToggleStep` contract (`rituals.jsx` line 49, README line 783 `ritualProgress` single source of truth).
- **[DIFFERENT] Progress model is positional in both, but Flutter's `doneCount` semantics must be confirmed.** Design treats `doneCount` as a *prefix count* (`i < r.doneCount` marks the first N steps done, lines 236, 330-331) — i.e. progress is "first N", not an arbitrary set, even though `INITIAL_RITUAL_PROGRESS` is a set `{morning:[0,1,2]}`. Flutter uses `state.isStepDone(routine.id, i)` per-index (line 389) which allows arbitrary done-sets. This is arguably *more correct* than the design's prefix assumption, but it is a behavioral difference in how a partially-completed-out-of-order routine renders (design would mis-render gaps; Flutter renders the true set). Flag for awareness. [DIFFERENT]

---

## 2. Rituals Builder (Screen 13b / "Manage")

Design reference: the builder lives in `src/ai-screens.jsx` per README lines 218 ("`RitualsBuilderScreen` (ai-screens) — manage/reorder rituals") and 852. That source file was not in the provided read set, so builder-internal copy/layout claims below are grounded in the README summary and the Flutter implementation only; exact design strings for the editor form could not be verified against JSX.

- **[COPY] Nav title is "Manage" with subtitle "Drag to reorder · tap to edit"** (`rituals_builder_screen.dart` lines 58-59). README calls it "Rituals Builder" / "manage/reorder rituals" (lines 218, 256, 262). Title "Manage" is a reasonable rendering of the builder; cannot confirm exact design string without `ai-screens.jsx`. [COPY — unverified against JSX]
- **[OK] Drag-to-reorder routines** via `ReorderableListView.builder` + `reorder()` (lines 115-133). Matches README line 769 "Drag-reorder (rituals, routine ex.) — Standard iOS reorder handles" and 218.
- **[OK] Drag-to-reorder steps inside the editor** via nested `ReorderableListView.builder` with default drag handles (lines 457-476). Matches design intent (steps are "ordered", README line 104, 769).
- **[OK] Tone segmented (Morning/Midday/Evening), icon grid, time picker, blurb field, per-step editor** all present (lines 417-476, 553-647). These map to `RitualRoutine` fields (README lines 96-104: name/time/tone/icon/blurb/streak/steps).
- **[DIFFERENT] Time entry uses a native `showTimePicker` dialog** (lines 342-349) rather than the prototype's free-text "7:00 AM" string. Reasonable platform adaptation; produces the same `"h:mm AM/PM"` string format the rest of the app consumes (line 335-339). Flag only.
- **[STYLE] Icon choices are a fixed 14-glyph set** (`_iconChoices`, lines 14-29). Design step/routine glyphs in `RITUAL_ROUTINES` include `sunrise.fill`, `sun.max.fill`, `moon.stars.fill`, `drop.fill`, `bolt.fill`, `leaf.fill`, `figure.walk`, `book.closed.fill`, `books.vertical.fill`, `character.book.closed.fill`, `tray.fill`, `sparkles` — all present. Flutter adds `cup.and.saucer.fill` and `heart.fill`. Superset; no missing glyph. [STYLE minor]
- **[COPY] Editor strings ("New routine"/"Edit routine", "Cancel"/"Save", labels TONE/ICON/STEPS, "+ Add step", "Add at least one step.", "New step"/"Edit step", "Step title", "Note (optional)") could not be diffed against design** because `ai-screens.jsx` was outside the read scope. No contradiction found against README. [COPY — unverified]

---

## 3. Routine Player (Screen 13b player / `RoutinePlayerScreen`)

### Structure / copy — mostly faithful

- **[COPY] Top-bar routine-name eyebrow matches** — uppercased routine name, 11/700, ink3, letter-spacing 1.2 (design lines 505-508; Flutter lines 128-135). Match.
- **[COPY] Counter "{idx+1}/{total}" matches** — `Math.min(idx+1,total)/total` (design line 513) vs `(idx+1).clamp(1,total)/total` (Flutter line 141). Equivalent.
- **[COPY] Step eyebrow "STEP n OF total" matches** — design `Step {idx+1} of {total}` rendered uppercase via CSS (lines 543-545); Flutter literal `'STEP ${idx + 1} OF $total'` (line 267). Match.
- **[COPY] Step title (SFR 32/700) + note (17, ink2, maxWidth 280) match** (design lines 546-553; Flutter lines 276-299). Flutter omits the design's `text-wrap: pretty` (no Flutter equivalent) — acceptable.
- **[COPY] Completion copy matches** — "{routine} complete", "All {n} steps done.", "{streak+1}-day streak" flame pill (design lines 570-580; Flutter `_CompletionView` lines 343-373). Match.
- **[COPY] Primary button "Mark done" / "Back to routines" match** (design lines 595, 617; Flutter lines 188, 213). Secondary "Back" + "Skip" match (design lines 604-609; Flutter lines 197-207).

### Differences

- **[DIFFERENT] "Mark done" button label does not switch to "Next step" for an already-done step.** Design: button reads `isStepDone ? 'Next step' : 'Mark done'` (line 595) — when you navigate Back onto an already-completed step, the CTA becomes "Next step". Flutter always shows "Mark done" (`_PrimaryButton(label: 'Mark done', ...)`, line 188); it has no `isStepDone` concept in the player view and re-calls `completeStep` on every press. [DIFFERENT / COPY]
- **[DIFFERENT] Segmented progress bar fill logic differs.** Design fills segment `i` when `(i < idx || done.includes(i))` (line 521) — so already-completed steps *ahead of* the cursor stay filled. Flutter fills only `i < idx` (line 161), ignoring the actual done-set. Result: if the player opens at the first incomplete step but later steps were already done, those segments render empty in Flutter where design would fill them. [DIFFERENT]
- **[DIFFERENT] Player is a full route, not an in-place overlay.** Design `RoutinePlayerScreen` is an absolutely-positioned overlay at `zIndex 60` over the tab (README line 264, `rituals.jsx` lines 491-495); close (`onClose`) and finish (`onFinish`) are parent callbacks that dismiss the overlay. Flutter implements it as a routed `Scaffold` at `/rituals/player/{id}`; both close (×) and "Back to routines" call `context.go('/rituals')` (lines 114-116, 215). Functionally equivalent navigation; structurally different (full nav vs overlay). [DIFFERENT — architectural, acceptable]
- **[STYLE] Background radial gradient stop/alpha differs slightly.** Design: `radial-gradient(120% 80% at 50% -10%, ${c}26 0%, bg 52%)` — center above-top, tone alpha `26`=0.149, stop 52% (line 493). Flutter: `RadialGradient(center: Alignment(0,-1.2), radius 1.0, colors [tone@0.15, bg], stops [0.0, 0.52])` (lines 99-104). Close match (0.15 vs 0.149, stop 0.52).
- **[STYLE] Step glyph circle matches** — 96px, `tone@0.12` bg (design `${c}1f`=0.122), `tone@0.2` border (design `${c}33`=0.2), shadow `tone@0.2` blur 30 (design `${c}33`) (design lines 534-540; Flutter lines 246-263). Match.
- **[STYLE] Completion check circle matches** — 110px gradient `tone → tone@0.8` (design `${c}cc`=0.8), shadow `tone@0.33` blur 36 (design `${c}55`=0.333) (design lines 561-565; Flutter lines 321-340). Match.
- **[STYLE] Primary button height/shadow** — Flutter fixes height 54, shadow `tone@0.3` blur 22 offset (0,8) (lines 399-410); design uses padding 17 (~54px) and shadow `${c}4d`=0.302 blur 22 (lines 589-593). Match.
- **[DIFFERENT] "Skip" can advance straight to the completion state.** Flutter `onSkip` clamps idx to `routine.steps.length` (line 59-60), so skipping the last step shows the completion view even though no step was marked done. Design `advance()` does the same (`Math.min(i+1, total)`, line 484) and `completedNow` is `idx >= total` (line 488). Matches design — both let Skip reach completion. No discrepancy (noted for completeness).
- **[STYLE] No step-transition slide-up animation.** Design animates each step with the `ritualStep` keyframe (slide-up + fade 320ms `cubic-bezier(0.22,1,0.36,1)`, lines 532, 558; README lines 268, 759). Flutter swaps the `_StepView` via `ValueKey(idx)` (line 173) with no explicit transition — steps cut rather than slide. [STYLE — animation missing]
- **[STYLE] Check-toggle micro-animation (scale 0.9 60ms + 180ms fill, README lines 683, 760) is implemented in the shared `CheckButton` widget** (`controls.dart` lines 87-104) but the Rituals Timeline `_StepRow` does NOT use `CheckButton` — it draws a plain `Container` checkbox with no scale/fill animation (`rituals_screen.dart` lines 428-441). So ritual step checks animate per spec on other screens but not on the Rituals tab. [STYLE]

---

## 4. Layout styles NOT shipped (intentional per README, catalogued for completeness)

- **[MISSING — intentional] Cards layout (`CardsBody`, `rituals.jsx` lines 178-275).** Per-routine surface card with icon tile + name + "{time} · {blurb}" + streak/Done pill header, full-width progress bar, inline checkable step rows (24px round checkboxes), and footer "Start/Continue/Run again" CTA. Not in Flutter. README line 258/885 sanctions shipping only Timeline.
- **[MISSING — intentional] Minimal layout (`MinimalBody` + `MinimalHero`, `rituals.jsx` lines 373-464).** A 54px SVG circular-progress hero showing `{doneSteps}/{totalSteps}` + "{routine} is up next" + pill "Begin" button, followed by inset `Section`s per routine whose step rows show **title AND note**, with a circular-play start row. Not in Flutter.
- **[MISSING — intentional] Layout switcher / `ritualStyle` dispatch (`rituals.jsx` lines 66-75).** Not in Flutter. This is the README's "Tweaks panel … Rituals layout switch" (lines 20, 863), a prototype-only authoring control, not an end-user feature.

These three are the only "missing" items, and all three are explicitly designated drop-one-keep-one explorations by the handoff. No genuinely-required Rituals surface is absent from the Flutter build.

---

## 5. Color / typography / token notes

- **[STYLE] Tone→color mapping is correct.** Design `toneColor`: morning→money(orange), midday→move(green), evening→rituals(purple) (`rituals.jsx` lines 42-44; README line 253). Flutter resolves via `c.forType(routine.colorKey)` (e.g. `rituals_screen.dart` line 118). Mapping verified consistent with tokens (`tokens.jsx` lines 16-21: money `#FF9500`, move `#34C759`, rituals `#AF52DE`).
- **[STYLE] Tint-alpha drift (systemic, minor).** Several design tints use hex `1f` (≈0.122) e.g. icon tiles, while Flutter sometimes uses the `*Tint` tokens defined at 0.14 (`tokens.jsx` lines 17/19/21) and sometimes `withValues(alpha: 0.08/0.12)`. Hero empty-tick: design `${move}1f` (0.122) vs Flutter `moveTint` (0.14). Sub-perceptual; noted for completeness.
- **[STYLE] SF Rounded vs SF Text usage matches** at the audited call sites — `AppFonts.sfr` is used where design uses `SFR` (hero name, step title 32, completion title, counter) and `AppFonts.sf` where design uses `SF`. No font-family mismatch found in the Rituals files.

---

## Severity tally

- [MISSING]: 3 (all three intentional per README — Cards body, Minimal body+hero, layout switcher)
- [DIFFERENT]: 6 (done-set vs prefix progress on tab; player segment-fill logic; "Mark done" not switching to "Next step"; player as route vs overlay; builder native time-picker; positional toggle semantics)
- [COPY]: 1 confirmed defect ("Routines" vs "Rituals" nav title) + several builder-editor strings unverifiable (ai-screens.jsx out of scope)
- [LAYOUT]: 1 (whole-hero tappable add; benign)
- [STYLE]: ~10 (missing hero decorative circle + stripe overlay; no `ritualStep` slide-up animation; Timeline step check not animated/not using CheckButton; tabular-nums omissions; minor gradient-angle/tint-alpha drift)
- [SUBTAB]: layout switcher correctly absent (Timeline shipped per spec); tone segmented present and faithful; no missing subtab.


---

# Pal & AI Surfaces

Audit of the Pal AI companion + reflective AI surfaces against the ExpensePal design handoff.
Design is the source of truth. Files read:

- Design: `pal-composer.jsx`, `ai-screens.jsx`, `new-screens.jsx` (Weekly Review / Streak / Evening Close-Out), `more-screens.jsx` (Pal Inbox), `README.md` (spec lines 277-338, 491-497, 795-809).
- Flutter: `pal_composer_screen.dart`, `ask_pal_screen.dart`, `pal_inbox_screen.dart`, `evening_close_out_screen.dart`, `streak_celebration_screen.dart`, `weekly_review_screen.dart`, `monthly_review_screen.dart`.

Severity tags: [MISSING] absent in Flutter · [DIFFERENT] behavior/structure differs · [COPY] text differs · [LAYOUT] ordering/spacing · [STYLE] color/typography/token · [SUBTAB] segmented-control / filter-chip / tab status.

---

## Subtab / Chip / Segmented-Control Inventory (focus area)

| Surface | Control | Design | Flutter | Status |
|---|---|---|---|---|
| Pal Composer | Starter "Try saying" chips (3) | present | present | OK (1 copy nuance, below) |
| Pal Composer | Compose mode toggle | none in design | none | N/A — single input surface by design |
| Ask Pal | Empty-state suggestion chips (3) | present | present | OK (1 copy diff) |
| Pal Inbox | Filter chips: All / Unread / Money / Workout / Rituals | 5 pills | 5 pills | OK — present & wired |
| Weekly Review | Period segmented control | none in design | none | N/A — fixed week |
| Monthly Review | Period segmented control | none in design | none | N/A — fixed month |
| Evening Close-Out | n/a (checklist, no chips) | — | — | N/A |
| Streak | 3 stat pills | present | present | OK |

Net: **no subtab/chip/segmented-control is missing.** All five inbox filter pills exist and are wired (`InboxFilter.all/unread/money/move/rituals`). Differences within these controls are copy/wiring nuances noted per-screen below.

---

## Pal Composer (`PalComposerSheet`)

- [DIFFERENT] **Send button icon mismatch.** Design uses `arrow.up` in the composer send button (`pal-composer.jsx` L268). Flutter also uses `arrow.up` (L664) — OK. (Note: the *standalone* Ask Pal screen differs; see that section.)
- [STYLE] **Send button color tracks `hasText` vs `input.trim()`.** Design colors the send button accent when `input.trim()` is truthy and disables only on empty/loading (L261-266). Flutter colors it accent on `hasText` but `onTap` is gated on `canSend = enabled && hasText` (L605/654). Equivalent behavior; minor: design keeps button accent even while loading if text present, Flutter keeps accent but disables tap — acceptable.
- [DIFFERENT] **Keyboard-lift mechanism.** Design measures `visualViewport` and translates the sheet up by a computed device-space lift (L44-71). Flutter uses `margin: EdgeInsets.only(bottom: keyboard)` from `viewInsets` (L103). Functionally equivalent on-device; not a visual defect.
- [STYLE] **Status dot color.** Design status-line dot is `theme.move` (green, L152). Flutter uses `c.move` (L189). OK.
- [COPY] **"Try saying" starter chip 3 label.** Design: `"How's my week so far?"` with a curly apostrophe `’` (L101). Flutter: `"How's my week so far?"` (L255) — verify the apostrophe glyph; Flutter source uses a straight `'`. Minor typographic difference.
- [STYLE] **"TRY SAYING" eyebrow.** Design renders label `Try saying` via CSS `textTransform: uppercase` (L213, content is lowercase "Try saying"). Flutter hard-codes the string `'TRY SAYING'` (L328). Same rendered result.
- [LAYOUT] **Starter-chip trailing icon.** Both use `arrow.up.right` (design L226 / Flutter L395). OK.
- OK: grabber (36×5, hair), gradient avatar (32, accent→rituals, sparkles), "Pal" title 15/600, status "Log, ask, or start anything", close `xmark` 30×30 fill circle, "Start a workout" moveTint card with `play.fill` + chevron, expanded 86% / max 92% sheet heights, bubbles (user accent/white radius 18 tail 5, assistant fill + 24px gradient avatar), typing dots — all match.
- OK: placeholders `'Log a coffee, ask about your week…'` (compact) / `'Reply or log something…'` (expanded) match design L248 verbatim.

## Ask Pal Screen (`AskPalScreen`)

> NOTE: The design intent (`pal-composer.jsx` header comment L2) is that the composer **replaces the standalone Ask Pal screen**. The Flutter app still ships and **routes** `AskPalScreen` at `/pal` (`router.dart` L80/315-319). So this screen is a design-superseded surface that nonetheless exists. Differences below are vs the original `AskPalScreen` in `ai-screens.jsx`.

- [COPY] **Subtitle differs.** Design: `"Your tracking companion"` (`ai-screens.jsx` L58). Flutter: `"Your money, workout & routines coach"` (L155).
- [COPY] **Empty-state greeting differs.** Design seeds the chat with a first assistant bubble: `"Hi Mira. I'm Pal — ask me anything about your money, workouts, or rituals. Or just tell me what you did and I'll log it."` (L6). Flutter shows a centered empty state with heading `"Hi there"` + body `"I'm Pal — ask me anything about your money, workouts, or routines. Or just tell me what you did and I'll log it."` (L334-349). Design says "rituals"; Flutter says "routines". Also Flutter drops the name ("Hi Mira" → "Hi there").
- [COPY] **Suggestion chip 3 differs.** Design: `"Suggest an evening ritual"` (L52). Flutter: `"Suggest an evening routine"` (L35). ("ritual" → "routine".)
- [DIFFERENT] **Empty-state layout.** Design renders suggestion chips inline under the seeded bubble with a `"Try asking"` uppercase label (L70-91). Flutter renders a centered card with a 56×56 accent-tint sparkles tile, `"Hi there"` headline, body, then chips — **no "Try asking" label** (L322-355). [MISSING] the "Try asking" label.
- [STYLE] **Send button icon.** Design send button uses `arrow.right` (L127). Flutter uses `arrow.up.right` (L498). [DIFFERENT].
- [STYLE] **Composer placeholder.** Design: `"Ask about your day or log something…"` (L108). Flutter: `"Message Pal"` (L475). [COPY].
- [STYLE] **Assistant bubble border.** Design assistant bubble = `theme.surface` background, no border (L155). Flutter adds `Border.all(c.hair, 0.5)` to assistant bubbles (L204). [STYLE].
- [STYLE] **Bubble font size.** Design bubbles 15px / letterSpacing -0.24 (L157). Flutter 16px / -0.31 (L208-212). [STYLE].
- [DIFFERENT] **Nav style.** Design uses the shared `NavBar` with a trailing `ellipsis` icon button (L58-60). Flutter uses a custom large-title header (back chevron + "Ask Pal" 34/700 + subtitle) and **no trailing ellipsis** (L114-166). [MISSING] trailing ellipsis.

## Pal Inbox (`PalInboxScreen`)

- [SUBTAB] **Filter chips — all present & wired.** Design pills `All (n) / Unread (n) / Money• / Workout• / Rituals•` (`more-screens.jsx` L645-650). Flutter has the same five (`pal_inbox_screen.dart` L175-208): All+count, Unread+count, Money(dot), Workout(dot), Rituals(dot), all wired to `controller.setFilter`. Match. Note design's `move` filter label is "Workout"; Flutter label is also "Workout" → "Routines" for rituals (Flutter uses `'Routines'` L206 vs design `'Rituals'` L650). [COPY] "Rituals" → "Routines" on the rituals chip.
- [STYLE] **Filter chip vertical padding.** Design `padding: '7px 12px'` (L655). Flutter chip has only horizontal padding 12 inside a fixed `SizedBox(height: 36)` row (L170/283). Visually similar; vertical metric not pinned.
- [COPY] **Title + sub.** Design `"Pal noticed"` 28/700 + `"{n} new · a quiet inbox, not an anxious one"` / `"All caught up · a quiet inbox, not an anxious one"` (L630-637). Flutter matches verbatim (L132-162). OK.
- [STYLE] **Avatar shadow.** Design sparkle avatar shadow `0 4px 14px {accent}55` (≈33% alpha, L622). Flutter shadow alpha 0.33 / blur 14 / offset (0,4) (L121-123). OK.
- [DIFFERENT] **Note kinds.** Design `KIND_META` has 6 kinds: Nudge(accent) / Spotted(rituals) / Pattern(rituals) / Win(move) / Reminder(money) / Recap(accent) (L575-582). Flutter `NoteKind` enum matches all 6 verbatim (`enums.dart` L76-82). OK.
- [DIFFERENT] **Note data source.** Design ships 8 fixed `INBOX_ITEMS` (L516-573). Flutter sources notes from the repository/DB seed (controller streams `PalInboxState`), so exact note copy is data-driven, not hard-coded. Structure (icon tile + meta row "{KIND} · {when}" + title + body + optional action pill + unread accent dot) matches design L685-744.
- [STYLE] **Unread indicator position.** Design places the accent dot absolutely at `left:6, top:50%` (vertically centered, L692-696). Flutter places it inline at the row start with `top:16` padding (top-aligned near the icon, L347-356). [LAYOUT] dot is vertically centered in design, near-top in Flutter.
- [DIFFERENT] **Action pill behavior.** Design action pill calls `onOpenPal(it.title)` → seeds Pal composer with the note title (L736). Flutter marks the note read then `context.go('/pal-composer?seed=…title…')` (L414-419). Matches intent; Flutter additionally marks-read.
- [COPY] **Empty + footer.** Empty: `"Nothing here. A quiet Pal is a happy Pal."` (design L754 / Flutter L218) match. Footer: `"Tune what Pal notices"` with `gearshape.fill` (design L765 / Flutter L243) match.

## Evening Close-Out (`EveningCloseOutScreen`)

- [STYLE] **Gradient stops.** Design `linear-gradient(180deg, #1a1340 0%, #2d1f5c 45%, #3d2a73 100%)` (L484). Flutter uses the same 3 colors with stops `[0.0, 0.45, 1.0]` (L83-84). OK.
- [COPY] **Hero copy.** `"Close out\nyour day."` 32/700 + `"{done} of {total} rituals done. One more to close the ring."` (design L508-515). Flutter matches (L133-148). OK.
- [DIFFERENT] **Checklist data source & subtitle format.** Design has 5 fixed items (`pages/inbox/spanish/read/reflect`) with subtitles `"06:42 · 15 min"`, `"21:30 · 28 min"`, `"5 min · tonight"` etc. (L470-476). Flutter flattens **every routine step** from `ritualsControllerProvider` into rows, subtitle = `"{routine} · {step note or time}"` (L268-271). [DIFFERENT] — design lists 5 discrete day rituals; Flutter lists routine *steps*. Different content model.
- [DIFFERENT] **"Active" / "Now" pill selection.** Design hard-codes the last item (`reflect`, `moon.stars.fill`) as `active:true` and shows the "Now" pill only when it is the active unchecked one (L475, L536). Flutter computes the active row as the **first incomplete step** across all routines (L60-75). Different selection rule; both render a purple-tinted highlight + "Now" pill.
- [MISSING] **"Reflect on the day" ritual.** Design's 5th item is a `moon.stars.fill` "Reflect on the day" / "5 min · tonight" row that is the seeded incomplete step (L475). Flutter has no equivalent synthetic reflect step — rows are purely routine steps, so this specific item is absent.
- [COPY] **Nav clock.** Design centerpiece is the literal `"21:30 · Thursday"` (L500). Flutter renders a **live** `HH:mm · {weekday}` from `DateTime.now()` (L50-52). [DIFFERENT] — dynamic vs fixed (acceptable, but won't read "21:30 · Thursday" in the demo).
- [COPY] **Pal nudge + CTA.** `"Ask Pal for a reflection prompt"` dashed button (seeds `"Give me a reflection prompt for tonight"`) and CTA `"Good night"` / `"{n} to go"` all match (design L591-620 / Flutter L205/199/234). OK.
- [STYLE] **Progress bar & checkbox accent.** `#BF5AF2` purple accent, 6px bar, 24px circular checkbox filled purple + checkmark — match (design L526/547-553 / Flutter L167/304-321). OK.

## Streak Celebration (`StreakCelebrationScreen`)

- [STYLE] **Radial glow + rays.** Design `radial-gradient(ellipse at 50% 38%, {move}33 0%, {bg} 60%)` (L327) and 12 rays at 0.35 opacity, strokeWidth 2, origin (195,250), length 280 (L332-343). Flutter: RadialGradient center `(0.0,-0.24)` radius 0.9, `move@0.20` → bg, stops [0,0.6] (L44-49); 12 rays alpha 0.35 strokeWidth 2 length 280 origin (w/2,250) (L356-378). [STYLE] glow alpha differs: design `0x33`≈20% — Flutter uses 0.20 → match; gradient *shape/position* differs slightly (ellipse@38% vs radius-0.9 @ -0.24) — minor.
- [COPY] **Eyebrow / number / copy.** `"STREAK UNLOCKED"` (design renders `"Streak unlocked"` uppercased, L361) → Flutter `'STREAK UNLOCKED'` (L88). Giant streak number 140/800 move green + glow → match (design L364-369 / Flutter L96-112). `"days moving"` 28/700 → match.
- [DIFFERENT] **Streak value source.** Design hard-codes `11` everywhere (number, copy, card, 11 filled dots) (L369/379/419/431). Flutter reads `profileStatsProvider.longestStreak` (fallback 11) and derives filled dots = `streak.clamp(0,16)` (L37-40). Dynamic vs fixed — acceptable.
- [COPY] **2-line copy "since {date}".** Design: `"You haven't missed a day since Apr 12.\nYour longest streak this year."` (L379). Flutter: `"You haven't missed a day in $streak days.\nYour longest streak this year."` (L123). [COPY] — design phrases it as "since Apr 12" (a date); Flutter says "in 11 days" (a count). README spec L803 pins `"You haven't missed a day since {date}."` → Flutter deviates from the pinned "since {date}" form.
- [COPY] **Share card handle.** Design share card reads `"@mira · ExpensePal"` (L423). Flutter reads `"Opal"` only (L309) — no "@mira", and brand renamed ExpensePal→Opal. [COPY]/[DIFFERENT].
- [STYLE] **Share card label.** Design `"Workout streak"` uppercased (L415). Flutter `'MOVE STREAK'` (L294). [COPY] "Workout streak" → "Move streak".
- [STYLE] **Stat pills.** 3 pills Total/Best day/Next milestone with values `486 min` / `Sat · 75m` / `14 days` — match (design L385-388 / Flutter L28-32). OK.
- [STYLE] **Share card rotation, dot grid.** −1.5° rotation, 16-dot 4×4 grid (filled = streak) — match (design L408/426-433 / Flutter L150/324-352). OK.
- [STYLE] **CTAs.** Green `"Share"` w/ `square.and.arrow.up` + outline `"Keep going"` — match (design L444-458 / Flutter L175-209). OK.

## Weekly Review (`WeeklyReviewScreen`)

- [COPY] **Lede sentence differs.** Design lede: `"Movement stayed consistent, rituals held together, and you came in under budget. Let's look closer."` (`new-screens.jsx` L46). Flutter: `"Workouts stayed consistent, routines held together, and you came in under budget. Let's look closer."` (L108-109). [COPY] — "Movement"→"Workouts", "rituals"→"routines".
- [COPY] **Win row 1 title.** Design: `"11-day workout streak"` (L7). Flutter: `"11-day move streak"` (L26). [COPY].
- [COPY] **Pattern card 2.** Design: `"You worked out 73 min on ritual days vs 42 min on skipped-ritual days."` (L14). Flutter: `"…on routine days vs 42 min on skipped-routine days."` (L42-43). [COPY] "ritual"→"routine".
- [STYLE] **Patterns lost bold spans.** Design pattern text has inline `<b>` emphasis ("2.8× an average day", "73 min on ritual days", "28 min") (L13-15). Flutter renders flat text — bold spans dropped (documented at L33-34). [STYLE] — intentional per code comment but a visual deviation from design.
- [STYLE] **"One thing to try" card gradient/border.** Design `{accent}12 → {rituals}12` gradient, border `{accent}33` (L144-145). Flutter uses `accent@0.07 → rituals@0.07` and border `accent@0.20` (L367-376). [STYLE] — gradient tint ~7% vs design ~7%(0x12≈7%) OK; border 0.20 vs 0x33≈20% OK. Effectively matches.
- [COPY] **"One thing" body bold + seed.** Design body bolds "Thursday evening" (L167); Flutter flat (L408-410). Seed string `"Tell me more about my Friday spending"` matches (design L169 / Flutter L358). OK.
- OK: eyebrow `"WEEKLY REVIEW · APR 17–23"` (design "Weekly Review · Apr 17–23" uppercased), headline `"Your steadiest week this month."`, three-ring stat tiles (Spent $435/of $595, Workout 296/of 420 min, Rituals 26/of 35) with `{color}14`≈8% tint, Wins inset list (icon+title+sub+check), accent-bar pattern cards (3px bar), footer `"Next review · Sunday, Apr 30"`, share nav icon — all match.

## Monthly Review (`MonthlyReviewScreen`)

- [DIFFERENT] **Narrative & patterns are data-driven.** Design hard-codes the April narrative and 3 patterns ("Morning rituals lower food spending" / "Friday is your spendiest day" / "Movement and sleep are linked", `ai-screens.jsx` L506-510). Flutter pulls narrative from `monthlyReviewControllerProvider` and uses **different** canned patterns: "Mornings set the tone", "Workouts are your anchor", "Weekends drift" (L32-45). [COPY]/[DIFFERENT] — pattern titles and bodies entirely differ from the design prototype's three.
- [DIFFERENT] **Patterns layout.** Design "Patterns Pal found" rows are bare rows with a leading `sparkles` icon on a section card without per-row icon tiles (L506-522, flat sparkles icon, no gradient circle). Flutter wraps each in an inset card row with a **30px gradient sparkle circle** tile (L348-361). [STYLE] — design uses a small flat accent sparkle; Flutter uses a gradient avatar circle.
- [STYLE] **Narrative card background tint.** Design narrative gradient `{accent}18 → {rituals}18` (≈9.4% alpha, L443). Flutter uses `c.accentTint → c.ritualsTint` which are **14%** (light) / **18%** (dark) alpha tokens (`app_colors.dart` L103-107/129-133). [STYLE] — Flutter tint is noticeably stronger (14-18% vs design ~9%).
- [DIFFERENT] **Regenerate label states.** Design Regenerate pill swaps to `"Writing…"` while loading (L469). Flutter shows static `"Regenerate"` (loading state instead replaces the narrative text with `"Pal is reading your month…"`, L242/199). [COPY] — missing the `"Writing…"` pill label.
- [DIFFERENT] **Title source.** Design title hard-codes `"April"` (L436). Flutter renders the current month name from `DateTime.now()` (L51). Dynamic vs fixed — acceptable.
- [DIFFERENT] **Stat rows data-driven.** Design 4 fixed rows (Total spent $1,840 ↓12% / Workout time 38 hrs / Rituals kept 112/150 / Streak 11 days) with sub-captions and 36px icon tiles (L477-501). Flutter computes rows from `monthlyStatsProvider` with 32px icon tiles, big value + unit, and **no sub-caption line** (L256-309). [LAYOUT]/[MISSING] — design stat rows include a secondary sub-line ("↓ 12% vs March", "23 active days", "best month yet", "Workouts, ongoing"); Flutter rows have value+unit only, **sub-caption omitted**.
- [STYLE] **Stat row value typography.** Design value SF Rounded 22/700 right-aligned (L498). Flutter value 24/700 + separate unit label (L291-302). [STYLE] size 22 vs 24, plus unit split.
- [COPY] **"Written by Pal" + nav.** Label `"WRITTEN BY PAL"` (design "Written by Pal" uppercased L454 / Flutter L188) and `"Monthly review"` subtitle + `ellipsis`/back nav — design uses trailing `ellipsis` (L437); Flutter `LargeTitleNavBar` has back leading and **no trailing ellipsis**. [MISSING] trailing ellipsis on monthly review nav.

---

## Summary of cross-cutting issues

- **"ritual(s)" → "routine(s)" rename** appears repeatedly (Ask Pal greeting/suggestion, Weekly Review lede/win/pattern, Pal Inbox "Rituals" chip). This is a deliberate vocabulary shift but diverges from the handoff's pinned copy.
- **"ExpensePal" → "Opal" / dropped "@mira"** on the streak share card.
- **Monthly Review patterns** are completely different content from the prototype, and stat-row sub-captions are dropped.
- **Trailing `ellipsis` nav buttons** dropped on Ask Pal and Monthly Review.


---

# Email Sync

Feature: auto-import receipts + subscriptions from Gmail/Outlook over IMAP. Three states in the design: Intro/Empty (`EmailSyncEmptyScreen`), App-password Setup (`EmailSyncConnectScreen`), Synced Dashboard (`EmailSyncedScreen`), plus the `GmailGlyph` SVG mark.

Source of truth: `C:\Users\cktra\Downloads\expensepal (4)\src\email-sync.jsx` (JSX prototype). Where the reference spec `design_handoff_expensepal\README.md` (screens 20/21/22) adds elements the JSX never built, those are flagged as spec-vs-prototype divergences but still audited because the task names them explicitly (provider toggles, subscriptions tab, filters).

Flutter files: `lib\screens\email\email_intro_screen.dart`, `email_setup_screen.dart`, `email_dashboard_screen.dart`, `email_nav.dart`.

---

## Cross-cutting

- **[STYLE]** GmailGlyph missing entirely in Flutter. Design ships a 5-color Gmail SVG mark (`GmailGlyph`, lines 546–556) used on the Intro CTA (size 18), the Setup how-to header (18), and the Dashboard hero (32). Flutter has no equivalent — the CTA button shows text only, and the dashboard hero uses a generic `envelope.fill` accent tile (`email_dashboard_screen.dart:105`). The brand glyph is absent in all three places.
- **[SUBTAB]** No provider segmented control / toggle anywhere. The README spec (screen 20, line 517) calls for an inset **"Gmail (Recommended) / Outlook / Other (IMAP)"** provider list. The JSX prototype does NOT implement this (it hardcodes Gmail and shows a static "iCloud, Outlook, any IMAP coming" caption). Flutter matches the JSX (caption only, `email_intro_screen.dart:161`), so relative to the prototype this is faithful — but relative to the written spec the provider picker is **[MISSING]**. No Gmail/Outlook toggle exists.
- **[SUBTAB]** No receipts-vs-subscriptions tab / segmented control anywhere in the Dashboard. The feature is described as "receipts + subscriptions" and the Dashboard `detections` array tags one row as `recurring` (Netflix, line 286), but neither design nor Flutter splits them into tabs. The JSX surfaces subscriptions only via the "Pal noticed" card ("7 recurring subscriptions… Review subscriptions"). Flutter drops that card entirely (see Dashboard below), so the only subscription affordance in the prototype is **[MISSING]** in Flutter.
- **[SUBTAB]** No category filter chips. README screen 22 (line 545) lists a **"Filters" button**; the JSX prototype did not build it. Flutter also omits it. Filter chips for synced-item categories do not exist in the prototype or the app.

---

## Intro / Empty state (`EmailSyncEmptyScreen` → `EmailIntroScreen`)

- **[COPY]** Nav leading label differs. Design: **"You"** with chevron (line 17), back to the You/profile tab. Flutter: **"Settings"** (`email_intro_screen.dart:50`). Mismatched destination label.
- **[LAYOUT/STYLE]** Headline line break dropped. Design renders two lines via `<br/>`: **"Stop logging card"** / **"charges by hand."** (line 43) with `textWrap: 'balance'`. Flutter passes a single string "Stop logging card charges by hand." (`:62`) — same words, no forced break, no balance wrap.
- **[STYLE]** Glyph gradient opacity mismatch. Design background gradient is `linear-gradient(135deg, ${accent}18, ${money}22)` = accent @ ~9%, money @ ~13% (line 24). Flutter uses `c.accentTint` and `c.moneyTint`, both 14% (`email_intro_screen.dart:191`). Slightly stronger tint than designed.
- **[STYLE]** Glyph badge shadow dropped. Design's sparkles badge has `boxShadow: 0 4px 12px ${money}55` (line 35) and the outer tile has a `0 0 0 0.5px hair` hairline (line 27). Flutter omits both the badge glow and the tile hairline.
- **[MISSING]** "How it works" middle step lost its accent color token. Design step 2 ("Pal reads only those") uses `color: theme.accent` (line 55). Flutter passes `''` as the token (`email_intro_screen.dart:29`) and resolves via `c.forType('')` — verify this yields accent; if `forType` falls back to a default, step 2's icon tile color is wrong.
- **[STYLE]** Step icon tile tint opacity differs. Design tile bg is `${color}22` = 13% (line 63). Flutter uses `withValues(alpha: 0.13)` (`:238`) — matches. (No issue; noted for completeness.)
- **[COPY]** Reassurance note copy trimmed. Design: "…Pal stores it encrypted in the **iOS keychain**. Revoke it anytime **from Gmail** without touching anything else." (line 91). Flutter: "…encrypted in the **keychain**. Revoke it anytime without touching anything else." (`:116-119`) — drops "iOS" and "from Gmail".
- **[MISSING]** Secondary CTA is a real button in design, plain text in Flutter. Design's "iCloud, Outlook, any IMAP coming" is a `<button>` (line 107). Flutter renders it as a non-interactive `Text` (`:160`). Functionally both are inert mocks, but the design models it as tappable.
- **[STYLE]** Primary CTA shadow dropped. Design CTA has `boxShadow: 0 4px 14px ${ink}33` (line 102). Flutter CTA has no shadow (`:139-144`).
- **[STYLE]** Primary CTA missing leading glyph + gap. Design CTA is `GmailGlyph(18)` + 10px gap + "Set up Gmail sync" (lines 104–106). Flutter shows the label only, centered, no glyph (`:146`).
- **[LAYOUT]** Bottom padding differs. Design `paddingBottom: 110` (line 7); Flutter `EdgeInsets.only(bottom: 48)` (`:46`). Likely intentional (no floating tab bar in this route) but noted.

---

## Setup / App-password (`EmailSyncConnectScreen` → `EmailSetupScreen`)

- **[COPY]** Seed email differs. Design prefills `mira@gmail.com` (line 119). Flutter prefills `alex@gmail.com` (`email_setup_screen.dart:33`). Cosmetic mock data.
- **[COPY]** App-password app label differs. Design step 3: `Create an app password labeled "ExpensePal"` (line 182). Flutter: `Create an app password labeled "Pal"` (`:284`). String mismatch.
- **[STYLE/COPY]** "Open Google app passwords" button icon differs. Design uses `square.and.arrow.up` (line 190). Flutter uses `arrow.up.right` (`:332`). Different SF symbol.
- **[STYLE]** How-to step 2 link styling dropped. Design renders `myaccount.google.com/apppasswords` underlined in accent color (`<u style={{color: accent}}>`, line 181). Flutter renders the URL as plain ink2 text inside the sentence (`:283`) — no accent, no underline, not visually a link.
- **[MISSING]** How-to header glyph dropped. Design header row is `GmailGlyph(18)` + "Generate a Gmail app password" (lines 170–173). Flutter shows the title text alone, no glyph (`:296`).
- **[DIFFERENT]** Test-connection success/idle background tint. Design success bg `${move}22` (13%) with border `${move}44` (line 200, 205); idle bg `theme.surface` (line 200). Flutter success bg `c.move.withValues(alpha:0.13)`, border 0.27 (`:373,399`) — matches. Idle/testing bg `c.surface` — matches. (No issue.)
- **[MISSING / DIFFERENT]** Error state added in Flutter, not in design. Design `runTest` only toggles testing→ok (lines 125–128); there is no error path. Flutter adds a `TestState.error` branch with `xmark` + "Connection failed — check the password" (`:375-380`). This is an addition beyond the prototype (the README spec line 532 does call for an Error state, so it aligns with the written spec).
- **[STYLE]** Test button leading icon: design idle uses `bolt.fill` accent (line 209) — Flutter matches (`:382`). Testing spinner color design `ink2` (line 207) — Flutter `c.ink2` (`:364`). Matches.
- **[COPY]** Advanced "Encryption" value matches ("SSL / TLS", line 247 vs `:217`). Host/Port defaults match (`imap.gmail.com` / `993`). No issue.
- **[BEHAVIOR]** Advanced section in design has NO chevron rotation state persisted beyond local; Flutter mirrors with `_advancedOpen` toggling `chevron.down`/`chevron.right` (`:182`). Matches.
- **[STYLE]** How-to card border. Design card uses `boxShadow: 0 0 0 0.5px hair` (line 167). Flutter uses `Border.all(color: c.hair, width: 0.5)` (`:291`). Equivalent rendering; acceptable.
- **[BEHAVIOR]** Save gating matches intent (disabled until test succeeds): design `disabled={!ok}` (line 141), Flutter `trailingEnabled: setup.canSave` (`:90`). Matches.

---

## Synced Dashboard (`EmailSyncedScreen` → `EmailDashboardScreen`)

### Nav bar
- **[LAYOUT]** Design uses the **small-title** `NavBar` (`large` defaults true but title is "Email sync" with a **subtitle "Gmail · connected"**, line 293). Flutter uses `LargeTitleNavBar` with title "Email sync" and **no subtitle** (`email_dashboard_screen.dart:64`). The "Gmail · connected" subtitle is **[MISSING]**.
- **[COPY]** Leading label "You" (design, line 302) vs "Settings" (Flutter, `:73`). Same mismatch as Intro.
- Trailing `ellipsis` icon button present in both. Matches.

### Sync-job hero
- **[STYLE]** Hero avatar. Design uses `GmailGlyph(32)` (line 314). Flutter uses a 32×32 accent-tinted tile with `envelope.fill` (`:97-107`). Brand glyph replaced by generic envelope.
- **[DIFFERENT]** Connection chip identity row. Design shows the **email address** `mira@gmail.com` next to the chip (line 319). Flutter shows the account address (`alex@gmail.com` fallback, `:57,116`). Address source differs but structure matches.
- **[DIFFERENT]** Status line copy / staging differs substantially. Design `lastMsg` cycles verbatim: "Last sync 4 min ago" (idle) → "Connecting to imap.gmail.com…" → "Scanning INBOX · 1,847 messages" → "Filtering by sender · 62 matches" → "Parsing 3 new receipts…" → "Pal categorized 3 · 1 duplicate skipped" → "Last sync just now · 3 new" (lines 261–278). Flutter uses generic short stages: "Scanning INBOX…", "Filtering by sender…", "Pal is categorizing…", "Up to date · just now", and an idle "Last sync N min ago" / "Never synced" (`:29-44`). The message-count details ("1,847 messages", "62 matches", "3 new", "1 duplicate skipped") and the "Connecting to imap.gmail.com…" / "Parsing N new receipts…" stages are **[MISSING]**.
- **[DIFFERENT]** Progress stages. Design step progresses 10→28→55→80→100% (lines 266–270). Flutter maps 0/0.28/0.55/0.80/1.0 by status (`:29-37`) — close but drops the 10% "connecting" stage and the explicit 100% "done" message.
- **[STYLE]** Completed-bar color flash. Design bar turns `theme.move` (green) when `syncState === 'done'` (line 346); Flutter sets color to `c.move` when `SyncStatus.upToDate` (`:144`). Matches.
- **[COPY]** Sync-now button icon differs. Design idle uses `arrow.triangle.2.circlepath` (line 367); Flutter idle uses `paperplane.fill` (`:331`). Design syncing has a Spinner + "Syncing…" (line 363); Flutter syncing uses `arrow.up.right` icon + "Syncing…" (`:328`) — **no spinner**, wrong icon. Done state: both `checkmark` + "Done". 
- Schedule chip "Every 15m" present in both; design icon `timer` (line 376) vs Flutter `clock.fill` (`:372`). **[STYLE]** icon mismatch.

### Stats tiles — MISSING
- **[MISSING]** The 3-up stats grid is absent in Flutter. Design renders a `surface` card with three tiles: **"This month" 147** (accent), **"All time" 2,143** (money), **"Recurring" 7** (rituals) (lines 384–406). Flutter's Dashboard has no stats row at all.

### Pal-noticed card — MISSING
- **[MISSING]** The "Pal noticed" subscription-insight card is absent in Flutter. Design renders an `accentTint` card (lines 409–429): eyebrow "PAL NOTICED", body "You have **7 recurring subscriptions** totaling $84/mo. Two of them you haven't opened in 30+ days — want me to flag cancel candidates?", and a **"Review subscriptions"** pill button. This is the only subscriptions affordance in the prototype and it is entirely **[MISSING]** — removing the feature's subscription half from the dashboard.

### Recently-synced list
- **[DIFFERENT]** Per-row category icon + color are hardcoded in Flutter. Design assigns each detection its own `catIcon`/`catColor` (e.g. Blue Bottle → `cup.and.saucer.fill` move-green; Uber → `figure.walk` accent; Netflix → `star.fill` rituals-purple; Whole Foods → `basket.fill` money-orange; lines 283–288). Flutter hardcodes **every** row to `basket.fill` with `c.money` tint (`email_dashboard_screen.dart:446`). All category icons/colors are wrong except groceries.
- **[MISSING]** Recurring indicator dropped. Design shows an `arrow.triangle.2.circlepath` glyph next to recurring merchants (Netflix, lines 453–455). Flutter renders no recurring marker on import rows.
- **[MISSING]** Row meta line is reduced. Design subtitle is `category · [tray.fill] source · time` (e.g. "Food & Drink · Chase · 2h ago", lines 463–473). Flutter shows only `item.category ?? 'Uncategorized'` (`:488`) — **no source (card) and no relative time**.
- **[STYLE]** Amount color. Design amount is `theme.ink` SF-Rounded (line 476). Flutter uses `c.ink` SF-Rounded (`:494-499`). Matches the JSX. (README line 543 says amount should be "money orange" — divergence is spec-vs-prototype; Flutter follows the JSX.)
- **[BEHAVIOR]** NEW badge fade. Design fades the accent-tint row highlight over 400ms and tags fresh rows with a "NEW" pill while `syncState === 'done'` (lines 438, 456–461). Flutter implements a 6s timer that fades both the row tint and the badge (`:398-484`) — aligns with README "fades after 6s" (line 543/765); reasonable, but the design JSX ties the tint to `syncState==='done'` rather than a 6s timer.
- **[MISSING]** Empty-list state is a Flutter addition. Design always renders the 6-item `detections` list. Flutter adds a "No imports yet — tap Sync now." placeholder when `imports` is empty (`:181-196`). Addition beyond prototype (acceptable for a real data-backed screen).

### Sync settings — MISSING
- **[MISSING]** The entire "Sync settings" section is absent in Flutter. Design renders a `Section` with four `ListRow`s (lines 484–493): **"Background sync" → "Every 15 min"**, **"Notify on new detection" → "Off"**, **"Pal auto-categorize" → "On"**, **"Detected senders" → "47"**. None exist in Flutter.

### Disconnect
- **[COPY]** Present and matching: "Disconnect Gmail" in red (design line 501, Flutter `:212`). Behavior differs — Flutter actually disconnects via controller and pops (`:203-207`); design is a static mock. Acceptable.

---

## Summary of structural gaps (Dashboard)

Flutter's dashboard is missing three whole design sections — **Stats tiles**, **Pal-noticed subscriptions card**, and **Sync settings list** — plus the nav subtitle, per-row category coloring, recurring markers, and the source/time meta. These are the highest-impact differences. Combined with the absent provider toggle and the absent receipts/subscriptions split, the "subscriptions" half of "receipts + subscriptions" has effectively no UI surface in the current Flutter build.


---

# Money & Misc (Onboarding, Detail, Sheets, Bills, Subscriptions, Budget, Settings)

Audit of the Flutter "opal" app against the ExpensePal React/JSX design handoff.
Design = source of truth. Each bullet is tagged
[MISSING]/[DIFFERENT]/[COPY]/[LAYOUT]/[STYLE]/[SUBTAB].

Design files read: `src/screens.jsx` (DetailScreen, ProfileScreen, BudgetSheet),
`src/today.jsx` (AddSheet), `src/tab-landings.jsx` (QuickActionSheet),
`src/ai-screens.jsx` (OnboardingScreen), `src/more-screens.jsx` (BillsScreen,
SubscriptionsScreen, BILLS, SUBSCRIPTIONS), `design_handoff_expensepal/README.md`,
`Handoff - Workout Rename & Budget Editor.md`.

---

## 0. Bills & Subscriptions — DELETED, now orphaned

Git shows `lib/screens/money/bills_screen.dart` and
`lib/screens/money/subscriptions_screen.dart` were **deleted**. The audit confirms
the data layer still exists but the screens and any way to reach them do **not**.

- **[MISSING] Bills screen (handoff 23) has no UI.** The model
  (`lib/models/bill.dart`), repository (`lib/data/repositories/bill_repository.dart`),
  seed data, and a fully-built controller (`buildBillsState`, `bills` provider in
  `lib/controllers/money_recurring_controller.dart`) all survive, but there is **no
  widget** rendering them and **no route**. `Grep` for `BillsScreen`/`Bills` route in
  `router.dart` returns nothing. Functionality is dead code behind the provider.
- **[MISSING] Subscriptions screen (handoff 18) has no UI.** Same situation:
  `lib/models/subscription.dart`, `subscription_repository.dart`, and
  `buildSubscriptionsState`/`subscriptions` provider exist, but no screen and no route.
- **[MISSING] You-screen links to Bills & Subscriptions are gone.** Design README §19
  specifies the You Settings list includes **Subscriptions (→ 18)** and **Bills (→ 23)**.
  `lib/screens/profile/profile_screen.dart` Settings sections (lines 164–235) contain
  neither row. So even the data that is computed can never be displayed.
- **[MISSING] Today contextual links to Bills.** README §02 says Today has "contextual
  links to Bills, Pal inbox, Streak…". With Bills deleted, the Bills link is unreachable.

Net: Bills + Subscriptions are **fully designed and half-built (data only)** but the
entire presentation + navigation layer is missing. This is the single largest gap in
this audit slice.

---

## 1. Onboarding (`onboarding_screen.dart` vs `OnboardingScreen` in ai-screens.jsx)

Structure matches well (4 steps, progress dots, 96×96 hero, big value, chips, rituals
list, CTA, Skip). Differences:

- **[COPY] Welcome body — "rituals" → "routines".** Design: *"One app for money,
  workouts, and the little **rituals** that hold your day together."* Flutter (line 268):
  *"…the little **routines** that hold your day together."*
- **[COPY] Step 3 title — "rituals" → "routines".** Design step 4 title: *"Choose your\nrituals"*.
  Flutter (line 258): *"Choose your\nroutines"*.
- **[COPY] Step 3 body differs and miscounts.** Design: *"**Five** small things you want to
  do each day. You can edit these anytime."* Flutter (line 266): *"**Six** small things you
  want to do each day…"*. (The list does have 6 suggested rituals, but the spec/README §01
  says "picks 5 daily rituals" — the design copy says "Five".)
- **[COPY] Step 2 (workout goal) body differs.** Design (post-rename handoff §1):
  *"Any session counts — lift, run, walk, yoga. You log the minutes."* Flutter (line 264):
  *"Any kind of workout counts — run, walk, yoga, anything."* — different wording, drops the
  "You log the minutes" clause.
- **[STYLE] Step 2 hero glyph differs.** Design step 3 `hero: '◐'`; Flutter uses `'◐'`
  (line 250) — **matches**. (No diff; noting verified.) Welcome `'✦'`, budget `'$'`,
  rituals `'✧'` all match.
- **[COPY] Welcome headline brand.** Design: *"Welcome to\nExpensePal"*. Flutter (line 259):
  *"Welcome to\nOpal"* — expected rebrand, flagged for completeness.
- **[STYLE] Big-value font size.** Design value (e.g. "$85", "60 MIN") is SFR **72px**/700
  (ai-screens.jsx line 259). Flutter `_BigValue` (line 354) uses **64px**. Smaller than spec.
- **[STYLE] Hero shadow alpha.** Design shadow `${color}33` (≈0.20). Flutter uses
  `alpha: 0.20` — matches. Hero tint design `${color}1F` (≈0.12); Flutter `alpha: 0.12` — matches.
- **[LAYOUT] Skip button behavior.** Design Skip is a no-op visual on steps >0. Flutter Skip
  (line 177) calls `_finish()` — i.e. it commits onboarding and exits. Reasonable, but a
  behavior the static design doesn't define.
- **[SUBTAB] Chip selectors present and correct.** Budget `$50/$85/$120/$200` and workout
  `20/45/60/90 min` chip rows exist (`_ChipRow`), single-select, default index correct.
  Verified — no gap.

---

## 2. Detail screen (`detail_screen.dart` vs `DetailScreen` in screens.jsx)

This is a substantial redesign, not a port. Many design elements are absent.

- **[MISSING] Hero is a different card.** Design hero (screens.jsx 475–519): tinted bg
  (`theme[type+'Tint']`) with `0.5px ${color}22` border, a **56×56 icon tile**, the big
  number, a colored **sub-line** (e.g. "Spent today"), a **goal line** ("of $85 daily
  budget"), and a **circular conic-gradient % ring** on the right. Flutter `_HeroCard`
  (lines 180–235) is a plain `c.surface` card with a **"TOTAL" eyebrow**, the number, a
  **horizontal ProgressBar**, and an "of $X budget" + "$X left/over" row. No icon tile, no
  percent ring, no tint/border, no colored sub-line.
- **[COPY] Eyebrow "TOTAL" not in design.** Design has no "TOTAL" label; it shows
  `cfg.sub` ("Spent today" / "Minutes logged" / "Rituals completed").
- **[COPY] Section header "By category" vs "Breakdown".** Design header (screens.jsx 522):
  **"Breakdown"**. Flutter (line 104): **"By category"** (uppercased).
- **[COPY] Section header "Recent" vs "Today's spending".** Design (line 559):
  ``Today's ${TYPE_META[type].label.toLowerCase()}`` → e.g. "Today's spending". Flutter
  (line 107): **"Recent"**, and groups by day (Today/Yesterday/date) rather than a single
  "Today's …" section.
- **[LAYOUT] Category rows: icon tile missing.** Design category row (screens.jsx 524–548)
  has a **29×29 colored icon tile** (`c.icon`) before the name. Flutter `_CategoryRow`
  (287–322) shows **label + amount + bar only** — no icon tile.
- **[DIFFERENT] Hero progress indicator.** Design uses a **conic-gradient donut** showing
  rounded %; Flutter uses a **linear ProgressBar** and an "over"/"left" text. Different
  visual metaphor (README §06 allows "horizontal bar OR donut", so this is acceptable but a
  visual mismatch vs the JSX).
- **[STYLE] Entry-row icon is hard-coded.** Flutter `_EntryRow` (line 434) always renders
  **`creditcard.fill`** regardless of entry; design uses each entry's own SF symbol (`e.sf`).
  Move/Rituals detail would show a credit-card icon — wrong for those trackers.
- **[MISSING] Bottom "Ask Pal" pill differs in copy.** Design pill text per README §06:
  *"Ask Pal about spending"*. Flutter uses `data.tracker.askPalPrompt` (gradient pill present,
  correct shape) — verify the string matches; copy lives in the controller, not this file.
- **[SUBTAB] No period/segmented toggle exists in either.** The design DetailScreen has **no**
  period segmented control, so none is expected. Verified — not a gap. (The brief asked to
  check; confirming absence by design.)

---

## 3. New-entry sheet (`new_entry_sheet.dart` vs `AddSheet` in today.jsx)

The segmented control is present and correct; several supporting elements differ.

- **[SUBTAB] Segmented type picker present & correct.** `Segmented<_Kind>` with
  **Expense / Workout / Routine** (lines 428–436) matches design `[Expense, Workout, Routine]`
  (today.jsx 432–437). Verified — no gap. (Design value tokens are money/move/rituals;
  Flutter maps the same.)
- **[COPY] Routine label.** Design third segment label is **"Routine"**; Flutter "Routine".
  Matches. (Design internal value `rituals`.)
- **[DIFFERENT] Natural-language entry placement & style.** Design renders the **"Log with
  Pal"** NL input **inline at the top of the sheet** — an always-visible accent-tinted box
  (today.jsx 386–428) with an input + "Parse" button. Flutter instead has a **"Type it"**
  button low in the scroll list (lines 480–484) that opens a **separate modal** `_TypeItInput`.
  Different IA and different copy.
- **[COPY] NL section label.** Design: **"LOG WITH PAL"** (uppercase eyebrow). Flutter button:
  **"Type it"** / placeholder *"e.g. \"coffee 5\" or \"ran 30 min\""* vs design placeholder
  *"spent $14 on ramen"*.
- **[COPY] Category section header.** Design (today.jsx 481): **"Category"**. Flutter (line 450):
  **"QUICK PICKS"**.
- **[LAYOUT] Quick picks: grid → wrap, and content differs.** Design quick-pick is a **3-col
  grid of single-word category chips** that depend on the active type (e.g. money:
  `Coffee/Lunch/Groceries/Transit/Dinner/Snacks`; move: `Run/Gym/Yoga/Walk/Bike/Swim`;
  rituals: `Journal/Read/Meditate/Language/Stretch/Focus`) — these set the note/category.
  Flutter shows a **fixed `Wrap` of 6 rich tiles** (icon + title + "$5"/"30 min" label) that
  are **not type-filtered** (all 6 always shown across money/workout/ritual). Different model
  entirely.
- **[STYLE] Big display.** Design amount is SFR **72px**/700 with a separate 46px `$` prefix
  for money and a 20px "min" suffix for move (today.jsx 453–473). Flutter `_buildDisplay`
  (510–533) uses SFR **56px** and renders the `$`/`min` inline in the formatted string. Smaller
  and structurally different. Empty state color `c.ink4` matches design intent.
- **[DIFFERENT] Keypad placement.** Design keypad is part of the scrolling sheet body. Flutter
  pins the keypad to the **fixed bottom** and scrolls only the middle. Functional, layout
  divergence.
- **[MISSING] Optional fields not in design AddSheet.** Flutter adds Category/Note `_OptionalField`
  rows (463–475) the design AddSheet doesn't have (design only has the quick-pick note +
  amount). Extra surface, not a deletion — flagged as scope addition.
- **[STYLE] Header padding token "New Entry" matches** (17/600). Grabber 36×5 present in Flutter,
  absent in design AddSheet (design has no grabber). Minor addition.

---

## 4. Keypad (`keypad.dart` vs inline keypad in AddSheet)

- **[STYLE] Key chrome differs.** Design keys (today.jsx 505–521): `theme.surface` bg, **no
  border**, radius **14**, padding `18px 0`, SFR **26**/500. Flutter `_Key` (lines 116–134):
  `c.surface` bg **with `0.5px c.hair` border**, radius **12**, fixed height **52**. Border +
  smaller radius are the visible diffs.
- **[LAYOUT] Decimal-hidden behavior differs.** Design always shows the `.` key (today.jsx 505
  includes `'.'` for all types and guards duplicate dots in the handler). Flutter renders the
  decimal as an **inert blank `SizedBox`** when `showDecimal` is false (move/integer), per the
  sheet passing `showDecimal: _kind == _Kind.expense`. So in design you can type "." on a move
  entry (no-op guarded) but it's visible; in Flutter the slot is empty. Minor.
- **[STYLE] Delete glyph matches.** Both use `delete.left.fill` (22px). Verified.

---

## 5. Quick Action sheet (`quick_actions_overlay.dart` vs `QuickActionSheet` in tab-landings.jsx)

Major structural divergence: a **bottom sheet of 3 list rows** in design vs a **centered 2×3
grid overlay** in Flutter.

- **[DIFFERENT] Layout.** Design `QuickActionSheet` (tab-landings.jsx 423–475) is a
  **bottom-anchored surface** with a grabber, a **"QUICK ACTIONS"** eyebrow, and **3 full-width
  list rows** (44×44 tinted icon + title + subtitle + chevron). Flutter `QuickActionsOverlay`
  is a **full-screen dim overlay** with a **2×3 GridView** of 6 square tiles + a top-right close ×.
- **[MISSING] / [DIFFERENT] Action set.** Design has **3 actions**: *Log entry* ("Money, meal,
  or workout — natural language"), *Start workout* ("Pick a routine or freestyle"), *Ask Pal*
  ("Chat about your patterns"). Flutter has **6 tiles**: *Log expense, Log workout, Start workout,
  Complete routine, Ask Pal, Voice entry* (lines 28–35) — none with subtitles.
- **[COPY] No subtitles in Flutter.** Design rows each carry a descriptive sub-line; Flutter
  tiles are label-only.
- **[COPY] "Log entry" → "Log expense" + extras.** Design's single "Log entry" (NL, all types)
  is split into separate "Log expense"/"Log workout"/"Voice entry" tiles.
- **[STYLE] Grabber / eyebrow absent.** No "QUICK ACTIONS" eyebrow and no 36×5 grabber in Flutter
  (it's a grid, not a sheet).

---

## 6. Budget editor (`BudgetSheet` design + Handoff §3) vs `budgets_goals_screen.dart`

The design specifies a **bottom-sheet `BudgetSheet`** opened from You ▸ Goals ▸ Daily budget.
Flutter implements a **full-page push screen** ("Budgets & goals") with steppers — a different
component shape, and it is missing the sheet's signature controls.

- **[MISSING] Period segmented control (Daily / Weekly).** The design's defining subtab
  (`BudgetSheet`, screens.jsx 364–375; Handoff §3) is a **Daily/Weekly segmented pill** that
  rescales the amount on switch (daily→weekly `round(×7/25)×25`; weekly→daily
  `max(5,round(/7/5)×5)`). Flutter `BudgetsGoalsScreen` has **no period toggle at all** — only a
  single "daily" budget stepper. This is a **missing segmented control**, the highest-priority
  subtab gap here.
- **[MISSING] Big amount display + circular steppers.** Design shows a **54px/700 `theme.money`**
  amount with **48×48 circular −/+** buttons and a "PER DAY"/"PER WEEK" caption. Flutter uses a
  compact inline `_StepperRow` (icon + label + small value + 30×30 −/+) inside an inset list — no
  large hero amount, no period caption.
- **[MISSING] Preset chips.** Design has preset chips (daily `[50,75,100,150]`, weekly
  `[350,500,700,1000]`) that select the amount. Flutter has **none**.
- **[MISSING] Footnote card.** Design footnote: *"Pal nudges you as you near your {daily/weekly}
  budget — gently, and never blocks a purchase."* (sparkles icon). Flutter footer (line 89):
  *"Targets power your daily rings and Pal's nudges."* — different copy, no sparkle card.
- **[DIFFERENT] Scope.** Design `BudgetSheet` edits **only the budget** (the Goals section's
  Workout goal `60 min` and Daily rituals `5` rows are separate, non-tappable on the You screen,
  screens.jsx 281–290). Flutter combines **Budget + Workout + Routines** steppers into one screen
  — a reasonable consolidation but not the spec'd component.
- **[COPY] Step size.** Design daily step ±5, weekly ±25. Flutter budget step ±5 (no weekly mode),
  workout ±5, routines ±1. Daily step matches; weekly mode absent (see above).
- **[COPY] Nav.** Design sheet nav: Cancel / **Budget** / Save. Flutter: leading "You" /
  **"Budgets & goals"** / Save. Different because it's a pushed screen, not a sheet.
- **[MISSING] Goals section on You screen.** Handoff §3 adds a **Goals** inset section directly
  under the profile card with 3 rows (Daily budget tappable → sheet, Workout goal, Daily rituals).
  `profile_screen.dart` has **no Goals section** — only a "This year" stat grid then the Settings
  list. The budget is reachable only via Settings → "Budgets & goals" (line 177), not via a Goals
  row showing the current "$85" value.

---

## 7. Settings sub-screens

The handoff has **no dedicated mockups** for Appearance / Notifications / Privacy / Export / About
beyond the You-screen Settings inset list (README §19). These Flutter screens are app-original
implementations; compared against the README list:

- **[MISSING] Settings list entries vs README §19.** README §19 Settings list:
  *Rituals · Budgets & goals · Notifications · HealthKit · Integrations→Email sync ·
  Subscriptions · Bills · Weekly review · Privacy · Export · About*. Flutter
  `profile_screen.dart` (164–235) has:
  *Routines · Budgets & goals · Notifications · **Appearance** · Integrations(Email sync) ·
  Weekly review · Privacy · Export · About*.
  - **Subscriptions** — missing (matches §0; intentional per Workout/Health handoff direction).
  - **Bills** — missing (matches §0).
  - **HealthKit** — missing **by design** (Handoff §4 removes Apple Health entirely). Correct.
  - **Appearance** — **added** (not in README list); legitimate extra.
- **[STYLE] Appearance — no design counterpart.** `appearance_screen.dart` (Light/Dark
  `Segmented` + accent swatch `Wrap`) is reasonable and tokens look correct (`THEME`/`ACCENT`
  eyebrows 13px ink3). No design to diff against; flagged as net-new.
- **[SUBTAB] Appearance segmented control present.** Light/Dark `Segmented<Brightness>` exists
  (appearance_screen.dart 40–47). Verified.
- **[COPY] Notifications copy is app-original.** Rows: "Allow notifications", "Routine reminders"
  (`sparkles`/rituals), "Budget alerts" (`flame.fill`/money). No design strings to match; note
  "Routine reminders" follows the rituals→routines rename.
- **[COPY] About version.** `about_screen.dart` hard-codes `_version = '1.0'` and shows
  "Opal 1.0" on the You row (profile line 230). README §19 just lists "About"; no version spec.
  Consistent internally.
- **[STYLE] Export screen is app-original.** Clipboard-JSON export with hero icon + CTA. README §19
  only lists "Export" as a row. No mockup; net-new, reasonable.
- **[STYLE] Privacy screen is app-original.** Two inset sections explaining local-first storage.
  No design mockup; net-new.

---

## Severity tally

- **[MISSING]**: 18
- **[DIFFERENT]**: 8
- **[COPY]**: 16
- **[LAYOUT]**: 5
- **[STYLE]**: 13
- **[SUBTAB]**: 5 (4 verified-present, 1 missing — the Budget Daily/Weekly toggle)

(Counts are approximate groupings; some bullets carry two tags.)

---

## Notes on grounding

All claims trace to specific lines in the files listed at the top. Where the README permitted a
choice (e.g. "horizontal bar OR donut" for the Detail hero), the divergence is noted as acceptable
rather than a hard defect. Settings sub-screens (Appearance/Notifications/Privacy/Export/About) have
no design mockups, so they are evaluated only against the README §19 list and the
rituals→routines / no-HealthKit handoff directives.
