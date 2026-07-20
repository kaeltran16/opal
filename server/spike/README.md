# Opal Phase 1 feasibility spike

Isolated Cloudflare Worker + D1 that benchmarks worst-case Opal request CPU on the
Workers Free plan (10 ms/invocation limit). See
`docs/roadmap-cloudflare-workers-d1.md` and `docs/superpowers/plans/2026-07-20-cloudflare-phase-1-spike.md`.

The spike is disposable: a pass seeds Phase 2, a fail ends the $0 direction.

It reuses the portable modules from `server/src/` (imported, not copied) — `pal.ts`,
`prompts.ts`, `product.ts`, `schemas.ts`, `receipts.ts`, `redact.ts`, `auth.ts` — and backs
auth/memory with D1. `better-sqlite3` (pulled transitively by `memory.ts`) is aliased to a
throwing stub (dead code in the Worker); `imapflow`/`mailparser` never enter the bundle because
`RawEmail` is imported `type`-only. `server/src/` is not modified.

## Local (correctness only — NOT the CPU gate)

```bash
cd server/spike
npm install
npm test          # vitest + local D1 (13 tests)
npm run dev       # wrangler dev on http://localhost:8787
```

`npm test` runs the full suite in the vitest-pool-workers runtime against a local D1.
Local emulation proves correctness but does not prove Cloudflare's CPU accounting.

## Deploy + run the CPU gate (owner)

The gate runs on the deployed Worker. The benchmark driver needs Node 22.6+ (it imports the
`.ts` fixtures via type stripping; Node 24 is what this was built on).

```bash
cd server/spike
npx wrangler d1 create opal-spike           # paste database_id into wrangler.toml
npx wrangler d1 migrations apply opal-spike --remote
npx wrangler secret put OPENROUTER_API_KEY  # the credit-capped prod key
npx wrangler secret put PAL_PROVISIONING_KEY
npx wrangler deploy                          # note the *.workers.dev URL
npm run size                                 # bundle size vs the 3 MB gzip limit
```

Run the benchmark (STUB_LLM=1 is the deployed default → CPU-isolation run, $0):

```bash
BASE_URL=https://opal-spike.<subdomain>.workers.dev \
PROVISIONING_KEY=<same as the secret> \
REPS=50 CATALOG_N=36 \
CF_API_TOKEN=<Account Analytics: Read token> \
CF_ACCOUNT_ID=<account id> WORKER_NAME=opal-spike \
node bench/drive.mjs           # writes bench/results.md
```

Live-smoke (proves the 30 s timeout + one retry on the real runtime, uses the capped key):
redeploy once with `STUB_LLM=0` (or `wrangler deploy --var STUB_LLM:0`) and run the driver with `REPS=3`.

### Optional local driver smoke (not the gate)

To exercise the driver end-to-end without deploying: create `.dev.vars` with
`PAL_PROVISIONING_KEY=test-prov-key`, run `npx wrangler d1 migrations apply opal-spike --local`,
start `npm run dev`, then run the driver with `BASE_URL=http://localhost:8787
PROVISIONING_KEY=test-prov-key REPS=3 CF_API_TOKEN=x CF_ACCOUNT_ID=x node bench/drive.mjs`. The
GraphQL analytics call returns a `note` locally (no analytics) — expected. The four route
contracts are already covered by `npm test`, so this smoke is optional.

## Go / no-go

- **Go:** worst-case CPU P99 < 10 ms with a documented margin, zero 1102/1027, bundle < 3 MB.
  → proceed to Phase 2 (route porting), seeded from this spike.
- **No-go:** any 1102/1027, or CPU cannot fit reliably. Measure which deterministic step
  dominates, trim only where the measurement supports it, re-run. If it still cannot fit,
  stop the $0 migration and reconsider a paid always-on service (roadmap).
