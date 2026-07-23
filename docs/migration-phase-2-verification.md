# Phase 2 — Staging Verification

Cloudflare Worker + D1 for Opal's non-LLM state endpoints, deployed and
contract-verified against a live `workers.dev` URL. This is the Phase 2 exit
condition from the migration roadmap.

- **Date:** 2026-07-23
- **Worker:** `opal-worker`
- **Staging URL:** https://opal-worker.piskael03.workers.dev
- **D1:** database `opal` (region APAC), migration `0001_init.sql` applied `--remote`
- **Bindings live:** `DB` (D1), `RL` (60 requests/60s), `CORS_ORIGINS` (""), `PAL_PROVISIONING_KEY` (secret)
- **Bundle:** 139.66 KiB / gzip 24.32 KiB

## Contracts passed

| Endpoint | Result |
|---|---|
| `GET /healthz` | 200 `ok` (unlimited) |
| unknown route | 404 `{ error: { code: "not_found" } }` |
| `POST /v1/register` (valid key) | 200, 64-char token |
| `POST /v1/register` (same deviceId) | same token (idempotent) |
| `POST /v1/register` (bad key) | 401 `unauthorized` |
| `GET /v1/*` (no bearer) | 401 `unauthorized` |
| `POST /v1/health/ingest` | 200 `{ upserted: 2 }` |
| `GET /v1/health/day?date=…` | 200, exact ingested metrics |
| `POST /v1/widget/snapshot` | 200 `{ ok: true }` |
| `GET /v1/widget/snapshot` | 200, exact snapshot round-tripped |
| `GET /v1/memory` | 200 `{ facts: [], patterns: [] }` |

## Rate limiting

The `RL` binding (60 req/60s, keyed by device token) is enforced but
**permissive and eventually-consistent per Cloudflare colo**, as the plan
anticipated. Observed behavior:

- 70 sequential and 200 moderately-concurrent authenticated requests: **0** rejected.
- A single **300-wide simultaneous burst**: ~23/300 returned `429` with
  `{ error: { code: "rate_limited", message: "too many requests" } }`.

Takeaway: the limiter trips only under large simultaneous concurrency, not
sustained moderate load. It is a coarse abuse guard, not a precise quota — the
hard financial safeguard remains the OpenRouter credit cap (relevant from
Phase 3 onward; no LLM calls exist in Phase 2).

## Follow-ups

- **Rotate the provisioning key.** Staging currently holds a throwaway
  `PAL_PROVISIONING_KEY` used only for this contract smoke. Before any client
  points at this Worker, set the real key:
  `cd server/worker && npx wrangler secret put PAL_PROVISIONING_KEY`
- The remote `opal` D1 contains a few test rows from this smoke (device tokens,
  one health day, one widget snapshot). Harmless; wipe if a clean slate is wanted.
- Data migration from the DigitalOcean Node deployment is Phase 6. The old
  deployment stays live and untouched; this Worker runs in parallel.
