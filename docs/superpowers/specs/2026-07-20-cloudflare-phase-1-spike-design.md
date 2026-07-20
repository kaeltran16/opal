# Phase 1 feasibility spike — Cloudflare Workers CPU gate

Date: 2026-07-20
Parent roadmap: [`docs/roadmap-cloudflare-workers-d1.md`](../../roadmap-cloudflare-workers-d1.md) · Phase 1
Phase 0 findings: [`docs/migration-phase-0-findings.md`](../../migration-phase-0-findings.md)

## Goal

Produce the **go/no-go CPU evidence** that decides whether Opal's backend can run on the Cloudflare
Workers Free plan (fixed 10 ms CPU/invocation). Nothing else. The spike answers one question:
do worst-case requests stay under the CPU limit with a documented margin?

## Non-goals

- No route porting, no production cutover, no native email boundary (Phases 2–7).
- No HTTP framework (native `fetch` routing per the roadmap).
- No ORM. No changes to `server/src/`.
- The spike is disposable. If the gate passes it *seeds* Phase 2; if it fails it is deleted and the
  $0 direction is abandoned per the roadmap (reconsider a paid always-on service).

## Architecture

**Location:** `server/spike/` — isolated, own `wrangler.toml` + `package.json`, sharing nothing with
the Fastify app.

**Reused from `server/src/` (pure, zod-only, portability confirmed by import audit — imported, not
copied, to preserve single source of truth):**

- `pal.ts` — Pal logic + `OpenRouterClient` (already `fetch` + `AbortSignal.timeout`, Workers-native).
- `prompts.ts`, `product.ts`, `schemas.ts`, `receipts.ts`, `redact.ts`.

**New in the spike:**

- `src/worker.ts` — `fetch` handler, method+path switch, JSON responses, bearer guard, error envelope
  matching Phase 0's contract (`{ error: { code, message, details? } }`).
- `src/d1-stores.ts` — minimal D1-backed token + memory store, replacing the `better-sqlite3` versions.
  `node:crypto` `randomBytes` → Web Crypto (`crypto.getRandomValues` / `crypto.randomUUID`). Prepared
  statements only.
- `migrations/0001_init.sql` — `device_tokens`, `pal_facts`, `pal_patterns` (the subset the benchmark
  touches; health/widget deferred to Phase 2).
- `bench/fixtures.ts` — worst-case payload generators (see below).
- `bench/drive.mjs` — Node driver (runs in this environment), hammers the deployed `*.workers.dev`
  URL, records outcomes, reads CPU margin.

## The five benchmark cases (roadmap-mandated)

Each exercises the real ported handler with a **worst-case** payload:

| Case | Endpoint | Worst-case fixture |
| --- | --- | --- |
| Chat | `POST /v1/chat` | 20-message history (retained max), all `chatContext` fields, long message, populated memory digest |
| Routine | `POST /v1/routine` | full exercise catalog (configurable `CATALOG_N`, default conservatively large — **flagged to validate against the real Flutter catalog size**) |
| Insights | `POST /v1/insights` | largest `insightsContext`: full `entries[]`, `spendByWeekday[7]`, correlation present, memory digest |
| Email extraction | `POST /v1/email/extract` (new seam) | 8 sanitized candidates each at the `receipts.ts` body-size bound |
| D1 memory | `POST /v1/chat` (D1 path) | token with populated memory; handler reads digest + applies remember/forget ops |

## Measurement methodology

The CPU gate targets the Worker's **deterministic** CPU (prompt building, `extractJson`, zod
validation) — the OpenRouter call is I/O (wall time, not CPU). Two modes:

1. **Stub mode (default, CPU isolation):** a Worker env flag makes handlers skip the network and feed
   a **canned worst-case completion** straight into the same `extractJson` + zod validation path. This
   isolates Worker CPU, costs $0, and removes network variance. CPU quantiles are read from these runs.
   Each stub returns a max-size result for its schema (routine with `CATALOG_N` exercises × max sets;
   insights with max wins/patterns; chat with max actions + memory ops), so validation does real work.
2. **Live smoke (correctness of I/O behavior):** a handful of real calls using the **same capped
   `OPENROUTER_API_KEY`**, to prove the 30 s timeout + one retry survive the runtime. Negligible spend.

**Driver (`bench/drive.mjs`):** N reps per case against the deployed URL; records HTTP status + wall
time; **flags any `1102`/`1027` "Exceeded Resources"** (hard no-go). After the run it queries the
**GraphQL Analytics API** (`workersInvocationsAdaptive.cpuTime` P50/P99) using a Cloudflare
**Analytics-read API token** (owner-provisioned; never stored in the repo, read from env) and writes
`bench/results.md`.

**Bundle-size check:** `wrangler deploy --dry-run` (or build output) reports gzip size vs the 3 MB
Free limit.

## Testing

- **Local (this environment):** `wrangler dev` + local D1 (miniflare). Stub mode. Contract/correctness
  checks against the fixtures — response shapes match Phase 0's contract table. No credits burned.
- **Deployed (owner-run):** `wrangler deploy`, `wrangler secret put OPENROUTER_API_KEY` +
  `PAL_PROVISIONING_KEY`, then the driver runs the CPU gate. Local emulation does **not** satisfy the
  gate — Cloudflare CPU accounting only exists on the real runtime.

## Exit criteria → go/no-go

Deliverable: `bench/results.md` with per-case CPU P50/P99, any 1102s, bundle size vs 3 MB, and a
documented margin based on observed variance.

- **Go:** worst-case CPU across repeated runs stays below 10 ms with a documented margin, zero 1102s,
  bundle under 3 MB. → proceed to Phase 2 (writing-plans for route porting), seeded from the spike.
- **No-go:** measure which deterministic step consumes CPU, reduce oversized inputs only where the
  measurement supports it, re-run. If worst-case cannot fit reliably, **stop the $0 migration** —
  reconsider a paid always-on service rather than weakening validation or exposing secrets.

## Owner-provided inputs

- Cloudflare account with Workers + D1 (Free) and a `*.workers.dev` subdomain.
- `wrangler deploy` + `wrangler secret put` for `OPENROUTER_API_KEY` (the capped prod key) and
  `PAL_PROVISIONING_KEY`.
- A Cloudflare API token scoped to **Account Analytics: Read** for the GraphQL CPU readout.

## Open assumption to validate

`CATALOG_N` (routine benchmark) must be set to the **real** Flutter exercise-catalog size before the
gate run — the catalog lives client-side and is the largest structured input. A too-small value would
under-measure the heaviest CPU case.
