# Routines and onboarding in the Oura design language

**Effort:** effort:c4342184-d6c7-424a-be76-048d8a167e17
**Verify:** `flutter test --exclude-tags "golden || scenario"`
**Setup:** `flutter pub get`
**Check:** `flutter analyze --fatal-infos`
**Final:** `flutter test --tags scenario test/scenario/routines_onboarding_scenario_test.dart test/scenario/today_scenario_test.dart test/scenario/area_page_scenario_test.dart`
**Prototype:** C:\Users\cktra\Projects\opal\.superpowers\design\oura-ai-first-routines\project\Main.dc.html

Run C of 3. This converts Manage routines and its sheets, the routine player, the evening close-out and onboarding to the Oura design language. The board above is the design: its inline styles are the measurements, its script's `renderVals()` is the behaviour, and its `startAt` tweak lists every state. The board is dark only. Light comes from the same tokens (`context.colors`), and every state is shot in both themes.

## Rules for every task

- `DESIGN.md` sections 2 to 9 are the rules. Colour means state only, never area, so there is no `c.forType(...)`, no area colours and no tinted tiles. No gradients, glass, shadows or glows. Big numbers are light and tabular (`AppType.display` / `AppType.score`). Titles are `AppType.title` (22/500). There is one primary pill per screen: `ink` fill, `bg` text, 48 tall, `Radii.pill`, `AppType.headline`. Separate with space first, hairline (1px `hair`) second, and a card (`surface`, `Radii.card`, padding 16) last. Icons are bare line glyphs in `ink2` (`AppIcon`), never on a tile.
- Type roles map from the board as follows: 13/500 is `AppType.label`; 12 is `AppType.caption`; 15 is `AppType.subhead`; 16 is `AppType.callout`; 17 is `AppType.body`; 17/600 is `AppType.headline`; the serif 30 is `AppType.lead`; 64/300 is `AppType.display`.
- Colours map as follows: `#101418` bg, `#1A1F24` surface, `#242A30` surface2, `#2E353C` hair, `#F7F1E8` ink, `#D3D1CE` ink2, `#A8A5A0` ink3, `#39424A` track, and `#F58A78` the care ink (`c.careInk`).
- Zero matches in each task's own files for the legacy pattern, checked with:
  `grep -nE 'AppType\.(caption2|footnote|title1|title2|title3|large|amountLg|amount)\b|\bc(olors)?\.(money|move|rituals|nutrition|sleep|mood)(Tint|Ink)?\b|Elevation\.(sm|card)\b|\.glass(Border|Highlight)?\b|\.accent(Ink|Tint)?\b|onAccent|\bsfr\(|AppText\.mono|Radii\.(md|lg)\b' <files>`
  Also keep `forType(`, `c.red`, `dangerInk`, `BoxShadow` and `Gradient` out of the touched screen files.
- No magic numbers: name every measurement as a file-level `const` (lower-case comment only when the why is not obvious). Inset fills (text fields) use `Radii.inset` from Task 1.
- Touch targets are 44 or larger, and every tappable control has a semantics label. Use `PressScale(semanticLabel: ...)` as the converted screens do.
- Handle load errors at the boundary: `debugPrint` the error with context and show calm copy. Never show the raw exception, and never swallow an error silently.
- Keep every feature. The shared widgets `LargeTitleNavBar`, `NavAction`, `NavIconButton` and `Segmented` belong to run A, which restyles them. Use them as they are. Do not restyle or reshape them here.
- Step counts read `1 step` at one and `<n> steps` otherwise, everywhere one is shown or announced.
- Every drag handle is a labelled 44 box: set `buildDefaultDragHandles: false` and wrap a `line.3.horizontal` glyph (`ink3`, 20) in `ReorderableDragStartListener(index: i)` inside `Semantics(button: true, label: 'Reorder <name or title>')`. The glyph name is mapped in Task 1.
- Comments are lower case and say why. No new dependencies. No emojis. Commit subjects use `type(scope): summary`, with no attribution trailer.
- Not in scope, and noted for the report: "a routine with no steps can never complete" has its root in `RitualsState.isComplete` (`lib/controllers/rituals_controller.dart`). "Today's close-out item never completes after the close-out is finished" is the `closeOut` `PlanItem` in `lib/screens/today/day_plan.dart`, which never sets `done`. Neither file is this run's, so do not edit them.

### Task 1: Shared inset radius and the progress bar on track
**Depends on:** none
**Model:** claude-sonnet-5-5
**Files:** `lib/theme/radii.dart`, `test/theme/radii_test.dart`, `lib/widgets/controls.dart`, `test/widgets/progress_bar_test.dart`, `lib/widgets/app_icon.dart`, `test/widgets/app_icon_test.dart`

Add the one shared token the screens need, make the shared bar draw the DESIGN.md bar so the three screens that show progress reuse it rather than each drawing their own, and map the drag-handle glyph that Tasks 2 and 3 need.

- `AppIcon`: add `'line.3.horizontal': CupertinoIcons.line_horizontal_3` to `_sfMap`. In the new `test/widgets/app_icon_test.dart`, `iconForSf('line.3.horizontal')` returns `CupertinoIcons.line_horizontal_3`, not the `CupertinoIcons.circle` fallback. The player's streak uses the existing `flame.fill`, so it needs no mapping.

- `Radii`: add `static const double inset = 12;`, with a doc comment saying it is for inset fills (DESIGN.md section 5). Leave every other radius alone, since the retirement run removes `md` and `lg`. In `test/theme/radii_test.dart`, add `expect(Radii.inset, 12.0);`.
- `ProgressBar` in `lib/widgets/controls.dart`: the track becomes `c.track` instead of `c.fill`, and the default fill becomes `c.ink` instead of `c.accent`. Keep the constructor source-compatible (`value`, `color`, `height = 4`, `gradient`) and touch nothing else in the file. Run A also owns this file, and the lead merges any overlap.
- New `test/widgets/progress_bar_test.dart`. In a themed `MaterialApp`, as the other widget tests boot it, `ProgressBar(value: 0.25)` paints a track box in `c.track`. Its fill is `c.ink` at a quarter of the track's width, and a `value` above 1 clamps to full width.

Acceptance: `flutter test test/theme/radii_test.dart test/widgets/progress_bar_test.dart test/widgets/app_icon_test.dart` passes, and the legacy grep on `lib/widgets/controls.dart` no longer matches `ProgressBar`'s lines. This task renders no view of its own. Its bar shows in Task 6's `player_*`, `closeout_*` and `onboarding_*` steps.

### Task 2: Manage routines, the Edit routine sheet and the step sheet
**Depends on:** Task 1
**Files:** `lib/screens/rituals/rituals_builder_screen.dart`, `test/screens/rituals_builder_screen_test.dart`

Match the board's `manage`, `manageEmpty`, `manageError`, `edit`, `newRoutine`, `stepSheet` and `confirmDelete` states.

- **Screen:** keep `LargeTitleNavBar`, with the title `Manage routines` (was `Manage`) and the subtitle `Drag to reorder · tap to edit`. Keep the back `NavAction` to `/rituals` and the `+` `NavIconButton` labelled `New routine`.
- **Rows** (`ReorderableListView`, same reorder callback, `buildDefaultDragHandles: false`): no card and no tile.
  - Each row is at least 64 tall under a 1px `hair` top border. It holds the routine's glyph (22, `ink2`), the name in `AppType.body` `ink` (one line, ellipsis), and `'<time> · <count>'` in `AppType.subhead` `ink3`. `<count>` follows the step-count rule, and the time reads `Any time` when it is empty.
  - The tappable part (glyph and text) is one `PressScale` with the semantic label `'<name>, <time or "any time">, <count>. Edit'`, and it opens the editor.
  - The row ends in the labelled drag handle from the rules (`Reorder <name>`).
  - The red x is removed from rows.
- **States:** loading is `…` in `subhead` `ink3`, left-aligned under the title. Empty is `No routines yet. Tap + to add one.` Error is `Couldn't load routines. Try again in a moment.`, with the error sent to `debugPrint`. Do not interpolate `$e` into the UI.
- **Edit routine sheet:**
  - Background `c.surface`, top radius `Radii.card`, a grabber (36x5, `track`, pill) and padding `8 16 34`. Use `useRootNavigator: true` so the sheet covers the tab bar, as the mood logger does.
  - Header row, 44 tall: `Cancel` (`body`, `ink2`), the title `Edit routine` or `New routine` in `headline`, and `Save` in `headline` (`ink`, or `ink3` and disabled while the name is empty or there are no steps). Keep the existing `_canSave` rule.
  - Body order, top to bottom, as on the board: the name field, the time field, `Tone`, `Icon`, the subtitle field, then `Steps`. Gaps are 12 between the name and time fields and 16 between the other blocks.
  - Fields are `surface2`, `Radii.inset`, 52 tall, `body` text, `ink3` hint, `ink` cursor. The time field is read-only and opens `showTimePicker`, as today.
  - Section labels are `Tone`, `Icon` and `Steps` in `AppType.label` `ink3`, in sentence case. The uppercase `TONE`/`ICON`/`STEPS` go.
  - Tone uses the shared `Segmented` unchanged.
  - Icon grid: 7 columns of 44 circles. Unselected is a 22 glyph in `ink2` with no fill. Selected adds a 1.5px `ink` ring and an `ink` glyph. Each cell carries `Semantics(button: true, selected: ..., label: <word>)`, with the words from one const map: Sparkles, Sunrise, Sun, Moon, Drop, Bolt, Leaf, Walk, Book, Books, Journal, Tray, Cup, Heart.
  - `Add step` is a text button (`plus` glyph and `subhead` w600 `ink`, 44 tall).
  - Step rows are at least 52 tall under a `hair` top border: glyph 20 `ink2`, title in `callout`, a remove `xmark` in `ink3` in a 44 box labelled `Remove <title>`, then the labelled drag handle (`Reorder <title>`). Keep the reorder. `Add at least one step.` shows when the list is empty.
- **Delete routine:**
  - Only when editing an existing routine. It is a full-width text button at the sheet's foot, 48 tall, under a `hair` top border. The text is `Delete routine` in `headline` weight and `c.careInk`.
  - Tapping it opens a confirm sheet with the same chrome: the title `Delete <name>?` in `AppType.title`, and the body `This removes the routine and its <count>. What you checked off before stays in your history.` in `subhead` `ink2`.
  - It has a `Delete` button (48, pill, `surface2` fill, `careInk` text, `headline`) and a `Keep it` text button (48, `ink`).
  - Delete calls `ritualsBuilderControllerProvider.notifier.delete(id)` and closes both sheets. Keep it returns to the editor with the draft intact.
- **Step sheet:** same chrome and header (`New step` or `Edit step`), the title and note fields, then `Icon` and the same grid.

Tests (`test/screens/rituals_builder_screen_test.dart`, booting with `bootToday` from `test/support/today_fixture.dart` and navigating to `/areas/routines/manage`):
- Rows render name and detail. There is no `xmark` on a row.
- Tapping a row opens `Edit routine`. `Delete routine` then `Delete` removes the routine from the list and the repository. `Keep it` keeps it.
- `New routine` shows no `Delete routine`, and Save stays disabled until a name and a step exist.
- Adding a step through the step sheet adds a row. `Remove <title>` removes it.
- Selecting an icon marks only that cell selected in semantics.
- Dragging the Evening row's `Reorder Evening wind-down` handle above Morning persists the new order. Each step row's handle is labelled `Reorder <title>`.
- A routine saved with one step reads `1 step` in its row detail and its semantic label. The five-step Morning reads `5 steps`.

Acceptance: `flutter test test/screens/rituals_builder_screen_test.dart` passes, and the legacy grep returns nothing for `lib/screens/rituals/rituals_builder_screen.dart`. Task 6's `manage_*` steps render these views: `manage_list`, `manage_empty`, `manage_loading`, `manage_error`, `manage_edit`, `manage_new`, `manage_step_sheet`, `manage_icon_selected`, `manage_step_removed`, `manage_delete_confirm`, `manage_deleted`, `manage_saved` and `manage_reordered`.

### Task 3: Routine player
**Depends on:** Task 1
**Files:** `lib/screens/rituals/routine_player_screen.dart`, `test/screens/routine_player_screen_test.dart`

Match the board's `player`, `playerStepDone`, `playerDone`, `playerSkipped`, `playerNoSteps`, `playerNotFound` and `playerError` states. The player follows the Workout canvas's active session.

- **Layout:** padding `52 16 48` (top clears the status bar, as a named const), on `bg` with no gradient.
  - Header row, 44 tall: a close `xmark` (22, `ink`, 44 box, label `Close`) going to `/rituals` as today. Then the routine name centred in `AppType.label` `ink3`, then a 44 spacer.
  - Progress block, 16 below: a caption row, `Step <i+1> of <total>` on the left and `<done> of <total> done` on the right (both `AppType.caption` `ink3`, tabular). Under it, 8 below, the shared `ProgressBar(value: done / total, color: c.ink)` at height 4. There is no orange and no segments. Wrap it in `Semantics(label: '<done> of <total> done')`.
- **Step card**, 28 below: `surface`, `Radii.card`, padding 16, gap 16. The step glyph is 28 in `ink2`. The title is in `AppType.title` and the note in `AppType.body` `ink2`, with 6 between them. Then the one primary pill, `Mark done` with a `checkmark` (18), or `Next step` when the step is already done. It keeps today's `completeStep` and advance behaviour. The card has the session card's weight: nothing else on screen is a card.
- **Controls row**, 8 below the card: `Back` (`chevron.left` and `subhead` w600 `ink2`, disabled `ink3` with `Semantics(enabled: false)` at the first step) on the left, and `Skip` (`subhead` w600 `ink2`) on the right. Each is at least 44 tall.
- **Up next**, 24 below, only when a next step exists: `Up next` in `label` `ink3`, then a row with the next title in `callout` and `Step <i+2>` in `subhead` `ink3`.
- **Finished view** (index past the end):
  - The header reads `Done · <name>`.
  - The serif `AppType.lead` line is `<name> is done.` when every step is done, otherwise `<name>, <done> of <total> done.`. This fixes today's copy, which always says complete even after skips.
  - 28 below it, `AppType.display` shows `<done>` with the unit ` of <total> steps` inline in `subhead` `ink3`, and `done today` in `subhead` `ink2` under it.
  - When `profileStatsProvider`'s `longestStreak` is above 0, 16 below that, the existing `flame.fill` glyph (16, `ink2`) and `<n>-day streak` in `subhead` `ink2`.
  - A spacer, then the primary pill `Back to routines` (to `/rituals`).
  - No gradient disc and no tinted pill.
- **States without a step:** each shows a title in `AppType.title`, a body in `AppType.body` `ink2` and one primary pill at the foot.
  - A routine with no steps: `No steps yet` / `Add a step to <name> to start it.`, with the pill `Manage routines` going to `AppRoute.areaManageRoutines`.
  - Not found: `Routine not found` / `It may have been deleted.`, with the pill `Back to routines`.
  - Load error: `Couldn't load routine` / `Try again in a moment.`, with the pill `Back to routines` and the error sent to `debugPrint`.
  - Loading stays an empty `bg`.
- Keep the step `AnimatedSwitcher` (fade and slide) on the card only.

Tests (`test/screens/routine_player_screen_test.dart`):
- Mark done advances and updates `1 of 5 done`.
- Skip advances without completing.
- Back is disabled at step 1.
- An already-done step shows `Next step`.
- Finishing all steps shows `Morning is done.` and the `5` / ` of 5 steps` number. Finishing with two skipped shows `Morning, 3 of 5 done.`
- A routine saved with an empty step list shows `No steps yet`, and its pill opens Manage routines.
- An unknown id shows `Routine not found`.

Acceptance: `flutter test test/screens/routine_player_screen_test.dart` passes, and the legacy grep returns nothing for `lib/screens/rituals/routine_player_screen.dart`. Task 6's `player_*` steps render these views: `player_step`, `player_marked`, `player_next_step`, `player_skipped`, `player_back`, `player_done`, `player_partial`, `player_no_steps`, `player_not_found`, `player_error` and `player_loading`.

### Task 4: Evening close-out
**Depends on:** Task 1
**Files:** `lib/screens/reflect/evening_close_out_screen.dart`, `test/screens/evening_close_out_screen_test.dart`

Match the board's `closeout`, `closeoutDone`, `closeoutEmpty`, `closeoutLoading` and `closeoutError` states. The close-out now follows the app theme on `bg`, with no scene. All of the fixed night palette consts, the purple wash, the pink Now pill, the purple cards and `DottedBorderBox` go.

- **Header**, 44 tall: a back `chevron.left` (24, `ink`, 44 box, label `Back to Today`) with today's pop-or-`/today` behaviour. Padding is `52 16 48`.
- **Lead block**, 12 below, gap 8:
  - The date line in `AppType.label` with letter spacing 1.2, `ink3`, uppercase, tabular, as Today's date line formats it (for example `MON 28 SEP · 9:30 PM`). Reuse Today's formatter if one is exported, otherwise format it with `kWeekdays` and `kMonthsShort` from `util/dates.dart`.
  - The serif `AppType.lead` line `Close out your day.`
  - The summary in `AppType.subhead` `ink2`: `<done> of <total> steps done. <tail>`. The tail is `The ring is closed.`, `One more to close the ring.` or `<n> more to close the ring.`. With no steps, the summary is `No wind-down steps yet.`
- **Progress:** 16 below, the shared `ProgressBar(value: done / total, color: c.ink)`, only when there are steps.
- **The one card**, 20 below: `surface`, `Radii.card`, padding 16, gap 14. It shows `label` `ink3`, a title in `AppType.title`, an optional note in `subhead` `ink2`, and the one primary pill.
  - While a step is open: `Now` / the step title / the note / `Mark done`, which calls `ritualsControllerProvider.notifier.completeStep(evening, index)` for the first incomplete step.
  - When all steps are done: `All done` / `Rest easy` / `Good night`.
  - With no steps: `Nothing to close` / `Rest easy` / `Good night`.
  - `Good night` keeps today's pop-or-`/today`. The old disabled `<n> to go` button goes.
- **Tonight list**, 32 below, only when there are steps:
  - The heading `Tonight` in `AppType.headline`.
  - Then every step as a row at least 56 tall under a `hair` top border: a 28 disc, the title in `callout` and the note in `subhead` `ink3`. The disc is filled `ink` with a `bg` check when done, and transparent with a 1.5 `ink3` border when open. Done titles drop to `ink3`, with no strikethrough.
  - Tapping a row keeps today's `toggleStep`. The row is `Semantics(checked: done, button: true, label: <title>)`.
  - Then the Pal row, at least 52 tall under a `hair` top border: a `sparkles` glyph (22, `ink2`), `Ask Pal for a reflection prompt` in `callout`, and a `chevron.right` in `ink3`. It goes to the same `/pal-composer?seed=...` as today.
- **Loading** (`ritualsControllerProvider` has no value yet): the lead block with the summary `…` in `ink3`. There is no card and no list. This replaces today's wrong `No wind-down steps yet.` while loading.
- **Error:** the lead block with `Couldn't load your routines. Try again in a moment.` in `ink3` and the error sent to `debugPrint`. There is no card and no list.
- The checklist stays driven by the `evening` routine, as today. No mood or notes are added: the screen never had them.

Tests (`test/screens/evening_close_out_screen_test.dart`, booting with `bootToday` and pushing `/close-out`):
- The card's `Mark done` completes the first open step, moves the card to the next one and updates the summary.
- Tapping a done row unchecks it.
- With all steps done, the card shows `Good night`, and tapping it pops.
- With `TodayDay(routines: [])`, the summary reads `No wind-down steps yet.` and `Good night` is present.
- A failing routines stream (override `ritualRoutinesStreamProvider` with `Stream.error`) shows the error copy.
- The Pal row navigates to the composer.

Acceptance: `flutter test test/screens/evening_close_out_screen_test.dart` passes. The legacy grep returns nothing for `lib/screens/reflect/evening_close_out_screen.dart`, and no `Color(0x` remains in it. Task 6's `closeout_*` steps render these views: `closeout_open`, `closeout_marked`, `closeout_row_toggled`, `closeout_done`, `closeout_good_night`, `closeout_empty`, `closeout_loading`, `closeout_error` and `closeout_pal`.

### Task 5: Onboarding
**Depends on:** Task 1
**Files:** `lib/screens/onboarding/onboarding_screen.dart`, `test/onboarding_test.dart`

Match the board's `onbWelcome`, `onbBudget`, `onbMove`, `onbRoutines`, `onbNone` and `onbSaveFailed` states. Onboarding follows the Today lead: Pal's label, then one serif headline per step.

- **Frame:** `SafeArea`, padding `16` at the sides with the top as on the board (60 from the screen top) and the bottom 34, on `bg`.
- **Progress:** `<n> of 4` in `AppType.caption` `ink3`, tabular, where `n` is the 1-based step. Then, 8 below, the shared `ProgressBar(value: n / 4, color: c.ink)`. It replaces the dots.
- **Lead block**, 32 below, gap 8:
  - The Pal label row: `sparkles` 16 and `Pal` in `AppType.label` `ink2`.
  - The step headline in `AppType.lead`. Its copy is the old title without the forced line break: `Welcome to Opal`, `Set a daily budget`, `Pick a workout goal`, `Choose your routines`.
  - The body in `AppType.body` `ink2`. Its copy is unchanged, except that em dashes become a comma or a full stop, as on the board.
- The 96 glyph hero tile and all per-area colour go. Nothing is coloured by area.
- **Welcome:** 28 below, the name field: `surface` fill, `Radii.inset`, 52 tall, `body`, hint `Your name` in `ink3`, cursor `ink`, no focus colour, and submit advances.
- **Budget and move:**
  - 32 below, `AppType.display` with `$85`, or `500` with the unit ` kcal` inline in `subhead` `ink3`. Under it in `subhead` `ink2` is what it is a fraction of: `to spend each day` or `of active energy each day`.
  - 24 below, the shared `Segmented` with the options `$50 $85 $120 $200` or `300 kcal 500 kcal 700 kcal 900 kcal`, selection unchanged.
  - Wrap the number in `Semantics(label: '$85 to spend each day')` and `'500 kcal of active energy each day'`.
- **Routines:**
  - 24 below, a row per seed routine, at least 64 tall under a `hair` top border: the glyph (22, `ink2`), the name in `callout`, and `<time> · <count>` in `subhead` `ink3`, following the step-count rule.
  - Then a `CupertinoSwitch` styled exactly as `lib/screens/you/autopilot_screen.dart`'s (`activeTrackColor: c.ink`, `inactiveTrackColor: c.track`, `thumbColor: c.bg`, `inactiveThumbColor: c.ink3`), with the switch carrying the row's semantics label (the routine name). The whole row toggles.
  - With none on, `Pick at least one routine to start.` shows in `subhead` `ink3` under the rows.
- **Foot:** the one primary pill (48, `ink` / `bg`), labelled `Get started`, `Continue` or `Start tracking`. It is disabled (`surface2` fill, `ink3` text, `Semantics(enabled: false)`) while no routine is on or while saving. On steps 2 to 4, under it, the `Skip` text button: 48 tall, `headline` `ink2`, same `_finish`.
- **Save failure:** replace the `SnackBar` with an inline `role=alert` message above the pill: `Couldn't save. Try again.` in `subhead` `ink`, on `surface2`, `Radii.inset`, padding `12 16`, wrapped in `Semantics(liveRegion: true)`. It clears on the next attempt or on any toggle. Keep the `catch` but bind the error and `debugPrint` it. Do not swallow it.
- **Persistence is unchanged:** `Goals` with the chosen budget and move goal and ritual target 5, the enabled routines upserted, the display name, and `onboardingComplete`.

Tests (update `test/onboarding_test.dart`):
- The finders move to the new headline strings.
- The full flow still persists the name, budget 120, move 700, target 5 and three routines.
- Switching all three routines off disables `Start tracking` and shows `Pick at least one routine to start.`
- Overriding `goalsRepositoryProvider` with one whose `upsert` throws shows `Couldn't save. Try again.` and stays on onboarding.
- `Skip` from step 2 finishes with the defaults.

Acceptance: `flutter test test/onboarding_test.dart` passes, and the legacy grep returns nothing for `lib/screens/onboarding/onboarding_screen.dart`. Task 6's `onboarding_*` steps render these views: `onboarding_welcome`, `onboarding_budget`, `onboarding_move`, `onboarding_routines`, `onboarding_none`, `onboarding_save_failed` and `onboarding_finished`.

### Task 6: Scenario coverage for routines and onboarding
**Depends on:** Task 2, Task 3, Task 4, Task 5
**Chunk:** Routines: Manage, Edit routine sheet, routine player, evening close-out
**Chunk:** Onboarding
**Files:** `test/scenario/routines_onboarding_scenario_test.dart`, `test/scenario/today_scenario_test.dart`, `test/scenario/area_page_scenario_test.dart`

Every rendered view and state from Tasks 2 to 5 gets a step in the new file, shot in both themes through `scenarioTest` and `shot` from `scenario_harness.dart`. Shot names are `<step>_<light|dark>`, one step per board state.

- **Manage:**
  - `manage_list`: boot with `bootToday`, open Areas, then Routines, then `Manage routines`.
  - `manage_empty`: `TodayDay(routines: [])`.
  - `manage_loading` and `manage_error`: override `ritualsBuilderControllerProvider` with a notifier whose `build` never emits, or one that throws.
  - `manage_edit`: tap the Morning row.
  - `manage_new`: the `New routine` sheet with Save disabled.
  - `manage_step_sheet`: open a step from the editor.
  - `manage_icon_selected`: tap the `Moon` cell and expect it selected.
  - `manage_step_removed`: `Remove Glass of water`, and the row is gone.
  - `manage_delete_confirm`: tap `Delete routine` and expect `Delete Morning?`.
  - `manage_deleted`: tap `Delete`, and Morning is gone from the list.
  - `manage_saved`: a new routine with a name and one step is saved, appears last and reads `1 step`.
  - `manage_reordered`: drag the `Reorder Evening wind-down` handle to the top and expect Evening wind-down first.
- **Player:**
  - `player_step`: Morning, step 1.
  - `player_marked`: after `Mark done`, `1 of 5 done`.
  - `player_next_step`: an already-done step shows `Next step`.
  - `player_skipped`: after `Skip`.
  - `player_back`: after `Back`.
  - `player_done`: all marked, `Morning is done.`
  - `player_partial`: with skips, `Morning, 3 of 5 done.`
  - `player_no_steps`: a seeded routine with no steps.
  - `player_not_found`: `/rituals/player/missing`.
  - `player_error`: override `ritualRoutinesStreamProvider` with an error stream.
  - `player_loading`: a never-emitting stream.
- **Close-out:**
  - `closeout_open`: reached from Today through `More`, the `Close-out` row and `Start`, as in `today_scenario_test.dart`.
  - `closeout_marked`: after the card's `Mark done`.
  - `closeout_row_toggled`: a done row tapped back to open.
  - `closeout_done`: every step done, `Good night` visible.
  - `closeout_good_night`: after `Good night`, back on Today.
  - `closeout_empty`: `TodayDay(routines: [])` and the route pushed.
  - `closeout_loading` and `closeout_error`: stream overrides.
  - `closeout_pal`: the reflection row opens the composer.
- **Onboarding:** boot the app with `settings.onboardingComplete` unset, the way `test/onboarding_test.dart` pumps it. Put that helper in this file, not in shared support.
  - `onboarding_welcome`, with a name typed.
  - `onboarding_budget`, with `$120` picked.
  - `onboarding_move`, with `700 kcal` picked.
  - `onboarding_routines`.
  - `onboarding_none`: all three off, pill disabled.
  - `onboarding_save_failed`: the `goalsRepositoryProvider` upsert throws.
  - `onboarding_finished`: lands on Today.
- **Each step asserts its view's lead** as well as the route. Examples: `find.text('Close out your day.')`, the `Mark done` pill, `AppType.title` text for the step, the `Pal` label on onboarding. A step that only opens a surface does not count.
- **`area_page_scenario_test.dart`:** in `area routines manage`, also expect the `Manage routines` title and the Morning row, and no `xmark` on a row. In `area routines player`, also expect `Mark done` and `Step 1 of 5`.
- **`today_scenario_test.dart`:** in `today action closeout`, also expect `Close out your day.` and the `Now` card. In `today action routine`, also expect `Mark done`. Keep the existing shot names.

Acceptance: the Final command passes, with every step above present, and the shots written to `ARC_FINAL_OUT`. `test/scenario/final_scenario_test.dart` is not touched and not run.
