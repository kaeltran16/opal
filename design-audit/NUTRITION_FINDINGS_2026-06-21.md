# Opal — Nutrition audit findings (2026-06-21)

Focused code-level audit of the Nutrition feature (built post-`audit-2026-06-12`,
never independently reviewed). Two passes: the data layer / repository /
controller, then the screens, sheets, and shared widgets. Companion to
`UX_FINDINGS_2026-06-20.md`. No code changed.

File references are grounded by reading the named lines, not by running the app.
The seed data masks finding #1 (see its note), which is why the prior UX
walkthroughs didn't surface it.

---

## Severity legend
- **P1** — broken core action / user-visible wrong number.
- **P2** — misleading or fabricated state; not data-destructive.
- **P3** — copy / polish / dead UI.

---

## P1 — broken core action

### 1. Pal-logged food never becomes a meal (cross-tracker linkage is half-dead)
- **Seen (by code):** The two headline cross-tracker behaviors — the *"an
  expense looks like a meal"* pending prompt and the *"Takeout vs. home"* spend
  pattern — both gate on the exact category string `'Food & Drink'`:
  - `lib/controllers/nutrition_controller.dart:257` (`_derivePending`)
  - `lib/controllers/nutrition_controller.dart:281` (`_buildPatterns`)
- **Root:** Pal's expense parser tags food expenses as **`'Dining'`** and
  **`'Coffee'`**, not `'Food & Drink'`
  (`lib/services/pal/mock_pal_service.dart:226–230`: coffee→`Coffee`,
  breakfast/lunch/dinner/restaurant→`Dining`). An expense logged by telling Pal
  *"lunch $14"* lands as `Dining` → never matches `'Food & Drink'` → never
  surfaces as a meal candidate and is never counted in the takeout-spend total.
- **Why it slipped past the UX audits:** the **seed** food expenses are
  categorized `'Food & Drink'` (`lib/data/seed/seed_data.dart:821, 840, 881,
  953`), so the demo path works; only real Pal-logged input breaks.
- **Compounding taxonomy break:** `'Dining'` and `'Coffee'` are **not in**
  `kSpendCategories` (`lib/models/spend_category.dart:8`), the list whose own
  doc-comment claims to be "the single source of truth" for categories. Sibling
  of `UX_FINDINGS_2026-06-20.md` finding #4 (category↔envelope mismatch).
- **Fix direction:** match on a *set* of food categories rather than one literal,
  and route the Pal parser's outputs through `kSpendCategories` so `Dining` /
  `Coffee` either become canonical members or map to `Food & Drink`. Pick one
  taxonomy; add a test that a Pal-parsed "lunch" expense produces a pending meal.

### 2. "Adjust estimate" doesn't adjust — it creates a duplicate
- **Seen (by code):** On meal detail, `_AdjustButton.onTap` calls
  `showNutritionAddSheet(context)` — the generic *blank* add-meal sheet
  (`lib/screens/nutrition/nutrition_meal_detail_screen.dart:312`). It does not
  prefill the current meal, and the sheet's Save calls `addManualMeal`, which
  **inserts a new meal** (`nutrition_controller.dart:337`). So tapping "Adjust
  estimate" on a dinner opens a blank form defaulted to *Lunch* and, on save,
  leaves the original meal untouched and adds a second one.
- **Dead param:** `_AdjustButton` takes `mealId` but never references it
  (`:304–331`) — the signal that the edit path was never wired.
- **Fix direction:** either open the sheet seeded with this meal's values and
  route Save through an `updateMeal(id, …)` (the repo already has `upsert`), or
  relabel the button to "Log similar" if duplicate-create is actually intended.
  Add a test that Adjust on an existing meal does not change the meal count.

---

## P2 — fabricated / misleading state

### 3. Three of the four landing "connections" are hardcoded fictions
- **Seen (by code):** `_buildPatterns`
  (`lib/controllers/nutrition_controller.dart:269–334`) computes the money
  pattern from real entries, then returns **three static patterns** with invented
  sparklines and prose stated as observed fact — e.g. *"On the days you trained,
  you tended to eat a little more…"* (`:310`), *"Days that started with your
  morning ritual leaned lighter…"* (`:319`), *"Most days land in a similar
  range…"* (`:327`). These render on the landing card, the "See all patterns"
  screen (`nutrition_patterns_screen.dart`), and feed the count badge.
- **Impact:** the user reads these as insights about *their own* data; they are
  constant strings (the code comment at `:268` concedes "first-pass"). Violates
  the project's "code finds it, the LLM narrates it" principle and the
  `roadmap-life-os.md` trust-layer requirement.
- **Fix direction:** compute these from entry/meal data (as the money pattern is)
  or hide them until a real computation exists. Don't ship fabricated claims.

### 4. The meal-detail "connection" card is fabricated and context-wrong
- **Seen (by code):**
  `lib/screens/nutrition/nutrition_meal_detail_screen.dart:240–258` hardcodes
  *"Today was a **rest day** — your dinners tend to run a little heavier on
  these."* on **every** meal detail.
- **Impact:** it always says "rest day" regardless of whether today had a
  workout, and always references "your dinners" even on a breakfast, snack, or
  drink. Worse than #3 because it asserts a specific fact about *today*.
- **Fix direction:** derive rest/train from the day's move data and only show the
  card when it's both true and relevant to the meal's slot; otherwise omit it.

---

## P3 — copy / polish / dead UI

### 5. The day's "carb-heavy" note is statistical noise
- **Seen (by code):** `MealEstimate.macros` is *always* `macrosFromCal(cal)` with
  carbs fixed at 50% of calories (`lib/services/pal/pal_service.dart:628`;
  `macrosFromCal` in `lib/models/nutrition_meal.dart:36–42`). The rollup flags
  *"leaning carb-heavy"* when `carbKcal / mid > 0.5`
  (`lib/controllers/nutrition_controller.dart:194`).
- **Impact:** because carbs are *defined* as 50% of calories, that ratio is
  always ≈0.5 and the label flips only on integer-rounding artifacts — it can
  never reflect a genuinely carb-heavy day.
- **Fix direction:** drop the note until macros have an independent source.

### 6. `note` and `tags` are dead — UI for them never renders
- **Seen (by code):** No write path sets `NutritionMeal.note` or `.tags`
  (`addManualMeal` `:337–356`, `confirmFromExpense` `:369–399` — neither passes
  them; quick-pick/estimate paths don't either). Yet meal detail uses
  `subtitle: meal.note` (`nutrition_meal_detail_screen.dart:87`) — always empty —
  and renders a tags `Wrap` (`:163–175`) that is always skipped.
- **Fix direction:** remove the unused fields + UI, or wire a path that sets them.

### 7. Manual add ignores time of day for the slot
- **Seen (by code):** the add-by-hand sheet defaults `_slot = 'Lunch'`
  (`nutrition_add_sheet.dart:51`) regardless of the current time, while the
  takeout path infers the slot from the expense hour
  (`nutrition_controller.dart:359, _slotForHour`). Minor inconsistency — a meal
  added at 8am defaults to Lunch.
- **Fix direction:** default the manual slot via the same `_slotForHour(now)`.

---

## Coverage
Covered: data layer, repository, controller, landing screen, meal detail,
patterns screen, add + confirm sheets, shared widgets.

Not verified here (next step): **live/on-device behavior** — the
`useRootNavigator` sheet fix, the week-strip rendering with real multi-day data,
and golden coverage for the Nutrition screens (no golden exists for them).
