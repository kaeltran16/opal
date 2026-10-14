# Budgets: Envelope Editor

**Effort:** effort:c4342184-d6c7-424a-be76-048d8a167e17
**Verify:** `flutter test --exclude-tags "golden || scenario"`
**Setup:** `flutter pub get`
**Check:** `flutter analyze --fatal-infos`
**Final:** `flutter analyze --fatal-infos && flutter test`
**Prototype:** C:\Users\cktra\Projects\opal\.superpowers\design\oura-envelope-editor\project\Main.dc.html

**Goal:** The inert "Budget options" control beside the Envelopes heading (`lib/screens/money/budgets_screen.dart:107-121`) opens an envelope editor. In the editor the user edits a cap with the keypad, adds an envelope (category, icon, cap), deletes one, reorders by drag, and applies a suggested cap. It also has empty, load-error and save-failure states, and amounts are formatted in USD and VND.

**Architecture:** One Riverpod stream controller, `BudgetEnvelopesController`, is the single source of truth for envelopes and owns every write. The five derived money providers, which today read envelopes once per entries emission, watch it instead, so an edit shows up everywhere straight away. The editor is a `SubScreen` pushed from Budgets. Its sheets (cap keypad, new envelope, delete confirm) live in one file that the Budgets screen also uses for "New envelope".

**Tech Stack:** Flutter, Riverpod with riverpod_generator (`dart run build_runner build --delete-conflicting-outputs`; generated `.g.dart` files are checked in), drift, go_router, flutter_test (scenario tests under `test/scenario/` tagged `scenario`).

## Design decisions beyond the prototype

The prototype (one interactive artboard, tweaks for theme, currency, data state and write failure) settles the layout, copy and states. These decisions are not in it, or differ from it on purpose:

1. **The prototype was approved autonomously.** Nobody was at the terminal, and the goal says to take the recommended option. The goal also names `.superpowers/design/oura-ai-first-workout` as the base, but that canvas no longer exists on disk (it was deleted when Workout shipped). So the prototype follows DESIGN.md, `lib/theme/` and the shipped Oura screens (`budgets_screen.dart`, `rituals_builder_screen.dart`, `sub_screen.dart`, `keypad.dart`).
2. **Route.** `/you/budgets/envelopes`, a new `AppRoute.envelopes('envelopes', 'envelopes')` nested under `youBudgets`, opened with `pushNamed` so that the `SubScreen` back control (which pops) returns to Budgets. `SubScreen(eyebrow: 'Budgets', title: 'Envelopes', backLabel: 'Budgets')`. Why: the editor is a sub-screen of Budgets, and the route keeps it deep-linkable for scenario tests.
3. **One source of truth.** `budgetsData`, `budgetRecommendations`, `budgetAdvisories`, `envelopeForecasts` and `insightsData` each call `getEnvelopes()` once per entries emission. Without a change, a cap edit would not reach Budgets or the suggestions until a new entry arrived. Each one watches `budgetEnvelopesControllerProvider.future` instead (root cause, fixed once in each reader), so the providers re-emit on any envelope write.
4. **Whole-unit caps.** The keypad hides its decimal key (`showDecimal: false`) in both currencies. The maximum is `100000 * currency.budgetScale`, the same bound Budgets & goals uses. The two step pills move by `kBudgetRoundingBaseUnit * currency.budgetScale` ($50 / 50.000 ₫), the unit suggested caps already round to, and are labelled through `formatCurrency`. The value clamps to [0, max], and Save/Add are disabled at 0. Why: caps are monthly round numbers, and the step reuses the existing rounding unit instead of adding a constant.
5. **The amount is the sheet's focal point.** `AppType.display` inside `FittedBox(fit: BoxFit.scaleDown)`, the same as the Budgets hero, so `1.250.000 ₫` fits at 390 wide. It is drawn in `ink3` while 0. The note line under it reads `<spent> spent so far this month` for an existing envelope (from `budgetsDataProvider`'s `EnvelopeSpend`; the line is left out when that data is not loaded) and `A month, from the 1st` for a new one.
6. **New envelope is one sheet with two steps.** Step one is the category and icon, with Next as the one primary pill. Step two is the cap, with Back and Add. Why: a text field and the custom keypad cannot share the screen without the system keyboard covering the keypad.
   - The category is trimmed, 1 to 40 characters, and must be unique under `normalizeCategory` (the same key spend matching uses). A duplicate shows `You already have a <name> envelope.` in `subhead` `ink2` and disables Next.
   - The picks under the field ("You spend on these without a cap") come from `budgetAdvisoriesProvider.unbudgeted`: the category with `<monthSpend> this month`. A pick that exactly matches the typed name is hidden, and tapping a pick fills the field. The list is left out when empty.
   - **A deliberate change from the prototype:** in the prototype, tapping a pick also selects that pick's icon. Here, tapping a pick fills only the name and leaves the icon selection alone, because `UnbudgetedCategory` carries no icon and inventing a category-to-icon mapping is speculative.
   - **Headers.** Step one: `Cancel` / `New envelope` / an empty slot the width of a text button, so the title stays centred. Step two: `Back` / the trimmed name / `Add`. The cap sheet's header is `Cancel` / the envelope's name / `Save`.
   - `Back` returns to step one and keeps the name and the selected icon. `Next` starts the cap at 0, as the prototype does. `Cancel` closes the sheet without writing anything.
7. **Icons.** The picker offers twelve line glyphs, stored by their stem names: `cup.and.saucer`, `basket`, `bolt`, `bag`, `car`, `tv`, `heart`, `house`, `fork.knife`, `creditcard`, `gift`, `airplane`. New envelopes, including ones created from a suggestion, default to `creditcard` (`kDefaultEnvelopeIcon`). The prototype preselects `basket` only because its fake data does. Seeded envelopes keep their `.fill` names; `AppIcon.line` draws their stems. Every envelope icon, on Budgets and in the editor, renders through `AppIcon.line` in `ink2`, never in a tile and never in an area colour. New envelopes store `colorToken: 'money'` (data only, like the seed).
   - **Picker layout:** a 6-column grid of 48-high pill cells under a `label` `ink3` heading `Icon`. The selected cell has a `surface2` fill with its glyph in `ink`; the others have no fill and `ink2` glyphs.
   - **Picker semantics:** the grid is one group. Each cell is a button with `inMutuallyExclusiveGroup: true` and `selected`/`checked` set for the chosen cell, labelled with its word: Cup, Basket, Bolt, Bag, Car, TV, Heart, House, Fork and knife, Card, Gift, Plane.
   - **A deliberate change from the prototype:** there, `Use` on a suggestion with no envelope creates it with a per-category icon from the fake data. Here it uses `kDefaultEnvelopeIcon`, because `BudgetRecommendation` carries no icon.
8. **Delete** starts from the cap sheet ("Delete envelope" in `careInk`). The confirm step replaces the sheet's content and has no header row:
   - the title `Delete <name>?`;
   - the body `Spending logged as <name> stays. It just has no cap.`;
   - a `Delete` pill (`surface2` fill, `careInk` text);
   - a `Cancel` text button that goes back to the cap step.

   On success the sheet closes. Survivors are reindexed to gap-free positions.
9. **Failures.** Every write goes through the controller. The UI catches it, logs with `debugPrint` including context, and shows `FailureNote`:
   - Cap save and add: `FailureNote()` (`saveFailedCopy`) inside the sheet, which stays open with the draft kept.
   - Delete: `FailureNote(deleteFailedCopy)` inside the confirm step. `deleteFailedCopy` ("Couldn't delete. Try again.") moves into `lib/widgets/failure_note.dart` beside `saveFailedCopy`, and the routines builder's private copy of it is deleted (DRY).
   - Reorder and apply suggestion: `FailureNote()` under the editor's summary line. The order reverts, because the stream never changed. Any later successful write, or any edit to the sheet's draft, clears the note.
10. **Reorder** persists in one drift transaction (`BudgetEnvelopeRepository.reorder`), so a failure never leaves positions half-written. Each row has a 44 by 44 `line.3.horizontal` drag handle labelled `Reorder <name>`, as in the routines builder. The list must drag correctly inside `SubScreen`'s scrolling `ListView`. The worker picks the mechanism (for example a shrink-wrapped `ReorderableListView.builder` with `NeverScrollableScrollPhysics`, or a `SliverReorderableList`).
11. **Suggested caps in the editor** come from `budgetRecommendationsProvider`. A row whose `currentCap == suggestedCap` is hidden. The subtitle reads `<avg>/mo · <trend word> · now <currentCap>` when the category has an envelope, or `No envelope yet · <avg>/mo` when it does not. The `Use` text button is labelled `Use <cap> for <category>`. Applying sets the cap of the matching envelope (matched by `normalizeCategory`), or creates one with `kDefaultEnvelopeIcon`. Budgets' own Suggested caps and advisories stay read-only: applying lives in the editor, so Budgets keeps one lead. The editor's section has the heading `Suggested caps` (`headline`) and the footer `From your spending over the last 3 months.` (the same string Budgets uses). The whole section, heading and footer included, is left out when no row remains.
12. **Editor states.**
    - Loading: `…` in `body` `ink3`, as on Budgets.
    - Load error: `Couldn't load your envelopes.` in `subhead` `ink3`, plus a `debugPrint`.
    - Empty: the summary line reads `Caps you set here pace this month’s spending.` and the list reads `No envelopes yet. Add one, or use a suggested cap below.` The New envelope row and the suggestions still show, and the `Tap an envelope to change its cap. Drag to reorder.` footer is left out.
    - Otherwise the summary reads `N envelopes · <sum of caps> a month` (`1 envelope` singular).
13. **The Budgets screen** gets five changes:
    - The options control becomes a real 44 by 44 button (label `Budget options`) that pushes the editor.
    - The inert `New envelope` row opens the same new-envelope sheet.
    - Envelope rows draw their icons with `AppIcon.line`.
    - With no envelopes, a hairline row under the Envelopes heading reads `No envelopes yet.` in `subhead` `ink3`, as the prototype draws it. Now that the editor can delete every envelope, the shipped screen would otherwise show nothing.
    - The footer copy becomes the prototype's `Adjust caps anytime. Pal nudges you before an envelope runs dry.` (no em dash, matching the earlier copy clean-up).

    **A deliberate change from the prototype:** the prototype's Budgets is shortened to the parts the flow passes through. The shipped Suggested caps, the advisories and the `Roll unused into next month` row stay where they are, between the envelope rows and New envelope. The Roll row is out of scope and stays inert.

## Global Constraints

- Touch only the files in the task's Files line, generated `.g.dart` files included.
- Colours, type, spacing and radii come only from `lib/theme/` (`context.colors`, `AppType`, `Spacing`, `Radii`). Name any new measurement as a file-level const. If the token guard (`test/theme/token_guard_test.dart`) fails, fix it with a name in `lib/theme/`, never with a `kept literal` annotation or a looser guard.
- No area colours in chrome, never ring a budget, one primary pill per screen or sheet, and every tap target at least 44 by 44. State colour appears only with its word.
- Amounts always go through `formatCurrency(amount, currency)` with the currency from `appSettingsControllerProvider`. Tabular figures wherever a number can change.
- Regenerate only the goldens your change moves (`flutter test --update-goldens <that golden test file>`), and say which ones in the task report. None are expected: no golden renders Budgets.
- Do not loosen any existing test.
- Writes from full-app widget or scenario tests may need `tester.runAsync` for the drift future to complete, before the pop that follows it can run (a known issue: effort chunk 36). Use `runAsync` or a repository override, never a sleep.
- Scenario steps use `scenarioTest` from `test/scenario/scenario_harness.dart` (it registers light and dark) and `shot(tester, '<name>_${dark ? 'dark' : 'light'}')`. Fail writes with a repository subclass override, as `defects_scenario_test.dart` does (`_FailingGoals`). The Final line (`flutter test`, no tag exclusion) runs every step in `test/scenario/envelope_editor_scenario_test.dart`.
- **Scenario fixture.** `bootToday` seeds only reference data, so the envelope scenario file boots with its own `_boot`, modelled on `pal_money_settings_scenario_test.dart`'s `_boot`: an in-memory `LoopDatabase` with `Seeder(db).seedIfNeeded()`, which writes `SeedData.budgetEnvelopes()`. It then adds scenario-local expense entries through the entry repository, relative to `goldenClock`:
  - Groceries spend in each of the three completed months, enough that its recommendation's `suggestedCap` differs from its seed cap of 500;
  - this-month spend in a category with no envelope (`Coffee`), above the advisory floor, so it appears both as a suggestion with no envelope and as a pick.

  The fixture asserts that these rows render before any step relies on them. Task 4 creates `_boot` and the fixture; Task 5 reuses them.

## Review Focus

- One source of truth: no screen or provider reads envelopes one-shot after Task 2.
- A failed write never closes a sheet, loses a draft or half-applies a reorder.
- The VND cap sheet shows `1.250.000 ₫` without clipping at 390 wide, and the steps read `50.000 ₫`.
- Duplicate detection uses `normalizeCategory`, not a raw lower-case compare.

---

### Task 1: Envelope controller and transactional reorder

**Depends on:** none
**Model:** claude-opus-5-5
**Files:** `lib/data/repositories/budget_envelope_repository.dart`, `lib/controllers/budget_envelopes_controller.dart`, `lib/controllers/budget_envelopes_controller.g.dart`, `test/data/budget_envelope_repository_test.dart`, `test/controllers/budget_envelopes_controller_test.dart`

Add `Future<void> reorder(List<BudgetEnvelope> envelopes)` to `BudgetEnvelopeRepository`. It writes `position = index` for every envelope in the list inside one `_db.transaction`.

Create `BudgetEnvelopesController` with `@Riverpod(retry: noRetry)`, following `RitualsBuilderController`'s idiom. Other tasks rely on this interface:

```dart
const String kDefaultEnvelopeIcon = 'creditcard';
const int kMaxEnvelopeNameLength = 40;

/// Whether [name] (trimmed) already names an envelope, by normalizeCategory.
bool isDuplicateEnvelope(List<BudgetEnvelope> envelopes, String name);

class BudgetEnvelopesController extends _$BudgetEnvelopesController {
  Stream<List<BudgetEnvelope>> build(); // repo.watchEnvelopes()
  Future<void> setCap(String id, double cap);
  Future<void> add({required String category, required String icon, required double cap});
  Future<void> delete(String id); // then reindexes survivors 0..n-1
  Future<void> reorder(int oldIndex, int newIndex); // post-removal newIndex, as onReorderItem gives it
  Future<void> applyCap(String category, double cap, {String icon = kDefaultEnvelopeIcon});
}
```

- Reads for writes come from `repo.getEnvelopes()`, not the streamed state (so back-to-back calls cannot race the stream).
- `add` assigns a `Uuid().v4()` id, `position = max + 1` (0 when empty) and `colorToken: 'money'`.
- `add` and `setCap` throw `ArgumentError` for a cap that is not finite or is 0 or below. `add` also throws for an empty, over-long or duplicate category.
- `applyCap` updates the envelope that matches under `normalizeCategory`, or adds one.
- Repository errors propagate to the caller unchanged.

Tests:

- **Repository**, against `LoopDatabase.forTesting(NativeDatabase.memory())`: reorder rewrites positions; a reorder that throws mid-way (a failing envelope id or a forced throw) leaves the original positions.
- **Controller**, with a `ProviderContainer` over the in-memory database:
  - add appends at the end with a fresh id;
  - add rejects a duplicate that differs only in case or spacing;
  - setCap changes only that envelope;
  - delete reindexes the survivors;
  - reorder moves first-to-last and last-to-first;
  - applyCap updates an existing envelope, case-insensitively;
  - applyCap creates a missing one with `kDefaultEnvelopeIcon`;
  - a repository that throws makes each write method throw.

### Task 2: Money providers watch the envelopes stream

**Depends on:** Task 1
**Model:** claude-sonnet-5-5
**Files:** `lib/controllers/budgets_controller.dart`, `lib/controllers/budgets_controller.g.dart`, `lib/controllers/budget_recommendations_controller.dart`, `lib/controllers/budget_recommendations_controller.g.dart`, `lib/controllers/budget_advisories_controller.dart`, `lib/controllers/budget_advisories_controller.g.dart`, `lib/controllers/budget_forecast_controller.dart`, `lib/controllers/budget_forecast_controller.g.dart`, `lib/controllers/insights_money_controller.dart`, `lib/controllers/insights_money_controller.g.dart`, `test/controllers/budget_envelopes_reactivity_test.dart`

Change `budgetsData`, `budgetRecommendations`, `budgetAdvisories`, `envelopeForecasts` and `insightsData`:

- Replace each one's per-emission `await envelopeRepo.getEnvelopes()` with `await ref.watch(budgetEnvelopesControllerProvider.future)`, watched before the entries `await for`, so an envelope write re-runs the provider.
- Drop the now-unused `budgetEnvelopeRepositoryProvider` watch.
- Update each doc comment that says "Reads envelopes one-shot per emission".
- Regenerate with build_runner.

Tests (new file, in-memory database, real providers): after `BudgetEnvelopesController.setCap`, each of `budgetsDataProvider`, `budgetRecommendationsProvider` (`currentCap`), `budgetAdvisoriesProvider` (an unbudgeted category disappears after `add`), `envelopeForecastsProvider` and `insightsDataProvider` emits a value that reflects the change, without any entry write. Existing tests for these providers must still pass unchanged, or with override updates only.

### Task 3: Envelope line glyphs and shared delete copy

**Depends on:** none
**Model:** claude-sonnet-5-5
**Files:** `lib/widgets/app_icon.dart`, `test/widgets/app_icon_test.dart`, `lib/widgets/failure_note.dart`, `lib/screens/rituals/rituals_builder_screen.dart`

- Add line stems to `_sfMap` so that every picker glyph in decision 7, and the seed's `.fill` names, draw as outlines through `AppIcon.line`:
  - `bag` → `CupertinoIcons.bag`
  - `car` → `CupertinoIcons.car`
  - `tv` → `CupertinoIcons.tv`
  - `basket` → `Icons.shopping_basket_outlined`
  - `house` → `CupertinoIcons.house`
  - `creditcard` → `CupertinoIcons.creditcard`
  - `gift` → `CupertinoIcons.gift`
  - `airplane` → `CupertinoIcons.airplane`

  `cup.and.saucer`, `bolt`, `heart` and `fork.knife` already exist.
- Add `const String deleteFailedCopy = "Couldn't delete. Try again.";` to `failure_note.dart`, and replace the routines builder's private `_deleteFailedCopy` with it.

Tests: for each of the twelve picker names, and for `bag.fill`, `car.fill`, `tv.fill`, `basket.fill` and `house.fill`, `lineIconForSf` returns a mapped glyph, not the `CupertinoIcons.circle` fallback, and it differs from `iconForSf` of the `.fill` name where a stem was added.

Scenario coverage, all run by Final:
- **Rituals delete copy:** the existing `manage_delete_failed` step in `test/scenario/defects_scenario_test.dart` already shows and asserts "Couldn't delete. Try again." on the routines builder. It must still pass unchanged.
- **Glyphs:** shown on Budgets by Task 5's `budgets_line_glyphs` and in the editor by Task 4's `envelopes_list` and `envelopes_add_name`.

### Task 4: Envelope editor screen, sheets and route

**Depends on:** Task 1, Task 3
**Model:** claude-opus-5-5
**Files:** `lib/screens/money/envelope_editor_screen.dart`, `lib/screens/money/envelope_sheets.dart`, `lib/router.dart`, `test/screens/money/envelope_editor_screen_test.dart`, `test/screens/money/envelope_sheets_test.dart`, `test/scenario/envelope_editor_scenario_test.dart`

Build the editor exactly as the prototype draws it, with decisions 2 and 4 to 12.

- **`envelope_editor_screen.dart`** holds `EnvelopeEditorScreen`. It watches `budgetEnvelopesControllerProvider`, `budgetRecommendationsProvider`, `budgetsDataProvider` (for spend) and the currency.
- **`envelope_sheets.dart`** holds the sheets. Task 5 relies on this public entry point:
  `Future<void> showNewEnvelopeSheet(BuildContext context, WidgetRef ref)`, which opens the two-step add sheet and writes through the controller.
  Also expose `showEnvelopeCapSheet(BuildContext context, WidgetRef ref, BudgetEnvelope envelope)`.
  Use `showAppSheet(..., scrollable: true)` from `lib/widgets/app_sheet.dart` and the existing `Keypad`. Use a Cancel/title/Save header like the routines builder's `_SheetHeader`, with Save disabled through `Semantics(enabled: false)`.
- **Router:** add `AppRoute.envelopes` under `youBudgets`.

Widget tests (light theme, provider overrides or an in-memory database):

- **Keypad and steps:**
  - typing `1`,`2`,`5`,`0` on the keypad shows `$1,250`;
  - delete removes a digit;
  - `+ $50` and `− $50` step, clamp at 0, and stop at the max;
  - in VND the steps read `50.000 ₫` and 1250000 shows `1.250.000 ₫`.
- **Saving:**
  - Save is disabled at 0;
  - Save calls `setCap` with the whole-unit value and closes the sheet;
  - a throwing `setCap` shows exactly one `FailureNote` with `saveFailedCopy`, keeps the sheet and the draft, and the next keypad press clears the note.
- **Adding:**
  - Next is disabled for an empty name and for a duplicate (with the note);
  - a pick fills the name and leaves the icon selection alone;
  - the icon grid has twelve cells with the word labels, and exactly one is selected (`kDefaultEnvelopeIcon` at first);
  - tapping a cell moves the selection;
  - Back from step two shows step one with the name and icon kept;
  - Cancel closes the sheet without calling `add`;
  - Add calls `add` with the trimmed name, the selected icon and the cap.
- **Cap sheet title:** the envelope's name.
- **Deleting:** the delete confirm calls `delete`. A throwing delete shows `deleteFailedCopy`. Cancel on the confirm returns to the cap step with the draft kept.
- **Reordering:** dragging a handle calls `reorder`. A throwing reorder shows the list `FailureNote`.
- **Suggestions:** a `Use` button calls `applyCap(category, suggestedCap)`. A row with `currentCap == suggestedCap` is hidden.
- **Suggestions section:** the `Suggested caps` heading and footer show with the rows, and are left out when no row remains.
- **States:** the loading ellipsis, the empty state copy, and the load-error copy.
- **Semantics:**
  - each row's label is `<name>, <cap> a month. Edit cap`;
  - handles are `Reorder <name>`;
  - every interactive element is at least 44 by 44 (`meetsGuideline(androidTapTargetGuideline)` or explicit size checks).

Create `test/scenario/envelope_editor_scenario_test.dart` with the `_boot` and fixture from Global Constraints. It opens the route `/you/budgets/envelopes`. Each step uses `scenarioTest`, so it runs light and dark, asserts what it shows, and ends in a `shot` named after the step. Final runs every one:

- `envelopes_list`: the seeded rows with line glyphs and caps, the summary line, and the Suggested caps section with the Groceries and Coffee rows.
- `envelopes_loading`: the controller overridden with a stream that never emits; asserts the ellipsis.
- `envelopes_cap_keypad`: Groceries open (title `Groceries`), `1250` typed, asserts `$1,250`.
- `envelopes_cap_stepped`: `+ $50` tapped twice and `− $50` once from 500; asserts `$550`.
- `envelopes_cap_vnd`: currency set to VND (`prefs: {'settings.currency': 'VND'}`); asserts a cap sheet showing `1.250.000 ₫` and steps labelled `50.000 ₫`.
- `envelopes_cap_save_failed`
- `envelopes_add_name`: picks visible (Coffee), the duplicate note shown for `groceries`, all twelve picker cells rendered with exactly one selected.
- `envelopes_add_picked`: the Coffee pick tapped and the Gift cell chosen; asserts the field reads `Coffee` and Gift is selected.
- `envelopes_add_cap`: step two showing `Coffee` with a cap typed.
- `envelopes_add_back`: Back from step two; asserts step one with `Coffee` and Gift kept.
- `envelopes_added`: the new Coffee row in the list, drawing the gift line glyph.
- `envelopes_delete_confirm`
- `envelopes_delete_cancelled`: Cancel on the confirm; asserts the cap sheet is back with its draft.
- `envelopes_delete_failed`
- `envelopes_deleted`
- `envelopes_reordered`: a drag via the handle, with the new order asserted.
- `envelopes_reorder_failed`
- `envelopes_suggestion_failed`
- `envelopes_empty`: every envelope deleted, or an empty-database override.
- `envelopes_load_error`: the controller overridden to error.

### Task 5: Budgets wiring and end-to-end steps

**Depends on:** Task 2, Task 4
**Model:** claude-sonnet-5-5
**Chunk:** Budgets: build an envelope editor behind the 'Budget options' control (beside the Envelopes heading)
**Files:** `lib/screens/money/budgets_screen.dart`, `test/screens/money/budgets_screen_test.dart`, `test/scenario/envelope_editor_scenario_test.dart`

Make the five Budgets changes in decision 13. The options control pushes `AppRoute.envelopes` by name, and the "New envelope" row calls `showNewEnvelopeSheet`. Keep the row's look; make it a button with a 48 minimum height. Envelope rows use `AppIcon.line(env.icon, ...)`. Add the empty row and the new footer copy.

Widget tests:

- tapping `Budget options` (found by semantics label) pushes the editor;
- tapping New envelope opens the add sheet;
- envelope rows render the line glyph (`lineIconForSf`) for a seed `.fill` name;
- with no envelopes, `No envelopes yet.` shows under the heading;
- the footer reads the new copy;
- the existing budgets tests still pass, with only the footer string updated where a test pins it.

Add these steps to `test/scenario/envelope_editor_scenario_test.dart`, reusing Task 4's `_boot` and fixture. Each asserts what it shows before it shoots, and Final runs every one:

- `budgets_options_opens_editor`: on `/you/budgets`, tap the options control and assert that the editor title `Envelopes` shows.
- `budgets_after_cap_edit`: change Groceries' cap in the editor, go back, and assert that the Groceries row's `left` amount reflects the new cap (proves Task 2's reactivity end to end).
- `budgets_new_envelope`: the add sheet opened from the Budgets row.
- `budgets_empty`: Budgets with every envelope deleted; asserts `No envelopes yet.`
- `envelopes_suggestion_applied`: tap `Use` on Groceries, then assert that the Groceries cap shows the suggested amount and its suggestion row is gone. Tap `Use` on Coffee, then assert that a Coffee row exists with the `creditcard` line glyph.
- `budgets_line_glyphs`: Budgets with its envelope rows. Assert that the Groceries row's icon is `lineIconForSf('basket.fill')` and not `iconForSf('basket.fill')`, and that the footer copy is the new string.
