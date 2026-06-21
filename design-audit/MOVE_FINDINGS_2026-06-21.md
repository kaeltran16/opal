# Opal — Move/Workout audit findings (2026-06-21)

Focused code-level audit of the Move dimension (move home, weekly plan, start
workout, Pal's pick, streaks), tracing the roots of the 06-20 walkthrough's Move
contradictions. Companion to `UX_FINDINGS_2026-06-20.md`. No code changed.

File references are grounded by reading the named lines. Move is in better shape
than Nutrition/Money — several 06-20 findings are genuinely fixed (see below).

---

## Severity legend
- **P1** — broken core action / user-visible wrong number.
- **P2** — inconsistency or wrong characterization; not data-destructive.
- **P3** — copy / polish / trust.

---

## Verified fixed since 06-20
- **#5 "Pal's pick differs by screen":** Move home and Start Workout now both
  watch the same `palPickControllerProvider`
  (`move_screen.dart:490, 498`; `start_workout_screen.dart:265`), and the mock's
  `suggestWorkout` is deterministic — it returns `_suggestions[_index]`, advancing
  only on "Another" (`mock_pal_service.dart:358–371`). Same provider + stable
  value → same pick.
- **#6 "Push Day card contradicts itself" ("3 days since" vs done today):** the
  day-count claim was removed from the suggestion rationales; the mock even
  documents the old bug (`mock_pal_service.dart:45–46`). Current rationales carry
  no specific day-count to contradict history.
- **#7 "Streak vs weekly grid":** not a bug — the Today/Profile "streak" is the
  *ritual* streak (`profile_controller.dart:143` → `ritualStreakDays`), a
  different metric than the Move week strip's workout count. The audit compared
  unrelated numbers. Streaks are also single-sourced (`_streakDays` in
  `pal_context_builder.dart:118`), so Profile and Recap can't diverge.

---

## P2 — inconsistency / wrong characterization

### 1. Weekly workout goal disagrees: Move hero (4) vs Weekly Plan (0 planned)
- **Seen (by code):** `moveState` sets `weekGoal = plannedDays > 0 ? plannedDays
  : kWeeklyWorkoutGoal` where `kWeeklyWorkoutGoal = 4`
  (`move_controller.dart:44, 152–154, 207`). `plannedDays` is the Weekly Plan's
  `totalCount` = scheduled non-rest days (`weekly_plan_controller.dart:77`).
- **Impact:** with no weekly-plan schedule, `totalCount = 0`, so the Move hero
  falls back to a goal of **4** and shows e.g. "2/4 this week", while the Weekly
  Plan screen correctly shows "0 of 0 done · 0 planned". Same question — "what's
  my weekly workout goal?" — two answers on two screens. This is the live root of
  06-20 #9 (still present).
- **Fix direction:** make the fallback visible on both screens (seed a default
  plan, or show "no goal set" on the hero), or have the Weekly Plan screen reflect
  the same fallback target. One source for the weekly goal.

### 2. "Longest streak" is a misnomer — the value shown is the *current* streak
- **Seen (by code):** `ritualStreakDays`/`moveStreakDays` compute the **current**
  consecutive-day run ending today-or-yesterday (`pal_context_builder.dart:115–
  139`). That value is stored in fields named `longestStreak`
  (`profile_controller.dart:143, 158`; `monthly_review_controller.dart:138`), and
  the streak-celebration screen renders the **current** move streak under the copy
  *"Your longest streak this year."* (`streak_celebration_screen.dart:68, 77, 80`).
- **Impact:** a user whose longest run was earlier in the year (now broken) sees
  their smaller *current* streak labelled as their *longest* — a wrong claim, not
  just an internal naming slip.
- **Fix direction:** either compute the true year-max for any "longest" copy, or
  relabel the copy/fields to "current streak". Also note the
  `streak_celebration_screen.dart:77` `start == null` branch is dead (unlocked
  implies `streak >= 1`, so `streakStartDate` is never null there).

---

## P3 — trust

### 3. Pal's workout pick is a canned list that ignores real history
- **Seen (by code):** `suggestWorkout` cycles a hardcoded 3-item `_suggestions`
  list (`mock_pal_service.dart:46–64, 358–371`) and never consults workout history
  or `lastDone`. Rationales like *"Your lower body is rested"* / *"You've lifted
  hard this week"* are static, so they can still mischaracterize what the user
  actually did (e.g. suggest a push day right after a logged push day) — only the
  explicit day-count text was removed (fixed #6), not the underlying disconnect.
- **Caveat:** mock-only; the real `/suggest` backend may be history-aware. Worth a
  contract check + a "don't suggest what was just done" guard.
- **Fix direction:** if the real service isn't history-aware, ground the pick in
  `lastDone` (already derived in `start_workout_controller.dart:64–72`).

---

## Coverage
Covered: `move_controller`, `weekly_plan_controller`, `start_workout_controller`,
the Pal-pick path (`PalPickController` + mock `suggestWorkout`), streak
computation (`_streakDays`, profile/monthly/celebration consumers). Not covered:
the live workout session + post-workout flows (`workout_session_controller`,
`post_workout_*`) and routine generation/editing — candidates for a later pass.
