# Roadmap: Life OS — cross-dimension pattern detection

Status: idea / not scheduled. Captured 2026-06-17.

## The vision

Instead of separate trackers, one system that sees the *relationship* between
dimensions and surfaces hidden patterns:

- "You overspend when you skip workouts."
- "Your productivity crashes after 3 bad sleep nights."

## Why opal is already most of the way there

The hard part of a Life OS is not the UI — it's a single source of truth that
lets dimensions see each other. Siloed-per-domain storage can never compute a
relationship *between* domains.

Opal avoids this: money, movement, and rituals are all rows in one unified
`Entries` table (`lib/data/db/tables.dart`), discriminated by `type`. Two series
can only be correlated if they share a coordinate system — opal already has that.

Delivery surfaces also exist:

- **Insights** (`/v1/insights`) — already does within-domain pattern detection
  (sends `spendByWeekday` to the LLM).
- **Pal memory** (`/v1/agenda` → `memory[]`) — durable learned patterns.
- **Recap** — the consolidated cross-domain review surface.

## The two gaps

### Gap 1 — correlation is implicit, not computed (the interesting one)

Today cross-domain relationships only emerge if the LLM happens to notice them
in the raw entry list. There is no feature that deliberately computes, e.g.,
"spend on workout-days vs skip-days."

Correlation is a deterministic transform, not an LLM job — it's a Pearson /
point-biserial computation over two paired daily series. Division of labor:

- **Code** finds the *strong* correlations (the statistics) — reproducible and
  testable (golden tests), not dependent on what the model noticed this run.
- **LLM** narrates the one worth telling (judgment + phrasing).

This matches the project's own principle: use the model for judgment, use code
for determinism.

Sketch: a `correlations.ts` step builds daily aggregate vectors per dimension
from `Entries`, computes pairwise correlations, filters to `|r|` above a
threshold with enough sample days, and passes the top 1–2 to the existing
insights prompt as "here is a verified relationship — explain it humanly."
Slots into the existing `/v1/insights` seam without new architecture.

### Gap 2 — dimension coverage

The vision name-drops sleep and productivity; opal tracks money/move/rituals.

- **Sleep** — nearly free. The health-metrics store already exists
  (`server/src/health.ts`, HealthKit ingest); sleep is one more metric folded
  into the daily vectors.
- **Productivity / mood** — genuinely new dimensions, but added the same way
  every existing dimension was: a new `Entries.type`, not a new subsystem. That
  is the payoff of the unified table.

## Suggested first step

Start with the correlation engine on the existing three dimensions. It proves
the "sees relationships between your data" claim with zero new data collection,
and it's a self-contained addition to a seam we already own. Sleep folds in
next (cheap); mood/productivity is the larger product bet.

Before building: a design pass to pin scope — which correlations, the
confidence / sample-size bar, how Pal surfaces them, and whether sleep comes in
at the same time.
