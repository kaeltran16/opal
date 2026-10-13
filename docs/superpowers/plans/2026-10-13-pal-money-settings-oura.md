# Pal, Money, Recap, Email and Settings in the Oura Language (Run B) Implementation Plan

**Effort:** effort:c4342184-d6c7-424a-be76-048d8a167e17
**Verify:** `flutter test --exclude-tags "golden || scenario"`
**Setup:** `flutter pub get`
**Check:** `flutter analyze --fatal-infos`
**Final:** `flutter test --tags scenario test/scenario/pal_money_settings_scenario_test.dart test/scenario/you_scenario_test.dart test/scenario/shell_scenario_test.dart test/scenario/today_scenario_test.dart test/scenario/area_page_scenario_test.dart test/scenario/theme_scenario_test.dart`
**Prototype:** C:\Users\cktra\Projects\opal\.superpowers\design\oura-ai-first-run-b\project\Main.dc.html

**Goal:** Move the Pal composer and the Why thread, Nutrition's meal detail and Add a meal sheet,
Money (Budgets, Budgets & goals, New entry sheet and keypad), Recap, Email sync and the
remaining settings screens to the Oura design language, keeping every current behaviour.

**Architecture:** A restyle on the converted pieces already in the repo. These are `SubScreen`
(`lib/screens/you/sub_screen.dart`), `PalLabel`, `ContributorBar`, `state_colors.dart` with
`AreaState`, and the `AppType` display/score/title/label roles. Three small shared changes come
first:
- `GlassSurface` sheds its legacy tokens.
- `SubScreen` gains an optional back label.
- A month-capable `budgetState` rule joins `area_state.dart`.

After that, six screen families convert in parallel. A last task deletes `PalAvatar` and the
now-unused `EmailNavBar`, then writes this run's scenario file.

**Tech Stack:** Flutter, Riverpod 3 (codegen via build_runner), go_router, flutter_test scenario
tests and goldens.

**Design source.** There is no spec file: the canvas settles the design, and the decisions below
were approved in the `Spec review`, including a second review after the plan review (decision
22). The Prototype is a copy of the oura-ai-first `Main.dc.html` in a folder of its own, so the
rings widget board (another run's) is not part of this run. Its board title scopes it to the Ask
Pal sheet and the meal detail. Today, Areas, the area pages and You are other runs' to verify.
The canvas is gitignored, so read it by absolute path:
- The `sheet` block (from `<sc-if value="{{sheet.open}}">`) and the script's `sheetView` are the
  Ask Pal composer.
- `C:\Users\cktra\Projects\opal\.superpowers\design\oura-ai-first-workout\project\Main.dc.html`
  shows the composer opened from Workout (its `ask` object) and is the reference for how an old
  screen converts. Its renderVals() is the behaviour and its inline styles are the measurements.
- The `sub.isMeal` block and the script's `mealView` are the meal detail.
- The `onYou` / `sub.open` header is the pattern `SubScreen` already implements.

Map inline styles onto the existing tokens (`Spacing`, `Radii`, `AppType`, `context.colors`).
Sentences and numbers on the canvas are sample data. Read `DESIGN.md` sections 2 to 9. Screens
Today, Areas, the area pages, You, What Pal remembers and Autopilot are already converted: match
them.

## Approved decisions (beyond the canvas)

1. **Chrome.** Every screen pushed from You uses `SubScreen`: back link, `label` eyebrow in
   ink3, `AppType.title` title. That covers Budgets, Budgets & goals, Recap, Email intro,
   dashboard and setup, Notifications, Data and privacy, About, Appearance and Export. The meal
   detail uses it too. `SubScreen` gains `backLabel` (default `'You'`), so existing callers do
   not change.
2. **Save.** Save on Budgets & goals and on Gmail setup becomes that screen's one primary pill,
   at the end of the form.
3. **Rows.** These screens stop passing area colours (`iconBg`/`iconColor` of `c.money`,
   `c.nutrition` and the rest) to `ListRow`. Run A owns how `ListRow` draws its icon.
4. **GlassSurface** stays only on the floating bars: tab bar, ask bar and the collapsed nav edge.
   - It drops `c.glass`, `glassBorder`, `glassHighlight` and `Elevation.card`.
   - The fill is `surface` at a named 0.78 alpha, with a `hair` border and no highlight strip.
   - The solid fallback has no card shadow. `Elevation.fab` stays (DESIGN.md 10).
   - Public constructor and `blurSigma` are unchanged.
5. **Composer sheet.**
   - Solid `surface`, top radius `Radii.xl` (20), no glass, no shadow.
   - The header is `PalLabel()` plus a 44 close button with semantics label `Close`.
   - The status line and green dot go.
6. **Context chip.**
   - `PalComposerSheet` takes an optional `from` (a location path), carried as the `from`
     query parameter of `/pal-composer`.
   - The shell's ask bar passes the current location.
   - A fixed table maps a path prefix to icon and label: `/today` Today, `/areas` Areas,
     `/areas/<area>` that `Area`'s title and glyph, `/move` Workout, `/you` You.
   - An unknown or missing `from` shows the canvas's fallback chip: sparkles and `Pal`.
   - The chip is display only: what is sent to Pal is unchanged.
7. **Idle composer.**
   - A `You could ask` `label` in ink3, then pills (`surface2`, ink text, min height 44).
   - The first pill is `Start <Pal's pick title>` from `palPickControllerProvider`. While the
     pick loads or fails it reads `Start a workout`. It pops the sheet and opens Start workout,
     as the Workout tab's pick does.
   - Then come the Pal starters (or the static fallback) as plain pills, with no coloured icons.
     Skeleton pills show while the suggestions load.
8. **Conversation.**
   - Multi-turn stays: the user's turn is a `headline` line and Pal's reply is `body` in ink.
   - No bubbles and no avatars. A `…` in ink3 shows while Pal is thinking.
   - `PalMessage` gains `final bool offline` (default false, carried by `copyWith`). The
     composer controller sets it on every offline reply (`_offlineConfirmation` and the generic
     offline message), and the composer renders those replies in ink3.
9. **Turns that act.**
   - A log turn shows `Based on`, then the affected tracker as a `ContributorBar` (`off` when a
     spend passes the budget), then an acted line with Undo and Edit text buttons.
   - A meal turn shows its kcal range line, then the same Undo and Edit.
   - A goal or routine turn shows its acted line and Undo.
   - Once a turn is undone, its line reads `Undone` in ink3.
10. **Input row.** A `surface2` pill 52 tall, placeholder `Tell Pal anything` (idle) or
    `Ask a follow-up` (in conversation), and a round 44 `ink` send button with semantics label
    `Send`. The offline hand-off to New entry (`/entry/new?kind=expense&notice=pal-offline`)
    stays.
11. **Pal avatar.** `PalAvatar` is deleted once the composer and Recap use `PalLabel`.
    `today_screen.dart` needs no edit: Today already draws `PalLabel`, and the Why thread is the
    composer opened with a seed.
12. **Budgets.**
    - The hero is what is left this month, in `AppType.display`. The month's state word sits
      beside it in state ink, only when off track.
    - Each envelope is a hairline row: ink2 line icon, name, `$X left` (or `$X over`), the state
      word only when off, and a 4px bar (`arcFor(state)` on `track`).
    - Suggested caps and advisories lose their tinted cards. No coloured tiles anywhere.
13. **Budget state.** Add `budgetState({spent, budget, elapsed})` to
    `lib/analysis/area_state.dart`:
    - no budget means On track;
    - over budget means Needs care;
    - a spent share at or above `elapsed + 0.25` means Worth watching;
    - otherwise On track.

    `moneyState` delegates to it with `dayShare(now)`. Envelopes and the month hero pass
    `BudgetsData.monthPaceFraction`. `spend_ring.dart` is deleted.
14. **New entry.**
    - The segmented control is Run A's.
    - The amount is `AppType.display`, light and tabular, in the user's currency.
    - Keypad keys are neutral: ink text and `surface2` press, at least 44. Quick-picks are neutral
      pills.
    - Log with Pal is a `surface2` input row.
    - Add is the one primary pill.
    - No orange chip and no bold `$0.00`.
15. **Meal detail** (`sub.isMeal`):
    - `SubScreen` with back `Nutrition`, eyebrow `slot · time` and the meal name as title.
    - The kcal mid in `display`, then `kcal, likely lo–hi` in `subhead` ink2.
    - A sparkles line in `label` ink2: Pal's source, with the confidence as a word.
    - A `Macros` heading over three rows (grams, with a 4px bar for that macro's share of the
      meal's split), since the app has no nutrition targets.
    - The meal's `note`, when present, as an ink2 `subhead` line under the macros (the canvas's
      note line). It is no longer the nav subtitle.
    - Tags as one ink3 `subhead` line.
    - One hairline `Where this came from` row. The linked expense amount uses the user's
      currency, replacing a hardcoded `$`.
    - `Adjust estimate` is a secondary pill that opens the edit sheet, as today.
    - Delete is a `care` text button.
16. **Add a meal.**
    - Slot pills: the selected one is ink on `surface2`, the others ink3 with no fill.
    - Estimate is a secondary pill.
    - The estimate shows on the sheet ground in `score` with macro rows, not in a teal panel.
    - `nutrition_widgets.dart` keeps every constructor parameter that
      `nutrition_confirm_sheet.dart` passes, so that untouched file still compiles. Do not edit
      `nutrition_confirm_sheet.dart`.
17. **Recap.**
    - Day / Week / Month segmented control (Run A's).
    - Stats are three light `score` numbers with `label` captions, with no tiles and no card.
    - Wins are hairline rows with ink2 line icons.
    - `One thing to try` is a `PalLabel` section: body text, then an `Ask Pal more` secondary
      pill.
    - The loading and empty notices are plain ink3 text.
18. **Recap patterns.**
    - The Connections (`PAL NOTICED` card) and Patterns sections go. One hairline row, `Patterns
      are on You`, opens `/you`.
    - `correlation_card.dart`, `correlation_view.dart` and their tests are deleted.
    - `Correlation.summary` becomes `summary(Currency currency)`, and `lib/controllers/providers.dart`
      passes the user's currency (as commit 7948908 did for findings).
19. **Email.**
    - Intro: no gradient tile, an ink2 line icon and title, steps as hairline rows, and Connect
      as the primary pill.
    - Dashboard: connection status is plain ink2 text; a failure is `care` ink with words, never
      colour alone. Sync now is a secondary pill and Disconnect a `care` text button.
    - Setup: hairline form rows. The how-to card becomes a plain section. Test connection is a
      secondary pill and Save the primary pill.
20. **Settings leftovers.**
    - Hairline rows and no tiles.
    - About shows the app name as `title`.
    - Export's action is the primary pill.
    - Appearance keeps its `Light` / `Dark` texts, which `theme_scenario_test.dart` finds.
21. **Scenarios.** One new file, `test/scenario/pal_money_settings_scenario_test.dart`, covers
    every view and state, in both themes through `scenarioTest`. The email dashboard overrides
    its provider with a connected account. Goldens are regenerated only for screens this run
    changed (`pal_composer_*`, `new_entry_*`).
22. **Approved deviations from the canvas** (second Spec review):
    - The idle placeholder is `Tell Pal anything` (DESIGN.md 7 and the Workout canvas), not the
      Main canvas's `Ask Pal anything`.
    - No follow-up pills: `PalChatResult` carries only a reply and actions, so pills need
      backend work (a follow-up).
    - No confirm-first action pill: Pal's actions stay auto-applied, shown as an acted line
      with Undo.
    - The meal detail's heading is `Macros`, not `Of today's targets`, because the app has no
      nutrition targets (DESIGN.md 11.4).
    - The meal detail keeps `Adjust estimate` (opens the edit sheet) in place of `Fix with Pal`.
    - Add a meal stays a sheet: manual entry, Estimate and edit mode. The canvas's composer
      route starts from the area page, which is outside this run.
    - Budgets, New entry, Recap, Email and the settings screens are not on the canvas.
      Decisions 12 to 20, plus the Workout canvas's conversion pattern, are their only source.
      No new boards are drawn.

## Global Constraints

- Legacy pattern: every file a task lists must end with zero matches for
  `AppType\.(caption2|footnote|title1|title2|title3|large|amountLg|amount)\b|\bc(olors)?\.(money|move|rituals|nutrition|sleep|mood)(Tint|Ink)?\b|Elevation\.(sm|card)\b|\.glass(Border|Highlight)?\b|\.accent(Ink|Tint)?\b|onAccent|\bsfr\(|AppText\.mono|Radii\.(md|lg)\b`.
  Check with `grep -nE '<pattern>' <files>`. Exception: `nutrition_confirm_sheet.dart`, which
  stays untouched.
- No area colour outside the activity rings (`c.forType(...)` included). No gradients, glass
  cards or shadows. Blur only on floating bars.
- Big numbers are light and tabular (`AppType.display` / `score`). Titles are `AppType.title`.
  One lead and one primary pill per screen. Every state colour sits beside its state word.
- Touch targets are 44 or larger. Every tappable control has a semantics label.
- No magic numbers: name measurements as file-level consts. Comments are lower case and only say
  why. No emojis. No new dependencies.
- Restyle, never drop behaviour. Every tap target that worked before still does the same thing.
- Shared widgets keep their public constructors source-compatible where they can.
- Riverpod codegen: if a provider changes, run
  `dart run build_runner build --delete-conflicting-outputs` and commit the `.g.dart`.
- Commit subjects use `type(scope): summary`, with no attribution or co-author trailer.
- Do not edit `test/scenario/final_scenario_test.dart` or `nutrition_confirm_sheet.dart`.

## Review Focus

1. **Non-USD currency.** A user on VND (the only non-USD `Currency`) sees their symbol on the Budgets hero and rows,
   the New entry amount, the meal's linked expense, Recap's spent stat and `Correlation.summary`.
   Tested in Tasks 3, 4 and 5.
2. **Budget edge cases.** A zero-cap envelope reads On track in neutral ink with no division
   error. An overspent envelope reads `$X over` with `Needs care`. Tested in Tasks 1 and 4.
3. **Pal's pick unavailable.** While the pick loads or fails, the first pill reads
   `Start a workout` and still opens Start workout. Tested in Task 2.
4. **Unknown composer origin.** A missing, unknown or empty `from` shows the fallback `Pal`
   chip, and a nested area path maps to its area. It never throws. Tested in Task 2.
5. **Large text.** At text scale 1.5, pills, rows and the budget envelope rows wrap instead of
   overflowing. Tested in Tasks 2 and 4 with `MediaQuery(textScaler: TextScaler.linear(1.5))`
   and no overflow error.

---

### Task 1: Shared foundations: GlassSurface, SubScreen back label, budgetState
**Depends on:** none
**Model:** claude-sonnet-5-5
**Files:** `lib/widgets/glass_surface.dart`, `lib/screens/you/sub_screen.dart`, `lib/analysis/area_state.dart`, `test/widgets/glass_surface_test.dart`, `test/screens/you/sub_screen_test.dart`, `test/analysis/area_state_test.dart`

Decisions 1, 4 and 13.

**GlassSurface:**
- Fill becomes `c.surface.withValues(alpha: _fillAlpha)` with `_fillAlpha = 0.78`, and the
  border is `c.hair`.
- Remove the highlight strip, its `Stack` and `_highlightHeight`.
- The solid fallbacks (high contrast, reduce transparency) keep their borders and drop
  `Elevation.card`.
- Keep the blur, saturation, `Elevation.fab` and the constructor exactly. Update the doc comment:
  only floating bars.

**SubScreen:** add `this.backLabel = 'You'`. `_BackHeader` shows it and its semantics label
reads `Back to <backLabel>`. Existing callers are unchanged.

**budgetState:**
- Add `AreaState budgetState({required double spent, required double budget, required double elapsed})`,
  with the rule in decision 13, reusing `_paceSlack`.
- Rewrite `moneyState` as `budgetState(spent: spent, budget: budget, elapsed: dayShare(now))`.
  The existing `moneyState` tests must pass unchanged.

**Acceptance (focused tests):**
- `flutter test test/widgets/glass_surface_test.dart`
  - The fill colour equals `surface` at 0.78 alpha.
  - No descendant `DecoratedBox` carries `Elevation.card` shadows in reduce-transparency mode.
  - `blurSigma` is still 30.
- `flutter test test/screens/you/sub_screen_test.dart` (new)
  - With no `backLabel`, it shows `You` with semantics `Back to You`.
  - With `backLabel: 'Nutrition'`, it shows `Nutrition`.
  - Tapping it pops.
- `flutter test test/analysis/area_state_test.dart`. New `budgetState` cases:
  - budget 0 gives good;
  - spent 101 of 100 gives care;
  - spent 60 of 100 at elapsed 0.3 gives watch;
  - spent 54 of 100 at elapsed 0.3 gives good;
  - the existing `moneyState` cases are unchanged.
- The legacy pattern has zero matches in the three lib files.

No rendered view changes here beyond the floating bars' fill. The ask bar and tab bar are shown
in the Final run by Task 8's `shell_composer` step and by `you_scenario_test.dart`.

### Task 2: Pal composer sheet and the Why thread
**Depends on:** none
**Model:** claude-opus-5-5
**Chunk:** Pal composer sheet and the Why thread
**Files:** `lib/screens/pal/pal_composer_screen.dart`, `lib/screens/pal/pal_composer_turns.dart`, `lib/router.dart`, `lib/screens/shell/loop_shell.dart`, `lib/services/pal/pal_service.dart`, `lib/controllers/pal_composer_controller.dart`, `test/controllers/pal_composer_controller_test.dart`, `test/screens/pal/pal_composer_starters_test.dart`, `test/screens/pal/pal_meal_card_test.dart`, `test/screens/pal/pal_composer_sheet_test.dart`, `test/screens/shell_test.dart`, `test/golden/goldens/pal_composer_dark.png`, `test/golden/goldens/pal_composer_light.png`

Decisions 5 to 11.

The composer file is 1351 lines. Move the turn widgets into `pal_composer_turns.dart`: the
user/Pal turn, the log, meal and action turns, and the thinking indicator. The sheet, header,
idle body and input stay in `pal_composer_screen.dart`.

**Composer API:**
- `PalComposerSheet({Key? key, String? seed, String? from})`.
- `lib/router.dart` reads `state.uri.queryParameters['from']` beside `seed`.
- `LoopShell._openComposer` pushes `palComposer` with
  `queryParameters: {'from': GoRouterState.of(context).uri.path}`. Keep the other callers as
  they are; they show the fallback `Pal` chip.
- Map the chip in a private pure function `_chipFor(String? from)` returning a record
  `({String icon, String label})`.
  - Area pages use `Area.values` (`lib/analysis/area.dart`) for title and glyph.
  - Today uses `sun.max`, Areas uses `circle.grid.2x2`, Workout uses `dumbbell` and You uses
    `person`. If one of these is not in `app_icon.dart`, use an icon that is and keep it in the
    one table.
  - Unknown, empty or null paths return the fallback: `sparkles` and `Pal`.

**Behaviour that must survive:**
- `seed` opens straight into the conversation.
- Pal starters, with the static fallback and loading skeletons.
- `sendStarter` with a payload.
- Log, meal, goal and routine turns with Undo and Edit (Edit refills the input, focused).
- The offline hand-off to New entry.
- Close pops the sheet.
- Keyboard lift, the expanded height and scroll-to-newest.

**Offline flag:** add `final bool offline` to `PalMessage` in `lib/services/pal/pal_service.dart`
(constructor default `false`, carried by `copyWith`). `PalComposerController` sets it on every
assistant message it appends because Pal was unreachable. The turn renders those replies in
ink3.

**Remove:** the green Start a workout card, the `TRY SAYING` caps label, coloured starter icons
(`c.forType`), bubbles, `PalAvatar` imports and every legacy-pattern token.

**Acceptance (focused tests):**
- `flutter test test/screens/pal/pal_composer_sheet_test.dart` (new)
  - With `from: '/move'` the chip reads `Workout`. With `from: '/areas/money'` it reads
    `Money`. `/today` gives `Today`, `/areas` gives `Areas` and `/you` gives `You`. With
    `from` null, `'/nowhere'` or `''` the chip reads `Pal`, with no exception.
  - With `palPickControllerProvider` overridden to data `WorkoutSuggestion(title: 'Push Day A', …)`,
    the first pill reads `Start Push Day A`. Overridden to loading or error, it reads
    `Start a workout`. Tapping it pops and lands on the Start workout route.
  - A seeded sheet shows the seed as a `headline` text and no `PalAvatar` type exists in the
    tree.
  - The send button has semantics label `Send`, and the close button `Close`.
  - At `TextScaler.linear(1.5)` the idle sheet renders with no overflow exception.
  - The sheet's decoration colour is `surface` and no `BackdropFilter` is under it.
  - Tapping a log turn's Edit refills the input with the original text, focused.
  - With suggestions overridden to an empty list, the three static starters show as pills.
  - Close pops the sheet.
  - An assistant message with `offline: true` renders in `ink3`.
- `flutter test test/controllers/pal_composer_controller_test.dart`
  - With Pal unreachable, the appended assistant message has `offline == true`.
  - A normal reply has `offline == false`.
- `flutter test test/screens/pal/pal_composer_starters_test.dart test/screens/pal/pal_meal_card_test.dart`
  - Updated to the new look. The meal turn shows its kcal range and Undo and Edit. Undo shows
    `Undone`.
- `flutter test test/screens/shell_test.dart`: tapping the ask bar on Workout opens the
  composer whose `from` is `/move`.
- `flutter test test/today_screen_test.dart` still passes unchanged: the Why seed text is found
  inside `PalComposerSheet`.
- Regenerate `pal_composer_*` goldens with
  `flutter test --update-goldens test/golden/design_system_golden_test.dart --plain-name pal_composer`.
  Say so in the report.
- The legacy pattern has zero matches in both composer files.

In the Final run, these views and interactions are shown by Task 8's steps:
- Chips: `composer_idle_workout` (chip `Workout`, first pill `Start <pick>`),
  `composer_chip_today`, `composer_chip_areas`, `composer_chip_area_money`, `composer_chip_you`
  and `composer_chip_fallback`.
- Starters: `composer_starters_loading` and `composer_starters_fallback`.
- `composer_start_pick`: tapping the first pill lands on Start workout.
- Conversation: `composer_thinking`, `composer_answer` and `composer_offline_answer` (ink3).
- Acting turns: `composer_log`, `composer_log_undone`, `composer_log_edit` (Edit refills the
  input), `composer_meal` and `composer_goal_action`.
- `composer_close`: Close pops back to the tab.
- `composer_offline_handoff`.
- `why_thread`: Today's `Why this first` opens the seeded composer.

### Task 3: Nutrition: meal detail and Add a meal sheet
**Depends on:** Task 1
**Model:** claude-opus-5-5
**Chunk:** Nutrition: meal detail and Add a meal sheet
**Files:** `lib/screens/nutrition/nutrition_meal_detail_screen.dart`, `lib/screens/nutrition/nutrition_add_sheet.dart`, `lib/screens/nutrition/widgets/nutrition_widgets.dart`, `test/screens/nutrition_meal_detail_test.dart`, `test/screens/nutrition_sheets_test.dart`, `test/screens/nutrition_widgets_test.dart`, `test/navigation/nutrition_nav_test.dart`

Decisions 15 and 16, from the canvas's `sub.isMeal` block and `mealView`.

**Meal detail:**
- Use `SubScreen(backLabel: 'Nutrition', eyebrow: '${meal.slot} · ${meal.time}', title: meal.name)`.
- Keep the loading and missing-meal states as plain ink3 text inside the same chrome.
- The linked expense value is formatted with the user's currency, from
  `appSettingsControllerProvider` and the existing formatter in `lib/util/format.dart`, never a
  literal `$`.
- `Adjust estimate` keeps opening the edit sheet. Delete keeps `_RemoveButton`'s current
  behaviour, restyled only.

**Add a meal:** restyle the sheet. `SheetShell`, `ChipRow`, `CalRange`, `MacroSplit` and
`ConfidenceChip` keep every constructor parameter `nutrition_confirm_sheet.dart` passes. A
parameter whose look is gone (for example `light`) may be accepted and ignored, with a
lower-case why comment.

**MealRow:** it has no lib caller (only `nutrition_widgets_test.dart`). Grep every reference,
then delete it and its tests.

**Acceptance (focused tests):**
- `flutter test test/screens/nutrition_meal_detail_test.dart`
  - Shows the kcal mid, the `kcal, likely` line, the `Macros` rows, the note line (when the
    meal has a note), the tags line, a `Back to Nutrition` semantics label, and
    `Adjust estimate` and `Delete`.
  - The loading and missing-meal states render their ink3 text.
  - With currency VND the linked expense reads `₫`.
  - Adjust opens the edit sheet; Delete removes the meal.
- `flutter test test/screens/nutrition_sheets_test.dart test/screens/nutrition_widgets_test.dart test/navigation/nutrition_nav_test.dart`
  - Slot pills select with semantics `selected`.
  - Estimate fills the result with a `score` number.
  - Save adds the meal, and edit-mode Save updates it.
- `flutter analyze --fatal-infos` stays clean, which proves the confirm sheet still compiles.
- The legacy pattern has zero matches in the three lib files.

In the Final run, these views and interactions are shown by Task 8's steps:
- Meal detail: `meal_detail_linked` (VND, with a note), `meal_detail_by_hand`,
  `meal_detail_loading` and `meal_detail_missing`.
- `meal_adjust`: Adjust estimate opens the sheet in edit mode.
- `meal_delete`: Delete removes the meal and returns to Nutrition.
- Add a meal: `add_meal_empty`, `add_meal_slot_selected`, `add_meal_estimated`,
  `add_meal_saved` (Save adds the meal) and `add_meal_edit`.

### Task 4: Money: Budgets, Budgets & goals, New entry sheet and keypad
**Depends on:** Task 1
**Model:** claude-opus-5-5
**Chunk:** Money: Budgets, Budgets & goals, New entry sheet and keypad
**Files:** `lib/screens/money/budgets_screen.dart`, `lib/screens/settings/budgets_goals_screen.dart`, `lib/screens/entry/new_entry_sheet.dart`, `lib/widgets/keypad.dart`, `lib/widgets/spend_ring.dart`, `test/screens/money/budgets_screen_test.dart`, `test/screens/settings/budgets_goals_screen_test.dart`, `test/new_entry_test.dart`, `test/screens/entry/new_entry_quick_picks_test.dart`, `test/golden/goldens/new_entry_dark.png`, `test/golden/goldens/new_entry_light.png`

Decisions 2, 12, 13 and 14. Consumes `budgetState` from Task 1.

**Budgets:**
- `SubScreen(eyebrow: <month name>, title: 'Budgets')`.
- The hero and envelope rows per decision 12. Each envelope's state is
  `budgetState(spent: e.spent, budget: e.cap, elapsed: data.monthPaceFraction)`, and the hero's
  is the same over `totalSpent` and `totalCap`.
- Keep the loading, error, suggested-caps and advisories sections and the options button.
- Delete `spend_ring.dart` after grepping every reference: imports, tests, goldens and strings.

**Budgets & goals:**
- `SubScreen` with neutral stepper rows: ink2 line icons, steppers at least 44 with semantics
  labels.
- `Save` becomes the primary pill at the end, enabled under the same `_loaded && !_saving`
  rule, and it keeps the snackbar outcome.

**New entry and keypad:**
- Every kind (expense, workout, ritual), quick-picks, optional fields, Log with Pal parsing,
  the offline notice and Cancel/Add keep working.
- `Keypad`'s constructor is unchanged.

**Acceptance (focused tests):**
- `flutter test test/screens/money/budgets_screen_test.dart` (new), with `budgetsDataProvider`
  overridden:
  - The hero shows what is left in the user's currency (VND gives `₫`).
  - An envelope at 120% shows `over` and `Needs care` in `careInk`.
  - A zero-cap envelope shows no state word and its bar is ink.
  - No `SpendRing` type exists.
  - The loading and error texts render.
  - At `TextScaler.linear(1.5)`, no overflow.
- `flutter test test/screens/settings/budgets_goals_screen_test.dart` (new):
  - Steppers change values.
  - Save is disabled before load.
  - Save persists and shows the snackbar.
- `flutter test test/new_entry_test.dart test/screens/entry/new_entry_quick_picks_test.dart`
  - The typed amount renders in `AppType.display` weight 300 with the currency symbol.
  - Add writes the entry.
  - Quick-picks fill values.
  - The offline notice shows with `notice=pal-offline`.
- Regenerate `new_entry_*` goldens
  (`flutter test --update-goldens test/golden/design_system_golden_test.dart --plain-name new_entry`)
  and report it.
- The legacy pattern has zero matches in all four remaining lib files.

In the Final run, these views and interactions are shown by Task 8's steps:
- Budgets: `budgets_on_track`, `budgets_over`, `budgets_zero_cap`, `budgets_loading` and
  `budgets_error`.
- Budgets & goals: `budgets_goals`, `budgets_goals_stepper` (tapping a stepper changes the
  value) and `budgets_goals_saved`.
- New entry: `new_entry_expense` (typed amount), `new_entry_quick_pick` (tapping a pick fills
  the form), `new_entry_added` (Add closes the sheet and writes the entry), `new_entry_workout`,
  `new_entry_ritual`, `new_entry_log_with_pal` and `new_entry_offline_notice`.

### Task 5: Recap and the correlation card
**Depends on:** Task 1
**Model:** claude-sonnet-5-5
**Chunk:** Recap (Reviews Day/Week/Month) and the correlation card
**Files:** `lib/screens/recap/recap_screen.dart`, `lib/widgets/correlation_card.dart`, `lib/widgets/correlation_view.dart`, `lib/analysis/correlations.dart`, `lib/analysis/spend_patterns.dart`, `lib/controllers/providers.dart`, `test/screens/recap_screen_test.dart`, `test/screens/correlation_card_test.dart`, `test/widgets/correlation_view_test.dart`, `test/analysis/correlations_test.dart`, `test/monthly_review_test.dart`

Decisions 17 and 18.

**Recap:**
- `SubScreen(eyebrow: recap?.subtitle ?? '…', title: 'Recap')`.
- Keep `initialRange`, the range switch, `recapMemoryRefreshProvider` on open, and `Ask Pal more`
  opening the composer with the existing seed.
- The `Patterns are on You` row calls `context.go('/you')`.

**Correlations:**
- Grep every reference, then delete `correlation_card.dart`, `correlation_view.dart` and both
  tests. `lib/analysis/spend_patterns.dart`'s comment names `Correlation.summary`: update its
  wording only if it becomes wrong.
- Change `Correlation.summary` to `String summary(Currency currency)`, calling
  `formatValue(..., currency: currency)`.
- At `providers.dart:335`, pass the currency from `appSettingsControllerProvider`.
- Run build_runner only if a provider signature changes; it should not.

**Acceptance (focused tests):**
- `flutter test test/screens/recap_screen_test.dart test/monthly_review_test.dart`:
  - The stats render as numbers with labels.
  - `Patterns are on You` is present and navigates to `/you`.
  - No `Patterns` header and no `PAL NOTICED` text.
  - Wins render.
  - The loading notice `Pal is reviewing your recap…` and the empty notice render.
  - `Ask Pal more` opens the composer seeded `Tell me more about this recap`.
- `flutter test test/analysis/correlations_test.dart`: `summary(Currency.vnd)` contains `₫`
  and no `$`.
- The legacy pattern has zero matches in `recap_screen.dart` and `correlations.dart`.

In the Final run, these views and interactions are shown by Task 8's steps:
- `recap_day`, `recap_week` and `recap_month`.
- `recap_loading`, `recap_error` and `recap_empty`.
- `recap_patterns_row`: tapping the row lands on You.
- `recap_ask_pal_more`: tapping the pill opens the seeded composer.

### Task 6: Email sync: intro, dashboard, Gmail setup
**Depends on:** Task 1
**Model:** claude-sonnet-5-5
**Chunk:** Email sync: intro, dashboard, Gmail setup
**Files:** `lib/screens/email/email_intro_screen.dart`, `lib/screens/email/email_dashboard_screen.dart`, `lib/screens/email/email_setup_screen.dart`, `lib/screens/email/sender_filter_section.dart`, `test/email_sync_test.dart`, `test/email_connect_propagation_test.dart`, `test/screens/email/email_screens_test.dart`

Decisions 1, 2 and 19.

**Chrome:**
- The intro and dashboard use `SubScreen` (eyebrow `Settings`, title `Email sync`).
- Setup uses `SubScreen(backLabel: 'Email sync', eyebrow: 'Gmail', title: 'Gmail setup')`.
- Stop importing `EmailNavBar` here. Task 8 deletes it once settings stop using it.
- Keep `AppPasswordFormatter` imported from `email_nav.dart`.

**Behaviour that must survive:** connect, test connection (its spinner and failure snackbar),
Save's `canSave` rule, the background sync, notify and auto-categorize toggles, Sync now,
Disconnect with its failure snackbar, and the sender filter add and remove.

**Remove:** the pulse dot animation. The status reads as text.

**Acceptance (focused tests):**
- `flutter test test/screens/email/email_screens_test.dart` (new):
  - The intro shows the steps and a `Connect` primary pill that opens setup.
  - Setup Save is disabled until `canSave` and enabled after a valid address and password.
  - The dashboard is rendered with its provider overridden to a connected account. It shows
    the status text, `Sync now` and `Disconnect`, and the toggles flip.
  - A failed-sync status shows its words in `careInk`.
  - A failed test connection shows `Connection failed — check the password`.
  - Sync now calls the sync service, and Disconnect returns to the intro.
- `flutter test test/email_sync_test.dart test/email_connect_propagation_test.dart` stay green.
- The legacy pattern has zero matches in the four lib files.

In the Final run, these views and interactions are shown by Task 8's steps:
- `email_intro`.
- `email_connect`: Connect opens setup.
- `email_setup_empty`, `email_setup_ready` and `email_setup_test_failed`.
- `email_dashboard_connected` and `email_dashboard_failed`.
- `email_dashboard_toggle`: tapping a toggle flips it.
- `email_sync_now`.
- `email_disconnect`: Disconnect returns to the intro.

### Task 7: Settings leftovers: Notifications, Data and privacy, About, Appearance, Export
**Depends on:** Task 1
**Model:** claude-sonnet-5-5
**Chunk:** Settings leftovers: Notifications, Data and privacy, About, Appearance, Export
**Files:** `lib/screens/settings/notifications_screen.dart`, `lib/screens/settings/privacy_screen.dart`, `lib/screens/settings/about_screen.dart`, `lib/screens/settings/appearance_screen.dart`, `lib/screens/settings/export_data_screen.dart`, `test/screens/privacy_screen_test.dart`, `test/controllers/notification_delivery_test.dart`, `test/screens/settings/settings_screens_test.dart`

Decisions 1, 3 and 20.

**Chrome:** each screen uses `SubScreen` (eyebrow `Settings`, title as today) and stops
importing `EmailNavBar`.

**Behaviour that must survive:**
- Notifications: the allow prompt, the not-allowed row, the routine reminder toggle and time,
  and budget alerts.
- Privacy: its rows and the Export link.
- Appearance: the Light / Dark choice (texts `Light` and `Dark`, no `accent` text).
- Export: the export action and its done and error outcomes.

**Acceptance (focused tests):**
- `flutter test test/screens/settings/settings_screens_test.dart` (new):
  - Each screen renders its title with a `Back to You` semantics label.
  - About shows the app name in `AppType.title`.
  - Appearance taps `Light` and the theme setting changes.
  - Export's primary pill runs the export, and the done state renders. A failing export
    renders its error state.
  - Notifications' toggles flip.
- `flutter test test/screens/privacy_screen_test.dart test/controllers/notification_delivery_test.dart`
  stay green.
- The legacy pattern has zero matches in the five lib files.

In the Final run, these views and interactions are shown by Task 8's steps:
- `notifications_allowed`, `notifications_not_allowed` and `notifications_toggle`.
- `privacy` and `about`.
- `appearance`, and `appearance_light` (tapping Light switches the theme).
- `export_idle`, `export_done` and `export_error`.

### Task 8: Retire PalAvatar and EmailNavBar; Run B scenarios
**Depends on:** Task 2, Task 3, Task 4, Task 5, Task 6, Task 7
**Model:** claude-sonnet-5-5
**Chunk:** Shared: glass_surface and pal_avatar (composer, Why thread, recap)
**Files:** `lib/widgets/pal_avatar.dart`, `lib/screens/email/email_nav.dart`, `lib/widgets/nav_bar.dart`, `test/widgets/pal_ask_bar_test.dart`, `test/scenario/pal_money_settings_scenario_test.dart`, `test/scenario/you_scenario_test.dart`, `test/scenario/shell_scenario_test.dart`, `test/scenario/today_scenario_test.dart`, `test/scenario/area_page_scenario_test.dart`, `test/scenario/theme_scenario_test.dart`

**Cleanup:**
- Grep `PalAvatar` and `pal_avatar` across `lib` and `test`: imports, type finders and strings.
  Delete `lib/widgets/pal_avatar.dart` and drop the `PalAvatar` assertion from
  `pal_ask_bar_test.dart`.
- Grep `EmailNavBar`. If only `email_nav.dart` defines it, delete the class and keep
  `AppPasswordFormatter`. `NavAction`'s doc comment in `lib/widgets/nav_bar.dart` (about line
  335) names `[EmailNavBar]`: edit only that doc line to drop the name. `nav_bar.dart` is Run A's
  file, so touch nothing else in it.
- Run the legacy pattern over every file Run B touched; it must be zero.

**Scenario file:** write `test/scenario/pal_money_settings_scenario_test.dart` with
`scenarioTest` and `shot` from `scenario_harness.dart`, following `you_scenario_test.dart`'s
app boot and seeding. Each step drives the real app, or a screen under the real router, to the
named state, asserts the state's key text or widget, then shoots `<step>_<theme>`:
- **Composer** (Task 2's list):
  - `composer_idle_workout`, `composer_chip_today`, `composer_chip_areas`,
    `composer_chip_area_money`, `composer_chip_you` and `composer_chip_fallback`.
  - `composer_starters_loading`, `composer_starters_fallback` and `composer_start_pick`.
  - `composer_thinking`, `composer_answer` and `composer_offline_answer`.
  - `composer_log`, `composer_log_undone`, `composer_log_edit`, `composer_meal` and
    `composer_goal_action`.
  - `composer_close`, `composer_offline_handoff` and `why_thread`.
- **Nutrition** (Task 3's list):
  - `meal_detail_linked`, `meal_detail_by_hand`, `meal_detail_loading`,
    `meal_detail_missing`, `meal_adjust` and `meal_delete`.
  - `add_meal_empty`, `add_meal_slot_selected`, `add_meal_estimated`, `add_meal_saved` and
    `add_meal_edit`.
- **Money** (Task 4's list):
  - `budgets_on_track`, `budgets_over`, `budgets_zero_cap`, `budgets_loading` and
    `budgets_error`.
  - `budgets_goals`, `budgets_goals_stepper` and `budgets_goals_saved`.
  - `new_entry_expense`, `new_entry_quick_pick`, `new_entry_added`, `new_entry_workout`,
    `new_entry_ritual`, `new_entry_log_with_pal` and `new_entry_offline_notice`.
- **Recap** (Task 5's list): `recap_day`, `recap_week`, `recap_month`, `recap_loading`,
  `recap_error`, `recap_empty`, `recap_patterns_row` and `recap_ask_pal_more`.
- **Email** (Task 6's list):
  - `email_intro`, `email_connect`, `email_setup_empty`, `email_setup_ready` and
    `email_setup_test_failed`.
  - `email_dashboard_connected`, which overrides the provider with a connected account.
  - `email_dashboard_failed`, `email_dashboard_toggle`, `email_sync_now` and
    `email_disconnect`.
- **Settings** (Task 7's list):
  - `notifications_allowed`, `notifications_not_allowed` and `notifications_toggle`.
  - `privacy`, `about`, `appearance` and `appearance_light`.
  - `export_idle`, `export_done` and `export_error`.

An interaction step shoots the state after the interaction and asserts its outcome, for
example the route reached or the text that appeared.

**Shared scenarios:** these files render views this run changed:
- `you_scenario_test.dart`: the pushed screens.
- `shell_scenario_test.dart`: the composer.
- `today_scenario_test.dart`: `today why this first` opens the composer.
- `area_page_scenario_test.dart`: `area nutrition meal` and `area nutrition add`.
- `theme_scenario_test.dart`: Appearance.

Update each one only where a finder no longer matches, and keep their existing step names. The
Today, area page and theme files belong to other runs: change only Run B's finders in them.

**Acceptance:**
- `flutter test --tags scenario test/scenario/pal_money_settings_scenario_test.dart test/scenario/you_scenario_test.dart test/scenario/shell_scenario_test.dart test/scenario/today_scenario_test.dart test/scenario/area_page_scenario_test.dart test/scenario/theme_scenario_test.dart`
  passes (the Final command), writing every listed step in light and dark.
- `flutter test test/widgets/pal_ask_bar_test.dart` passes.
- `grep -rn "PalAvatar\|SpendRing\|CorrelationCard\|CorrelationView\|EmailNavBar" lib test`
  returns nothing.
