# Life OS — step 2 notes (anomaly + forecast)

Status: notes only. Captured 2026-06-22. Not a plan, no implementation intended.
Companion to `docs/roadmap-life-os.md`; records a code re-baseline plus the design
decisions reached discussing step 2.

## Where the roadmap stands

Step 1 shipped: the correlation engine + trust layer
(`lib/analysis/correlations.dart`, spec
`docs/superpowers/specs/2026-06-21-correlation-engine-design.md`). Four dimensions
(money, move, rituals, **nutrition**), 6 pairs, the
`n≥21 / |r|≥0.4 / Holm-corrected p<0.05` bar, trust sheet, surfaced on Recap and
the Connections screen.

| # | Step | Status |
|---|------|--------|
| 1 | Correlation engine + trust layer | shipped |
| 2 | Anomaly detection + forecast | next (designed below) |
| 3 | Leading-indicator nudges (`nudge` note) | unblocked |
| 4 | Weekly "one thing" digest | — |
| 5 | Bypass-reachable dimensions (sleep, HRV, calendar/time, mood) | — |

## Key finding — the proactive surface exists, the producer does not

The "What Pal noticed" inbox is fully built:

- Storage: Drift `palNotes` table + `PalNoteRepository` full CRUD
  (`lib/data/repositories/pal_note_repository.dart`).
- UI: `PalNoticedSection` in the Pal hub — filters, unread counts, action pills
  that deep-link into the composer (`lib/screens/pal/pal_noticed_section.dart`).
- `NoteKind` (`lib/models/enums.dart`) already defines `nudge`, `spotted`,
  `pattern`, `win`, `reminder`, `recap`. `spotted` = anomaly, `reminder` =
  forecast, `nudge` = step-3 leading-indicator.

But nothing real produces notes — the only `PalNote` constructor is the seeder
(`lib/data/seed/seed_data.dart`, 8 demo notes). Step 2 is the *missing middle*:
a deterministic detector that reads the existing daily-vector substrate and calls
`palNoteRepository.insert(...)`. Both bookends (substrate, surface) already exist.

## Step 2 design (settled)

Step 2 ships **anomaly + forecast together**. Conceptual frame: the correlation
engine relates two dimensions ("when X, then Y"); anomaly and forecast each watch
one dimension across time — anomaly looks back ("unusual for you"), forecast looks
forward ("you'll exceed").

### Detection model

- **Anomaly**: weekly z-score against a trailing baseline. Use a robust
  (median / MAD) variant for the heavy-tailed money and nutrition series so a
  single large day (rent, a flight) doesn't distort the baseline. All four
  dimensions get anomaly detection.
- **Rituals is the exception** — a small bounded count, not a continuous series.
  Its "anomaly" is a **streak-break rule** (e.g. kept 0 for N straight days vs the
  usual cadence), not a z-score. One uniform model would be a false economy here
  (unlike all-Pearson in step 1, which was a true one).
- **Forecast** is money-only: it needs a period + a cap, which in Opal means the
  budget envelopes (`lib/screens/money/budgets_screen.dart`). Run-rate projection
  over the daily spend vector vs the envelope cap; solve for the crossing date.

### Note lifecycle (the genuinely new part)

The correlation card recomputes live on render; a note is a *persisted row* with
read/unread state, so minting one is a deliberate, non-repeating event.

- **Trigger**: daily first-foreground. A once-per-day guard (last-run date in
  prefs) means most opens no-op.
- **Bar**: ~2.5σ on the weekly series (higher than 2.0 because four dimensions
  are scanned).
- **Dedup via hysteresis**: a note fires on crossing the high bar; a new note for
  that dimension is suppressed until the value first normalizes and then crosses
  again. You hear about a spike once — not every day it stays elevated.
- **Quiet cap**: at most one new note per day. ("A quiet Pal is a happy Pal" is
  the inbox's own empty-state copy.)

Threshold + dedup are one **noise budget** — three behavioral guards (high σ bar,
hysteresis, one-per-day cap) replace step 1's statistical Holm correction, because
anomaly detection isn't a clean hypothesis test.

### Cross-producer ranking — by agency, not magnitude

Two producers now feed one inbox with incomparable severity scales (σ vs
dollars-over). Resolve the daily single-slot contest **editorially, by what the
user can still act on**, never by a fabricated numeric conversion:

> nudge > forecast > anomaly; within a tier, by magnitude.

A forecast is forward-looking and still actionable; an anomaly already happened.
This priority ladder is inherited verbatim by step 3's nudges.

### Surfaces, trust, narration

- **Forecast has two surfaces**: a live projection on the budgets screen
  (recomputed like the correlation card) **and** a one-shot `reminder` note.
  Anomaly has one surface (the `spotted` note).
- **Trust is a wire-up, not new work**: every note is tappable into the step-1
  trust sheet — anomaly shows the baseline, this week's value, and σ in plain
  words; forecast shows the projection, the cap, and the crossing date. This is
  what keeps a *proactive* note from reading as an anxious assertion.
- **Narration is progressive enhancement**: mint the note with deterministic
  template text immediately (offline-safe; the finding is what matters — it exists
  because the math cleared the bar), then upgrade the body via the LLM on the next
  Pal call. The finding is deterministic; the phrasing is enhancement.

### Performance

- **Off the launch critical path**: run the detector deferred (post-first-frame
  callback / on Pal-hub mount), not in the cold-start sequence. The note appears a
  beat later via the inbox's reactive `watchNotes()` stream.
- **No new cache for the substrate**: read the shared daily-vector provider (the
  existing `surfacedCorrelations` Riverpod provider memoizes it and invalidates
  reactively on entry changes); persist outputs and the dedup/hysteresis state.
  The dedup state is *required state*, not a perf cache. Avoid a TTL cache of the
  vectors — premature (the query is a few ms) and a staleness risk.
- **No LLM prompt caching**: on Haiku 4.5 the cacheable-prefix floor is 4096
  tokens and the TTL is 5 minutes; a once-daily narration with a small,
  per-user-volatile prompt clears neither bar. Prompt caching's only real payoff
  surface in Opal is `/v1/chat` (a large prefix reused many times inside the TTL),
  not the analysis family.

## Still open (deferred to whenever step 2 is actually scoped)

- The note **action**: what the action pill does — forecast → "see dining" /
  "adjust budget"; anomaly → (TBD).
- Exact σ threshold (~2.5 is the lean, validate against real data).
- Forecast: uniform run-rate for v1 vs weighting by historical within-month spend
  shape.
- Rituals streak-break specifics (how many consecutive missed days, relative to
  the user's usual cadence).

## Pointers

- Roadmap + delivery sequence: `docs/roadmap-life-os.md`
- Step 1 spec: `docs/superpowers/specs/2026-06-21-correlation-engine-design.md`
- Substrate: `lib/analysis/correlations.dart`
- Note surface: `lib/models/pal_note.dart`, `lib/models/enums.dart` (`NoteKind`),
  `lib/data/repositories/pal_note_repository.dart`,
  `lib/screens/pal/pal_noticed_section.dart`
- Only current producer (seed): `lib/data/seed/seed_data.dart`
- Budgets (forecast home): `lib/screens/money/budgets_screen.dart`
