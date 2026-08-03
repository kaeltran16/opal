# Opal backend — Cloudflare Worker + D1

The trusted backend for the Opal app, iOS widget, and Health Shortcut. It serves
`https://opal.kael.life` from a single Cloudflare Worker with a D1 database.

Two things it exists to hold that a client cannot: the **OpenRouter API key**, and
the small amount of **server-side state** (device tokens, Pal memory, Health
metrics, the widget snapshot).

## Layout

| Path | What |
| --- | --- |
| `worker/` | The deployable. Routing, CORS, D1 stores, email extraction, wrangler config. |
| `src/` | Shared pure TypeScript the Worker imports: Pal, prompts, product vocabulary, zod schemas, receipt extraction, PII redaction, bearer parsing. No I/O, no platform APIs. |

`src/` is a library, not a service — it has no entry point. It stays a separate
package so its pure unit tests run under plain Vitest without the Workers pool.
The Worker reaches it via relative imports (`../../src/pal.js`).

## Local dev

```bash
cd worker
cp .env.example .env      # OPENROUTER_API_KEY + PAL_PROVISIONING_KEY
npm install
npm run dev               # wrangler dev
npm test                  # Vitest on workerd, local D1, no network
npm run size              # dry-run build; check the bundle against the 3 MB limit
```

Shared modules:

```bash
cd server
npm install
npm test                  # pure unit tests, no network
npm run typecheck
```

## Deploy

`.github/workflows/worker.yml` runs on any push to `main` touching
`server/worker/**`: test → bundle-size build → `wrangler deploy` → `/healthz`
check. Repository config: secrets `CLOUDFLARE_API_TOKEN` and
`CLOUDFLARE_ACCOUNT_ID`, variable `WORKER_BASE_URL`.

`WORKER_BASE_URL` points at the `workers.dev` URL rather than `opal.kael.life`
so the post-deploy healthcheck does not race DNS.

Note the path filter: changes under `server/src/**` alone do **not** trigger a
deploy, even though the Worker bundles them. Touch something in `server/worker/`
or dispatch the workflow manually when shipping a shared-module change.

### D1 migrations are a manual gate

Migrations are deliberately not applied by CI, so a schema change is never a
side effect of a deploy:

```bash
cd worker
npx wrangler d1 time-travel info opal    # record the bookmark first
npm run migrate:remote
```

Time Travel is the only rollback for a bad migration, and the free recovery
window is 7 days. `npm run migrate:local` does the same against local D1.

## Configuration

Non-secret values live in `worker/wrangler.toml` under `[vars]` and deploy with
the Worker: `CORS_ORIGINS`, `OPENROUTER_BASE_URL`, `PAL_MODEL`,
`PAL_REQUEST_TIMEOUT_MS`.

Secrets are set out of band and are never in the repo:

```bash
npx wrangler secret put OPENROUTER_API_KEY
npx wrangler secret put PAL_PROVISIONING_KEY
```

- `OPENROUTER_API_KEY` — give it its own credit cap on OpenRouter. The Worker's
  rate limiter is traffic control; the credit cap is the actual spending bound.
- `PAL_PROVISIONING_KEY` — gates `POST /v1/register`. It ships inside the app and
  widget builds, so treat it as an enrollment gate, not a strong secret. It must
  match the `--dart-define` value (`dart_defines/prod.json`).

Bindings: `DB` (D1, database `opal`) and `RL` (rate limit, 60 req/60 s).

## Endpoints

`GET /healthz` → `ok`. Unauthenticated and not rate limited.

`POST /v1/register` takes `{ provisioningKey, deviceId }` and returns `{ token }`.
Every other `/v1/*` route requires that token as `Authorization: Bearer`, and
answers 401 when it is missing or unknown — the client clears its stored token
and re-registers on a 401.

| Route | Method |
| --- | --- |
| `/v1/chat` | POST |
| `/v1/parse`, `/v1/nutrition/estimate` | POST |
| `/v1/review`, `/v1/insights`, `/v1/agenda`, `/v1/suggestions` | POST |
| `/v1/suggest-workout`, `/v1/post-workout-note`, `/v1/routine` | POST |
| `/v1/memory` | GET, DELETE |
| `/v1/memory/fact/:id` | DELETE |
| `/v1/memory/refresh` | POST |
| `/v1/health/ingest` | POST |
| `/v1/health/day` | GET |
| `/v1/widget/snapshot` | POST, GET |
| `/v1/email/extract` | POST |

`POST /v1/chat` returns `{ reply, actions[] }`. Pal can call tools to mutate data
(`log_expense`/`log_income`/`log_movement`/`log_ritual`, `set_daily_budget`/
`set_move_goal`/`set_ritual_goal`, `create_routine`); each call is validated
server-side and returned as an `action` the client applies and can undo.
`create_routine` carries only the goal — the client fulfills it by calling
`/v1/routine` with its exercise catalog, so the catalog never rides on `/chat`.
Unknown or invalid tool calls are dropped.

Structured endpoints request strict JSON (`response_format`); `extractJson`
remains a tolerant fallback, so the model slug stays swappable.

Upstream failures map to 502 (`OpenRouterError`) or 500, both as an `upstream`
error envelope.

## Email runs on the device

IMAP is **not** in the Worker. The native client owns the app password, the IMAP
connection, MIME parsing, sender filtering, Message-ID dedup, non-receipt
filtering, body bounds, and PII redaction. It posts already-sanitized candidates
to `POST /v1/email/extract` in batches of at most `BATCH_SIZE` (8), one LLM call
per request, and the client loops across batches so one failed batch cannot
discard the others.

So the Worker never sees the Gmail app password, and the client never sees the
OpenRouter key. Flutter **web** cannot sync email at all — browsers have no raw
TCP socket — and gets an explicit unavailable state rather than a silent no-op.

The old server-side `/v1/email/test` and `/v1/email/sync` routes were removed
with the DigitalOcean backend.

## CORS

Browser calls are rejected unless the origin is listed in `CORS_ORIGINS`
(comma-separated, scheme + host + optional port, no trailing slash). Currently
`http://localhost:8080` for the local web preview. Empty means no browser origin
is allowed. Native builds are unaffected — CORS only constrains browsers.

## Client wiring

```
--dart-define=PAL_BASE_URL=https://opal.kael.life
--dart-define=PAL_PROVISIONING_KEY=<same value as the Worker secret>
```

Without `PAL_BASE_URL` the app stays on `MockPalService`.

## Free-tier budget

The binding constraint is **10 ms CPU per invocation**. `/v1/chat` is the
critical path; Phase 1 measured p90 ≈ 7 ms and Phase 4 saw 8–15 ms on the
heaviest route, with zero enforced CPU kills. See
`docs/migration-phase-1-benchmark.md`. The bundle is ~39 KiB gzip against a 3 MB
limit. Watch CPU time if prompt or catalog sizes grow.
