# Text-led Today Implementation Plan

**Verify:** `flutter test --exclude-tags scenario`
**Setup:** `flutter pub get`
**Check:** `flutter analyze --fatal-infos`
**Final:** `flutter test --tags scenario test/scenario`
**Prototype:** C:\Users\cktra\Projects\opal\.superpowers\design\oura-ai-first-today\project\Main.dc.html

**Goal:** Rebuild Today to the `onToday` branch of the oura-ai-first canvas and DESIGN.md (as of
1b16bd5): text-led, no rings, Pal's lead line, one action card and a short timeline of open items.

**Architecture:** The lead order stays a pure function of the shipped `DayPlan` model: it gains
the rules that pick the lead (Needs care first, then Pal's order online, else the clock). Pal is
"offline" when the `/agenda` fetch fails. `TodayScreen` is rebuilt to the canvas and reads only
that model plus the existing providers. The Money, Move, Routines, Sleep and Mood pages lose
their entry on Today and get a temporary `Areas` group on the You tab until the Areas tab lands.

**Tech Stack:** Flutter, Riverpod 3 (codegen), go_router 16, flutter_test goldens and scenario
tests.

**Design source.** No spec file: the canvas settles the design and the decisions below were
approved in the `Spec review`. The Prototype is a copy of the `Main.dc.html` board of
`C:\Users\cktra\Projects\opal\.superpowers\design\oura-ai-first\project\` in a folder of its own,
so the rings widget board (out of scope) is not part of this run's canvas. Read it from its
absolute path (it is gitignored, not in the worktree): the markup between
`<sc-if value="{{onToday}}">` and its closing tag is Today, and the script's `plan`, `rank`,
`palPick`, `cur`, `laterAll`, `later`, `settle`, `undo` and `leadView` are its behaviour. Its plan
items and sentences are sample data. Inline styles are the measurements. Read `DESIGN.md`
sections 2, 4, 7 and 9 too. The board's other views (Areas, Workout, You, the area focus pages,
the answer sheet), its tab bar and the Areas state dot are out of scope: the final verifier
compares the Today view only.

## Approved decisions (beyond the canvas)

1. **Online/offline.** Pal is offline when the `/agenda` fetch fails. `palAgenda` stops swallowing
   the error into an empty agenda; it rethrows so the provider is `AsyncError`. Callers read
   `.value ?? const PalAgenda()` (You already reads `asData?.value ?? const PalAgenda()`).
   Loading counts as online, so the label does not flicker on a cold start. After an earlier
   success, a failed refresh is `AsyncError` that still carries the last proposals.
2. **Pal's order.** Online: open Pal proposals lead, in the order Pal sends them, then the shipped
   clock order (overdue timed, untimed, upcoming). Offline: the clock order only. Proposals still
   held from an earlier success stay in the plan offline, as untimed items in clock position.
   A cold start offline has no proposals.
3. **Needs care rule** (fixed code, online or offline). Area state comes from the shipped
   `moneyState` / `progressState` over TodayState numbers (Money: `moneySpent` against
   `goals.dailyBudget`; Move: `moveKcal` against `goals.dailyMoveKcal`; Routines: completed
   routines against `routines.length`, 0 of 0 when there are none). An area in `AreaState.care`
   forces a lead: Move forces today's workout, Routines the earliest open routine (by time,
   untimed last), Money the first open proposal tagged money (`colorToken == 'money'`, including
   one held from an earlier success while offline); with no such open item, nothing is forced
   for that area. Several areas at once: Money, then Move, then Routines. A forced lead counts as
   Pal's pick.
4. **Why this first.** A text button after the Pal label, shown only when Pal is online, the lead
   is Pal's pick (not a row the user tapped) and the day is not done. It pushes the Pal composer
   seeded with `Why <title> first?` (the `seed` query parameter of `AppRoute.palComposer`); the
   composer shows that message and Pal's reply. This replaces the canvas's order answer sheet.
5. **Lead line.** Pal's day headline (`todayBriefProvider`) when online and the lead is Pal's pick;
   otherwise the item's own sentence (`said`), else its title. All done: `Nothing is left. Rest up.`
6. **Pal label row.** `Pal`, or `Pal is offline · next on the clock` when offline, with the
   sparkles icon. `PalLabel` gains the text as a parameter (default `Pal`); the area page keeps
   the default.
7. **Header.** The date line (`dateLine`, uppercase `label` with +1.2 tracking) and `Undo` after a
   settle. The `N of M done` progress label goes. No profile button.
8. **Action card** as drawn: `label` when line, `title`, a primary pill (flex) and the skip label
   as a text button (`headline`, `ink2`, no fill). No icon disc. `surface` fill, radius 20, no
   border, 16 padding, 14 gap. All done: `All done` / `That's the day`, no buttons.
9. **Timeline.** Open items except the lead, sorted by time with untimed items first (time column
   `Any`). Two rows shown, then `N more later today` (`subhead`, `ink3`), which expands the rest in
   place. Once expanded it stays expanded for as long as the screen lives, through settles and
   `Undo`, as the canvas's `allLater` does. Tapping a row makes it the lead. A row is time, 28px
   disc with icon, title in `callout` on one line; no trailing detail. Rail as today.
10. **Row notes.** No data marks a change Pal made, so rows carry no note and no note slot is built.
    The item detail (`45 min`) stays in the card's when line only.
11. **Done rows leave Today:** done routines, logged meals, the mood check-in once done, the sleep
    row and Pal-logged receipts with their Undo. Receipts stay deletable by swipe on the Money
    page and by the composer's undo.
12. **Reachability.** Until the Areas tab lands, an `Areas` group on the You tab lists Money, Move,
    Routines, Sleep and Mood, pushing `spendingDetail`, `moveDetail`, `ritualsDetail`,
    `todaySleep`, `todayMood`. Those routes live under `/today`, so they open on the Today branch
    and back returns to Today.
13. **Dead code is deleted**, not left behind: `ShortcutRing` and its test, `areaGlances` and
    `AreaGlance`, `GlanceNumbers` getters nothing reads, `DayPlan.doneRows` / `doneCount` /
    `total` and the receipt and sleep plan items if unused, the screen's `_opener`,
    `_undoReceipt`, `_receiptRow`, `_ringIcon`, `_ringRoute`. Grep every reference first.
14. **Goldens.** Only the affected baselines are regenerated: `profile_dark.png` /
    `profile_light.png` (Task 2, the new Areas group); `today_dark.png` / `today_light.png` and
    `pal_composer_dark.png` / `pal_composer_light.png` (Task 3; the composer golden is pushed
    non-opaque over Today, so Today shows through its scrim). Any other golden diff is a failure
    to fix, not to rebase.

## Global Constraints

- No commit message carries `Co-Authored-By`, `Claude-Session` or any attribution trailer.
- Every number shown comes from local providers; Pal supplies only the headline and proposals.
- Today shows no ring, bar or chart (DESIGN.md section 9).
- The serif (`AppType.lead`) is used for the lead line only.
- Touch targets at least 44; the primary pill 48 tall.
- Magic numbers are named constants at the top of the file, as `today_screen.dart` does now.
- Comments say why, never what, lower case.
- The composer bar stays `Tell Pal anything`; it is not changed by this run.

## Review Focus

1. Agenda refetch fails after an earlier success (`AsyncError` that still carries the old value):
   Today must read offline (label, clock order, no Why), not keep acting as online. Test in Task 1
   (provider) and Task 3 (screen).
2. The forced Needs care item is already done or skipped: the rule falls through to the next care
   area or Pal's order, never leads a settled item. Test in Task 1.
3. Exactly two open items besides the lead: no `more later today` button; three: two rows plus
   `1 more later today`. Test in Task 3.
4. The user taps a row, then skips it: the lead returns to Pal's pick and `Why this first` comes
   back; `Undo` restores the tapped item as the lead without `Why`. Test in Task 3.
5. Large text (text scale 2.0): row titles and the when line stay one line with ellipsis, the lead
   stays at most three lines, nothing overflows. Test in Task 3.

---

### Task 1: Lead rules in the day plan
**Depends on:** none
**Files:** `lib/screens/today/day_plan.dart`, `lib/analysis/area_state.dart`, `lib/controllers/pal_agenda_controller.dart`, `test/screens/day_plan_test.dart`, `test/analysis/area_state_test.dart`, `test/controllers/pal_agenda_controller_test.dart`

Decisions 1, 2 and 3. Keep the existing `DayPlan` methods compiling for the current screen: new
parameters are optional with defaults that reproduce today's clock-only behaviour, so Task 3 can
switch over. Do not delete `areaGlances` or `doneRows` here; Task 3 does that with the screen.

Interfaces this task produces (Task 3 relies on these names):
- `PlanItem` gains `final DetailTracker? area;` (`DetailTracker` from
  `lib/controllers/spending_controller.dart`): proposals map `colorToken` `money` / `move` /
  `rituals` to the tracker (else null), the workout is `move`, routines are `rituals`.
- `class LeadRules { const LeadRules({this.palOnline = true, this.care = const []}); final bool palOnline; final List<DetailTracker> care; }`
  in `day_plan.dart`. `care` is in rule order.
- `List<PlanItem> DayPlan.open(PlanSession session, DateTime now, [LeadRules rules = const LeadRules(palOnline: false)])`:
  forced care leads first (decision 3), then online proposals in agenda order, then the clock order
  (offline, proposals sit in the clock order as untimed items). With the default, the result
  equals today's clock order.
- `PlanItem? DayPlan.palPick(PlanSession session, DateTime now, [LeadRules rules])`: the first of
  `open`, ignoring `session.selected`.
- `PlanItem? DayPlan.current(...)` and `List<PlanItem> DayPlan.later(...)` take the same optional
  `rules`. `later` is sorted by time with untimed items first (decision 9), ties in build order.
- `bool DayPlan.isPalPick(PlanSession session, DateTime now, [LeadRules rules])`: true when there
  is a lead and it equals `palPick` (the user's selection, if any, is the pick itself or absent).
- `List<DetailTracker> careAreas(GlanceNumbers n, DateTime now)` in `area_state.dart`: the areas in
  `AreaState.care`, Money, Move, Routines order, from `moneyState` / `progressState`.
- `palAgenda` rethrows fetch errors (decision 1); its doc comment says why.

Acceptance, each with a focused test:
- `test/screens/day_plan_test.dart`: online proposals lead ahead of an overdue routine; offline the
  same plan leads with the overdue routine and lists the proposals in clock position; Money care
  forces the money proposal over a move proposal Pal sent first; Money care offline forces a held
  money proposal; Move care forces the workout online and offline; Routines care forces the
  earliest open routine; Move and Money both in care lead with the money proposal; a care item
  already settled in the session falls through to the next rule; Money care with no money
  proposal forces nothing; `later` puts untimed first then by minute and excludes the lead;
  `isPalPick` is false after `select` of another item and true again after that item is settled.
- `test/analysis/area_state_test.dart`: `careAreas` returns `[]` when all on track, `[money]` when
  spent is over budget, `[move, rituals]` at 21:30 with under half of both goals, and ignores an
  area with no goal.
- `test/controllers/pal_agenda_controller_test.dart` (new): with a `MockPalService` whose
  `agenda()` throws, the provider is `AsyncError`; after a success then a failing refresh
  (`invalidate`), `hasError` is true and `.value` still holds the earlier proposals.
- Run: `flutter test test/screens/day_plan_test.dart test/analysis/area_state_test.dart test/controllers/pal_agenda_controller_test.dart`

### Task 2: Areas group on the You tab
**Depends on:** none
**Files:** `lib/screens/profile/profile_screen.dart`, `test/profile_test.dart`, `test/golden/goldens/profile_dark.png`, `test/golden/goldens/profile_light.png`

Decision 12. Add one `_Group(label: 'Areas', ...)` directly after the Goals group, reusing
`ListRow` as the neighbouring groups do: Money (`dollarsign.circle.fill`), Move (`figure.run`),
Routines (`sparkles`), Sleep (`moon.stars.fill`), Mood (`heart.fill`), each pushing its route by
name (`AppRoute.spendingDetail`, `moveDetail`, `ritualsDetail`, `todaySleep`, `todayMood`), the
last row `last: true`. Icon tint and colours follow the neighbouring Goals rows. A short comment
says the group stands in until the Areas tab lands.

Acceptance:
- `test/profile_test.dart`: the You tab shows an `Areas` group with the five rows in that order;
  tapping Money opens the Money area page and tapping Sleep opens the Sleep page (assert on a
  widget unique to each page, e.g. `DetailScreen` with `DetailTracker.money`, `SleepScreen`).
- Goldens: `flutter test --update-goldens test/golden/design_system_golden_test.dart --plain-name profile`
  regenerates the two You baselines; `git status test/golden` lists only the two profile PNGs.
- Run: `flutter test test/profile_test.dart`

### Task 3: Rebuild Today to the canvas
**Depends on:** Task 1, Task 2
**Files:** `lib/screens/today/today_screen.dart`, `lib/screens/today/day_plan.dart`, `lib/screens/today/today_logic.dart`, `lib/analysis/area_state.dart`, `lib/widgets/pal_label.dart`, `lib/widgets/shortcut_ring.dart`, `test/widgets/shortcut_ring_test.dart`, `test/today_screen_test.dart`, `test/screens/day_plan_test.dart`, `test/screens/today_logic_test.dart`, `test/analysis/area_state_test.dart`, `test/support/today_fixture.dart`, `test/scenario/today_scenario_test.dart`, `test/scenario/components_scenario_test.dart`, `test/scenario/area_page_scenario_test.dart`, `test/scenario/final_scenario_test.dart`, `test/golden/goldens/today_dark.png`, `test/golden/goldens/today_light.png`, `test/golden/goldens/pal_composer_dark.png`, `test/golden/goldens/pal_composer_light.png`

Decisions 4 to 11, 13 and 14, using Task 1's `LeadRules`, `palPick`, `isPalPick`, `later` and
`careAreas`. Top to bottom: the time-of-day `DayScene` (kept), the header (decision 7), the Pal
label row with `Why this first` (decisions 4 and 6), the lead line (decision 5), the action card
(decision 8), the timeline (decisions 9 and 10). Build `LeadRules(palOnline: !agenda.hasError, care: careAreas(...))`
once per build. The `more later today` expansion is screen state that is never reset while the
screen lives (decision 9). Keep: pull to refresh, the minute tick, resume refresh, `_act` routing
per `PlanKind`, the loading and error states, the a11y `Today` heading, the lead as a live
region, row semantics `<title>, at <time>|any time. Do this next`. Delete dead code per decision
13 (`ShortcutRing` with its test; `areaGlances`, `AreaGlance`; unused `GlanceNumbers` getters;
`doneRows`, `doneCount`, `total`; receipt and sleep plan items and `isDoneByPal` if nothing else
reads them), grepping every reference first, including the scenario files.

`test/support/today_fixture.dart`: `TodayPal.offline` becomes settable after boot, so a test can
load proposals online, go offline and pull to refresh (the stale-value case of decisions 1 to 3).

Scenario steps. The Final line runs these; each writes its PNG to `ARC_FINAL_OUT` through the
existing `scenario_harness.dart` `shot`. Every step below is named by its `scenarioTest`
description.

`test/scenario/today_scenario_test.dart`:
- Rewrite `today morning` / `today afternoon` / `today evening`: keep the phase, date line and
  headline asserts; drop the `ShortcutRing` count and the `Sleep` done-row asserts; assert the
  `Pal` label, the action card title and at most two timeline rows.
- Rewrite `today action card` (shots `today_row_selected`, `today_after_action`,
  `today_after_skip`, `today_after_undo`): drop the `N of 8 done` asserts; after selecting a row
  assert `Why this first` is absent; keep the `Undo` asserts after the action and the skip.
- Keep `today all done`; also assert no `Why this first` and no rail.
- Rewrite `today offline`: label `Pal is offline · next on the clock`, no `Why this first`, the
  card holds the first item in clock order.
- Delete `today money worth watching`, `today over budget`, `today zero goals`,
  `today no routines, default goals` (ring states), `today scrolled to the done rows`,
  `today receipt undo`, `today receipt undo failed`, and `today done rows open their screens`
  (done rows and their openers left Today; Sleep and Mood are opened from You in
  `area_page_scenario_test.dart`).
- Keep `today error`, `today loading`, `today pull to refresh` and the `today action <kind>` loop;
  where a selected row sits behind `N more later today` (the `closeout` case), tap the More
  button first.
- Add `today online proposal leads`: a proposal leads, the lead is the headline, `Why this first`
  shows.
- Add `today why this first`: tap `Why this first`; the composer sheet is open and shows the user
  message `Why <lead title> first?`.
- Add `today money needs care`: `TodayDay(spent: 80)` with a money proposal and a move proposal
  sent first; the money proposal leads.
- Add `today money needs care offline`: as above, then go offline and pull to refresh; the label
  reads offline and the money proposal still leads.
- Add `today more expanded`: five open items, tap `3 more later today`; all four rows show; then
  skip the lead and the timeline stays expanded.
- Add `today undo restores tapped row`: tap a timeline row, skip it, tap `Undo`; the tapped item
  is the lead again and `Why this first` is absent.

`test/scenario/components_scenario_test.dart`: delete `components rings`; keep `components bars`.

`test/scenario/area_page_scenario_test.dart`: `_open` reaches each page by the You tab's
`Areas` row instead of a ring (tap the `You` tab, then the row). `area back` asserts Today is
shown with its date line, without the ring assert. Add `area you group` (the You tab scrolled to
the `Areas` group, five rows), `area sleep from you` and `area mood from you` (tap the row, the
Sleep and Mood screens open).

`test/scenario/final_scenario_test.dart`: `final` keeps its theme, date line, scene, ask bar and
tab bar asserts; replaces the ring asserts with: no `Money: ` / `Move: ` / `Routines: ` ring
semantics on Today, the `Pal` label and the action card present; shot `final_today`; then opens
Money through You's `Areas` row instead of tapping the ring, and keeps the `final_area_money` asserts.

Acceptance:
- `test/today_screen_test.dart` (replace ring and done-row tests): no ring semantics on Today;
  online the label reads `Pal` and the lead is Pal's headline; offline (cold) the label reads
  `Pal is offline · next on the clock`, the lead is the item's sentence and the order is the
  clock; `Why this first` pushes the composer with seed `Why <lead title> first?`; tapping a row
  makes it the lead and hides Why; skip shows `Undo` and Undo restores the item; with five open
  items two rows and `3 more later today` show, tapping it shows all four, and a skip keeps them
  expanded; with three open items no More button; all done shows `All done`, `That's the day`,
  `Nothing is left. Rest up.`, no rail and no Why; Money over budget leads with the money
  proposal online, and still after going offline with a failed refresh (stale proposals); Move
  over its late threshold leads with the workout on a cold offline start; Review Focus items 1,
  4 and 5.
- `test/screens/day_plan_test.dart` and `test/screens/today_logic_test.dart` drop tests of deleted
  members only.
- Goldens: `flutter test --update-goldens test/golden/design_system_golden_test.dart --plain-name today`
  and `flutter test --update-goldens test/golden/design_system_golden_test.dart --plain-name pal_composer`
  regenerate the four baselines; then `flutter test test/golden` passes and `git status test/golden`
  lists only the two Today and two composer PNGs. Look at the PNGs before committing: no rings,
  the layout of decisions 7 to 9.
- Run: `flutter test test/today_screen_test.dart test/screens/day_plan_test.dart test/screens/today_logic_test.dart test/analysis/area_state_test.dart`
  and `flutter test --tags scenario test/scenario/today_scenario_test.dart test/scenario/area_page_scenario_test.dart test/scenario/final_scenario_test.dart test/scenario/components_scenario_test.dart`
