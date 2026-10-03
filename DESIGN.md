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
   next action. Nothing else on the screen competes with it in size, weight or colour.
2. **Colour means state.** A hue on screen answers "how is this going", never "which area is
   this". Areas are told apart by icon and label.
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

`money`, `move`, `rituals`, `nutrition`, `sleep`, `mood` and their tints and inks no longer
colour rings, icons, chips or cards. They survive only as series colours in explore-level
charts that plot several areas together. The user-selectable accent is removed: the accent is
`ink`.

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
- The scene sits behind the top third of Today and fades into `bg`. Other tabs do not carry a
  scene; a detail view may reuse it behind its hero number.
- Text on the scene is `ink` only and must hold 4.5:1 against the lightest point behind it.
- No other gradients anywhere in the product.

## 7. Components

**Shortcut circle** (glance). The row at the top of Today.
- 56px circle, 3px arc, `ink` on `track`, area icon (20px, 1.6 stroke) in the centre.
- Under it: the number in `headline`, then the state word or unit in `caption`.
- The arc always draws the same fraction the number states.
- Neutral by default; arc and state word switch to `watch` or `care` when off track. A goal
  met shows a small filled check at the arc's end, in `thriving`.
- Equal columns across the width. More than four: the row scrolls sideways. Each opens its
  focus view.

**Lead** (the one big thing).
- Pal's line in `lead`, at most three lines, followed by one card holding the next action.
- The action card: icon, `label` line for when, `title` for what, one primary pill and at most
  one secondary pill.

**Vital card** (focus).
- Row 1: icon, area name in `headline`, state word right-aligned in state ink.
- Row 2: number in `score` with its unit in `subhead`.
- Row 3: a range bar: `track`, a `surface2` band for the usual range, a dot for today.
- Tapping the card opens that area's page. Nothing expands in place: it shifts the layout.

**Contributor bar.** Label left, value or state word right, a 4px bar beneath. Bar is `ink`
on `track`; `care` only when that contributor needs attention.

**Timeline.** A 1px `hair` rail with time in `caption` at left, a 28px icon disc on the rail,
title in `callout`, detail right-aligned in `subhead` `ink3`. Done items drop to `ink3`.

**Explore chart.** D / W / M / Y segmented control (pill, `surface2`), one series per chart
unless comparing areas, usual-range band behind the series, a scrubber that reads out the
exact value.

**Buttons.** Primary: `ink` fill, `bg`-coloured text, pill, 48 tall, `headline`. Secondary:
`surface2` fill, `ink` text. Text button: `ink`, `headline`, no fill. One primary per screen.

**Tab bar.** Floating pill over content with blur, icon over `caption` label, active tab in
`ink` on a `surface2` pill, inactive in `ink3`.

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
- Colour by area. No orange for money, green for move, purple for routines.
- Add a second accent, a gradient wash, a shadow or a glass card.
- Put a chart on Today beyond a ring or a bar.
- Use bold or rounded numerals for amounts.
- Use `ink4` for text, or the serif below 28px or in controls.

## 10. Token delta against `lib/theme/`

Not yet applied. Each row is a follow-up change to the token source.

| Area | Today in code | Target |
|---|---|---|
| Light neutrals | iOS system greys, `bg #F2F2F7`, `ink #000000` | cream and graphite, section 3 |
| Dark neutrals | pure black `#000000`, iOS greys | graphite `#101418`, cream ink |
| State colours | none; only `red`, `dangerInk` | `thriving`, `good`, `watch`, `care` with fill and ink |
| Area colours | six hues with tint and ink, used across chrome | chart series only |
| Accent | eight user-selectable accents | removed; accent is `ink` |
| Glass | `glass`, `glassBorder`, `glassHighlight` on cards | floating bars only |
| Shadow | `Elevation.sm/card/fab` | unused on cards; keep `fab` for floating bars |
| Type | `AppType` 11 to 34, titles w700, `amount` rounded w700 | section 4 ramp; light display numerals; serif `lead` |
| Mono eyebrow | `AppType.eyebrow` | removed |
| Radius | `Radii.card` 14 as workhorse | 20 for cards, pill for controls |
| Contrast test | covers area inks on tints | must cover state inks on all three grounds |

## 11. Open decisions

1. **Serif face.** Candidates with open licences: Newsreader (variable, has a light display
   cut), Instrument Serif (regular and italic only), Fraunces. Recommendation: Newsreader
   Light. Or skip the serif and set `lead` in SF Pro Light.
2. **Tabs.** Oura's Today / Vitals / My Health against Opal's current Today / Workout /
   Nutrition / You. Adopting Oura's structure is an information-architecture change, not a
   restyle, and is not decided here.
3. **Default theme.** Oura's app is dark-first; Opal's current prototype is light. Both
   palettes are specified; which one ships as default is open.
4. **State thresholds.** Oura's 85 / 70 / 60 cut-offs apply to 0 to 100 scores. Opal's areas
   are goals and budgets, so each needs its own rule for when it turns `watch` or `care`.
5. **Achievement mark.** Oura uses a crown at 85+. Opal needs its own mark; a check is the
   placeholder.

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
