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
