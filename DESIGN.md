# Opal design system

Status: target direction, adopted 2026-10-04. Opal is being redesigned to follow the Oura
app's design approach. This document is the rulebook for that redesign.

- **Rules live here. Numbers live in `lib/theme/`.** Where the two disagree today, the
  "Token delta" section lists the gap; the code has not been migrated yet.
- New screens and `.dc.html` canvases follow this document, not the current widgets.
- This is "follow their approach", not "clone their app": Oura's fonts, photography, icons and
  the crown mark are theirs. Substitutes are named below.

Evidence tags used in the research section:
`[measured]` read from Oura's live site CSS by third-party token extractors;
`[stated]` said by Oura or by Instrument, the agency behind the 2025 redesign;
`[observed]` described in reviews or recalled from using the app, not verified against a
current build.

## 1. What Oura does

### Structure

- Three tabs: **Today**, **Vitals**, **My Health**. The 2024 redesign cut five tabs to these
  three; everything else moved to a side menu and a "+" button. `[stated]`
- **Today** is "like the Top Stories page of a news app": it changes through the day and leads
  with **one big thing**, the single most relevant score or insight for this moment. `[stated]`
- Today, top to bottom: a row of **shortcuts** (small circles for Readiness, Sleep, Activity,
  then heart rate, stress), the daily highlight, action items, a **timeline** of the day,
  then what's new. Shortcuts are reorderable, minimum three. `[stated]`
- **Vitals** puts every core metric on one screen as grouped cards, each showing where today
  sits against **your own baseline range**. A card expands in place for top contributors and
  opens a detail view for everything. `[stated]`
- **My Health** is the long view: health areas rated over 90 days, habits and routines tied to
  outcomes, reports. `[stated]`

### Hierarchy: progressive disclosure

- The surface holds enough for most visits; more detail is always exactly one tap away. `[stated]`
- Information is ordered by how a day actually runs, morning to night. `[stated]`
- Three levels of data visualisation, never mixed on one surface: `[stated]`
  1. **Glance**: abstract rings, bars and a colour cue. Daily status only.
  2. **Focus**: one metric with short-term pattern and context.
  3. **Explore**: precise, interactive charts over weeks, months, years.

### Colour

- Colour is **semantic, not decorative**. It signals the state of the body relative to a
  personal baseline, not which feature you are looking at. `[stated]`
- Four states with fixed words. My Health: Thriving (blue), Looking Good (green), Worth
  Watching (yellow), Needs Care (red). `[stated]`
- Scores run 0 to 100: 85+ Optimal (marked with a crown), 70 to 84 Good, 60 to 69 Fair, below
  60 Pay attention. A contributor that needs attention gets a red bar; the rest stay neutral.
  `[stated]`
- The brand palette is warm and nearly colourless: cream `#F7F1E8`, sandstone `#4A4741`,
  graphite `#1E2427`, with olive `#5C6F5D`, mustard `#AF751B`, slate `#27455C`, red `#D22C15`
  and one blue `#2A72DE` held in reserve. `[measured]`
- The app itself is dark-first, with muted, single-tone arcs; saturated colour appears only as
  a state signal. `[observed]`

### Type, shape, imagery

- AkkuratLL, a precise grotesque, does all functional text (400 body, 500 labels, 700
  emphasis). Display sizes are **light** (200 to 300) with negative tracking. `[measured]`
- Editorial New, a high-contrast serif, appears only in emotional headlines, typically one
  phrase per heading, never below 30px. `[measured, website]` Whether the app uses the serif
  is not verified.
- Small labels are 12 to 14px with slight positive tracking. `[measured]`
- Buttons are full pills, 48px tall. Primary is graphite on cream, not the blue. Surfaces are
  flat with 1px hairlines; overlays use a dark scrim, not shadow. `[measured]`
- The 2025 redesign dropped the card-per-thing layout for a more open one and "doubles down on
  serene landscapes". `[stated/observed]`
- Detail screens set a large light-weight number under a wide open arc over a landscape
  image, with contributors as plain horizontal bars beneath. `[observed]`

### Voice

- Calm and non-judgemental. A low score says "Pay attention", not "Bad". States are words
  first, numbers second. `[stated]`
- An AI advisor sits beside the long-term view and explains the why. `[stated]`

## 2. Principles for Opal

1. **One big thing.** Every screen has one lead element. On Today it is Pal's line and the
   next action, and Today carries no glance: no rings, bars or score row. The glance lives on
   the Areas screen, whose lead is the activity rings. Nothing else on a screen competes with
   its lead in size, weight or colour.
2. **Colour means state.** A hue on screen answers "how is this going", never "which area is
   this". Areas are told apart by icon and label. The one exception is the activity rings
   (section 3).
3. **Quiet until it matters.** The default rendering of any score is neutral ink. State colour
   appears when something is off track or has been achieved.
4. **Words before numbers.** Every score carries a state word. A bare number never stands alone
   as status.
5. **One tap deeper.** Glance, focus, explore. A surface shows one level and links to the next.
6. **Open, not boxed.** Sections are separated by space and hairlines. A card is the exception,
   used for one thing that can be acted on.
7. **The scene carries the mood.** Decoration comes from the time-of-day landscape and from
   typography, not from gradients, glass or coloured tiles.

## 3. Colour

All ratios below were computed with the WCAG formula against `bg` / `surface` / `surface2`.

### Neutrals, light

| Token | Value | Use | Contrast on bg |
|---|---|---|---|
| `bg` | `#F7F1E8` | page ground | |
| `surface` | `#FEFAEF` | the rare card, sheets | |
| `surface2` | `#EEE6DC` | inset fills, pressed states | |
| `hair` | `#E6DED3` | 1px dividers | decorative |
| `ink` | `#1E2427` | primary text, primary button fill | 13.99 |
| `ink2` | `#4A4741` | body, secondary headings | 8.24 |
| `ink3` | `#5A5958` | captions, metadata | 6.22 |
| `ink4` | `#A8A5A0` | disabled, non-text only | 2.19, never for text |
| `track` | `#D9D0C3` | empty ring and bar tracks | decorative |

### Neutrals, dark

Oura's in-app hex values are not published; these are Opal's own, built to the same recipe
(cream ink on a cool graphite ground).

| Token | Value | Contrast on bg |
|---|---|---|
| `bg` | `#101418` | |
| `surface` | `#1A1F24` | |
| `surface2` | `#242A30` | |
| `hair` | `#2E353C` | decorative |
| `ink` | `#F7F1E8` | 16.47 |
| `ink2` | `#D3D1CE` | 12.14 |
| `ink3` | `#A8A5A0` | 7.54 |
| `ink4` | `#5A5958` | 2.65, never for text |
| `track` | `#39424A` | decorative |

### State

The only chromatic colours in the product. `Fill` is for arcs, bars and dots (3:1 or better
on every light ground). `Ink` is for text and icons (4.5:1 or better on every ground).

| State | Word | Light fill | Light ink | Dark (fill and ink) |
|---|---|---|---|---|
| `thriving` | Ahead | `#2A72DE` | `#2056A6` | `#7FB0F5` |
| `good` | On track | `#5C6F5D` | `#4C5E4D` | `#A3BBA4` |
| `watch` | Worth watching | `#AF751B` | `#86570F` | `#E0B060` |
| `care` | Needs care | `#D22C15` | `#B32410` | `#F58A78` |

- Default rendering is neutral: `ink` arc on `track`. Apply `watch` or `care` when a score is
  off track, `thriving` when a goal is beaten. `good` is for charts and legends where every
  state must be shown; a single on-track score stays neutral.
- State is never colour alone: the state word, or an icon, always accompanies it.
- Destructive actions use `care`.

### Area colours are retired from UI chrome

The area hues `money`, `move`, `rituals`, `nutrition`, `sleep`, `mood` and their tints and
inks are deleted from `lib/theme/`. No area colour tints icons, chips or cards. The only
surviving area hues are `ringMove` and `ringRoutines` in `lib/theme/app_colors.dart`, for the
activity rings on Areas and the home-screen widget. The user-selectable accent is removed: the
accent is `ink`.

On the activity rings:
- Use `ringMove` (light `#34C759`, dark `#30D158`) and `ringRoutines` (light `#AF52DE`, dark
  `#BF5AF2`). Tracks are the same hue at 20% alpha.
- Neighbouring rings must also differ in lightness, at 1.5:1 or more, so they stay apart
  without hue. Dark `ringMove` against `ringRoutines` is 1.74:1. Check this before adding a
  ring: the old sleep hue (`#8491F0`) against `ringRoutines` is only 1.22:1.
- A ring's colour never signals state. State shows as the state word in state ink beside the
  ring's value, only when off track or ahead.

## 4. Typography

Oura's faces are licensed and are not bundled. Substitutes:

- **Sans: SF Pro** (system, already used via `AppFonts.sf`). Functional text.
- **Serif: one bundled open-licence display serif** (see open decisions). Used only for Pal's
  lead line and screen-level emotional headlines, at 28px and above, light weight.
- SF Pro Rounded and bold tabular amounts are dropped. Mono is dropped for eyebrows.

| Role | Face | Size / line | Weight | Tracking |
|---|---|---|---|---|
| `display` (hero number) | sans, tabular | 64 / 68 | 300 | -1.6 |
| `score` (number in a focus view) | sans, tabular | 40 / 44 | 300 | -0.8 |
| `lead` (Pal's line) | serif | 30 / 36 | 300 | -0.6 |
| `title` | sans | 22 / 27 | 500 | -0.4 |
| `headline` | sans | 17 / 22 | 600 | -0.43 |
| `body` | sans | 17 / 24 | 400 | -0.43 |
| `callout` | sans | 16 / 22 | 400 | 0 |
| `subhead` | sans | 15 / 20 | 400 | -0.23 |
| `label` | sans | 13 / 18 | 500 | +0.3 |
| `caption` | sans | 12 / 16 | 400 | +0.3 |

- Large numbers are light, never bold. Emphasis comes from size.
- Uppercase is allowed only on the date line (`SAT 3 OCT · 2:14 PM`, `label` with +1.2).
- Numbers use tabular figures wherever they can change.
- Minimum text size is 12.

## 5. Shape, space, depth

- **Spacing:** the existing 4pt scale (`Spacing`). Screen gutter 16. Section gap 32
  (`xxxl`); inside a section 12 to 16.
- **Radius:** controls are full pills. Cards and sheets 20 (`Radii.xl`). Inset fills 12.
  Nothing uses 14 or 16 for a card any more.
- **Depth:** flat. No shadows on cards. A card is `surface` on `bg` with no border, or a 1px
  `hair` border where the surfaces are too close to read.
- **Blur:** only for bars that float over the scene or scrolling content (tab bar, composer).
  Nothing else is glass.
- **Dividers:** 1px `hair`, inset to the text edge, never full-bleed inside a card.
- **Touch targets:** 44 minimum. Primary buttons 48 tall.

## 6. Imagery

- Today opens on a **time-of-day landscape**: layered hills under a sky that shifts across
  morning, afternoon and evening. This is Opal's equivalent of Oura's landscapes and is drawn,
  not photographed.
- The scene sits behind the top of Today, the Areas tab and each area page (Money, Move,
  Routines, Nutrition, Sleep, Mood) and fades into `bg`. The other tabs (Workout, You) and
  sub-screens (meal detail, the routines builder) do not carry a scene.
- Text on the scene is `ink` only and must hold 4.5:1 against the lightest point behind it.
- No other gradients anywhere in the product.

## 7. Components

**Activity rings** (glance). The lead of the Areas screen.
- Only goals you close get a ring, so a full ring always means done: Move (outer), Routines
  (inner). Budgets (Money) and readings (Nutrition, Mood, Sleep) are vital cards below,
  under "Also tracked".
- Nested, 152px, 16px stroke, radii 68 and 48, round caps, starting at 12 o'clock. Colours per
  section 3.
- A legend beside the rings, one row per ring: swatch, area name in `label` `ink2`, the state
  word only when Worth watching or Needs care (a ring past its goal shows no word; its arc
  says so), then the value in `headline` weight 400 (`310 of 500 kcal`).
  Each row opens that area's page.
- The arc always draws the same fraction the value states.
- Under the rings, one `subhead` line from Pal naming what is off ("Money and sleep are worth
  a look"), or "Everything is on track".

**Rings widget.** The iOS medium home-screen widget is the same glance off the app.
- Move and Routines rings, 104px, 12px stroke, radii 46 and 32.
- Legend rows for Move and Routines, then Money as a row with a dollar mark instead of a swatch,
  reading what is left (`$22 left of $60`), never what is spent.
- State words come from the app's state rules, never recomputed in the widget.
- Before the first fetch, with nothing cached: empty tracks and dashes, never zeros.
- A round `ink` "+" at top right opens the Pal composer; anywhere else opens Today.

**Lead** (the one big thing).
- Pal's line in `lead`, at most three lines, followed by one card holding the next action. A
  longer line is never cut: it drops to `body` in `ink` and shows in full (`PalLeadText`).
- The code picks the lead; Pal words one line about that item and never picks or adds numbers.
  When Pal is offline, or has no line for the item as it stands now, the line is the item's own
  sentence. `Why this first` shows whenever Pal is online and there is a lead.
- The action card: a 40px `surface2` icon disc, the `label` when line in `ink3`, the `title`
  for what, one primary pill and one text button. With nothing left it reads `All done` /
  `That's the day` with a check and no buttons.
- Offline, the order falls back to the clock, and the label says so.
- **Needs care rule.** Anything in Needs care leads Today, ahead of Pal's order, online or
  offline. This is a fixed rule in code, not a model call.

**Vital card** (focus).
- Row 1: icon, area name in `headline`, state word right-aligned in state ink.
- Row 2: number in `score` with its unit in `subhead`.
- Row 3: a range bar: `track`, a `surface2` band for the usual range, a dot for today.
- Tapping the card opens that area's page. Nothing expands in place: it shifts the layout.

**Contributor bar.** Label left, value or state word right, a 4px bar beneath. Bar is `ink`
on `track`; `care` only when that contributor needs attention.

**Timeline.** A 1px `hair` rail with time in `caption` at left, a 28px icon disc on the rail,
title in `callout` on one line, detail under the title in `caption` `ink3`. Done items are
ticked and drop to `ink3`; put-off items drop to `ink3`. A tappable row carries a small `ink3`
chevron at right; an inert row has none and is not a button.

**Toast.** A `surface2` pill with a `hair` border, just above the composer. It names the change
made in place (`Put off until tomorrow: Morning`), offers `Undo` when the change can be undone,
and leaves after 6 seconds. It never names a flow that a tap opened.

**Explore chart.** D / W / M / Y segmented control (pill, `surface2`), one series per chart
unless comparing areas, usual-range band behind the series, a scrubber that reads out the
exact value.

**Buttons.** Primary: `ink` fill, `bg`-coloured text, pill, 48 tall, `headline`. Secondary:
`surface2` fill, `ink` text. Text button: `ink`, `headline`, no fill. One primary per screen.

**Tab bar.** Four tabs: Today, Areas, Workout, You (section 11, decision 2). Floating pill over
content with blur, icon over `caption` label, active tab in
`ink` on a `surface2` pill, inactive in `ink3`. With the glance off Today, the Areas tab
carries an 8px state dot when any area is off track: `care` if any area needs care, else
`watch`. Its accessible label names the areas, e.g. "Areas, money worth watching".

**Composer.** Floating pill above the tab bar, placeholder "Tell Pal anything" in `ink3`, one
round `ink` button at the right.

## 8. Voice

- State words are fixed: Ahead, On track, Worth watching, Needs care. Do not invent others.
- Pal speaks in short declaratives and names the consequence: "You fade after 6. Train first."
- No alarm, no exclamation marks, no praise inflation. A miss is stated, then the next step.
- Numbers always carry their unit and what they are a fraction of.

## 9. Do and don't

Do
- Lead every screen with one thing.
- Render scores neutral and let state colour mark the exceptions.
- Pair every state colour with its word.
- Use light weight for big numbers and the serif for Pal's line only.
- Separate with space first, hairline second, card last.

Don't
- Colour by area. No orange for money, green for move, purple for routines, except on the
  activity rings.
- Add a second accent, a gradient wash, a shadow or a glass card.
- Put a glance on Today. No rings, bars or charts; the glance is on Areas.
- Add a second patterns surface. Every pattern is one of Pal's findings, shown on You.
- Give a budget a ring. A full ring means done, and a spent budget is not.
- Use bold or rounded numerals for amounts.
- Use `ink4` for text, or the serif below 28px or in controls.

## 10. Token delta against `lib/theme/`

Applied in `lib/theme/`. Each row names what was done.

| Area | Before | Done |
|---|---|---|
| Light neutrals | iOS system greys, `bg #F2F2F7`, `ink #000000` | `AppColors.light()` takes the section 3 light table; `track` added; `fill` is `surface2` |
| Dark neutrals | pure black `#000000`, iOS greys | `AppColors.dark()` takes the section 3 dark table; `track` added; `fill` is `surface2` |
| State colours | none; only `red`, `dangerInk` | `thriving`, `good`, `watch`, `care` added with fill and ink; `red` is the `care` fill and `dangerInk` the `care` ink |
| Area colours | six hues with tint and ink, used across chrome | first kept for the screens not yet redesigned; deleted in the legacy token retirement, with `forType` and `inkForType`. `ringMove` and `ringRoutines` remain, carrying the old `move` and `rituals` values for the activity rings |
| Accent | eight user-selectable accents | the choice is removed; `accent`, `accentInk`, `accentTint`, `onAccent` were kept as aliases of `ink`, `ink`, `surface2`, `bg`, then deleted in the legacy token retirement |
| Glass | `glass`, `glassBorder`, `glassHighlight` on cards | first re-valued for floating bars; deleted in the legacy token retirement |
| Shadow | `Elevation.sm/card/fab` | `fab` is on the floating bars, Today and the area pages use none; `sm` and `card` were deleted in the legacy token retirement |
| Type | `AppType` 11 to 34, titles w700, `amount` rounded w700 | `display`, `score`, `lead`, `title`, `label` added per section 4; the legacy roles `caption2`, `footnote`, `title1` to `title3`, `large`, `amount`, `amountLg` and `AppFonts.sfr` were deleted in the legacy token retirement |
| Mono eyebrow | `AppType.eyebrow` | removed; the nav bar eyebrow uses `label`; `AppFonts.mono` was deleted in the legacy token retirement |
| Radius | `Radii.card` 14 as workhorse | `Radii.card` is 20; `Radii.md` and `Radii.lg` were deleted in the legacy token retirement |
| Contrast test | covers area inks on tints | covers state inks (4.5:1) and state fills (3:1) on all three grounds in both themes, and `ink` on every scene palette; the area-ink check went with the inks, replaced by `ringMove` against `ringRoutines` at 1.5:1 lightness in both themes |

## 11. Open decisions

1. **Serif face.** Resolved: Newsreader Light, bundled under the OFL
   (`assets/fonts/Newsreader-Light.ttf`, family `Newsreader`). No network fetch.
2. **Tabs.** Resolved: **Today / Areas / Workout / You**, a middle ground rather than Oura's
   three. Today is the day; Areas is the glance and focus level (Oura's Vitals); You is the
   long view (Oura's My Health) plus Pal and settings; Workout stays because it is a tool used
   mid-session, often unplanned.
   - A feature earns a tab only when it is opened on purpose most days, without Today's plan
     sending you there, and every other path costs more than one tap. Nutrition is the one
     contender: it stays off the bar unless logging through the composer proves slow in use.
   - Where everything else lives:
     - **Today:** the day plan. The routine player, the evening close-out and the mood
       logger open from the action card and from their Your day rows. Today has no Sleep
       row; Sleep and Mood pages open from Areas.
     - **Areas:** a page per area (Money, Move, Routines, Nutrition, Sleep, Mood). Nutrition's
       page lists today's meals, each opening a meal detail, with "Add a meal". Routines'
       page lists today's routines and ends with "Manage routines". Spending detail sits
       under Money.
     - **Workout:** unchanged: start, active session, post-workout, history, weekly plan,
       routine generator, exercise library, streak celebration.
     - **You:** a header line with name and streak; Pal's findings as the lead, then "Also
       seen"; a Pal group (What Pal remembers, Autopilot, each its own screen); then
       settings rows: Goals, Budgets, Reviews (day, week, month), Email sync, Data and
       privacy, Appearance, About and help.
   - **One home for patterns.** Pal's findings are the only patterns surface. Money insights
     and nutrition patterns become findings for their area. "Patterns Pal uses" in What Pal
     remembers lists the same findings; dismissing one removes it from both.
   - Old routes that move (the area pages out of Today, the Nutrition branch) keep redirects,
     as the old tab paths already do, so Siri and Live Activity links resolve.
3. **Default theme.** Resolved: dark is the default when nothing is saved. A saved Light is
   kept.
4. **State thresholds.** Resolved: pace against the waking day, 07:00 to 22:00. `dayShare`
   is the fraction of that window elapsed: 0 at or before 07:00, 1 at or after 22:00, linear
   between. The first rule that matches wins.
   - Money: no budget (0 or less) is On track; spent over budget is Needs care; the share of
     the budget spent 25 points or more ahead of `dayShare` is Worth watching; under a tenth
     of the budget left before the day ends is Worth watching; otherwise On track. Money is
     never Ahead during the day. The same rule reads a budget over any period (envelopes).
   - Move and Routines: no goal (0 or less, or no routines) is On track; goal met is Ahead;
     under half the goal at or after 21:00 is Needs care; the share of the goal done 25
     points or more behind `dayShare` is Worth watching; otherwise On track.
   - An area with no goal set renders in neutral ink.
   - Nutrition, Sleep and Mood have no state rule yet, so they render in neutral ink and are
     never off track. Nutrition has no targets in the app, so its page shows meals and macros
     without a target line until targets become a setting. Sleep has no goal yet
     (decision 6). Mood is a reading, not a goal, and never takes a state colour.
   - The Areas tab's `N of M on track` counts only areas with a state rule (Money, Move,
     Routines today), so it reads `N of 3` until the others gain one.
5. **Achievement mark.** Oura uses a crown at 85+. Opal needs its own mark; a check is the
   placeholder.
6. **Sleep.** Sleep reads each night, with stages, from Apple Health through HealthKit. It
   stays a vital card, not a ring, and has no goal and no state rule yet.

## Sources

- Oura, "A New Look for the Oura App" (2025): https://ouraring.com/blog/new-app-design/
- Oura, "Introducing the New Oura App Design" (2024): https://ouraring.com/blog/new-oura-app-experience/
- Oura Member Care, "How to Use the Oura App": https://support.ouraring.com/hc/en-us/articles/360058599753-How-to-Use-the-Oura-App
- Oura Member Care, "Readiness Score": https://support.ouraring.com/hc/en-us/articles/360025589793-Readiness-Score
- Instrument, "Designing a more intuitive ŌURA app": https://www.instrument.com/work/oura-app
- Shorty Awards entry, "A More Intuitive ŌURA App": https://shortyawards.com/18th/test-2
- Digital Trends, hands-on with the 2024 app: https://www.digitaltrends.com/phones/i-used-the-brand-new-oura-ring-app-here-is-why-you-will-want-it/
- 9to5Google on the 2025 redesign: https://9to5google.com/2025/10/20/oura-app-redesign/
- Site token extractions: https://oh-my-design.kr/design-systems/oura ,
  https://styles.refero.design/style/9decde51-2a8b-4212-bba5-be9457efc62e ,
  https://www.shadcn.io/design/oura
