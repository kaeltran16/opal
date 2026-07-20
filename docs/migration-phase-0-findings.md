# Migration Phase 0 — revalidate and recover

Companion to [`roadmap-cloudflare-workers-d1.md`](roadmap-cloudflare-workers-d1.md). Records the
Phase 0 outputs so Phase 1 starts from known contracts and confirmed limits.

Captured 2026-07-20. Prerequisites confirmed by the owner: Cloudflare account ready, OpenRouter key
with a credit cap, DigitalOcean `loop.sqlite` recoverable.

## 1. Limit revalidation (Cloudflare, checked 2026-07-20)

The roadmap snapshot was 2026-07-17. Rechecked against the live docs three days later.

| Resource | Roadmap snapshot | 2026-07-20 | Delta |
| --- | ---: | ---: | --- |
| Requests | 100,000/day | 100,000/day | none |
| CPU time (Free) | 10 ms/invocation | 10 ms/invocation | none — still fixed on Free; only Paid is configurable (up to 5 min) |
| Memory | 128 MB | 128 MB per isolate | none |
| Worker size | 3 MB | 3 MB gzipped (64 MB uncompressed) | none; the 3 MB gate is post-gzip |
| D1 size | 500 MB | 500 MB | none |
| D1 queries/invocation | 50 | 50 | none |
| D1 Time Travel | 7 days | 7 days | none |
| D1 reads | 5M rows/day | carry-forward | not independently re-confirmed on the limits page (it lists queries/invocation, not daily rows); recheck the D1 pricing page's free daily allowances at Phase 1 |
| D1 writes | 100k rows/day | carry-forward | same as above |

**Load-bearing result: nothing changed.** The 10 ms Free CPU limit is confirmed still in force and
still Free-only-fixed. Revalidation did **not** de-risk the feasibility gate — the mandatory go/no-go
CPU benchmark on a real deployed Worker (roadmap "Mandatory go/no-go gate") remains mandatory and is
still the primary risk.

Sources rechecked: Workers [limits](https://developers.cloudflare.com/workers/platform/limits/) and
[pricing](https://developers.cloudflare.com/workers/platform/pricing/); D1
[limits](https://developers.cloudflare.com/d1/platform/limits/).

## 2. Production environment inventory

From `server/src/config.ts` (names only; no secret values recorded).

**Secrets → `wrangler secret put`:**

- `OPENROUTER_API_KEY` (required)
- `PAL_PROVISIONING_KEY` (required)

**Non-secret config → Worker `vars`:**

- `OPENROUTER_BASE_URL` (default `https://openrouter.ai/api/v1`)
- `PAL_MODEL` (default `deepseek/deepseek-v4-flash`)
- `PAL_REQUEST_TIMEOUT_MS` (default `30000`)
- `CORS_ORIGINS` (comma-separated allowlist)

**Node-process-only → dropped under Workers:**

- `PORT` (8080) — Workers has no listener
- `SQLITE_PATH` (`./loop.sqlite`) — replaced by the D1 binding

This exactly matches the roadmap's "Worker secrets" and "Non-secret configuration" lists. No drift.

## 3. Endpoint contract fixtures

Derived from `server/src/app.ts` + `schemas.ts` + `pal.ts` return types. These are the contracts the
Worker must preserve (roadmap Phase 2/3: "Preserve status codes and response bodies").

**Auth:** bearer token on every `/v1/*` route except `/v1/register` (which authenticates via
`provisioningKey` in the body). Rate limit: 60/min keyed by device token, falling back to IP for
`/register` and `/healthz`.

**Error envelope (all failures):** `{ error: { code: string, message: string, details?: string[] } }`

**Status code catalog:** 200 ok · 204 CORS preflight · 400 `bad_request` · 401 `unauthorized`
(bad provisioning key / invalid token) · 404 `not_found` · 422 `imap_auth` · 429 rate-limited ·
500 `upstream` (generic) · 502 `upstream` (`OpenRouterError`).

| Method + path | Auth | Request | 200 response |
| --- | --- | --- | --- |
| `GET /healthz` | none | — | `ok` (text) |
| `POST /v1/register` | provisioningKey | `{ provisioningKey, deviceId }` | `{ token }` |
| `POST /v1/chat` | token | `{ history[], message, context:chatContext }` | `{ reply, actions: PalAction[] }` (memoryOps applied server-side, not on wire) |
| `POST /v1/parse` | token | `{ text }` | `{ type, amount\|null, duration\|null, category\|null, title, note\|null, direction:'expense'\|'income'\|null }` |
| `POST /v1/nutrition/estimate` | token | `{ text }` | `{ name, calLo, calHi, confidence:'high'\|'med'\|'low' }` |
| `POST /v1/review` | token | `{ context:reviewContext }` | `{ text }` |
| `POST /v1/insights` | token | `{ context:insightsContext }` | `{ headline\|null, lede\|null, suggestion\|null, correlationNarration?\|null, wins:[{colorToken,title,sub}], patterns:[{colorToken,title,detail}] }` |
| `POST /v1/suggest-workout` | token | `{ another, context:suggestContext }` | `{ routineId, reason }` |
| `POST /v1/post-workout-note` | token | `{ context:postWorkoutContext }` | `{ note }` |
| `POST /v1/routine` | token | `{ goal, exercises[] }` | `{ name, tag, estMin?\|null, rationale?\|null, exercises:[{exerciseId, sets:[{reps?,weight?,duration?}]}] }` |
| `POST /v1/agenda` | token | `{ context:chatContext }` | `{ proposals:[{id,tag,colorToken,icon,title,body,approveLabel,approveIcon,doneLabel,action\|null}], autopilot:[{id,colorToken,icon,title,subtitle,enabled}], streakDays }` |
| `POST /v1/suggestions` | token | `{ surface, context: chatContext\|suggestContext }` | `{ suggestions:[{label,icon,colorToken,entry:{type,title,amount\|null,category\|null,minutes\|null}\|null}] }` |
| `GET /v1/memory` | token | — | `{ facts:[{id,text}], patterns:[{colorToken,title,detail}] }` |
| `POST /v1/memory/refresh` | token | `{ context:insightsContext }` | memory digest (as above) |
| `DELETE /v1/memory/facts/:id` | token | — | memory digest |
| `DELETE /v1/memory` | token | — | `{ ok: true }` |
| `POST /v1/health/ingest` | token | `{ date, metrics }` | `{ upserted }` |
| `GET /v1/health/day?date=` | token | query `date=YYYY-MM-DD` | `{ date, metrics }` |
| `POST /v1/widget/snapshot` | token | widgetSnapshotBody (9 numeric rings) | `{ ok: true }` |
| `GET /v1/widget/snapshot` | token | — | snapshot, or 404 `not_found` |
| `POST /v1/email/test` | token | imapCreds | `{ ok: boolean }` — 422 on `imap_auth` · **native after cutover** |
| `POST /v1/email/sync` | token | imapCreds + `{ senderFilters, since }` | `{ items, truncated }` — **native after cutover** |

`PalAction` union (client executes by `kind`, ignores unknown): `log_expense`, `log_income`,
`log_movement`, `log_ritual`, `set_daily_budget`, `set_move_goal`, `set_ritual_goal`,
`create_routine`, `log_meal`.

## 4. Open Phase 0 items (need the owner's hands)

1. **Pull the `loop.sqlite` backup** from DigitalOcean and verify it opens (row counts for
   `device_tokens`, `pal_facts`, `pal_patterns`, `health_metrics`, `widget_snapshot`). Confirmed
   recoverable; the actual export is a DO-side action.
2. **Confirm `kael.life` zone attachment** mechanics in the Cloudflare dashboard (custom-domain route
   for the Worker). Account confirmed ready; the zone wiring is verified at cutover, not Phase 1.
3. **Optional live-response capture** — the response shapes above are derived from source, which is
   authoritative for structure. If exact-byte fixtures are wanted, capture one live response per
   endpoint from production before the old deployment is torn down.

## 5. Exit condition

Roadmap Phase 0 exit: "current contracts and recoverable data are known."

- Contracts: **known** (section 3).
- Env/config surface: **known** (section 2).
- Limits: **revalidated, unchanged** (section 1).
- Recoverable data: **confirmed recoverable**, pull pending (section 4, item 1).

Phase 0 is complete except for the owner-side backup pull, which is not a blocker for starting the
Phase 1 feasibility spike. Per the roadmap, execute **Phase 1 only** next, then make a fresh
go/no-go decision on the benchmark evidence before any route porting.
