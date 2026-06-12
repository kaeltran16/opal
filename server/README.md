# Loop Pal proxy (U22) + email IMAP worker (U24)

Stateless backend for the Loop app. Two concerns:

- **Pal LLM proxy** — forwards to **OpenRouter** (OpenAI-compatible chat
  completions) with the handoff prompts (`PalService`). See
  `docs/superpowers/specs/2026-06-10-backend-llm-proxy-design.md`.
- **Email receipt import** — a live IMAP scan + LLM receipt extraction
  (`EmailSyncService`). **Pull model**: the client holds the IMAP app-password in
  the device keychain and sends it per request; the server stores **no
  credentials and no email state** (dedup is the client's job, by `sourceRef`).
  Sender filtering + Message-ID dedup are deterministic; field extraction is the
  model. A scheduled background scan + APNs push is intentionally **out of
  scope** here (device/Mac-gated, like the native HealthKit work).

Per-device bearer tokens (SQLite) gate every `/v1/*` endpoint except `/v1/register`.

The model is configurable via `PAL_MODEL` (any OpenRouter slug). The default is a
cheap, fast model; `/parse` and `/suggest-workout` ask the model for JSON and the
server validates it with zod, so it works across models without relying on
provider-specific structured-output support.

## Local dev

```bash
cp .env.example .env   # fill OPENROUTER_API_KEY + PAL_PROVISIONING_KEY
npm install
npm run dev            # tsx watch on PORT (default 8080)
npm test               # Vitest, no network
```

## Deploy (DigitalOcean droplet)

opal-api runs as a systemd service (`opal-api.service`) on the host, bound to
`0.0.0.0:8080`. TLS and public routing for `https://opal.kael.life` are handled
by the droplet's existing nginx reverse proxy (the co-hosted `krypton` stack),
which proxies to the host at `172.18.0.1:8080` (the nginx network's gateway).

Deploys are automated via GitHub Actions (`.github/workflows/deploy.yml`): every
push to `main` touching `server/**` runs tests, then rsyncs the source to the
droplet and runs `npm ci && npm run build && systemctl restart opal-api`.

First-time droplet setup (run once):

1. **Host service** — copy `server/scripts/bootstrap.sh` to the droplet and run
   it as root. It installs Node 24 + build tools, creates the `opal` user and
   `/opt/opal-api`, installs the systemd unit, and writes `.env`.
2. **nginx wiring** — issue a cert for `opal.kael.life` via the existing certbot,
   add the `server` block from `nginx-opal.conf.example` to the nginx config and
   reload, and let the container subnet reach the host service:
   `ufw allow from 172.18.0.0/16 to any port 8080 proto tcp`.

Verify: `curl https://opal.kael.life/healthz` → `ok`.

## Client wiring

Build the Flutter app with:

```
--dart-define=PAL_BASE_URL=https://opal.kael.life
--dart-define=PAL_PROVISIONING_KEY=<same as server PAL_PROVISIONING_KEY>
```

Without `PAL_BASE_URL` the app stays on `MockPalService`.

## Environment

| Var | Required | Notes |
| --- | --- | --- |
| `OPENROUTER_API_KEY` | yes | OpenRouter API key (`sk-or-...`). Server-side only. |
| `PAL_PROVISIONING_KEY` | yes | Gates `POST /v1/register`; ships in the app build. |
| `PAL_MODEL` | no | OpenRouter model slug. Default: a cheap/fast model. |
| `PAL_REQUEST_TIMEOUT_MS` | no | Per-request timeout to OpenRouter. Default `30000`. |
| `OPENROUTER_BASE_URL` | no | Defaults to `https://openrouter.ai/api/v1`. |
| `PORT` | no | Default `8080`. |
| `SQLITE_PATH` | no | Default `./loop.sqlite`. |
| `CORS_ORIGINS` | no | Comma-separated allowed browser origins. |

## Endpoints

`POST /v1/{chat,parse,review,suggest-workout,post-workout-note,routine}` (Bearer token),
`POST /v1/register` (provisioning key → token), `GET /healthz`.

`POST /v1/chat` returns `{ reply, actions[] }`. Pal can call tools to mutate
data (`log_expense`/`log_income`/`log_movement`/`log_ritual`,
`set_daily_budget`/`set_move_goal`/`set_ritual_goal`, `create_routine`); each
tool call is validated server-side and returned as an `action` the client
applies (and can undo). `create_routine` carries only the goal — the client
fulfills it by calling `/v1/routine` with its exercise catalog, so the catalog
never rides along on `/chat`. Unknown/invalid tool calls are dropped.

The structured endpoints (`parse`, `insights`, `suggest-workout`, `routine`,
email receipt extraction) request strict JSON output (`response_format`) for
reliability; `extractJson` remains as a tolerant fallback.

**Email (Bearer token):**

- `POST /v1/email/test` — `{ host, port, address, appPassword }` → `{ ok }`.
  Verifies the IMAP login. A rejected app-password returns `{ ok: false }` (not an error).
- `POST /v1/email/sync` — `{ host, port, address, appPassword, senderFilters[], since }`
  (`since` = epoch ms of the client's last sync, or `null` for a default 7-day
  window) → `{ items: [{ id, merchant, amount, receivedAt, category }] }`.
  `amount` is negative (expense); `id` is the email Message-ID. A bad
  app-password mid-sync returns **422** (distinct from the bearer-token **401**,
  which the client retries by re-registering).

Email creds are never persisted server-side; the same `OPENROUTER_API_KEY`
powers receipt extraction.

## CORS

The Flutter **web** build calls the API from the browser, so the server must
echo CORS headers for the web app's origin. Browser calls are blocked unless the
requesting origin is in `CORS_ORIGINS`. This is **off by default** (empty list).

In production, set `CORS_ORIGINS` to the exact origin(s) the web app is served
from — comma-separated, scheme + host + optional port, **no trailing slash**
(e.g. `CORS_ORIGINS=https://app.kael.life,http://localhost:5173`). Then rebuild
and restart so the running process picks up the new env: `npm run build &&
systemctl restart opal-api`. Native (mobile) builds are unaffected — CORS only
matters for browsers.
