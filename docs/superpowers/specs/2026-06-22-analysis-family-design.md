# Life OS — Analysis Family (steps 2–5) design

Status: approved design (this session), pre-implementation. Coding deferred until
all of steps 2–5 are designed — now complete. Captured 2026-06-22. Builds on step 1
(`docs/superpowers/specs/2026-06-21-correlation-engine-design.md`) and
`docs/roadmap-life-os.md`; expands the working notes in
`docs/2026-06-22-life-os-step2-notes.md`.

## Purpose & boundary

Step 1 built a daily-vector substrate and a trust layer. This spec designs the four
remaining roadmap steps that reuse that substrate:

- **Step 2** — anomaly detection + forecast
- **Step 3** — leading-indicator nudges (the payoff: insight → action)
- **Step 4** — the unified reflection engine (weekly digest + Recap + yearly review)
- **Step 5** — bypass-reachable dimensions (sleep, stress, calendar/time, mood)

Unifying principle, carried throughout: **code finds the finding deterministically;
the LLM narrates it; every surfaced claim is one tap from its "why."**

## Shared foundations (from step 1)

- **Substrate**: `buildDailyVectors(entries, meals) → Map<Dimension, DailySeries>`
  (`lib/analysis/correlations.dart`) — client-side, instant, golden-tested.
- **Trust sheet**: tap a card/note → the numbers, sample size, strength in plain
  words. Reused by every surface below; it is a wire-up, not new work.
- **PalNote inbox already exists** — storage (`PalNoteRepository`), UI
  (`PalNoticedSection`), and the `NoteKind` enum (`nudge`/`spotted`/`pattern`/`win`/
  `reminder`/`recap`). The only missing piece is a *producer*: nothing real mints a
  note today except the seeder (`lib/data/seed/seed_data.dart`).

## Shared note-producer lifecycle (steps 2 & 3)

The "missing middle." One lifecycle, used by anomaly, forecast, and nudge:

- **Trigger**: daily first-foreground; a once-per-day guard (last-run date in prefs)
  means most opens no-op.
- **Execution**: deferred past first frame (post-frame callback / Pal-hub mount),
  **off the launch critical path**. Reads the shared daily-vector provider
  (`surfacedCorrelations`, which Riverpod memoizes and invalidates reactively). The
  inbox updates via `watchNotes()` when a note lands — nothing blocks on it.
- **Dedup via hysteresis**: a note fires when the value crosses the high bar; a new
  note for that dimension is suppressed until the value first normalizes and then
  crosses again. The hysteresis state is **persisted (required state, not a perf
  cache)** so it survives relaunch.
- **Quiet cap**: at most one new note per day. ("A quiet Pal is a happy Pal" — the
  inbox's own empty-state copy.)
- **Cross-producer ranking — by agency, not magnitude**: when more than one note
  wants the day's single slot, rank `nudge > forecast > anomaly`; within a tier, by
  magnitude. Never compare σ to dollars numerically. This ladder also decides
  delivery loudness (below).
- **Narration — progressive enhancement**: mint the note with deterministic template
  text immediately (offline-safe; the finding exists because the math cleared the
  bar), then upgrade the body via the LLM on the next Pal call. The body is persisted;
  a note is never re-narrated.
- **Interactions**: tap the card → trust sheet (the *why*); tap the action pill →
  seed the Pal composer (generic across kinds — the existing
  `/pal-composer?seed=...` behavior). Kind-specific deep-links deferred.
- **Delivery by agency**: `spotted` and `reminder` are inbox-only; `nudge` is the one
  kind that also fires a local notification (`notification_service.dart`).

## Step 2 — anomaly + forecast (ship together)

Frame: correlation relates two dimensions ("when X, then Y"); anomaly and forecast
each watch one dimension across time — anomaly backward ("unusual for you"), forecast
forward ("you'll exceed").

### Anomaly detection
- Weekly **z-score** against a trailing baseline; a **robust (median/MAD)** variant
  for the heavy-tailed money and nutrition series so a single large day doesn't
  distort the baseline.
- All four dimensions get it — **except rituals**, a small bounded count, which uses a
  **streak-break rule** (e.g. kept 0 for N straight days vs the usual cadence), not a
  z-score. One uniform model here would be a false economy (unlike all-Pearson in
  step 1, which was a true one).
- Bar: ~2.5σ (a tuning parameter; higher than 2.0 because four dimensions are
  scanned). Note kind: `spotted`.

### Forecast
- **Money-only** — it needs a period + a cap, which in Opal means the budget envelopes
  (`lib/screens/money/budgets_screen.dart`).
- Run-rate projection over the daily spend vector vs the envelope cap; solve for the
  crossing date.
- **Don't fire until ≥1/3 of the period has elapsed** (early run-rate is wild). v1
  uses a uniform run-rate; weighting by the historical within-month spend shape is a
  refinement.
- **Two surfaces**: a live projection on the budgets screen (recomputed like the
  correlation card) **and** a one-shot `reminder` note.

### Noise budget
Threshold + hysteresis + one-per-day cap are **three behavioral guards** that replace
step 1's statistical Holm correction — anomaly detection isn't a clean hypothesis
test, so the analog to "a fluke rarely shows" is behavioral, not statistical.

## Step 3 — leading-indicator nudges

The payoff: closes the loop — correlation *finds* the relationship, the producer
*surfaces* it, the nudge *acts* on it preventively.

- **Timing — lag-1 / next-day action.** A nudge acts on *yesterday's confirmed*
  behavior, never a same-day prediction. "You skipped your workout yesterday — the day
  after a skip tends to run high for you. Heads up today." This requires the engine to
  compute **lag-1 correlations** (offset one series by a day before pairing — the same
  `pearson` machinery). It is the step where the engine extends from descriptive
  (lag-0) to anticipatory (lag-1), and the first time the producer couples to the
  correlation engine.
- **Trigger**: morning first-foreground; fires when (a) a confirmed lag-1 correlation
  exists for this user **and** (b) yesterday's antecedent actually occurred.
- **Bar**: the single strongest lag-1 correlation clearing step 1's full bar (n≥21,
  |r|≥0.4, corrected p). Highest bar of any note — it earns the interruption.
- **Delivery**: local notification + inbox entry (`nudge` kind).
- **Deferred**: the "useful / not true" feedback loop (a roadmap bigger bet); the high
  firing bar stands in for it until then.

## Step 4 — unified reflection engine (digest + Recap + yearly)

**Decision: unify the weekly digest with Recap** rather than build parallel surfaces.
One engine, one selection, three period-scaled depths.

### Framing
The digest's real job is not "summarize the week's notes" — it is to give the
**otherwise-silent correlation layer a regular push cadence**. Correlations never push
anything; a confirmed relationship just sits on Recap/Connections until the monthly
Recap. The digest fills that gap.

### One engine, three depths
| Period | Depth | Surface |
|--------|-------|---------|
| Weekly | the one thing only | `recap` note + content-light push |
| Monthly | full reflection, headlined by the one thing | existing Recap screen + push |
| Yearly | expanded "year in review" | new scroll layout + push |

### Selection
- The headline is always **the single strongest finding over the window**. At the
  period level, rank by **confidence (|r|)** — not agency — over a comparable pool
  (the correlations). Fall back to the week's strongest unsurfaced note only if there
  is no fresh correlation.
- Two selection criteria, each honest to its purpose: **interrupt by agency** at the
  daily level; **reflect by confidence** at the period level. No cross-unit fabrication
  anywhere.

### Dedup
Within a cadence, not across: a weekly digest dedups against recent weekly digests
(via Pal `memory[]`), but a weekly mention must **not** suppress the monthly headline —
different scope, comprehensive by intent.

### Delivery
A **scheduled content-light notification** ("Pal noticed something this week — tap to
see") on the period beat; the actual "one thing" is computed **on open**, which avoids
acting on stale data and reaches users who never open the app in the morning. This is
the scheduled-ahead delivery deferred from step 3.

### Recap unification (highest-downside change — its own careful slice)
Recap stops being a passive screen the user must remember to visit and becomes the
**depth layer behind the push**. This restructures already-shipped code
(`recap_screen.dart`, which already headlines the strongest correlation). Reversible,
but the one change here that touches working surface — design its boundaries carefully.

### Yearly review
Format: **scroll** (extends Recap, reuses existing cards/tiles), **no sharing**,
**graceful partial-year** ("your year so far" when under 365 days). Five movements over
the 365-day window:

1. **Headline** — the year's strongest correlation (correlation card + trust sheet).
2. **Per-dimension totals + one superlative each** (money/move/rituals/nutrition) —
   reuse the ring/stat tiles.
3. **Biggest shifts** — step 2's change-point pass run at year scale.
4. **The connections story** — the year's top few correlations.
5. **Closing narrative** — the LLM weaves the deterministic facts into a year-end
   reflection.

Almost no new *analysis* — it's the existing three engines (correlation, change-point,
totals) over a 365-day window. The only new work is presentation. Every fact is
deterministic and testable; the LLM narrates only proven numbers.

## Step 5 — bypass-reachable dimensions

New dimensions: **sleep, stress (HRV / resting HR), calendar/time, mood.** (Nutrition
already shipped in step 1.)

### Capture — the Shortcut bypass (no Apple Developer account)
The `com.apple.developer.healthkit` entitlement needs a paid account, so there is **no
in-app Health read**. Instead an **iOS Shortcut** reads Health / Calendar /
State-of-Mind samples under the Shortcuts app's *own* permission and POSTs them to
`POST /v1/health/ingest` — the same bypass already used for the rings widget and Watch
health. The server `HealthStore` (`server/src/health.ts`) is the single source of
truth. `sleepMinutes` and `restingHeartRate` are already in the ingest enum
(`schemas.ts`); HRV, mood, and calendar/time are one-line enum additions each
(calendar via the "Find Calendar Events" action, mood via the iOS "State of Mind"
sample).

### Materialization seam (the one genuine architectural decision)
The engine is **client-side** over local Drift data; health metrics are **server-side
only** (the read-back is `GET /v1/health/day`, a single day). Decision: **sync into a
local store** — add a bulk `GET /v1/health/range`, sync the daily metrics into a small
local Drift table, and extend `buildDailyVectors` to take them. The engine stays
instant, offline, and golden-tested over local data.
- Rejected: *fetch-on-demand* (puts the network on the engine's critical path);
  *server-side analysis* (the server deliberately never sees raw entries — this would
  reverse the architecture).

### Dimension-addition pattern (the payoff)
Once the seam exists, a new dimension is **enum value + one bucketing line in
`buildDailyVectors` + display strings (label / unit / optional binary-split)**. It then
flows through all five engines — correlation, anomaly, forecast, digest, yearly — with
zero new analysis code. This is why step 5 is sequenced last: each dimension lands into
working engines.

### Missing-data rule (correctness crux)
Every step-5 dimension is **missing = excluded** (no sample ≠ zero), unlike
money/move/rituals where absence is a genuine 0. This also absorbs the
Shortcut-freshness reality with no special-casing:
- health series are only as fresh as the last Shortcut run (Shortcuts read Health only
  while unlocked → scheduled on morning unlock);
- health correlations take longer to clear the n≥21 floor (more missing days —
  correct, like nutrition);
- a health-leading nudge simply **doesn't fire** when yesterday's sample is absent
  (missing antecedent → no nudge, never a guess);
- a one-day lag on the newest day is irrelevant to a 90-day correlation.

### Trust-sheet split
New dimensions default to the trend-summary trust view; add a two-group binary split
only where a natural threshold is obvious (e.g. sleep at ~7h).

## Sequencing within the family

1. **Step 2** — establishes the producer + the noise budget.
2. **Step 3** — reuses the producer, couples it to the engine (lag-1); the payoff.
3. **Step 4** — the unified reflection engine; restructures Recap (its own careful
   slice).
4. **Step 5** — dimensions land into all working engines; sequenced after the engines
   exist.

## Open tuning parameters (pin during implementation)

- Exact anomaly σ bar (~2.5 lean).
- Forecast: uniform vs shape-weighted run-rate (v1 uniform).
- Rituals streak-break specifics (N consecutive missed vs the user's usual cadence).
- Per-dimension binary-split thresholds.

## Out of scope / deferred

- "Useful / not true" pattern feedback loop (bigger bet).
- Kind-specific note-action deep-links (generic Pal-composer seed for v1).
- Yearly swipe-deck format and any sharing.
- Scheduled-ahead notification for *daily* nudges (only the weekly/period beat is
  scheduled; daily nudges fire on morning foreground).
- True in-app-capture dimensions (focus quality, social connection).

## Testing posture (carried from step 1)

- **Deterministic finders golden-tested**: z-score (incl. robust median/MAD), run-rate
  + crossing date, lag-1 correlation, change-point, per-dimension yearly aggregates,
  and every missing-data rule (excluded vs zero).
- **Audit-lesson regression**: a constant or fabricated series yields no finding.
- **Producer lifecycle**: hysteresis (no re-fire until normalized), one-per-day cap,
  agency ranking, the once-per-day guard.
- **Widget / golden**: the note card per kind, the yearly review sections.
- No test hits the real Anthropic API or the droplet.

## Decisions locked

| Area | Decision |
|------|----------|
| Producer trigger | daily first-foreground, once-per-day guard, deferred off critical path |
| Dedup | hysteresis (normalize before re-fire); persisted state |
| Quiet cap | one new note/day |
| Daily ranking | by agency: nudge > forecast > anomaly |
| Narration | template now, LLM-upgrade on next Pal call |
| Anomaly | weekly z-score (robust for money/nutrition); rituals = streak-break |
| Forecast | money-only run-rate vs budget envelope; live screen + `reminder` note; ≥1/3 period gate |
| Nudge | lag-1 next-day action; notification + inbox; strongest lag-1 over step-1 bar |
| Step 4 | unify digest + Recap + yearly under one engine, three depths |
| Period selection | by confidence (|r|), pool = correlations, fallback to top note |
| Scheduled delivery | content-light push on the period beat, compute on open |
| Yearly | scroll, no sharing, graceful partial-year, five movements |
| Step-5 seam | sync server health into a local store; bulk `/v1/health/range` |
| Step-5 capture | Shortcut bypass → `/v1/health/ingest`; one-line enum adds |
| Step-5 missing-data | missing = excluded for every new dimension |
