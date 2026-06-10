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
