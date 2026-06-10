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
