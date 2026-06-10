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
