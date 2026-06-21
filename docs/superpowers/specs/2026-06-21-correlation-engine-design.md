# Correlation Engine + Trust Layer — design

Status: approved design, pre-implementation. Captured 2026-06-21.
Implements step 1 of `docs/roadmap-life-os.md` (the correlation engine and its
prerequisite trust layer, built together).

## Purpose & boundary

Replace the *implicit, sometimes-fabricated* cross-dimension "patterns" with one
deterministic engine that computes real correlations among the four tracked
dimensions, surfaces only the single strongest that clears a strict statistical
bar, and lets the existing insights LLM narrate it — with a computed template as
both fallback and instant render.

One unit, one job: **find the strongest verified relationship, or surface
nothing.** The engine never decides *whether* a pattern exists by model
judgment; that is a deterministic, tested computation. The LLM only phrases a
relationship already proven true.

This directly pays down debt surfaced in the 2026-06-21 audit: the Nutrition and
Rituals findings were fabricated insights (hardcoded "connection" cards, an
always-on "rest day" note, Pal notes citing counts that didn't exist), removed in
commit `eabec94`. Two of those fabrications were *exactly* nutrition correlations
(Nutrition↔Move "you ate more on training days", Nutrition↔Rituals "lighter on
ritual mornings"). The engine replaces those fictions with real computed versions
— the project's "code finds it, the LLM narrates it" principle made concrete.

## Scope (locked)

All pairwise correlations among the four dimensions — **6 pairs**:

- Money↔Move, Money↔Rituals, Move↔Rituals *(the original three)*
- Nutrition↔Money, Nutrition↔Move, Nutrition↔Rituals *(the three the removed
  fabrications faked)*

Surface the single strongest pair that clears the confidence bar. Per-category
breakdowns and additional analyses (forecast, anomaly, leading-indicator nudges)
are explicit roadmap follow-ups, out of scope here.

## Components

All computation is client-side Dart, in one new dependency-free module —
proposed `lib/analysis/correlations.dart`. This matches the existing
architecture: `InsightsContext` is already entirely client-computed and POSTed to
the thin `/v1/insights` proxy (the server never sees raw entries, only
pre-aggregated context — `server/src/prompts.ts:37`, `server/src/app.ts:132`).

- **`buildDailyVectors(entries, meals, window) → Map<Dimension, Map<DateOnly, double>>`**
  — buckets each dimension to one continuous daily scalar over a rolling window
  (last **90 days**, capped to available data). Money/Move/Rituals bucket from the
  `Entries` table (`createdAt`, `lib/data/db/tables.dart:197`); Nutrition buckets
  from the meals store (per-meal `cal` mid, already summed per day for the week
  strip — `lib/controllers/nutrition_controller.dart:224`).
- **`pearson(xs, ys) → {r, n, p}`** — pure; `p` from the standard t-statistic on
  `r`. No external package.
- **`findStrongest(vectors, {minN, minAbsR, alpha}) → Correlation?`** — forms the
  6 pairs over their shared days, computes each, applies a Holm-Bonferroni
  correction across the 6, returns the strongest survivor or `null`.
- **`Correlation` model** — the two dimensions, `r`, `n`, direction, and the
  pre-computed breakdown payload for the trust sheet (two-group means where a
  natural binary split exists, else a trend summary).

## Confidence bar (locked: strong + corrected)

A pair surfaces only if **all** hold:

- `n ≥ 21` paired days,
- `|r| ≥ 0.4`,
- Holm-corrected `p < 0.05` across the 6 pairs tested.

If none qualify, **no card renders** — the honest empty state, and the correct
behavior for a fresh or young dataset. The correction is load-bearing: testing 6
pairs raises the chance one clears by luck, and the trust-first framing demands a
fluke rarely shows.

## Missing-data rules (the correctness crux)

Pairing requires both series defined on the same days, so absence is handled
per dimension:

- **Money / Move / Rituals** — a day in-window with no entry is a genuine **0**
  (didn't spend / didn't move / kept no rituals).
- **Nutrition** — a day with no logged meal is **missing and excluded** (no log ≠
  ate nothing). This shrinks nutrition's `n`, so nutrition pairs won't clear the
  21-day floor until enough days accrue — correct for the youngest dimension.

## Modeling choice: all-Pearson

Every dimension is modeled as a continuous daily scalar and all 6 pairs use
Pearson (one function, uniform). The binary split (e.g. workout day vs rest day)
is derived only for the trust sheet's two-group view, not for the statistic.
Rationale: KISS — a true point-biserial path on a binary flag is arguably more
faithful to "workout days vs skip days" but adds a second code path for marginal
gain. Revisit only if a continuous-vs-binary pair proves to mislead.

## Data flow

1. The insights controller builds daily vectors from Drift entries + meals
   (instant; same query shape Insights/Recap already run).
2. `findStrongest` → `Correlation?` (deterministic, golden-tested).
3. If present: render the **template phrasing immediately** (no network);
   attach the correlation as a new field on `InsightsContext`; call
   `/v1/insights`.
4. The server adds the relationship to the patterns output, prompted to "explain
   this verified relationship humanly; do not invent others." The response
   **upgrades the card wording in place** (progressive enhancement).
5. Tapping a correlation card opens the shared **trust sheet**: the numeric
   breakdown (e.g. "12 workout days: $34 avg · 16 rest days: $52 avg"), the
   sample size, and `r` translated to plain language. No chart in v1.

### Latency

The correlation math is sub-millisecond over ~90 days × 4 dimensions; the only
cost is the day-bucketing query, already a familiar shape. Narration adds no new
round-trip — it rides the `/v1/insights` call the Insights screen already makes.
The template fallback renders the proven relationship with zero network, so the
user perceives no delay; the LLM phrasing swaps in async. Net: no meaningful
delay, and faster-feeling than today's insights surface, which shows nothing
until the LLM returns.

## Surfacing (locked)

- **Insights** patterns section — the single strongest across all 6 pairs.
- **Nutrition** connections screen — the nutrition-involving pairs, replacing the
  removed fabrications (its one real money pattern stays).
- Both reuse the same card + trust-sheet widgets. No new screen, no
  notifications. Weekly digest and leading-indicator nudges remain roadmap
  follow-ups.

## Server change (minimal, backward-compatible)

- Add an optional `correlation` field to the insights body schema
  (`server/src/schemas.ts:50` area) and to `InsightsContext`
  (`server/src/prompts.ts:37`).
- Add one prompt clause in `insightsPrompt` (`prompts.ts:115`) to narrate the
  verified relationship and forbid inventing others.
- Optional field → older clients that omit it are unaffected.

## Error handling

- No survivor → no card (not an error state).
- Insights call fails or returns null → template fallback keeps the computed card.
- A dimension below the sample floor → its pairs drop out; if all drop, no card.

## Testing

- **Unit / golden:** `pearson` on known fixtures (incl. perfect ±1 and zero
  correlation); Holm correction across synthetic p-values; the missing-data rules
  (nutrition-excluded vs money-zero); `findStrongest` selects the right survivor
  and *rejects* weak (`|r|<0.4`), under-sampled (`n<21`), and
  correction-failing-spurious pairs.
- **Audit-lesson regression:** a constant or fabricated series yields **no**
  correlation — guards against re-introducing fiction.
- **Widget / golden:** the correlation pattern card and the trust sheet (Nutrition
  has no goldens today; this adds the first for the connections screen).

## Out of scope (named, deferred to roadmap)

Forecast / run-rate, anomaly / change-point detection, leading-indicator nudges,
the weekly "one thing" digest, and a `spotted` PalNote surface. Each reuses this
engine's daily-vector substrate but is a separate step in
`docs/roadmap-life-os.md`.
