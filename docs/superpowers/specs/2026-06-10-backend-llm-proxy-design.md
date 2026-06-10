# Loop Backend — LLM Proxy (U22 + U23) Design

> Scope decision: the backend is two independent subsystems — the **LLM proxy** (U22 server +
> U23 client) and the **IMAP receipt worker** (U24). This spec fully designs the LLM proxy and
> ships it first. The IMAP worker is sketched only enough to confirm the host serves both; it gets
> its own spec/plan later.

## Goals

- Replace `MockPalService` with a real Anthropic-backed proxy with **zero screen/controller changes**
  (the locked SF-3 contract): swapping is a single Riverpod provider override.
- Keep the exact handoff prompts **server-side**, editable without an app release.
- Run on the **existing DigitalOcean droplet** — no new managed platform, and the same service later
  hosts the IMAP worker.

## Non-goals

- Streaming chat (typing dots already animate against a full reply — noted future enhancement).
- The IMAP worker itself (U24, separate spec).
- Apple App Attest / DeviceCheck and APNs push (Mac/Apple-dev, deferred).

---

## 1. Topology

One **Node + TypeScript** service in `server/` (in the loop monorepo, outside `lib/`), on the droplet:

```
iOS app / chrome preview
        │  HTTPS (Bearer device-token)
        ▼
   Caddy (auto-TLS via Let's Encrypt, reverse proxy, CORS for web preview)
        ▼
   Node/Fastify service  ──►  Anthropic Messages API
        │
        ▼
   SQLite (single file)   ← device tokens now; IMAP dedup/state later (U24)
```

- **Caddy** terminates TLS (valid cert required by iOS ATS and the web preview's secure-context/CORS)
  and reverse-proxies to the Node service on localhost.
- Process managed by **systemd** (or Docker Compose); secrets via an env file, never committed.
- **SQLite** (single file on a persisted path) is the only datastore — zero-config, and U24's
  dedup/state tables share it.

Runtime choice rationale: Node/TS has the strongest ecosystem for both halves — `@anthropic-ai/sdk`
for the proxy and `imapflow` (best-in-class IMAP) for U24 — and a long-lived droplet process has none
of the edge-runtime TCP/timeout caveats that ruled out serverless options.

---

## 2. Endpoints

The client `PalService` exposes **5** operations. The handoff names 3 endpoints (`/chat`, `/review`,
`/parse`) but also gives prompts for workout suggestion and the post-workout note, so the proxy
exposes all 5, plus registration and health.

| Endpoint | Body (from client) | Returns | PalService method |
|---|---|---|---|
| `POST /v1/chat` | `{history[], message, context}` | `{reply}` | `chat` |
| `POST /v1/parse` | `{text}` | `ParsedEntryDraft` JSON | `parse` |
| `POST /v1/review` | `{month, context}` | `{text}` | `review` |
| `POST /v1/suggest-workout` | `{another, context}` | `{routineId, reason}` | `suggestWorkout` |
| `POST /v1/post-workout-note` | `{context}` | `{note}` | `postWorkoutNote` |
| `POST /v1/register` | `{provisioningKey, deviceId}` | `{token}` | (bootstrap) |
| `GET /healthz` | — | `200 OK` | — |

- **Prompt templates live on the server** — the exact handoff strings (`README.md` "AI Prompts").
  The client sends only structured data, never prompt text.
- `/parse` and `/suggest-workout` use Anthropic **tool-use / JSON mode** so the returned JSON is
  guaranteed well-formed (not best-effort string parsing). `/chat`, `/review`, `/post-workout-note`
  return free text.
- Model `claude-haiku-4-5`, env-configurable via `PAL_MODEL`. Verify the model id against the current
  Claude API at build time (use the `claude-api` skill).

### Context payloads (what each prompt needs)

| Prompt | Context fields |
|---|---|
| chat | userName; today's entries (`HH:MM Title (type, detail)`); daily budget, move goal, ritual goal; spent today, moved-min today, rituals done/total; week spent/budget, moved-min, rituals done/total; move streak (days) |
| review | month; spent (+ % vs last month); hours moved (+ %); active days; rituals kept/target (%); move streak; top category (+ %); discovered pattern string |
| suggest-workout | this week's workouts (`routineName — date — muscles`); dayOfWeek; available routines (id + name) |
| post-workout-note | routineName; set count; total volume kg; PR count; PR exercises; last same-routine session volume + daysAgo |

---

## 3. Context assembly (client side, `HttpPalService`)

`HttpPalService` injects `EntryRepository`, `GoalsRepository`, `WorkoutRepository`,
`RoutineRepository`, builds the context above, POSTs it, and maps the response into the existing DTOs.

- **Reuse, don't duplicate aggregates.** U18's monthly-review controller and Today's ring logic
  already compute most of these (spend, move minutes, rituals, streak, top category, monthly stats).
  Factor a small `PalContextBuilder` that calls existing aggregate code rather than re-deriving it.
  Where an aggregate currently lives inside a controller's display path, lift the pure computation so
  both the controller and the builder share one source of truth.
- The `discoveredPattern` for `/review` reuses whatever U18 already produces for its
  "Patterns Pal found" rows; the builder passes that string through. (If U18's patterns are
  hardcoded, that is the v1 source — improving pattern discovery is out of scope here.)
- `suggestWorkout`: the server returns `{routineId, reason}`; the service resolves
  `title`/`focus`/`estimatedMinutes` from `RoutineRepository` to fill the `WorkoutSuggestion` DTO.
- **The `PalService` interface is unchanged byte-for-byte.** `MockPalService` is untouched.

---

## 4. Auth — per-device token

1. On the first Pal call, the app checks `flutter_secure_storage` for a device token.
2. If absent → `POST /v1/register` with the build-time **provisioning key** (`--dart-define`) and a
   generated `deviceId` (UUID). The server validates the provisioning key, issues a random opaque
   token, stores `{token, deviceId, createdAt}` in SQLite, returns the token. The app saves it.
3. Every request carries `Authorization: Bearer <token>`. Middleware validates against SQLite and
   **rate-limits per token**.
4. `401` → the app re-registers once, then retries the original call.
5. Revocation = delete the token row.

Caveats (documented, accepted for now):
- The provisioning key ships in the app binary; it gates `/register` and is rotatable, but is
  extractable. Per-token rate limiting + revocation are the real backstops.
- Hardening with Apple **App Attest / DeviceCheck** is deferred to a Mac session (cannot be exercised
  on Windows/web).
- On web preview, `flutter_secure_storage` is not truly secure (already the project's documented
  stance for email creds) — acceptable for the Chrome preview.

---

## 5. Client wiring & config

- `palServiceProvider` is overridden with `HttpPalService(baseUrl, repos, secureStorage)` **only when
  `PAL_BASE_URL` is supplied** via `--dart-define`; otherwise it stays `MockPalService`. This keeps
  tests and a backend-less web preview working unchanged.
- Config via `--dart-define`: `PAL_BASE_URL`, `PAL_PROVISIONING_KEY`. Never committed.
- New client deps: `http` (already planned for U23). `flutter_secure_storage` already in the stack.

---

## 6. Error handling

**Client (`HttpPalService`):**
- 30s timeout; typed exceptions on non-2xx / network error / timeout.
- Single re-register retry on `401`, then surface the error.
- Controllers already render `AsyncValue.error`, so this finally gives Ask Pal a **real error state**
  (U21 explicitly deferred Pal-chat error handling to U23). Add user-facing error copy.

**Server:**
- Validate every input server-side; reject malformed bodies with `400`.
- Map Anthropic failures to `502` without leaking the API key or internals.
- Structured JSON error bodies (`{error: {code, message}}`).
- Per-token rate limiting; `429` on exceed.
- `ANTHROPIC_API_KEY`, `PAL_PROVISIONING_KEY`, `PAL_MODEL` from env. Key never logged.

---

## 7. Testing

**Server (Vitest or Jest):**
- Prompt-template fill: given a context object, the assembled Anthropic request matches the handoff
  template.
- Auth middleware: valid / invalid / revoked token; provisioning-key gate on `/register`.
- Input validation: malformed bodies rejected.
- Response shapes per endpoint, with a **mocked Anthropic client** — no real API calls, no spend in CI.

**Client (Dart, `http`'s `MockClient`):**
- `HttpPalService` builds the correct context JSON from fake repositories.
- Parses each response into the right DTO (`ParsedEntryDraft`, `WorkoutSuggestion`, strings).
- Re-registers on `401`; throws typed errors on failure.
- `MockPalService` and all existing widget/integration tests stay untouched.

No test hits the real Anthropic API or the droplet.

---

## 8. Deploy

- `Caddyfile` (auto-HTTPS, reverse proxy, CORS allow-list for the preview origin).
- `systemd` unit (or `docker-compose.yml`).
- `.env.example` documenting `ANTHROPIC_API_KEY`, `PAL_PROVISIONING_KEY`, `PAL_MODEL`, `PORT`,
  `SQLITE_PATH`.
- `server/README.md`: droplet setup, deploy, and the client `--dart-define` values.
- SQLite file on a persisted path.

---

## 9. U24 IMAP worker — forward sketch (host-fit confirmation only)

The same Node service later gains an `imapflow` worker on `node-cron` (15m default, user-configurable).
Shared SQLite tables: `accounts` (host/port/ssl/username + **app-password encrypted at rest** with a
server key; the app holds only a reference, per the handoff `EmailAccount.appPasswordRef`),
`imported_messages` (dedupe by message-id), `sync_jobs` (status). Flow: cron → IMAP fetch since last
UID → sender filter → parse receipt (heuristic, optionally reusing `/v1/parse`) → dedupe → store
`Entry` rows → APNs push + status report. `RealEmailSyncService` implements the existing
`EmailSyncService`, emitting the same `SyncStatus` stream by polling `/v1/sync/status`, swapped via a
provider override. **APNs is Apple-dev/Mac-later**; on Windows the app polls. This confirms Node +
SQLite + cron on the droplet covers U24 with no new platform — full design deferred to its own spec.

---

## Decisions locked

| Decision | Choice |
|---|---|
| Session scope | LLM proxy (U22+U23) full; IMAP (U24) sketched |
| Host | Existing DigitalOcean droplet, single service + Caddy + systemd |
| Runtime | Node + TypeScript (Fastify, `@anthropic-ai/sdk`) |
| Context flow | `HttpPalService` reads repos → structured JSON; server owns prompts + Anthropic |
| Auth | Per-device token via provisioning-key-gated `/register`; App Attest Mac-later |
| Persistence | SQLite on the droplet (tokens now, IMAP state later) |
| Repo layout | `server/` folder in the loop monorepo |
| Model | `claude-haiku-4-5`, env-configurable; non-streaming v1 |
