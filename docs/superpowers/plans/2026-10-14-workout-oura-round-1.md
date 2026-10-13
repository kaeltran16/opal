# Workout Oura Round 1: Trailing Text at the Row's End

**Effort:** effort:c4342184-d6c7-424a-be76-048d8a167e17
**Verify:** `flutter test --exclude-tags "golden || scenario"`
**Setup:** `flutter pub get`
**Check:** `flutter analyze --fatal-infos`
**Final:** `flutter test --tags scenario test/scenario/workout_scenario_test.dart`
**Prototype:** C:\Users\cktra\Projects\opal\.superpowers\design\oura-ai-first-workout\project\Main.dc.html

**Goal:** Trailing text that the canvas puts at a row's right edge renders at the right edge at 390 wide, not mid-row.

**Architecture:** One shared defect in four places. A `Row` with `Expanded(lead)` and `Flexible(trailing Text)` splits the row in half. The loose `Flexible` lets the `Text` size to its own width, and the `Row` places it at the left of its half, so `textAlign: TextAlign.end` and `Align(widthFactor: 1)` have no effect. The fix keeps the lead flexible and places the trailing child at the row's end at its natural width, capped so a long value still ellipsises instead of crowding out the lead.

**Tech Stack:** Flutter, flutter_test widget tests with the Ahem test font.

**Spec:** `docs/superpowers/plans/2026-10-13-workout-oura.md` (the run's plan; Tasks 3, 5 and 9 own these layouts). The canvas is the Prototype: `r.detail` in the session rows sits at the right with the title at `flex:1`, the section `h2` is at `flex:1` with its count at the right, and a `flex:1` spacer sits before Skip exercise.

## Global Constraints

- Touch only the files in the task's Files line.
- The trailing child's right edge equals the row's right edge (in LTR) at 390 wide and text scale 1.0.
- At text scale 1.3 on a 390 wide surface, nothing overflows: a long trailing value ellipsises, and the lead keeps at least half the row.
- Use one approach at all four sites. The pattern to match is `ListRow`'s value in `lib/widgets/inset_section.dart`: a `LayoutBuilder` with `BoxConstraints(maxWidth: box.maxWidth * share)` on a non-flex trailing child after an `Expanded` lead. Alternatively, `Align(alignment: AlignmentDirectional.centerEnd)` with no `widthFactor` inside the `Flexible`, if that reads simpler at a site. Either way, the end edge comes from `AlignmentDirectional`/the row's own order, so RTL mirrors.
- No raw `Color(0x...)` or numeric `BorderRadius.circular` (the token guard). Name any new measurement as a file-level const.
- Every tap target stays at least 44 by 44.
- Do not loosen any existing test.

## Review Focus

- The SessionRow `New best` word, when present, sits after the detail at the row's end. The detail and `New best` line up from one row to the next in a list.
- A title long enough to ellipsise still leaves the trailing value visible.
- `Skip exercise` keeps its 44 tap target and sits at the row's end while `Add set` stays at the start.
- The `This week` heading with `No weekly plan yet` (the longer count) still fits at 390 and text scale 1.3.

---

### Task 1: Trailing text at the row's end

**Depends on:** none
**Chunk:** Shared: segmented controls, toggles and chips (controls.dart)
**Files:** `lib/widgets/session_row.dart`, `lib/screens/move/move_screen.dart`, `lib/screens/workout/active_session_screen.dart`, `test/widgets/workout_rows_test.dart`, `test/move_screen_test.dart`, `test/active_session_test.dart`

The four sites:

1. `lib/widgets/session_row.dart:62`: the `detail` `Flexible`, plus the `New best` text after it. The detail and New best go together at the row's end.
2. `lib/screens/move/move_screen.dart:134`: `_Heading`'s `Flexible(child: trailing)`. It holds `This week`'s `{n} of {goal} workouts` and `Recent`'s `See all`.
3. `lib/screens/workout/active_session_screen.dart:403`: `Best {kg} kg × {reps}` beside the set label.
4. `lib/screens/workout/active_session_screen.dart:669-675`: `Flexible(Add set)`, `Spacer()`, `Flexible(Skip exercise)` splits the row in thirds, so Skip exercise starts at two-thirds. `Add set` stays at the start and `Skip exercise` sits at the end.

**Interfaces:**
- Consumes: nothing new.
- Produces: no constructor changes. `SessionRow`, `_Heading` and the session card keep their parameters.

- [ ] **Step 1: Write the failing tests**

Each test pumps at 390 wide, text scale 1.0 (`tester.view.physicalSize = const Size(390, 844)`, `devicePixelRatio = 1`, reset in `addTearDown`), then compares edges with `tester.getTopRight` / `tester.getRect`. Each test must fail against the current code:

- `test/widgets/workout_rows_test.dart`: a `SessionRow` with a short detail (`'45 min'`). The detail text's right edge equals the `SessionRow`'s right edge, within 0.5. With `newBest: true`, the `New best` text's right edge equals the row's right edge, and the detail's right edge is left of New best's left edge. Two SessionRows with different-length titles give the same detail right edge.
- `test/move_screen_test.dart`: on the Workout tab, the `This week` count text's right edge equals the `This week` heading row's right edge, and the same holds for `See all` in Recent (seed a session so Recent shows, following the file's existing setup).
- `test/active_session_test.dart`: in the entering state with a PR present, `Best … kg × …`'s right edge equals its row's right edge. `Skip exercise`'s tap target's right edge equals the action row's right edge, and `Add set`'s left edge equals the row's left edge.
- One test per file at text scale 1.3 and 390 wide with a long title, asserting `tester.takeException()` is null.

- [ ] **Step 2: Run them and confirm the edge assertions fail**

Run: `flutter test test/widgets/workout_rows_test.dart test/move_screen_test.dart test/active_session_test.dart`
Expected: the new edge tests FAIL (trailing text sits mid-row).

- [ ] **Step 3: Fix the four sites with the one approach in Global Constraints**

- [ ] **Step 4: Run the three files, the token guard and analyze**

Run: `flutter test test/widgets/workout_rows_test.dart test/move_screen_test.dart test/active_session_test.dart test/theme/token_guard_test.dart && flutter analyze --fatal-infos`
Expected: PASS, no issues.

- [ ] **Step 5: Run the scenario and look at the shots**

Run: `flutter test --tags scenario test/scenario/workout_scenario_test.dart`
Check the shots for `workout_tab`, `workout_tab_settled`, `weekly_plan`, `history` and `session_entering` in light and dark. The detail, the count, See all, Best and Skip exercise sit at the right edge.

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/session_row.dart lib/screens/move/move_screen.dart lib/screens/workout/active_session_screen.dart test/widgets/workout_rows_test.dart test/move_screen_test.dart test/active_session_test.dart
git commit -m "fix(workout): trailing row text sits at the row's end"
```
