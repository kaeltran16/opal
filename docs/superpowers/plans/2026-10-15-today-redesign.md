# Today Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Today redesign approved 10-15 (effort c4342184, chunk 122). Pal's line is about the card. The whole day is a quiet list. Undo is a named toast. Put-offs and approvals are saved for the day.

**Architecture:**
- The code still picks the lead.
- The `/v1/agenda` request also carries the day's open local items as facts. The server words one sentence per item in a second, parallel model call, checks every number against that item's facts, and returns the sentences as `lines`.
- Today shows the line for the item the code picked. When Pal is offline, or has no line for that item, Today shows the item's own sentence.
- `PlanSession` loses tap-to-swap. It gains named changes, a notice that the shell renders as a toast above the composer, and a settled map saved to SharedPreferences under the day's date.

**Tech Stack:** Flutter, Riverpod 3 codegen, drift, SharedPreferences, flutter_test scenario harness; TypeScript server (zod, vitest) and Cloudflare worker.

**Effort:** effort:c4342184-d6c7-424a-be76-048d8a167e17
**Verify:** `sh -c 'c="${ARC_VERIFY_CHANGED:-}"; f=1; s=1; if [ -n "$c" ]; then grep -qE "^(lib|test|pubspec|assets)" "$c" || f=0; grep -q "^server/" "$c" || s=0; fi; if [ $f = 1 ]; then flutter test --exclude-tags "golden || scenario" || exit 1; fi; if [ $s = 1 ]; then (cd server && npx vitest run) && (cd server/worker && npx vitest run) || exit 1; fi'`
**Setup:** `flutter pub get && (cd server && npm ci) && (cd server/worker && npm ci)`
**Check:** `flutter analyze --fatal-infos && (cd server && npx tsc -p tsconfig.json --noEmit) && (cd server/worker && npx tsc -p tsconfig.json --noEmit)`
**Final:** `flutter test --tags scenario test/scenario/today_scenario_test.dart test/scenario/undo_toast_scenario_test.dart test/scenario/you_scenario_test.dart test/scenario/defects_scenario_test.dart test/scenario/final_scenario_test.dart test/scenario/routines_onboarding_scenario_test.dart test/scenario/pal_money_settings_scenario_test.dart`
**Prototype:** C:/Users/cktra/Projects/opal/.superpowers/design/today-redesign/project/Main.dc.html

## Design decisions beyond the canvas

The canvas (`Main.dc.html`, clicked through in Chrome before planning) settles the layout. `Before.dc.html` is a screenshot of the screen being replaced. Its Final step is `today_old_shapes_gone` (Task 6), which asserts that what it shows is gone: the day summary above the card, the header Undo, the `N more later today` fold, and the `Do this next` row labels. Where the canvas and the goal differ, the goal wins. Each call below was made without a human, as the recommended option.

1. **Where Pal's line comes from: extra fields on `/v1/agenda`, not a new endpoint.**
   - The request gains `plan`: the open local items (not proposals), each with an opaque `key` and its facts (`title`, `when`, `status`, `steps`, `why`).
   - The response gains `lines: [{key, line}]`.
   - The worker runs `Pal.agenda` and a new `Pal.leadLines(plan)` in parallel and merges the results. Why a separate model call: the line prompt stays focused, and a failed or invalid line never costs the proposals (or the reverse). It also keeps the change additive beside run 3cdfeff3's rework of `Pal.agenda`.
   - A line-call failure is logged and returns `lines: []`.
2. **One line per open item, not only for the current lead.** After "Not today" the next card already has its line, so put-offs need no refetch.
3. **The model never picks and never invents numbers.**
   - The prompt sends only the item facts and asks for one sentence about that item.
   - `lineAgrees` drops any line that states a number (digits, or the words zero to twenty) that its item's facts do not hold. There is no redraw, because the fallback is cheap.
4. **A line is used only while its facts still hold.**
   - The client builds `key` from the item id, its status and its steps detail, so after a step is logged or the clock moves the item to missed, the key no longer matches.
   - Today then shows the item's own sentence until the next agenda fetch. The agenda is not refetched on every change, which keeps model calls bounded.
5. **Line precedence on Today:**
   - no lead: `Nothing is left. Rest up.`;
   - a proposal leads: its body;
   - online with a line for the lead's current key: the line;
   - otherwise: the item's own sentence (`said`), else its title.

   "Online" is `!agenda.hasError`, as today.
6. **The day summary leaves Today.** `todayBriefProvider` (`insights(day)`) has no other reader, so it is deleted with its test. Recap's Day range already shows the summary.
7. **Why this first:** it shows whenever Pal is online and there is a lead, and opens the composer with `whyNote` as today. `reasonFor` is pulled out of `whyNote` and also feeds each fact's `why`.
8. **The list is every item of the day**, timed by minute first, then untimed in build order. Done and put-off items stay.

   | Row | Detail under the title | Tap |
   |---|---|---|
   | open | `item.detail` (`2 of 4 steps`, `45 min`), or `Pal suggests` for a proposal | `actOnPlanItem` |
   | missed open | `Missed · <detail>`, or `Missed` | `actOnPlanItem` |
   | put off | `Put off until tomorrow` | brings it back |
   | done | `Done`; mood: the mood word; approved proposal: its `doneLabel` | inert, except mood (opens the logger, verb `Check in again`) |

   - Routine and close-out details read `3 steps` with none done, else `2 of 4 steps`.
   - The screen-reader label is `<verb>: <title>, <detail>`. An inert row has no verb and is not a button.
   - The header reads `Your day · N of M done`. N counts items that are done or approved; M counts all rows.
9. **Mood after a check-in is a done row (ticked, ink3) that reopens the logger.** This supersedes run 3cdfeff3's Task 9 (an open, trailing `Check in again` item) on Today; the lead keeps this at merge.
10. **The toast lives in the shell**, above the composer. It shows on Today and on You, where Pal suggests approves and puts off too.
    - It names the change, offers `Undo` when the change is undoable, and leaves after 6 seconds.
    - Undo awaits `PlanSessionController.undo()`, which reverses the change and saves. A failed undo shows `Couldn't save. Try again.` (3cdfeff3's copy).
    - Toast copy:
      - put off: `Put off until tomorrow: <title>`;
      - approve: the proposal's `doneLabel`;
      - bring back: `<title> is back on today`, with no Undo.
    - When run 3cdfeff3 lands, its per-kind app copy replaces the approve label, and its repository reversals run inside `undo()`. Approve is `Added <step> to <routine>` or `Planned <routine> for <tomorrow|weekday>`. The weekly plan has no slot times, so the canvas's "at 7:00 AM" is dropped.
11. **Persistence follows `SettingsRepository`** (SharedPreferences, `settings.*` keys).
    - Key `settings.today.planSettled` stores `{"day":"yyyy-MM-dd","settled":{id: bool}}`.
    - A stored day that is not today reads as empty, so the next day starts fresh.
    - `PlanSessionController.syncDay(now)` resets a session left running across midnight. Today calls it on its minute tick and on resume.
    - Undo history is not saved, because the toast is gone after a relaunch anyway.
12. **The workout's done detail is `Done`.** The plan has no actual duration, only the estimate, so the canvas's "52 min" is not shown.
13. **Taps open; only in-place changes toast.**
    - In the canvas, the card pill and a row tap settle the item with a toast such as `Morning done`. That is the prototype standing in for the real flows.
    - Per the goal, a tap opens what it names (`actOnPlanItem`): the routine player, Start workout, the close-out, the composer or the mood logger. None of these shows a toast; the item ticks when the flow finishes it.
    - A toast names only a change made in place on the plan: put off, approve, bring back.
14. **The toast's position does not move with the ask bar.** When the ask bar minimizes beside the tab bar on scroll, the toast stays at the expanded composer's top (`kShellOverlay` above the bottom safe area). It then never overlaps either bar, and it does not jump while the user scrolls.
15. **Goldens.** Task 6 regenerates `today_light/dark.png` and `pal_composer_light/dark.png`, which show Today, and no other golden.

## Global Constraints

- **Tests first.** Each task writes its failing tests first, then makes them pass. Tests check behaviour, not internals.
- **Style.** Comments are lower case and say only why. No magic numbers: name constants as the surrounding files do. No new dependencies. No emojis.
- **Tokens.** Sizes, colours and type come from `lib/theme/` (`Spacing`, `Radii`, `AppType`, `context.colors`). A token-guard failure (`test/theme/token_guard_test.dart`) is fixed with a `lib/theme` name, never an annotation or a looser guard.
- **Accessibility.** Every tappable control is at least 44px and has a semantics label.
- **Codegen.** Run `dart run build_runner build --delete-conflicting-outputs` and commit the `.g.dart` files it changes. Only the task that lists a `.g.dart` file regenerates it. `test/codegen_hash_test.dart` must pass.
- **Exact copy:**
  - `Nothing is left. Rest up.`
  - `Pal is offline · next on the clock`
  - `Why this first`
  - `Your day`
  - `Put off until tomorrow`
  - `Put off until tomorrow: <title>`
  - `<title> is back on today`
  - `Any time`
  - `Missed`
  - `Pal suggests`
  - `Done`
  - `Check in again`
  - `Bring back`
  - `Undo`
  - `Couldn't save. Try again.`
- **Parallel runs.** Runs 8602490a and 3cdfeff3 edit `today_screen.dart`, `day_plan.dart`, `plan_session_controller.dart`, `prompts.ts`, `pal.ts` and the Pal service. Do not reformat or reorganise code you are not changing. Workers do not merge main; the lead does.
- **Scenario files** follow `test/scenario/today_scenario_test.dart`: the `scenario` tag, `scenario_harness.dart`, and `shot()` in light and dark.
- **Commits.** Subjects use the repo's `type(scope): summary` style, with no attribution or co-author trailer.
- **Fake-async stalls.** Widget tests that boot the full `LoopApp` can stall after a repository write; wrap such writes in `tester.runAsync`, as existing tests do.

## Review Focus

- **Pal goes offline after a line was fetched.** The error still holds the old agenda value, but Today must show the item's own sentence and hide Why. Pinned in Task 5 (`leadLine`) and Task 6.
- **The lead's facts change after the fetch.** For example, a close-out step is logged and the item goes from `3 steps` to `1 of 3 steps`. The old line must not show. Pinned in Task 5.
- **A put-off made at 11:58 PM, with the app left open past midnight.** The item is open again on the new day without a relaunch. Pinned in Task 3 (`syncDay`) and in Task 6's mutable-clock test (the minute tick).
- **A model line stating a number its facts do not hold.** For example, "Three steps left" for `2 of 4 steps` is dropped server-side. Pinned in Task 1.
- **An older client sends no `plan`.** `/v1/agenda` still returns 200, with `lines: []` and no line model call. Pinned in Task 1.

---

### Task 1: Server: agenda lines from the day's plan facts
**Depends on:** none
**Files:** `server/src/schemas.ts`, `server/src/prompts.ts`, `server/src/pal.ts`, `server/src/pal.test.ts`, `server/src/prompts.test.ts`, `server/worker/src/worker.ts`, `server/worker/test/pal-stateless.test.ts`

**Interfaces (produces, the wire contract Task 2 decodes):**
- Request body: `{context, plan?: PlanFact[]}`. `PlanFact = {key: string, title: string, when: string, status: 'due'|'upcoming'|'missed'|'anytime', steps: string|null, why: string}`.
  - In `schemas.ts`, `agendaBody` gains `plan: z.array(planFact).max(20).default([])`. Strings are bounded (key ≤ 200 chars, others ≤ 300).
- Response: the existing agenda JSON plus `lines: Array<{key: string, line: string}>`. The array has at most one entry per request key, and only keys that were sent.
- `Pal.leadLines(plan: PlanFact[]): Promise<Array<{key: string, line: string}>>`. An empty `plan` returns `[]` with no model call.
- `leadLinesPrompt(plan: PlanFact[]): string` in `prompts.ts`.
- `lineAgrees(line: string, fact: PlanFact): boolean` in `pal.ts`, exported for tests.

**Do:**
- [ ] Write failing tests:
  - `prompts.test.ts`: the prompt lists each item's key and facts, includes `PLAIN_TEXT`, and says to write one sentence per key about that item, of 20 words or fewer. It must not pick or order items, and must state no number its facts do not hold.
  - `pal.test.ts`:
    - lines come back keyed by request key;
    - unknown keys and repeats are dropped;
    - markup is stripped (use the existing `prose` schema);
    - a line stating a number its facts do not hold is dropped. Examples: `Three steps left` against steps `2 of 4 steps` is dropped; `Two steps left` is kept; `9:30` is kept against when `9:30 PM`;
    - an empty plan makes no model call.
  - `lineAgrees` unit cases: digits, the number words zero to twenty, and times.
  - `pal-stateless.test.ts`:
    - `/v1/agenda` with a `plan` returns `lines`;
    - without `plan` it returns `lines: []` and the line prompt is never sent;
    - when the line call throws, proposals still return with `lines: []` and the failure is logged (`console.warn` with the route), not swallowed silently.
- [ ] Implement:
  - `leadLinesPrompt` returns JSON `{"lines":[{"key":string,"line":string}]}`. It uses the agenda's temperature 0 and a small max-token budget, named as a const.
  - `Pal.leadLines` validates through `lineAgrees`.
  - The worker's `/v1/agenda` handler runs `Promise.all([pal.agenda(...), pal.leadLines(plan).catch(log → [])])` and returns `{...agenda, lines}`.
- [ ] Run: `cd server && npx vitest run src/pal.test.ts src/prompts.test.ts && npx tsc -p tsconfig.json --noEmit` and `cd server/worker && npx vitest run test/pal-stateless.test.ts && npx tsc -p tsconfig.json --noEmit`.

**Acceptance:** the tests above pass, and both `tsc` runs (`server/` and `server/worker/`) are clean. No client change is needed for an older client. There is no rendered view, so there is no scenario step.

### Task 2: Client agenda contract: plan facts out, lines in; test fixture relaunch
**Depends on:** none
**Files:** `lib/services/pal/pal_service.dart`, `lib/services/pal/http_pal_service.dart`, `lib/services/pal/mock_pal_service.dart`, `test/support/today_fixture.dart`, `test/services/http_pal_service_test.dart`, `test/services/mock_pal_service_test.dart`, `test/scenario/you_scenario_test.dart`, `test/controllers/insights_controller_test.dart`, `test/controllers/pal_action_executor_test.dart`, `test/controllers/pal_agenda_controller_test.dart`, `test/controllers/pal_composer_controller_test.dart`, `test/controllers/pal_pick_controller_test.dart`, `test/controllers/routine_generator_controller_test.dart`, `test/controllers/weekly_review_controller_test.dart`, `test/monthly_review_test.dart`, `test/screens/pal/pal_composer_sheet_test.dart`, `test/screens/pal/pal_meal_card_test.dart`

**Interfaces (produces):**
- In `pal_service.dart`:
  ```dart
  /// One open item of the day, as the agenda call words Pal's line about it.
  class PlanFact {
    const PlanFact({required this.key, required this.title, required this.when,
        required this.status, this.steps, required this.why});
    final String key, title, when, status; // status: PlanFact.due|upcoming|missed|anytime
    final String? steps;
    final String why;
    static const due = 'due', upcoming = 'upcoming', missed = 'missed', anytime = 'anytime';
    Map<String, Object?> toJson();
  }
  ```
- `PalAgenda` gains `final Map<String, String> lines` (key → line, default `const {}`).
- `PalService.agenda({List<PlanFact> plan = const []})`, also implemented by `HttpPalService` and `MockPalService`.
- `today_fixture.dart`:
  - `TodayPal` gains `Map<String, String>? linesByTitle`. Its agenda returns a line for each received fact whose title has an entry.
  - `TodayPal` gains `final List<List<PlanFact>> plans`, which records each call's plan.
  - New `Future<void> relaunchToday(WidgetTester tester, {MockPalService? pal})`. It pumps an empty widget, then a fresh `ProviderScope` + `LoopApp` that reuses the same SharedPreferences instance and database as the last `bootToday`, so it is a relaunch.
  - Keep `TodayPal.headline` for now; Task 6 removes its last use.

**Do:**
- [ ] Write failing tests:
  - `http_pal_service_test.dart`:
    - `agenda(plan:)` posts `plan` as JSON;
    - it decodes `lines` into the map, dropping keys it did not send and blank lines;
    - a payload with no `lines` gives `{}`.
  - `mock_pal_service_test.dart`: the mock returns one deterministic line per fact, keyed by `fact.key`, with copy by status:
    - `<title> is due now.`
    - `<title> is next, at <when>.`
    - `<title> was missed. It is still open if you want it.`
    - `<title> fits any time today.`
- [ ] Implement the above. Update every `agenda()` override to the new signature `agenda({List<PlanFact> plan = const []})`, with no behaviour change. A fake without the named parameter is an invalid override that fails to compile. The overrides are in every test file on the Files line besides the two service tests: `today_fixture.dart`, `you_scenario_test.dart`, the seven controller tests (`pal_action_executor_test.dart` has two), `monthly_review_test.dart`, `pal_composer_sheet_test.dart` and `pal_meal_card_test.dart`. Confirm none is left with `grep -rn "Future<PalAgenda> agenda()" lib test`, which must print nothing.
- [ ] Run: `flutter test test/services/http_pal_service_test.dart test/services/mock_pal_service_test.dart test/controllers/pal_agenda_controller_test.dart test/controllers/pal_action_executor_test.dart`.

**Acceptance:** the tests pass; `flutter analyze --fatal-infos` is clean. There is no rendered change, so there is no scenario step.

### Task 3: Plan session: named changes, put-offs saved for the day, no tap-to-swap
**Depends on:** none
**Files:** `lib/screens/today/day_plan.dart`, `lib/controllers/plan_session_controller.dart`, `lib/controllers/plan_session_controller.g.dart`, `lib/data/repositories/settings_repository.dart`, `lib/screens/profile/profile_screen.dart`, `lib/screens/today/today_screen.dart`, `test/screens/day_plan_test.dart`, `test/controllers/plan_session_controller_test.dart`, `test/settings_repository_test.dart`, `test/today_screen_test.dart`, `test/scenario/today_scenario_test.dart`, `test/pal_home_test.dart`, `test/scenario/routines_onboarding_scenario_test.dart`

**Interfaces (produces):**
- In `day_plan.dart`:
  ```dart
  class PlanChange { const PlanChange({required this.id, required this.label}); final String id, label; }
  class PlanNotice { const PlanNotice({required this.label, required this.undoable}); final String label; final bool undoable; }
  class PlanSession {
    const PlanSession({required this.day, this.settled = const {}, this.history = const [], this.notice});
    final DateTime day;                 // start of the local day it belongs to
    final Map<String, bool> settled;    // true done, false put off (name kept: You and tests read it)
    final List<PlanChange> history;
    final PlanNotice? notice;           // a new instance per change, so the toast restarts
    PlanSession settle(String id, {required bool done, required String label});
    PlanSession undo();                 // pops the last change, clears notice
    PlanSession bringBack(String id, {required String label}); // unsettles, drops id from history, notice not undoable
    PlanSession dismissNotice();
    bool get canUndo;
  }
  ```
- `PlanItem` gains `final String? doneDetail`. `proposalItem` sets it to `p.doneLabel`.
- `selected`, `select()`, `palPick()` and `isPalPick()` are removed. `current()` is `open().firstOrNull`.
- `PlanSessionController` (still `keepAlive`):
  - `build()` loads today's saved map;
  - `void putOff(PlanItem item)` uses the label `Put off until tomorrow: <title>`;
  - `void approve(PlanItem item)` uses the label `item.doneDetail ?? item.title`;
  - `void bringBack(PlanItem item)` uses `<title> is back on today`;
  - `Future<void> undo()`;
  - `void dismissNotice()`;
  - `void syncDay(DateTime now)` resets to an empty session for the new day when `now` is on another day.

  Every settled-map change is saved; a save failure is logged with `debugPrint` and context, never swallowed.
- `SettingsRepository`:
  - `Map<String, bool> planSettled(DateTime day)`;
  - `Future<void> setPlanSettled(DateTime day, Map<String, bool> settled)`;
  - key `settings.today.planSettled`, JSON `{"day":"yyyy-MM-dd","settled":{...}}`;
  - another day, or JSON that does not parse, reads as `{}`.
- Call sites, kept minimal:
  - `actOnPlanItem`'s proposal branch calls `approve(item)`;
  - Today's skip calls `putOff`;
  - the header Undo calls `undo()` until Task 6 removes it;
  - a Today row tap calls `actOnPlanItem` (tap-to-swap goes);
  - You's Not now calls `putOff`.

**Do:**
- [ ] Write failing tests:
  - `day_plan_test.dart`:
    - settle, undo and bringBack semantics and labels;
    - lead order is unchanged without `selected`;
    - existing lead-order and whyNote tests still pass. Delete only the tests of `select`, `palPick` and `isPalPick`.
  - `plan_session_controller_test.dart`, with a `ProviderContainer` on mock SharedPreferences:
    - a put-off and an approval survive a new container on the same prefs (a relaunch);
    - a container built the next day (`withClock`) starts empty;
    - `syncDay` past midnight empties the state, and a later save writes the new day;
    - undo reverses the settle and saves;
    - each change sets a named `notice`.
  - `settings_repository_test.dart`: round-trip, another day reads empty, corrupt JSON reads empty.
  - In `today_screen_test.dart` and `today_scenario_test.dart`, delete or adapt the tap-to-swap tests and steps (`tapping a row makes it the lead…`, `a tapped row skipped…`, `today_row_selected`). A row tap now opens its flow; assert that instead. The fold (`N more later today`) is still on screen until Task 6, so tests may still open it.
  - `pal_home_test.dart`: its `select()` helper opens the fold and taps a row to make a proposal the card. Now it taps the proposal's row, which approves it through `actOnPlanItem`, or reaches the proposal through the card when it leads. Keep each test's intent: approve settles, and Undo (still the header button in this task) brings it back.
  - `routines_onboarding_scenario_test.dart` `closeout open`: tapping the Close-out row now opens the close-out directly; drop the old card `Start` tap.
- [ ] Implement, then regenerate `plan_session_controller.g.dart`.
- [ ] Run: `flutter test test/screens/day_plan_test.dart test/controllers/plan_session_controller_test.dart test/settings_repository_test.dart test/today_screen_test.dart test/pal_home_test.dart test/profile_test.dart test/codegen_hash_test.dart` and `flutter test --tags scenario test/scenario/today_scenario_test.dart test/scenario/defects_scenario_test.dart test/scenario/routines_onboarding_scenario_test.dart`.

**Acceptance:**
- The tests and scenarios above pass.
- The `you_pal_suggests` step in `defects_scenario_test` still approves and puts off from You and reads `settled`.
- `today_scenario_test`'s row-tap step (renamed from `today_row_selected` to `today_row_opens`) taps a row, asserts that its flow opens, and asserts that the card's item is unchanged after returning.

### Task 4: Undo toast above the composer
**Depends on:** Task 2, Task 3
**Files:** `lib/screens/shell/plan_undo_toast.dart`, `lib/screens/shell/loop_shell.dart`, `test/screens/plan_undo_toast_test.dart`, `test/screens/shell_test.dart`, `test/scenario/undo_toast_scenario_test.dart`

**Interfaces:**
- Consumes `ref.watch(planSessionControllerProvider).notice` (the `PlanSession` state's field), and the notifier's `undo()` and `dismissNotice()` (Task 3). Also consumes `relaunchToday` (Task 2).
- Produces `PlanUndoToast` (a `ConsumerStatefulWidget`), `const Key planUndoToastKey`, and `const Duration planToastDuration = Duration(seconds: 6)`.

**Design:**
- A pill (`Radii.pill`, `surface2` fill, 1px `hair` border, no blur and no shadow), at least `PalAskBar.height` tall, inset like the tab bar (`GlassTabBar.sideInset`).
- It sits a named `Spacing` gap above the composer's top (`kShellOverlay` plus the safe area).
- Label in `subhead` `ink` (wraps, never cut). `Undo` is a 44px `headline` `ink` text button.
- The pill is a live region, so screen readers announce it.
- It is shown while `notice != null`. Each new notice instance restarts the 6-second timer, then `dismissNotice()`.
- Undo awaits `undo()`. On error it logs and shows the snack bar `Couldn't save. Try again.`.

**Do:**
- [ ] Write failing tests:
  - `plan_undo_toast_test.dart`:
    - a put-off notice shows `Put off until tomorrow: Close-out` and Undo;
    - Undo restores `settled` and hides the toast;
    - it is gone after 6 seconds (pump `planToastDuration`);
    - a second change restarts the timer and shows the new label;
    - a bring-back notice shows no Undo;
    - semantics: live region; the Undo button is labelled `Undo`.
  - `shell_test.dart`: the toast's bottom edge is above the Pal ask bar's top edge on Today and on You.
  - `undo_toast_scenario_test.dart` (new, light and dark, shots `today_undo_toast_*`):
    1. boot Today;
    2. tap the card's `Not today`;
    3. the toast reads `Put off until tomorrow: <title>` (shot);
    4. Undo brings the card back;
    5. put off again and pump 6 seconds: the toast is gone;
    6. `relaunchToday`: the put-off item is still not on the card (shot `today_relaunch_*`).
  - Step `toast approve` (shot `toast_approve_*`):
    1. boot with `TodayPal(proposals: [proposal('a', 'Plan tomorrow')])`, so the proposal leads the card;
    2. tap the card's pill;
    3. the toast reads the proposal's `doneLabel` (`Plan tomorrow done`) with Undo;
    4. Undo puts the proposal back on the card.
  - Step `toast on You` (shot `toast_you_*`):
    1. boot with a proposal and go to `/you`;
    2. tap Pal suggests `Not now`;
    3. the toast reads `Put off until tomorrow: <title>` above the ask bar, on You;
    4. Undo brings the suggestion back.
  - Step `toast undo fails` (shot `toast_undo_failed_*`):
    1. boot with `planSessionControllerProvider` overridden by a subclass whose `undo()` throws;
    2. put off, then tap Undo;
    3. the snack bar reads `Couldn't save. Try again.`.
  - Step `toast minimized ask bar` (shot `toast_minimized_*`):
    1. put off, then scroll Today down so the ask bar minimizes;
    2. the toast keeps its position (same rect as before the scroll), and the tab bar and ask bar do not overlap it.
- [ ] Implement: mount `PlanUndoToast` in `LoopShell`'s overlay stack, above the content and below the tab bar's z-order only where they would overlap.
- [ ] Run: `flutter test test/screens/plan_undo_toast_test.dart test/screens/shell_test.dart` and `flutter test --tags scenario test/scenario/undo_toast_scenario_test.dart`.

**Acceptance:**
- The widget tests pass.
- Each interaction is shown by its `undo_toast_scenario_test` step: the named put-off toast, Undo, auto-dismiss, relaunch persistence, the approve toast, the toast on You, the failed Undo and the minimized ask bar.
- The bring-back toast without Undo is shown in Task 6's `today_bring_back` step, because the put-off row it needs ships there.

### Task 5: Day plan as the whole-day list; facts and lead line; agenda sends the plan
**Depends on:** Task 2, Task 3
**Files:** `lib/screens/today/day_plan.dart`, `lib/controllers/pal_agenda_controller.dart`, `lib/controllers/pal_agenda_controller.g.dart`, `test/screens/day_plan_test.dart`, `test/controllers/pal_agenda_controller_test.dart`

**Interfaces (produces, for Task 6):**
- In `day_plan.dart`:
  ```dart
  enum PlanRowState { open, missed, done, putOff }
  class PlanRow {
    final PlanItem item; final PlanRowState state;
    String? get detail;          // decision 8
    String? get verb;            // open: item.actionLabel; putOff: 'Bring back'; done mood: 'Check in again'; else null
    bool get tappable => verb != null;
    String get semanticLabel;    // '<verb>: <title>, <detail>' / '<title>, <detail>'; omits ', <detail>' when null
  }
  List<PlanRow> DayPlan.rows(PlanSession session, DateTime now); // timed by minute, then untimed in build order
  ({int done, int total}) DayPlan.progress(PlanSession session);
  String DayPlan.reasonFor(PlanItem item, PlanSession session, DateTime now, [LeadRules rules]); // pulled out of whyNote
  PlanFact DayPlan.factFor(PlanItem item, PlanSession session, DateTime now, [LeadRules rules]);
  List<PlanFact> DayPlan.planFacts(PlanSession session, DateTime now, [LeadRules rules]); // open, non-proposal, in open() order
  String leadLine({required PlanItem? lead, required PalAgenda agenda, required bool online, required String? leadKey}); // decision 5
  ```
- Fact fields:
  - `key` is `'<id>|<status>|<detail or empty>'`;
  - `when` is `clockLabel(minute)` or `any time`;
  - `status` is due (passed, not missed), upcoming, missed or anytime;
  - `steps` is `item.detail`;
  - `why` is `reasonFor(...)`, computed with the rules the agenda provider passes.
- `buildDayPlan` changes:
  - routine and close-out items get `detail` (`3 steps`, or `2 of 4 steps` once any step is done);
  - the mood item gets `doneDetail: moodWord(lastCheckin.pleasantness)` when it is done.
- `palAgendaProvider`:
  - reads, once with `ref.read(...future)` and never watching, so a logged step does not refetch the model: rituals, today's weekly-plan day, the last check-in, meals, `todayStateProvider`'s glance (for `careAreas`) and the plan session;
  - builds `buildDayPlan(agenda: const PalAgenda(), …)`;
  - sends `planFacts(session, now, LeadRules(care: careAreas(glance, now)))`;
  - if reading any input fails, it logs and sends `plan: const []`, so the agenda still loads.

**Do:**
- [ ] Write failing tests:
  - `day_plan_test.dart`:
    - row order (timed by minute, then Any time);
    - done items stay listed and count in `progress`;
    - a put-off row's detail and verb;
    - a missed row reads `Missed · 3 steps`, with label `Start: Morning, Missed · 3 steps`;
    - an approved proposal's detail is its `doneLabel`, and the row is inert;
    - a done mood row reads the mood word and its verb is `Check in again`;
    - the open proposal detail is `Pal suggests`;
    - `planFacts` excludes proposals, done items and settled items;
    - the key changes when steps or status change;
    - `leadLine`, each precedence case, including offline with a matching line (the item's sentence wins) and a stale key (the item's sentence);
    - `whyNote` text is unchanged.
  - `pal_agenda_controller_test.dart`:
    - the agenda receives facts for the open local items in lead order;
    - an input failure still fetches with an empty plan;
    - existing failure tests still pass.
- [ ] Implement, then regenerate `pal_agenda_controller.g.dart`.
- [ ] Run: `flutter test test/screens/day_plan_test.dart test/controllers/pal_agenda_controller_test.dart test/codegen_hash_test.dart`.

**Acceptance:** the tests pass. There is no rendered change in this task: Task 6 renders the rows and the line, and its scenario steps show them.

### Task 6: Today screen: Pal's line, the card, Your day, no header Undo; DESIGN.md
**Depends on:** Task 4, Task 5
**Files:** `lib/screens/today/today_screen.dart`, `lib/controllers/today_brief_controller.dart`, `lib/controllers/today_brief_controller.g.dart`, `test/controllers/today_brief_controller_test.dart`, `test/today_screen_test.dart`, `test/scenario/today_scenario_test.dart`, `test/support/today_fixture.dart`, `test/pal_home_test.dart`, `test/scenario/defects_scenario_test.dart`, `test/scenario/pal_money_settings_scenario_test.dart`, `test/golden/goldens/today_light.png`, `test/golden/goldens/today_dark.png`, `test/golden/goldens/pal_composer_light.png`, `test/golden/goldens/pal_composer_dark.png`, `DESIGN.md`

**Design (match the canvas):**
- Remove the header's Undo; the header is only the date line.
- **Pal's row:** the `Pal` label (or the offline label) and `Why this first ›` whenever online and there is a lead. Below it, `leadLine(...)` in `PalLeadText`. Delete `todayBriefProvider` and its files, and stop refreshing it.
- **Card:**
  - a 40px `surface2` disc with the item's icon (`AppIcon`; the all-done card uses `checkmark`);
  - the when line (`label`, `ink3`, tabular);
  - the title (`title`, a header in semantics);
  - the primary pill (`actOnPlanItem`) and the skip text button (`putOff`).
  - The all-done card reads `All done` / `That's the day` and has no buttons.
- **Your day:**
  - the heading `Your day` (`label` `ink2`, a header in semantics) then `· N of M done` (`ink3`, tabular);
  - every `PlanRow` on the hairline rail: the time column (`caption`, `ink3`, `Any time` when untimed), a 28px disc (a `checkmark` in `ink3` when done), the title (`callout`, one line, `ink` or `ink3` when done or put off), the detail under the title (`caption`, `ink3`), and a small `ink3` chevron when tappable;
  - each row is one 44px+ button labelled `semanticLabel`. Inert rows are not buttons.
- **Taps:**
  - open: `actOnPlanItem`;
  - put off: `bringBack`;
  - done mood: `showMoodLogger`.
- Delete the fold (`_laterShown`, `_MoreRow`, `_allLater`).
- The minute tick and resume call `syncDay(clock.now())`. Resume still invalidates `palAgendaProvider`.
- **DESIGN.md:**
  - Lead entry: the code picks the lead and Pal words one line about it, falling back to the item's sentence. The card is a 40px icon disc, the when line, the title, one pill and one text button.
  - Timeline entry: detail under the title in `caption` `ink3`; done items ticked in `ink3`; a tappable row carries an `ink3` chevron.
  - Add a Toast entry: above the composer, names the change, Undo, leaves after 6 seconds.
- `today_fixture.dart`: drop the now-unused `headline`/`insightsCalls`.
- Tests that used the removed shapes:
  - `pal_money_settings_scenario_test.dart`: drop `TodayPal(headline:)`.
  - `defects_scenario_test.dart`: delete `_showAllLater` and its calls, since every row is now listed.
  - `pal_home_test.dart`: the header Undo becomes the toast's Undo (`find.descendant(of: find.byKey(planUndoToastKey), ...)`).

**Do:**
- [ ] Write failing tests:
  - `today_screen_test.dart`:
    - online, Pal's line for the card's item shows (via `linesByTitle`);
    - offline, or with no line, the item's own sentence shows; failed after a success, the item's sentence shows and Why is hidden;
    - no lead shows `Nothing is left. Rest up.`;
    - Why shows whenever online with a lead, including when Needs care forces the lead, and opens the composer with the why-note;
    - the card has no reason line, a 40px disc, one pill and the skip button;
    - `Your day · N of M done` counts;
    - the card's item is also a row, and there is no `more later today`;
    - a row tap opens its flow (routine player, Start workout, close-out, composer for a meal, approve for a proposal);
    - a done routine row is inert;
    - a done mood row opens the mood logger;
    - Not today makes the row read `Put off until tomorrow`, and tapping it brings it back;
    - no header Undo;
    - at text scale 2.0 rows hold one title line;
    - put off at 11:58 PM under a mutable clock (`Clock(() => current)`), then move the clock to 12:01 AM the next day and pump past the minute tick: the row is open again and the card offers it, with no relaunch;
    - the existing date-line, uppercase, neutral-colour, loading and error tests still pass.
  - `today_scenario_test.dart`: update the steps (light and dark) so that each of these is shot:
    - `today_lead_line` (online line about the card);
    - `today_offline` (the offline label, the item's sentence, no Why);
    - `today_your_day` (every row kind: open, missed, done ticked, put off, approved proposal, done mood with its word);
    - `today_row_opens` (a row tap opens the routine player);
    - `today_bring_back`;
    - `today_mood_again` (a done mood row opens the logger);
    - `today_why` (Why this first opens the composer);
    - `today_rest` (an empty day);
    - `today_row_opens`: tapping the Morning row opens the routine player, and after Back the card's item is unchanged (tap-to-swap is gone). Tapping the workout row opens Start workout, and tapping the Close-out row opens the close-out;
    - `today_row_approve`: tapping an open proposal row approves it. The toast reads its `doneLabel`, and the row turns done, reading its `doneLabel`;
    - `today_bring_back`: tapping a put-off row brings it back. The toast reads `<title> is back on today` and offers no Undo;
    - `today_loading` (the ellipsis while today loads, with `todayStateProvider` overridden by a never-completing future) and `today_error` (`Couldn't load today. Try again in a moment.`, with it overridden by an error);
    - `today_old_shapes_gone` (for `Before.dc.html`): no day-summary headline (`TodayPal` is never asked for `insights(day)`), no header `Undo` outside the toast, no `more later today`, and no `Do this next` label.
- [ ] Implement. Regenerate only the four listed goldens: `flutter test --update-goldens --tags golden test/golden/design_system_golden_test.dart --plain-name today`, then the same with `--plain-name pal_composer`. Check that the diff touches only those PNGs, then compare without updating: `flutter test --tags golden test/golden/design_system_golden_test.dart --plain-name today` and the same for `pal_composer`.
- [ ] Run:
  - `flutter test test/today_screen_test.dart test/pal_home_test.dart test/theme/token_guard_test.dart test/codegen_hash_test.dart`
  - `flutter test --tags scenario test/scenario/today_scenario_test.dart test/scenario/final_scenario_test.dart test/scenario/you_scenario_test.dart test/scenario/defects_scenario_test.dart test/scenario/pal_money_settings_scenario_test.dart test/scenario/undo_toast_scenario_test.dart`
  - the DESIGN.md check: `grep -q "under the title" DESIGN.md && grep -q "^\*\*Toast" DESIGN.md && ! grep -q "detail right-aligned" DESIGN.md`

**Acceptance:**
- The tests and scenarios above pass, including `test/theme/token_guard_test.dart`, and `flutter analyze --fatal-infos` is clean.
- The no-update golden comparison passes.
- The DESIGN.md grep check passes.
- Each changed view and interaction has its named `today_scenario_test` step.
