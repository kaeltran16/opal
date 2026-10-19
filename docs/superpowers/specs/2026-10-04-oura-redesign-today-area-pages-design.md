# Oura-style redesign: Today and the area pages (design)

Date: 2026-10-04

The visual design is the prototype
`C:\Users\cktra\Projects\opal\.superpowers\design\ai-first-home\project\Today.dc.html`
and the rules are `DESIGN.md`. This document records only what those two do not settle:
what this run builds from the board, what it defers, and the decisions made beyond it.

## Purpose

Opal is a single-user personal app. Today should lead with one thing (Pal's line and the
next action), show the three areas as quiet rings whose colour means state, and send the
user one tap deeper to a page per area. Success: Today and the Money, Move and Routines
pages match the prototype in both themes, read real data, and the existing suite stays
green.

## In scope

1. `lib/theme` migrated to DESIGN.md sections 3, 4, 5 and 10.
2. Today rebuilt to the board's Today view.
3. The area page for Money, Move and Routines, behind the existing three routes.
4. The floating composer and tab bar restyled, keeping the current four tabs.

## Deferred to a follow-up run

The board was extended after this run was scoped. These parts of it are deliberately not
built here, and reviewers should not hold this run to them:

- The **Areas tab**: the six-card grid, the usual-by-this-hour band and dot, the
  `N of 6 on track` label and Pal's areas sentence.
- The **Nutrition, Sleep and Mood area pages**. Only Money, Move and Routines get the area
  page. Sleep, Mood and Nutrition keep their current screens, reached from Today's
  timeline.
- The **three-tab bar** (Today / Areas / Trends). The tab structure is unchanged: Today,
  Workout, Nutrition, You. Only the bar's styling follows the board.
- The **profile button** in the Today and Areas headers. The You tab still exists, so the
  header has no profile button.
- The area page's back label `Areas`. With no Areas tab the label is always `Today`.
- The board's tap-the-date-to-preview-the-next-phase affordance. The phase follows the clock.

## Decisions beyond the board

**State rule (DESIGN.md open decision 4).** Pace against the waking day, 07:00 to 22:00.
`dayShare` is the fraction of that window elapsed.
- Money: over budget is Needs care; budget share spent 25 points or more ahead of
  `dayShare` is Worth watching; otherwise On track. Money is never Ahead during the day.
- Move and Routines: goal met is Ahead; under half the goal at or after 21:00 is Needs
  care; 25 points or more behind `dayShare` is Worth watching; otherwise On track.
- No goal set (budget 0, move goal 0, no routines) is On track in neutral ink.

**Default theme (open decision 3).** Dark when nothing is saved. A saved Light is kept.

**Serif (open decision 1).** Newsreader Light, bundled under the OFL. No network fetch.

**Light theme.** The board is dark only. Light uses the DESIGN.md section 3 light table
for every surface, ink and state colour, laid out identically. The three scene palettes
get light variants: the same morning, afternoon and evening moods in pale warm tones that
fade into `bg #F7F1E8`, with `ink #1E2427` holding 4.5:1 against every sky stop and hill
fill. That contrast is enforced by test.

**Accent.** The accent picker and `AppAccent` are removed. The accent tokens remain as
aliases (`accent = ink`, `accentInk = ink`, `accentTint = surface2`, `onAccent = bg`) so
untouched screens compile unchanged and turn graphite and cream.

**Kept for untouched screens.** Area colours with their tints and inks, glass and shadow
tokens, and the legacy type roles. Today and the area pages use none of them except glass
on the two floating bars. `Radii.card` becomes 20 everywhere.

**Today's content.**
- Pal's lead is the existing day headline; with none, the current item's own sentence.
  The inline number chips and the what's-left row are removed.
- The action card and timeline come from one local day plan: pending Pal proposals,
  ritual routines at their time, today's planned workout, the mood check-in, a meal, and
  the evening close-out. The primary pill opens the real flow, the secondary pill skips
  the item for this session, and Undo sits in the header beside `N of M done`.
- The timeline also lists done and informational rows in quiet ink: last night's sleep,
  the mood check-in, logged meals, and receipts Pal logged with their Undo. These replace
  the Sleep, Mood and Nutrition cards and the Done by Pal list, and keep Sleep and Mood
  reachable.

**Area page content.**
- Header: back to Today at the left, the date line at the right, as drawn. The `+` button
  leaves this page; logging goes through the floating composer.
- Hero number, unit and state word; Pal's line; contributor bars; this week's bars against
  the goal line; then the existing recent-entries list, restyled flat.
- Pal's line is composed locally from the same numbers, with no backend call.
- Contributors: Money is spent of budget plus the top categories; Move is burned of goal
  plus today's planned workout; Routines is each routine's steps done.
- This week is Monday to Sunday daily totals from logged entries; a past day that missed
  is drawn in the Worth watching colour; today is never marked.
- The board's weekly numbers and Pal sentences are sample data.

**States the board does not draw.** Each uses the board's type and neutral inks, no card
and no colour:
- Loading: `…` in `body`, `ink3`, centred.
- Error: one centred sentence in `subhead`, `ink3` (`Couldn't load today. Try again in a
  moment.` on Today; the area page keeps its current copy).
- Empty day on Today (nothing planned): the mood check-in is the day's one item
  (`0 of 1 done`); the meal nudge rides along a planned day only. Once checked in (or put
  off), the board's all-done card (`All done` / `That's the day`, no buttons) and lead
  `Nothing is left. Rest up.` (User's call, 10-19.)
- No entries on an area page: `Nothing logged yet.` in `subhead`, `ink3`, in place of the
  list.
- No goal set: plain amounts, On track, no goal line and no goal caption.

## Verification

- The contrast test covers the four state inks and fills on `bg`, `surface` and `surface2`
  in both themes.
- A screenshot scenario renders every view, state and interaction named in the plan, in
  light and dark, with real fonts.
- Local goldens are regenerated.

## Entitlements

Nothing here needs a paid Apple entitlement.
