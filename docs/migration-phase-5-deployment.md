# Phase 5 — Deployment automation

Replaces the SSH/systemd deploy for the Worker path with a Cloudflare deploy that
runs after tests. The DigitalOcean workflow stays intact until Phase 6 cutover.

- **Date:** 2026-07-30
- **Worker:** `opal-worker` (currently `workers.dev` only — no custom domain yet)
- **New workflow:** `.github/workflows/worker.yml`

## What changed

| File | Change |
|---|---|
| `.github/workflows/worker.yml` | New: test → build → `wrangler deploy` on push to `main` |
| `.github/workflows/deploy.yml` | Path filter now excludes `server/worker/**` and `server/spike/**` so Worker-only changes no longer redeploy the droplet |
| `server/worker/package.json` | Added `migrate:local` / `migrate:remote` scripts |

Both workflows are independent and path-filtered, so the two deploy paths coexist.
`deploy.yml` is untouched otherwise and remains the production path until cutover.

## CI gates

`test` job, on every PR and push touching `server/worker/**`:

1. `npm ci`
2. `npm test` — 51 tests / 11 files under `@cloudflare/vitest-pool-workers`
3. `npm run size` — `wrangler deploy --dry-run`, which fails the job if the bundle
   no longer builds. Current: 192.33 KiB / gzip 38.75 KiB against the 3 MB limit.

`tsc --noEmit` is deliberately not a CI gate: it reports pre-existing errors in the
test files only (the `cloudflare:test` virtual module is not in `tsconfig.json`'s
`types`, and older tests pass a third arg to the 2-param `worker.fetch`). Adding it
would require unrelated test cleanup. Noted in
`docs/migration-phase-4-verification.md` as well.

`deploy` job runs only on push to `main` after `test` passes, then healthchecks
`GET /healthz` (unauthenticated, unrate-limited) with a 30 s retry budget.

## Required repository configuration

GitHub Actions secrets (Settings → Secrets and variables → Actions):

| Name | Purpose |
|---|---|
| `CLOUDFLARE_API_TOKEN` | Deploy token. Scopes: *Workers Scripts: Edit*, *D1: Edit*, *Account Settings: Read*. Nothing broader. |
| `CLOUDFLARE_ACCOUNT_ID` | Target account |

GitHub Actions variable (not a secret):

| Name | Purpose |
|---|---|
| `WORKER_BASE_URL` | Base URL for the post-deploy healthcheck, e.g. `https://opal-worker.<subdomain>.workers.dev`. The healthcheck step is skipped when unset. |

Worker runtime secrets are **not** stored in GitHub. They are provisioned once
through Cloudflare and live only in the Worker:

```
cd server/worker
npx wrangler secret put OPENROUTER_API_KEY
npx wrangler secret put PAL_PROVISIONING_KEY
```

So the only credential in GitHub is the deploy token, per the roadmap's security
boundary. `wrangler deploy` does not clear existing Worker secrets.

## D1 migrations: explicit manual gate

**Decision: migrations are applied by hand, never by CI and never at Worker startup.**

```
npm run migrate:local     # local dev D1
npm run migrate:remote    # production D1 (opal)
```

Rationale:

- A schema change against the single production D1 database is effectively
  irreversible within a request path; D1 Time Travel gives a 7-day recovery window
  but recovery is a manual operation either way. A human should choose the moment.
- Migration frequency is near zero — one migration file (`0001_init.sql`) exists.
  Automating a once-a-quarter operation buys nothing and adds a failure mode where
  a merge silently mutates production schema.
- The roadmap explicitly forbids hiding schema changes inside Worker startup, and
  a CI step is the same hazard one layer out: schema and code would deploy in a
  single unreviewable action.
- Ordering matters at cutover (Phase 6 imports SQLite data into D1), and that
  sequence is a maintenance-window decision, not a CI one.

Consequence to respect: a migration that a new Worker version depends on must be
applied **before** merging that version, since deploy is automatic on merge.
Additive-first migrations keep that ordering safe.

## Verification

| Check | Command | Result |
|---|---|---|
| Unit suite | `npm test` | 51 passed / 11 files |
| Bundle builds | `npm run size` | 192.33 KiB / gzip 38.75 KiB |
| Workflow YAML parses | `yaml.safe_load` on both workflows | both parse; jobs `test`, `deploy` |
| `.env` not committed | `git check-ignore server/worker/.env` | ignored via `server/.gitignore` |

Not yet verified: an actual CI run. The `deploy` job cannot execute until
`CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`, and `WORKER_BASE_URL` are set in
the repository, and it first runs on the merge that lands this workflow. Until
then this phase is proven only locally.

## Exit condition

Met on the repeatability side: Worker deploys are a single reviewable workflow
gated on tests, with only a deploy token in CI, and production schema changes stay
an explicit manual step. Confirmation of a green CI deploy run is outstanding and
depends on the repository secrets above.
