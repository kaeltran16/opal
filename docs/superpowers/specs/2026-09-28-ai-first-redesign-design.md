# AI-first Redesign with Liquid Glass

Date: 2026-09-28
Status: Mockups approved, scope and gap decisions made 2026-09-28 (decisions 5-9), spec awaiting review
Tracker: `effort:579571b0-46fa-4c4f-8c84-43719b4b615c`
Mockups (local, gitignored): `.superpowers/design/ai-first/project/` (Main, TodayGlass,
TodayFallback, TodayScrolled, YouGlass, LogGlass)

## Problem

The app has become Pal-first in what it does (parse, review, insights, agenda, autopilot), but its UI
is still organized like a tracker from before Pal. There are five tabs, and Rituals, Sleep and Mood
each have their own shell branch. Logging goes through a center FAB. Pal's brief sits one level down,
in the Pal hub. The chrome is a flat blurred bar, which looks dated next to iOS 26 Liquid Glass.

## Goal

A full redesign, not a polish:

1. **Pal-first Today.** Today opens on Pal's brief and on what needs the user, followed by
   area cards ordered by Pal.
2. **Liquid Glass chrome over solid content.** Glass is used only for navigation and transient
   layers. Content stays on solid surfaces.
3. **Fewer tabs.** The tabs become Today, Workout, Nutrition and You. An ask bar on every tab
   replaces the FAB.

## Non-goals

- Any backend or Pal contract change. Everything below uses the existing `PalService` methods.
- The native widget extension, the Live Activity UI and Siri UI.
- New features. Every screen keeps its current capabilities. Only the layout, hierarchy and chrome
  change. The one exception is Today's search, which is dropped per decision 6.
- Native SwiftUI glass (`cupertino_native` and similar packages).

## Decisions (locked)

1. **Direction.** AI-first plus Liquid Glass. The visual language is direction A (refined native),
   pushed further in polish.
2. **Information architecture.**
   - The tabs are Today, Workout, Nutrition and You.
   - Routines, Sleep, Mood and Money become area cards on Today that open their existing detail
     screens.
   - The Pal hub moves under You.
   - The ask bar appears on every tab.
3. **Glass implementation.** Glass is drawn in Flutter with `BackdropFilter`, behind a single
   `GlassSurface` widget. This keeps the web build and goldens working and adds no dependencies. The
   rendering can be swapped for native glass later without touching call sites.
4. **At-a-glance numbers.**
   - The numbers sit inside Pal's brief as tappable chips, with no rings or pills.
   - If the brief is unavailable, a row without a card shows what's left for each area.
5. **This run's scope (decided 2026-09-28).** Only the parts the mockups cover ship in this run:
   P0, P1, P2, P3, the Today redesign (P4 "Today + detail"), the You tab and the log sheet. The
   other P4 area chunks (Workout, Nutrition, Rituals, Sleep + Mood, Money + Settings screens,
   Pal/Email/Recap, one-offs) and P5 wait for their own mockups and are not planned here.
6. **Today follows the mockups exactly.** The rings hero, the three summary tiles, the timeline and
   the search button are removed from Today. Entries stay reachable through each area's detail
   screen. Search is not re-homed in this run.
7. **Done by Pal** is sourced client-side from today's entries whose `source` is
   `EntrySource.email` (the Gmail-receipt autopilot). Undo deletes that entry through the existing
   repository delete. There is no backend change.
8. **Ask bar mic.** The mic button is drawn, and tapping it opens the composer exactly as the bar
   does. Dictation is deferred and recorded as a pending chunk on the tracker. No speech dependency
   is added.
9. **Deterministic goldens.** The app reads time through `clock.now()` from `package:clock` (already
   in the lockfile through `flutter_test`, now a direct dependency) instead of `DateTime.now()`.
   Golden tests run under `withClock(Clock.fixed(...))`. Today's goldens already drift by date
   (`today.png` differs by 0.47% on 2026-09-28), so without this the P1 baseline cannot guard P2.

## Information architecture

### Shell

`StatefulShellRoute.indexedStack` drops from 6 branches to 4: `today`, `move`, `nutrition` and `you`.

| Today (5-tab bar)                  | After                                                     |
|------------------------------------|-----------------------------------------------------------|
| Today tab                          | Today tab (Pal brief, needs you, area cards)              |
| Workout tab                        | Workout tab                                               |
| [+] FAB, opens the composer        | Ask bar on every tab, opens the composer as a glass sheet |
| Nutrition tab                      | Nutrition tab                                             |
| More tab                           | You tab (profile, Pal hub, goals, settings)               |
| Rituals, Sleep, Mood branches      | Child routes under `today`                                |

**Deep links must keep working.** Siri, Live Activities and the widget all resolve `AppRoute` paths
through `context.go` (`lib/app.dart`, `lib/services/siri/`).

- Every `AppRoute` path that exists today still resolves after the change.
- When a route moves to a different parent, its old path becomes a `redirect` to the new location. The
  `AppRoute` names stay the same.
- The concrete moves:
  - `/rituals` → `/today/rituals`, `/rituals/manage` → `/today/rituals/manage`, `/sleep` →
    `/today/sleep` and `/mood` → `/today/mood`. Each old path redirects. `/rituals/player/:routineId`
    stays a root-level focus route and is unaffected.
  - `/you` and its sub-routes keep their paths but become the fourth branch's routes instead of a
    route pushed above the shell. The profile's back button goes away, because it is a tab root now.
  - `/pal`, `/pal-home` and `/pal-inbox` redirect to `/you` once the You tab carries the hub content.
    Until then, `/pal` stays as it is, so each phase keeps the app shippable.

### Today

The screen, top to bottom (see TodayGlass and TodayScrolled):

1. **Header.** The date as an eyebrow, then the greeting as the large title.
2. **Pal's brief.**
   - A lead sentence from Pal. This is the existing insights headline, the same seam
     `pal_screen.dart` uses for `_brief` today.
   - Then a number sentence built on the client, with three inline chips: spent against budget, move
     kcal, and routines done against total.
   - The chip values come from the local providers, never from the model: code handles the facts and
     the model handles the tone.
   - Each chip is a button that opens its area's detail screen. Each has an `aria`-style semantic
     label, for example "Spent $38 of $60, open Money".
3. **Fallback.** Shown when there is no headline yet (first load failed, offline or empty):
   - Pal's brief is replaced by a row with no card: three columns with thin separators, showing
     `$ left to spend`, `kcal to go` and `routines left`.
   - Below the row is a quiet line: "Pal's brief is catching up".
   - A brief that loaded earlier is never blanked on a later failure. This matches the current
     `_refreshBrief` behavior.
   - **Refresh** (decided 2026-09-28): Today has no refresh button, per the mockup. The brief and
     the agenda refresh on pull-to-refresh and whenever the app resumes. This replaces the Pal hub's
     refetch-on-open and its "Refresh brief" button, so no capability is lost.
4. **Needs you.** The pending `PalAgenda.proposals`, shown as cards with a primary and a secondary
   action, plus a count badge. The section is hidden when there are none.
5. **Done by Pal.** Today's email-sourced entries (decision 7), each with its source line ("Done by
   Pal · from your Gmail receipt") and Undo. The section is hidden when there are none.
6. **Your day.** The Routines, Sleep, Mood, Money, Move and Nutrition cards, in Pal's order. For v1
   the order is a deterministic client rule: incomplete first, then by time of day. There is no model
   call in the ordering.
   - Taps: Routines → `ritualsDetail`, Sleep → `/today/sleep`, Mood → `/today/mood`, Money →
     `spendingDetail`, Move → `moveDetail`, Nutrition → the Nutrition tab.
   - Area cards show the content in TodayScrolled. An area with no mockup reuses the same card shell
     with its detail screen's headline figure.
7. **Removed** (decision 6): the rings hero, the summary tiles, the timeline and search.

### You

The You tab has the profile card with the streak, then the Pal section (what Pal remembers, autopilot
switches), then Goals, then Settings. The current Pal hub content (`pal_screen.dart`) and the More
content live here. No capability is lost.

- Where the Pal hub's parts go:
  - The brief and Needs you move to Today.
  - Memory, the autopilot toggles and "What Pal noticed" (`PalNoticedSection`) go into You's Pal
    section.
  - The hub's hero stat strip is dropped, and the profile card carries the streak.
- "Settings" means the profile's existing sections (Money, Reviews, Integrations, Data, Account),
  restyled. The "Pal" row under Reviews is removed because Pal is inline now.
- `PalScreen` is deleted. Its agenda widgets move to `lib/screens/pal/pal_agenda_widgets.dart`,
  shared by Today and You.

### Logging

The ask bar opens the Pal composer as a glass sheet (see LogGlass). The flow is:

1. The user types or dictates.
2. Pal replies with draft rows from `parse`.
3. The user confirms with "Log both" or edits a row.

This replaces the FAB. The composer logic itself does not change.

## Visual language

### Tokens (changes to `lib/theme`)

- **`AppColors` additions:**
  - `glass`, `glassBorder` and `glassHighlight` for glass fills and edges, in light and dark.
  - Per-area ink colors for text and icons on tints: `moneyInk`, `moveInk`, `ritualsInk`,
    `nutritionInk`, `sleepInk` and `moodInk`. The existing area colors fail 4.5:1 as text on their
    tints. The ink values fix that.
  - `accentInk`: an explicit value per `AppAccent` in `AppAccentInfo`, 8 accents × light and dark,
    each checked for 4.5:1 on `accentTint`. It is a table, not a computed value, so it is
    deterministic and reviewable.
- **`AppColors` change:** light `ink3` moves from `rgba(60,60,67,.60)` to opaque `#6E6E73`. The
  old value measures 3.3:1 on `#F2F2F7`; the new one reaches 4.5:1 on `bg` and `surface`. Dark
  `ink3` is unchanged.
- **Starting values** come from the mockups:
  - moneyInk `#B45400` / `#FFB340`
  - moveInk `#1E7B34` / `#4CDB73`
  - ritualsInk `#8A2FB8` / `#D08CF7`
  - sleepInk `#3F4FBF` / `#A3ADF5`
  - moodInk `#1B7688` / `#7FD3E6`
  - glass `rgba(255,255,255,.52)` / `rgba(44,44,48,.52)`
  - P0 finalizes these, adds nutritionInk, and verifies contrast.
- **Radii:**
  - Top-level cards move from `Radii.card` (14) to `Radii.xxl` (28).
  - Buttons and chips use `Radii.pill`.
  - `Radii.card` stays for inner elements, so its meaning does not change.
- **Type:**
  - Existing `AppType` ramp.
  - Numbers use `AppFonts.sfr` at weight 800 in the brief chips and the fallback row.
  - Greeting: `large`. Brief lead: a new `brief` style, 21/38 semibold, letterSpacing -0.3 (the tall line fits the
    inline chips).
- **Touch targets:** at least 44 pt everywhere. Primary buttons are 52 tall.

### Glass rules

- Glass is used only on the tab bar, the ask bar, sheets and the collapsed top edge bar. It is never
  used on cards or list content. This keeps contrast predictable and limits `BackdropFilter` to four
  surfaces at most on screen.
- **`GlassSurface` builds:**
  - A blur of about 30, plus a saturation boost through `ImageFilter.compose`.
  - The `glass` fill, a 1 px top highlight and a 0.5 px border.
  - `Elevation`-style shadows.
- **Reduce Transparency:**
  - A small method channel reads `UIAccessibility.isReduceTransparencyEnabled` and listens for
    changes.
  - When it is on, `GlassSurface` renders a solid `surface` with a hairline border and no blur.
  - Web and tests default to off, and the value can be overridden in tests.
- **High contrast:** `MediaQuery.highContrastOf` switches to a stronger border and an opaque fill.

### Tab bar and ask bar

- **`GlassTabBar`** replaces `LoopTabBar`.
  - It is a floating capsule with 4 tabs and the accent color on the selected tab.
  - On scroll-down it minimizes to a 52 pt circle showing the active tab, and the ask bar slides in
    beside it (see TodayScrolled). It restores on scroll-up or tap.
  - It honors Reduce Motion: no animated transition, only a state swap.
- **`PalAskBar`** is a glass capsule with the Pal sparkle, a placeholder and a mic button. Tapping it
  opens the composer sheet. For now the mic opens the composer too (decision 8). Starting dictation
  is deferred.

## Architecture notes

- **New shared widgets** in `lib/widgets`: `GlassSurface`, `GlassTabBar`, `PalAskBar`, `BriefText`
  (lead plus chip sentence) and `WhatsLeftRow`.
  - `LoopTabBar` is deleted once nothing references it.
- **Area cards on Today** reuse the existing detail controllers. Each card watches the same provider
  as its detail screen, so there is one source of truth.
- **Brief state** moves from `_PalScreenState` into a small Riverpod controller, `todayBriefProvider`.
  Today reads it. You shows no brief in the mockup, so `PalScreen`'s local copy simply goes away
  with the screen.
  - The controller keeps the last good headline.
  - It exposes `AsyncValue` so that Today can choose between the brief and the fallback.
- **Ordering the Your day cards** is a pure function over the area states. It is unit tested.

## Rollout

These are the tracker's build phases. Each phase leaves the app shippable.

- **P0: Tokens.**
  - Finalize the ink, glass and accentInk values.
  - Check contrast with a unit test that computes WCAG ratios over every tint/ink pair and every
    accent.
- **P1: Golden safety net.**
  - Goldens for every main screen in light and dark, at 390 wide, taken before any visual change.
  - Today only `design_system_golden_test.dart` exists.
  - The main screens are Today, Workout, Nutrition, Routines, Sleep, Mood, You, the Pal hub, Money
    detail and the composer.
  - The clock migration (decision 9) lands first, so the baselines are stable.
- **P2: Token cleanup.**
  - Migrate the roughly 290 hardcoded values to tokens, with no visual change. The P1 goldens must
    pass unchanged.
  - The count, measured 2026-09-28: 106 raw colours outside `lib/theme`, 35 numeric
    `BorderRadius.circular`, 88 numeric `EdgeInsets`, 71 numeric `SizedBox` and 37 numeric font
    sizes.
  - Replace a value only when it exactly equals a token. Any other value stays, with a
    `// kept literal: <why>` comment, which is the existing convention.
  - Skip the files this run rewrites: `today_screen.dart`, `loop_shell.dart`, `loop_tab_bar.dart`,
    `pal_screen.dart` and `profile_screen.dart`.
  - A guard test fails on any new raw `Color(0x…)` or numeric `BorderRadius.circular(…)` outside
    `lib/theme` that has no `kept literal` comment.
- **P3: Foundations.**
  - `GlassSurface`, the Reduce Transparency bridge, `GlassTabBar`, `PalAskBar`, the composer as a
    glass sheet, `todayBriefProvider`, and the 4-branch shell with redirects.
  - Measure raster time on a device with the tab bar and a sheet open. If a frame exceeds budget,
    lower the blur sigma before doing anything more elaborate.
  - The measurement needs a physical iPhone, so it is a manual step after this run and is recorded
    on the tracker. The blur sigma is a single constant in `GlassSurface`.
- **P4: Redesign, one chunk per area.**
  - Order: Today + detail, Workout, Nutrition, Rituals, Sleep + Mood, Money + You/Settings,
    Pal/Email/Recap, one-offs.
  - Each chunk regenerates the goldens it intentionally changes. Each diff is reviewed.
- **P5: Final QA.**
  - Web build, driven with agent-browser: light and dark, phone width, Reduce Transparency on and
    off, Dynamic Type at its largest.

## Testing

- **Unit tests:**
  - Contrast ratios for every token pair.
  - Your day ordering.
  - Building the chip sentence from provider values, including zero budget and zero routines.
  - The rule that chooses between the brief and the fallback.
- **Widget tests:**
  - Tab bar minimize and restore.
  - Ask bar opens the composer.
  - Chip taps route to the right detail screen.
  - Semantic labels on chips, tabs and icon-only buttons.
  - `GlassSurface` renders solid when Reduce Transparency is on.
- **Router tests:** every `AppRoute` path from before the change still resolves (redirects included).
- **Goldens:** P1 baseline, updated deliberately in P4.

## Risks

- **`BackdropFilter` cost on older devices.** Glass is capped at four surfaces, and P3 measures before
  building on top of it.
- **Deep-link regressions.** The router test in P3 covers every existing path.
- **The brief going stale while the chips stay live.** The lead sentence never states numbers. Only
  the chips carry numbers, and they always come from providers.

## Cleanup

Delete `.superpowers/design/ai-first/` in the session that ships P5. This spec and the plan fold into
the feature commits they describe.
