# Roadmap: Cloudflare Workers + D1 backend migration

Status: deferred / not scheduled. Captured 2026-07-17.

## Decision summary

Migrate Opal's DigitalOcean-hosted Node backend to Cloudflare Workers + D1 if
the Workers Free CPU budget passes a production-runtime feasibility benchmark.

The target keeps `opal.kael.life`, the OpenRouter key, device authentication,
Pal memory, Health ingestion, and widget snapshots behind a trusted backend,
without a sleeping container or a recurring hosting charge.

Email sync is split at the trust boundary:

- The native Flutter client owns IMAP credentials, IMAP transport, MIME parsing,
  deterministic filtering, deduplication, body limits, and PII redaction.
- The Worker receives only sanitized receipt candidates, calls OpenRouter, validates
  the structured result, and returns importable entries.
- Flutter web does not perform real IMAP sync.

This roadmap records the intended direction only. Revalidate Cloudflare pricing,
limits, APIs, and the current Opal code before implementation.

## Why this direction

The replacement must satisfy four constraints:

1. No recurring hosting charge for the current personal-use workload.
2. No container cold start for Pal calls or iOS widget refreshes.
3. No OpenRouter API key in the Flutter binary or device storage.
4. Preserve the current external API contract where practical so the app, widget,
   and Health Shortcut do not need a coordinated URL migration.

Free container platforms fail the second constraint because they sleep when idle.
A literal backend-less app fails the third constraint and cannot support the current
widget workaround without a paid Apple team. Workers + D1 retain a narrow trusted
backend while removing VM and process management.

## Current backend responsibilities

The backend under `server/src/` currently owns:

- Fastify HTTP routing, CORS, request validation, bearer authentication, and rate
  limiting (`app.ts`).
- OpenRouter transport, prompts, structured parsing, and Pal actions (`pal.ts`,
  `prompts.ts`, `product.ts`, `schemas.ts`).
- SQLite persistence for device tokens, Pal memory, Health metrics, and the current
  widget snapshot (`store.ts`, `memory.ts`, `health.ts`, `widget.ts`).
- IMAP transport, MIME parsing, receipt filtering, and OpenRouter extraction
  (`imap.ts`, `email.ts`, `receipts.ts`, `redact.ts`).
- A Node process, systemd service, nginx proxy, and SSH-based GitHub deployment.

Most business logic is already pure TypeScript and portable. The incompatible pieces
are Fastify's listening-server model, `better-sqlite3`, systemd/nginx deployment, and
the IMAP/MIME workload on the Workers Free CPU and bundle budgets.

## Target architecture

```text
Flutter app -------- HTTPS --------> Cloudflare Worker ------ fetch ------> OpenRouter
    |                                      |
    | native IMAP + MIME                   | D1 binding
    v                                      v
Gmail IMAP                           tokens / memory / health / widget

iOS widget -------- HTTPS ----------^
Health Shortcut ---- HTTPS ----------^
```

### Worker

Use one Worker with an explicit `fetch` handler and route dispatch. Do not introduce
an HTTP framework unless the native routing implementation proves materially harder
to maintain. Reuse the existing Zod schemas, prompt builders, Pal logic, product
vocabulary, receipt extraction, and deterministic transforms.

Worker secrets:

- `OPENROUTER_API_KEY`
- `PAL_PROVISIONING_KEY`

Non-secret configuration:

- `OPENROUTER_BASE_URL`
- `PAL_MODEL`
- `PAL_REQUEST_TIMEOUT_MS`
- allowed CORS origins

The OpenRouter key must have its own daily or monthly credit limit. The Worker rate
limiter is a traffic control, not the authoritative spending boundary.

### D1

Use one D1 database with an Asia-Pacific location hint. Preserve the existing SQLite
schema and semantics unless D1 requires a documented change:

- `device_tokens`
- `pal_facts`
- `pal_patterns`
- `health_metrics`
- `widget_snapshot`

Use versioned SQL migrations. Keep queries prepared and indexed. Do not add an ORM;
the schema and query set are too small to justify one.

D1 store operations become asynchronous. Pal remains storage-independent: route
handlers load the memory digest, call Pal, and then apply validated memory operations.

### Native email sync

Replace the current server-side IMAP scan with a client-side mailbox adapter behind
the existing `EmailSyncService` interface.

The native client flow is:

1. Read the Gmail app password from the device keychain.
2. Connect to IMAP and fetch recent INBOX messages using the current date and count
   bounds.
3. Extract the minimum MIME text and header fields required by receipt detection.
4. Apply sender filtering, Message-ID deduplication, obvious non-receipt filtering,
   body-size limits, and PII redaction on-device.
5. Submit sanitized candidates in bounded batches to `POST /v1/email/extract`.
6. Receive validated merchant, amount, transaction date, and category values.
7. Persist entries through the existing client repository and `sourceRef` dedup path.

The Worker never receives the Gmail app password. The client never receives the
OpenRouter key. Background email scheduling remains out of scope; current email sync
is already pull-based.

The client IMAP/MIME dependency is deliberately not selected in this roadmap. At
implementation time, compare maintained Flutter packages against a small native iOS
adapter and choose the smaller reliable option. Do not write an IMAP protocol client.

## Endpoint disposition

| Current endpoint | Target owner | Migration |
| --- | --- | --- |
| `GET /healthz` | Worker | Keep contract |
| `POST /v1/register` | Worker + D1 | Keep contract |
| `POST /v1/chat` | Worker + D1 + OpenRouter | Keep contract |
| `POST /v1/parse` | Worker + OpenRouter | Keep contract |
| `POST /v1/nutrition/estimate` | Worker + OpenRouter | Keep contract |
| `POST /v1/review` | Worker + D1 + OpenRouter | Keep contract |
| `POST /v1/insights` | Worker + D1 + OpenRouter | Keep contract |
| `POST /v1/suggest-workout` | Worker + OpenRouter | Keep contract |
| `POST /v1/post-workout-note` | Worker + OpenRouter | Keep contract |
| `POST /v1/routine` | Worker + D1 + OpenRouter | Keep contract |
| `POST /v1/agenda` | Worker + D1 + OpenRouter | Keep contract |
| `POST /v1/suggestions` | Worker + OpenRouter | Keep contract |
| Memory GET/POST/DELETE routes | Worker + D1 | Keep contracts |
| Health ingest/day routes | Worker + D1 | Keep contracts |
| Widget snapshot POST/GET routes | Worker + D1 | Keep contracts |
| `POST /v1/email/test` | Native client | Remove after cutover |
| `POST /v1/email/sync` | Native client | Remove after cutover |
| `POST /v1/email/extract` | Worker + OpenRouter | New sanitized extraction seam |

## Free-tier feasibility snapshot

Values below were checked on 2026-07-17 and are not permanent assumptions.

| Resource | Workers Free limit | Opal implication |
| --- | ---: | --- |
| Requests | 100,000/day | One Worker request per API call |
| CPU time | 10 ms/invocation | Mandatory benchmark gate |
| Memory | 128 MB | Exclude IMAP/MIME packages from Worker bundle |
| Worker size | 3 MB | Measure the production bundle before cutover |
| HTTP wall time | Unlimited while client remains connected | Compatible with bounded OpenRouter waits |
| D1 database size | 500 MB | Current state is small and bounded |
| D1 reads | 5 million rows/day | Index token, memory, and date lookups |
| D1 writes | 100,000 rows/day | Current personal write volume should be measured |
| D1 queries | 50/invocation | Keep each handler to a small bounded query set |
| D1 Time Travel | 7 days | Free point-in-time recovery window |

Current references:

- [Workers pricing](https://developers.cloudflare.com/workers/platform/pricing/)
- [Workers limits](https://developers.cloudflare.com/workers/platform/limits/)
- [D1 pricing](https://developers.cloudflare.com/d1/platform/pricing/)
- [D1 limits](https://developers.cloudflare.com/d1/platform/limits/)
- [D1 data location](https://developers.cloudflare.com/d1/configuration/data-location/)
- [D1 Time Travel](https://developers.cloudflare.com/d1/reference/time-travel/)
- [Workers secrets](https://developers.cloudflare.com/workers/configuration/secrets/)
- [Workers custom domains](https://developers.cloudflare.com/workers/configuration/routing/custom-domains/)
- [OpenRouter key limits](https://openrouter.ai/docs/api/reference/authentication)

## Mandatory go/no-go gate

Do not begin the full migration until a minimal deployed Worker on the Free plan is
benchmarked with production-shaped inputs. Local emulation is useful for correctness
but does not prove Cloudflare CPU accounting.

Benchmark at least:

- Chat with the maximum retained 20-message history and representative full context.
- Routine generation with the full exercise catalog and a maximum structured reply.
- Insights/review with the largest current context payload.
- Email extraction with eight maximum-sized sanitized candidates.
- D1-authenticated requests that read memory and apply memory operations.

Record Worker CPU time, wall time, bundle size, D1 query count, and any `1102` CPU
limit failures across repeated runs. Proceed only when worst-case requests stay below
the platform CPU limit with a documented margin based on observed variance.

If the gate fails:

1. Measure which deterministic step consumes CPU.
2. Reduce oversized inputs or batch sizes only where the measurement supports it.
3. Re-run the same benchmark.
4. If representative behavior cannot fit reliably, stop the $0 migration. Reconsider
   a paid always-on service rather than weakening validation or exposing secrets.

## Migration phases

### Phase 0 — revalidate and recover

- Recheck all linked Cloudflare limits and plan availability.
- Confirm `kael.life` is or can be managed as a Cloudflare zone.
- Inventory production environment variables without copying secret values into docs.
- Recover a consistent `loop.sqlite` backup from DigitalOcean if one still exists.
- Record the current production endpoint responses used by Flutter, the widget, and the
  Health Shortcut as contract fixtures.

Exit condition: current contracts and recoverable data are known.

### Phase 1 — feasibility spike

- Create an isolated Worker prototype using only portable Pal modules, Zod, a D1 test
  binding, and the OpenRouter fetch client.
- Exercise the mandatory benchmark cases above on the actual Free runtime.
- Verify the production bundle remains under the Worker size limit.
- Verify the Worker can sustain the current 30-second OpenRouter timeout and one retry.
- Make the explicit go/no-go decision before porting routes.

Exit condition: the $0 runtime is demonstrated, not assumed.

### Phase 2 — Worker and D1 foundation

- Add Worker configuration, generated binding types, local development configuration,
  and the initial D1 migration under `server/`.
- Implement explicit method/path routing, JSON responses, CORS, structured error mapping,
  request logging, and a health endpoint.
- Replace process environment access with typed Worker bindings.
- Add D1-backed token, memory, Health, and widget stores with the current behavior.
- Port bearer authentication and per-token rate limiting.
- Add explicit request and string bounds to every externally supplied schema.

Exit condition: non-LLM state endpoints pass contract tests locally and on a staging
`workers.dev` URL.

### Phase 3 — Pal endpoints

- Reuse existing prompts, product vocabulary, action conversion, memory operations,
  OpenRouter retry behavior, and Zod result validation.
- Port the Pal routes in small contract-tested groups.
- Preserve status codes and response bodies consumed by `HttpPalService`.
- Verify OpenRouter usage and cost remain visible in Worker logs without logging prompts,
  secrets, email contents, or Health values.

Exit condition: all non-email Flutter Pal features pass against staging without client
contract changes.

### Phase 4 — native email boundary

- Add a native mailbox adapter behind `EmailSyncService`.
- Port deterministic sender filtering, deduplication, non-receipt detection, body bounds,
  and PII redaction to Dart or the native adapter.
- Add the authenticated Worker extraction endpoint using the existing receipt prompt and
  output schema.
- Keep batch failures isolated so one bad batch does not discard successful results.
- Disable real email sync on Flutter web with an explicit unavailable state or the current
  mock behavior.

Exit condition: native test-connection, sync, extraction, local persistence, and duplicate
suppression work without sending IMAP credentials to Cloudflare.

### Phase 5 — deployment automation

- Replace the SSH/systemd deployment job with Cloudflare deployment after tests.
- Store only the Cloudflare deployment token in GitHub Actions; provision Worker runtime
  secrets through Cloudflare's secret mechanism.
- Decide and document whether production D1 migrations are an explicit manual gate or a
  controlled CI step. Do not hide schema changes inside Worker startup.
- Keep the old deployment workflow available until production cutover succeeds.

Exit condition: staging deploys are repeatable and production changes remain reviewable.

### Phase 6 — data migration and cutover

- Stop writes to the old API for a short personal maintenance window.
- Export the final SQLite database to SQL and import it into D1.
- Validate table counts and representative token, memory, Health, and widget rows.
- Deploy the tested Worker version and attach `opal.kael.life` as its custom domain.
- Run live app, widget, Shortcut, Pal, memory, Health, and native email checks.
- Monitor Worker errors, CPU time, D1 usage, and OpenRouter spend before removing the old
  deployment path.

If the old database is unavailable, initialize D1 empty. Existing clients should recover
device authentication through their current 401-clear-and-register flow; server-only Pal
memory and Health history cannot be reconstructed without a backup.

Exit condition: all current consumers use the Worker through the existing production URL.

### Phase 7 — cleanup

- Remove Fastify, `@fastify/rate-limit`, `better-sqlite3`, `imapflow`, and `mailparser` only
  after the Worker and native replacements are verified.
- Remove the Node listener, systemd unit, nginx example, bootstrap script, and SSH deploy.
- Update `server/README.md`, environment examples, native setup docs, and architecture notes.
- Keep reusable pure TypeScript tests and add Worker/D1 contract coverage.

Exit condition: no dormant DigitalOcean deployment path or server-only dependency remains.

## Verification strategy

Test behavior rather than Cloudflare implementation details:

- Preserve pure tests for prompts, Pal actions, JSON extraction, receipt classification,
  redaction, and product vocabulary.
- Replace Fastify injection tests with Worker request/response contract tests.
- Test D1 migrations and every store against a local persisted D1 database.
- Test authentication, registration races, rate limiting, CORS, malformed input, upstream
  timeouts, retryable errors, and OpenRouter failure mapping.
- Test the native mailbox adapter with recorded MIME fixtures and a fake transport; live
  Gmail verification remains a device/account test.
- Test that sanitized extraction requests contain no app password and no fields excluded
  by the redaction contract.
- Run end-to-end staging checks from Flutter, the iOS widget, and the Health Shortcut.
- Re-run the CPU feasibility suite against the final production bundle before cutover.

The current Windows environment does not have the Flutter/Dart toolchain and should not be
modified to install it. Flutter analysis and tests remain a handoff for the user's normal
verification machine.

## Security boundaries

- Never ship or return the OpenRouter key to a client.
- Never send or store the IMAP app password in the Worker or D1.
- Treat `PAL_PROVISIONING_KEY` as an enrollment gate, not a strong secret; it is embedded in
  app and widget builds today.
- Validate all request bodies and query parameters before D1 or OpenRouter use.
- Use prepared D1 statements and explicit limits for histories, catalogs, email bodies, and
  extraction batches.
- Rate-limit by validated device token. Cloudflare's limiter is permissive and local, so
  the OpenRouter key credit cap remains the hard financial safeguard.
- Do not log prompts, raw emails, credentials, memory facts, or Health values.

## Known risks and trade-offs

- **Workers Free CPU:** 10 ms is tight and is the primary feasibility risk.
- **No free-tier SLA:** suitable for this personal app, not guaranteed infrastructure.
- **Plan drift:** Cloudflare can change limits or pricing before this roadmap is resumed.
- **Native-only email:** browsers cannot connect directly to IMAP; Flutter web loses real
  email sync.
- **New client dependency:** native IMAP/MIME support must be selected and maintained.
- **D1 consistency:** if global read replication is enabled later, use sessions where a
  handler requires read-your-own-writes behavior.
- **Data location:** an Asia-Pacific hint improves placement but is not a strict guarantee.
- **Authentication:** the migration preserves the existing device-token model rather than
  expanding scope into user accounts.

## Non-goals

- Multi-user accounts, teams, or tenant administration.
- Background email scheduling or APNs-based receipt import.
- A new ORM, dependency-injection framework, or generalized storage abstraction.
- Rewriting stable prompt, Pal, product, or deterministic receipt logic.
- Changing Flutter wire contracts without a demonstrated platform requirement.
- Installing Flutter, Dart, or Node tooling in the current Windows environment.

## Revisit checklist

When this work is picked up:

1. Re-read this roadmap against the current repository.
2. Recheck Cloudflare and OpenRouter pricing, limits, and API availability.
3. Confirm whether the DigitalOcean SQLite data is recoverable.
4. Decide the native IMAP/MIME implementation after reviewing current maintained options.
5. Execute Phase 1 only.
6. Review the benchmark evidence and make a fresh go/no-go decision.
7. Write a task-level implementation plan only after the feasibility gate passes.

