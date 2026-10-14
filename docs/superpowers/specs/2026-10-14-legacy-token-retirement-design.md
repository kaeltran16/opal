# Legacy Token Retirement and Oura Clean-up

Runs A, B and C of the Oura conversion have landed on main (ac99734). This run removes the
last readers of the legacy design tokens, deletes the tokens from `lib/theme/`, guards against
their return, and closes the clean-up items left behind by the three runs.

## The legacy pattern

```
AppType\.(caption2|footnote|title1|title2|title3|large|amountLg|amount)\b|\bc(olors)?\.(money|move|rituals|nutrition|sleep|mood)(Tint|Ink)?\b|Elevation\.(sm|card)\b|\.glass(Border|Highlight)?\b|\.accent(Ink|Tint)?\b|onAccent|\bsfr\(|AppText\.mono|Radii\.(md|lg)\b
```

Matches on ac99734 outside `lib/theme/`:

| File | Matches | Treatment |
|---|---|---|
| `lib/screens/nutrition/nutrition_confirm_sheet.dart` | 14 | delete |
| `lib/widgets/dashed_border.dart` | 1 | delete |
| `lib/screens/mood/widgets/mood_widgets.dart` | 3 | convert |
| `lib/screens/mood/mood_logger_sheet.dart` | 2 | convert |
| `lib/screens/detail/detail_screen.dart` | 2 | convert |
| `lib/screens/you/autopilot_screen.dart` | 1 | convert |
| `lib/screens/areas/areas_screen.dart` | 1 | ring colours, renamed in theme |
| `lib/controllers/weekly_plan_controller.dart` | 1 | stale doc comment, reword |
| `test/theme/*`, `test/today_screen_test.dart` | many | rewrite with the retirement |

Members the pattern does not name but which only exist to serve the legacy set are retired with
it: `AppColors.forType` and `inkForType` (fall through to the area colours and `accent`) and
`AppFonts.mono` (the pattern's `AppText.mono`; the class in `app_text.dart` is `AppFonts`).

## Decisions

### Delete, do not convert

- `lib/screens/nutrition/nutrition_confirm_sheet.dart`: nothing opens it. The whole chain only it
  or its prompt reached goes with it: `showNutritionConfirmSheet`, `NutritionPending`,
  `NutritionState.pending` and `_derivePending`, `NutritionController.confirmFromExpense` and
  `portionFactors`, and `NutritionRepository.linkedEntryIds`, plus the tests that cover only
  those. `NutritionMeal.linkedEntryId` and `NutritionState.linkedExpenses` stay: the meal detail
  reads them. The seed expense `seed-nutrition-pending` stays as an ordinary expense; only its
  comment changes.
- `lib/widgets/dashed_border.dart` (`DottedBorderBox`): no users.
- `lib/widgets/donut_chart.dart` (`CategoryDonut`, `DonutPainter`): no users, and the only caller
  of `forType`.
- Every deletion is preceded by a grep across lib and test for the symbol, including `.g.dart`
  files and string routes.

### Convert

- Follow DESIGN.md and the screens runs A, B and C converted. Area colours appear nowhere but
  the activity rings.
- The mood logger becomes a sheet like the ones runs A and B built: `showAppSheet` from
  `lib/widgets/app_sheet.dart`, `PillButton` from `lib/widgets/controls.dart` for its action,
  `Radii` and `AppType` roles from the current set. Its mood-scale colours (`moodColor`) are a
  data scale, not an area colour, and stay.
- `detail_screen.dart`: the sleep empty title takes a current `AppType` role; the swipe-delete
  icon takes `c.bg` (the value `onAccent` aliased).
- `autopilot_screen.dart`: the subtitle takes the current role converted list rows use.
- The `weekly_plan_controller.dart` doc comment stops naming `c.forType` and `c.accent`.

### Ring colours are named in the theme

The six area hues, their tints and inks are deleted. The two the activity rings need survive
under ring names, with their current light and dark values unchanged:

- `AppColors.ringMove` (was `move`), `AppColors.ringRoutines` (was `rituals`).
- `areas_screen.dart` reads them. DESIGN.md section 3 ("Area colours are retired") names the two
  ring members. Section 10 is a record of what was done, so its rows stay: the area colour,
  accent, glass, shadow, type, mono and radius rows are updated to say the legacy members were
  deleted in this run and which ring members remain.
- The guard stays strict: no file exemption, no annotation.

### Retire

Once lib and test have zero matches, delete from `lib/theme/`:

- `AppType`: `caption2`, `footnote`, `title1`, `title2`, `title3`, `large`, `amount`, `amountLg`.
- `AppColors`: `money`, `move`, `rituals`, `nutrition`, `sleep`, `mood` with their `Tint` and `Ink`,
  `accent`, `accentTint`, `accentInk`, `onAccent`, `glass`, `glassBorder`, `glassHighlight`,
  `forType`, `inkForType`, and the `_glassAlpha` constant once unused.
- `Elevation.sm`, `Elevation.card` (`fab` stays).
- `AppFonts.sfr`, `AppFonts.mono`.
- `Radii.md`, `Radii.lg`.

Theme tests drop their assertions on retired members and keep the rest. The contrast test's
area-ink check goes with the inks; a check that the two ring colours differ in lightness by
1.5:1 or more in both themes replaces it, since DESIGN.md requires it. Doc comments in
controllers and models that name `forType` are reworded, so that no file in lib or test names
`forType` or `inkForType` afterwards (the guard pattern does not cover them).

### The guard

`test/theme/token_guard_test.dart` gains a second test: every `.dart` file under `lib/`
outside `lib/theme/` (excluding `.g.dart`, as the existing test does) must have no match for
the legacy pattern, comments included. The `kept literal` annotation does not apply to it.
The failure message lists `path:line` per offender.

### Goldens

After the retirement lands, every golden under `test/golden/goldens/` is regenerated with
`flutter test --update-goldens --tags golden`. Each changed image is looked at before it is
committed. A golden that looks broken (clipped, overlapping, unthemed, empty) is never
committed. A broken golden means broken rendering: the task fixes the cause in the screen and
regenerates, or, if the fix is beyond it, fails and escalates naming the image and what is wrong.
The golden suite passes on the committed images; there is no "known broken" escape, because
Final runs it. If the parallel run on routines, close-out and the You header has
landed on main first, main is merged before regenerating so the profile goldens include it.

### final_scenario_test

Its You step expects `Daily routines` and `MONEY`, which the You rebuild (c107c7c) removed, and
fails with `Bad state: No element`. The step is rewritten to what You shows now: scroll to and
assert the rows that now follow Goals (`Budgets`, `Reviews`), and keep the assertions that the
removed groups stay absent. Its Today, Areas, Money page, Back and Workout steps are checked
against the converted screens and updated where they drifted. No step is deleted.

### Line endings

- `.gitattributes`: `* text=auto eol=lf`, `*.sh text eol=lf`, and `*.png`, `*.jpg`, `*.ttf`,
  `*.otf`, `*.wasm` as `binary`.
- The index already holds every text file as LF (`git ls-files --eol`: 615 `i/lf`, 47 binary),
  so `git add --renormalize .` is expected to change nothing. It is run, and committed only if it
  changes no content beyond line endings; the report names what it touched.
- After it, `dart run build_runner build --delete-conflicting-outputs` must leave the committed
  `.g.dart` files unmodified in `git status`.

### Formatting

`lib/analysis/area_state.dart` and `test/analysis/area_state_test.dart` are run through
`dart format`, after `flutter pub get` so the package's formatter settings resolve.

## Already resolved on main

`email_dashboard_screen.dart` passes `c.ink` to `ProgressBar`; no legacy fill remains. The
retirement task's zero-match check confirms it.

## Out of scope

The parallel run's files (rituals_controller, day_plan, rituals_builder_screen, providers,
profile_screen, and snackbar copy in budgets_goals_screen, post_workout_screen and
routine_generator_screen) are not edited here. The `colorToken` strings on controllers and
models stay: they are data, and `insightIcon` still reads them.

## Verification

- Unit: `flutter test --exclude-tags "golden || scenario"` after each merge; analyze clean with
  `flutter analyze --fatal-infos`.
- The guard test fails if a legacy match is reintroduced.
- Final: `flutter test --tags "golden || scenario"`, including final_scenario_test, and a
  Today scenario step that opens the converted mood logger.
