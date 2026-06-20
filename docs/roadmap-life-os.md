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

The dimensions split by *capture cost*, not by storage — storage is always one
more `Entries.type` or health metric. What varies is whether new data collection
is needed:

- **"Cheap" only with HealthKit (currently gated)** — sleep, nutrition /
  hydration, and **HRV / resting heart rate as a passive stress proxy** would
  fold into the daily vectors via the existing ingest in `server/src/health.ts`
  with no new capture UX. **But HealthKit needs a paid Apple Developer account,
  which the project deliberately does not require** (see README — the entitlement
  is omitted and the app degrades gracefully without it). So today these are
  *unavailable*, not cheap; they only become cheap if a paid account is later
  adopted. Until then, treat the HRV stress proxy (the highest-value one) as
  blocked on that decision, not as a quick win.
- **Expensive (needs new capture UX)** — **mood, focus/time, social
  connection**. The storage is still just a new `Entries.type`; the real cost is
  the logging interaction, so treat these as deliberate product bets, not
  freebies. (Deferred — see "Bigger bets" below.)

## The analysis family — siblings of the correlation engine

The correlation engine builds *daily aggregate vectors per dimension* from
`Entries`. Once that substrate exists, three more analyses reuse it for near-zero
marginal cost, each keeping the same division of labor (code finds it, the LLM
narrates it):

- **Forecast / run-rate projection** — "at this pace you'll exceed the dining
  envelope by the 22nd." A deterministic run-rate over `BudgetEnvelopes` and the
  daily spend vector; Pal phrases the result. Slots into `/v1/insights`.
- **Anomaly / change-point detection** — "spend this week is 2.3σ over your
  8-week baseline." A z-score / EWMA pass over the same vectors that drops a
  `spotted` `PalNote`. No new data, just one more read of the substrate.
- **Leading-indicator nudges (the payoff)** — correlation reports the *past*
  relationship ("skip a workout → overspend"); this acts on it, firing a
  *preventive* `nudge` `PalNote` on a skip-day *before* the overspend happens.
  This is what turns "we compute correlations" into "Opal changed my day." It
  closes the loop: insight → action.

## Trust layer (prerequisite for the analysis family)

Surfacing a computed pattern to a user is only safe if the user can see why it
was surfaced — otherwise a statistical fluke reads as fact, the exact failure the
"code finds, LLM narrates" split is meant to prevent on the generation side but
not yet on the *presentation* side.

- **Confidence + "why"** — every surfaced pattern carries its sample size and
  `|r|` (or σ for anomalies) and a tap-to-see-the-underlying-data view. This is a
  cross-cutting requirement for *everything* in the analysis family above, not a
  standalone feature; build it alongside the first analysis that ships, not after.

## Delivery cadence

- **Weekly "one thing" digest** — Recap is monthly; the analysis family produces
  candidates continuously. A weekly push of the single highest-confidence pattern
  (via `PalNote` + notification) gives the engine a regular surface without
  waiting for the monthly review. Reuses `/v1/agenda` → `memory[]` for what's
  already been said, so it doesn't repeat itself.

## Bigger bets (named, deferred)

Captured so they aren't re-discovered later, but explicitly *not* cheap and *not*
next:

- **Expensive dimensions** — mood, focus/time, social connection. Each needs a
  new capture interaction, which is the actual product work.
- **"What changed" attribution in Recap** — decompose a moved metric into its
  drivers ("dining +$80, driven by 3 weekend deliveries") and let Pal narrate.
  Valuable but a larger deterministic-decomposition effort.
- **Pattern feedback loop** — let the user mark a `PalNote` "useful / not true"
  to feed `memory` (suppress or boost). Makes Pal learn what's worth saying;
  depends on the trust layer existing first.

## Suggested first step

Start with the correlation engine on the existing three dimensions. It proves
the "sees relationships between your data" claim with zero new data collection,
and it's a self-contained addition to a seam we already own — and it builds the
daily-vector substrate every other analysis reuses.

Rough sequence (each step exploits the previous one's substrate, not new
architecture):

1. **Correlation engine** + the **trust layer** (confidence/"why") together —
   the trust layer is a prerequisite, not a follow-up.
2. **Anomaly detection** and **forecast** — same vectors, second read.
3. **Leading-indicator nudges** — needs a confirmed correlation to act on.
4. **Weekly digest** once there's a steady stream of patterns worth pushing.
5. **HealthKit dimensions** (sleep, HRV stress proxy, nutrition) — only if/when a
   paid Apple Developer account is adopted; blocked until then, so not on the
   critical path.

The "bigger bets" stay out of this sequence until a deliberate product decision
pulls one in.

Before building: a design pass to pin scope — which correlations, the
confidence / sample-size bar, and how Pal surfaces them.
