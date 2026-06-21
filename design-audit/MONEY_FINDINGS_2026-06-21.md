# Opal — Money/Budgets audit findings (2026-06-21)

Focused code-level audit of the Money dimension (budgets, insights, recap, today
ring), going deeper than the 06-15 / 06-20 UX walkthroughs. Companion to
`UX_FINDINGS_2026-06-20.md` (whose finding #4 — "spent this month reads 4 values"
— motivated this pass). No code changed.

File references are grounded by reading the named lines.

---

## Severity legend
- **P1** — broken core action / user-visible wrong number.
- **P2** — inconsistency or confusing state; not data-destructive.
- **P3** — copy / polish / latent.

---

## Verified fixed since 06-20
The **spend-side** of `UX_FINDINGS_2026-06-20.md` #4 (Budgets total ≠ Insights
total) is now resolved: `buildBudgetsData` routes every unmatched expense into an
`_uncategorizedEnvelope` catch-all (`budgets_controller.dart:81–88, 109–127`), so
`BudgetsData.totalSpent` equals the full month spend — matching the Insights
month total, which sums the same way (`insights_money_controller.dart:142–149,
193–194`). The remaining divergence is on the **budget** side (below), not spend.

---

## P1 — budget the user can't actually change

### 1. Envelope caps are immutable and disconnected from the editable daily budget
- **Seen (by code):** there are two independent budget sources:
  - `Goals.dailyBudget` (DB column, default 85 — `data/db/tables.dart:222`) — the
    **only user-editable** budget. Written from onboarding
    (`onboarding_screen.dart:82`), the budget sheet (`budget_sheet.dart:85`), the
    Budgets & goals screen (`budgets_goals_screen.dart:65`), and a Pal action
    (`pal_action_executor.dart:96`).
  - The **sum of `BudgetEnvelope.cap`** — labelled "the canonical monthly budget"
    (`recap_controller.dart:65–66, 220`) and shown on the Budgets screen.
- **Root:** envelope caps are **only ever read** — `grep` for writers finds only
  `getEnvelopes()` callers; the **sole writer of envelope rows is the seeder**.
  No screen edits a cap. So the "canonical monthly budget" is a frozen seed value.
- **Impact:** when a user lowers their budget (say $85→$50/day), the Today ring,
  Day/Week recap, and the daily-budget alert all follow `dailyBudget` and update —
  but the **Budgets screen** and **monthly Recap** keep measuring against the
  seeded cap sum (e.g. $2,600) and never move. The monthly budget is effectively
  un-editable and ignores the only budget the user can set. This is the code root
  of — and deeper than — 06-20 #4's "$2,600 vs $2,550".
- **Fix direction:** pick one source of truth. Either (a) derive envelope caps
  from `dailyBudget` (and/or make caps editable and derive `dailyBudget` from
  their sum), or (b) compute the monthly budget as `dailyBudget × daysInMonth`
  everywhere and drop the cap-sum basis. Add a test that editing the budget moves
  the Budgets-screen and monthly-Recap targets.

---

## P2 — inconsistency

### 2. Day/Week and Month budgets imply different daily allowances
- **Seen (by code):** `buildRecapData` sets the period budget two ways
  (`recap_controller.dart:172–175`): month → envelope-cap sum; day/week →
  `goals.dailyBudget × days`. Weekly Review also uses `dailyBudget × 7`
  (`weekly_review_controller.dart:148`); the Today ring uses `dailyBudget`
  (`today_controller.dart:104`).
- **Impact:** with the seed (dailyBudget 85, caps summing to ~2,600), the Week
  recap shows "of $595" (85×7 → $85/day) while the Month recap shows "of $2,600"
  ($86.67/day). The same "of $X" budget line means a different daily allowance per
  tab — even before considering #1's editability gap.
- **Fix direction:** falls out of fixing #1 — one budget basis used by all periods.

---

## P3 — latent

### 3. Month recap silently falls back to daily×days when caps sum to 0
- **Seen (by code):** `recap_controller.dart:173–175` uses the envelope sum only
  when `monthlyBudget != null && monthlyBudget > 0`, else `dailyBudget × days`.
  If a user (eventually) clears all caps, the monthly Recap would show
  `dailyBudget × daysInMonth` while the Budgets screen shows a $0 cap — a fresh
  divergence in the empty-envelope case.
- **Fix direction:** subsumed by #1; until then, make the empty case consistent
  between the two screens.

### 4. Budget pacing getters mix `now` with the covered month
- **Seen (by code):** `BudgetsData.monthPaceFraction` and `daysLeft`
  (`budgets_controller.dart:61–72`) compute against `DateTime.now()` regardless of
  the stored `month`. Correct only because the provider always builds the current
  month (`:143–149`); a latent trap if the builder is ever reused for a historical
  month (e.g. a month picker), which the `now`-injection seam invites.
- **Fix direction:** derive the elapsed fraction from `month` vs `now` explicitly,
  clamping to the covered month, if historical months ever render.

---

## Coverage
Covered: `budgets_controller`, `insights_money_controller`, `recap_controller`
(money path), `today_controller` (money ring), budget editing surfaces
(`budget_sheet`, `budgets_goals_screen`, onboarding), envelope repository writers.
Not covered: `budget_alert_controller` threshold/notification behavior on device,
and the Insights screen's chart rendering.
