# Opal — Rituals/Routines audit findings (2026-06-21)

Focused code-level audit of the Rituals dimension, tracing 06-20 finding #2
(rituals count disagreeing across 7 screens). Companion to
`UX_FINDINGS_2026-06-20.md`. No code changed.

File references are grounded by reading the named lines. Rituals is the
best-reconciled dimension — the core of #2 is genuinely fixed.

---

## Severity legend
- **P1** — broken core action / user-visible wrong number.
- **P2** — fabricated / contradictory state; not data-destructive.
- **P3** — polish / latent.

---

## Verified fixed since 06-20
- **#2 core (Recap "3/3" counting step entries):** `completedRoutines`
  (`goals.dart:61–84`) is now the documented single source — a routine counts
  only when every step has a same-day ritual entry; empty routines never count.
  Recap and the period reviews route through `completedRoutinesInPeriod`
  (`recap_controller.dart:195`, `weekly_review_controller.dart:151`), so the
  step-vs-routine scale bug is resolved.
- **#2 "Rituals tab 3/12 steps":** not a contradiction — the tab deliberately
  shows a **step**-level count, correctly labelled "{done} of {total} steps today"
  (`rituals_screen.dart:54`). A different metric than the routine count, honestly
  labelled.

---

## P2 — fabricated / contradictory

### 1. Pal notes hardcode ritual counts that contradict the canonical count
- **Seen (by code):** Pal note bodies hardcode `"4 of 5 rituals done…"`
  (`mock_pal_service.dart:474`) and `"Your evening routine slips 3 of 5 nights"`
  (`:487`). These cite **5** rituals, but only **3** routines are seeded — so
  `effectiveDailyRitualTarget` is 3 everywhere else (`goals.dart:55`). The notes
  render in the Pal "noticed" feed (the inbox), where the user sees "4 of 5" while
  Today/Recap show "X of 3" via `completedRoutines`. This is the unfixed half of
  06-20 #2 ("Pal Home/Inbox 4/5").
- **Related:** `:332` `"Under budget 3 of 4 weeks"` is the same class of hardcoded
  count in a money note.
- **Caveat:** mock-only; a real `/agenda` backend would presumably compute these.
  But the mock is what every current build and test sees.
- **Fix direction:** build these note bodies from `completedRoutines` /
  `effectiveDailyRitualTarget` (and the real budget data) instead of literals, or
  drop the specific counts. Add a test that no surfaced ritual count exceeds the
  routine count.

---

## P3 — latent

### 2. Three implementations of "routine complete"; the SSOT doc is inaccurate
- **Seen (by code):** completion is computed three independent ways:
  - `completedRoutines` (`goals.dart:70`) — from ritual entries' `ritualId`.
  - `today_controller._routineComplete` (`today_controller.dart:80–83`) — from a
    local `_completedStepIds` set.
  - `rituals_controller.isComplete` (`rituals_controller.dart:40–41`) — from the
    `progress` step-index map.
- **Impact:** they agree today (all require every step done, all guard empty
  routines), but `goals.dart:67–69` claims "The Today ring, the rituals detail
  hero, Recap … all read this" — and in fact **neither Today nor the Rituals tab
  calls `completedRoutines`**. Two extra copies are exactly the drift risk the
  SSOT helper was introduced to remove; the doc overstates the consolidation.
- **Fix direction:** have `today_controller` and `rituals_controller` derive their
  routine-complete count from `completedRoutines` (passing the day/entries), or
  soften the doc claim to match reality.

---

## Coverage
Covered: `goals.dart` count helpers, `rituals_controller`, `today_controller`
(ritual path), `recap`/`weekly_review` ritual counts, `pal_context_builder`
ritual fields, the Pal mock agenda note bodies, and the Rituals tab labelling.
Not covered: the rituals builder/editor flows (`rituals_builder_controller`,
`routine_editor_controller`) and the guided routine player interaction.
