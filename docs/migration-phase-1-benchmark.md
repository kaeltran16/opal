# Phase 1 — feasibility benchmark results (go/no-go gate)

This is the evidence for the roadmap's mandatory go/no-go gate. It was produced by the
Phase 1 spike under `server/spike/`, which **was removed in Phase 7 cleanup** — the
prototype had served its purpose and left a second deployable `wrangler.toml` in the
tree. The results below were rescued from the spike's untracked `bench/results.md`
before deletion; they are the only full record of the gate.

Base: `https://opal-spike.piskael03.workers.dev` · worker: `opal-spike` · mode: `STUB_LLM=1` ($0 CPU-isolation)
D1 location: APAC/SIN · bundle: 184.46 KiB raw / **37.07 KiB gzip** (limit 3 MB → 1.2% used)
Run: 2026-07-23. Two runs: driver (50 reps × 4 cases = 200 req) + per-case burst (150 reps × 4 = 600 req). Total 800 worst-case requests.

CPU quantiles read from the Cloudflare GraphQL Analytics API
(`workersInvocationsAdaptive.quantiles.cpuTime*`, microseconds → ms).

## CPU time per endpoint (150-rep burst, ms)

| case | reqs | errors | cpuFails (1102/1027) | p50 | p90 | p99 | p999 | mean |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| chat | 135 | 0 | 0 | 5.67 | 7.03 | 10.19 | 13.46 | 5.72 |
| insights | 185 | 0 | 0 | 1.80 | 2.26 | 10.02 | 14.76 | 1.95 |
| routine | 164 | 0 | 0 | 2.43 | 5.66 | 13.00 | 14.76 | 3.32 |
| email-extract | 49 | 0 | 0 | 1.54 | 2.77 | 4.68 | 4.68 | 1.77 |

## Aggregate (first 200-rep driver run)

CPU p50 2.05 · p90 6.00 · p99 8.99 · p999 11.04 ms. 200 req, 0 errors, 0 cpuFails.

## Reading

- **chat is the CPU-critical path**: worst-case 18 tool-calls + memory ops. Steady-state p50 5.7 /
  p90 7.0 ms — under 10 ms with ~30% headroom at p90. All other cases have a cheap median (<2.5 ms).
- **The p99/p999 tail (~10–15 ms) is platform variance, not app work**: it appears uniformly even on
  the cheap insights case (p50 1.8 → p99 10.0), so it reflects isolate cold-start / GC, not the
  deterministic parse/validate cost. A 3-request warmup did not remove it (Cloudflare rotates isolates).
- **Zero enforced CPU kills (1102/1027) across all 800 worst-case requests.** The 10 ms Free CPU limit
  did not produce a single killed request, including the tail samples above 10 ms.
- Bundle 37 KiB gzip is trivially within the 3 MB gate. `imapflow`/`mailparser`/`better-sqlite3` are
  absent (type-only imports + stub alias).

## Verdict: GO (thin margin) — chat is the binding case

- Bundle < 3 MB: **PASS** (37 KiB).
- Zero 1102/1027 across 800 worst-case req: **PASS**.
- Steady-state CPU < 10 ms for every case: **PASS** (chat highest, p90 7.0 ms).
- Extreme-tail (p99+) CPU margin: **THIN** — p99 brushes 10 ms, p999 10–15 ms, but caused zero kills.

Practical GO for a personal-use app. Two levers to widen the margin if wanted:

1. Treat chat as the CPU budget owner; cap the number of parsed tool-calls and/or the 20-message
   history (the 18-tool-call worst case is far beyond real usage).
2. Re-run with higher REPS on the final bundle to confirm the tail is stable.

Phase 4 later measured 8–15 ms on the heaviest route against the live Worker
(`docs/migration-phase-4-verification.md`), consistent with the thin-margin verdict.

## Historical note — querying CPU quantiles

The spike's `bench/drive.mjs` is deleted along with the rest of the prototype. If the
benchmark is ever re-run, these were its known defects and the corrected query shape:

- dataset: `workersInvocationsAdaptiveGroups` → **`workersInvocationsAdaptive`** (the `...Groups`
  variant is not in the current schema).
- filter: `datetime_geq` works; add `scriptName`.
- quantile fields: `cpuTimeP50 cpuTimeP90 cpuTimeP99 cpuTimeP999` (µs).
- Needs Node ≥ 23.6 (or tsx) to import `.ts` fixtures via a `.js` specifier; Node 22.14 with
  `--experimental-strip-types` cannot resolve `.js`→`.ts`.

The live-smoke against a real capped OpenRouter key (`STUB_LLM=0`) was never run in Phase 1;
it exercises wall-time and subrequest behavior rather than CPU, and Phases 3–4 covered that
path against the real Worker instead.
