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

1. Install Node 20+, Caddy. Create user `loop`, dir `/opt/loop-pal`.
2. Copy the repo's `server/` to `/opt/loop-pal`, `npm ci`, `npm run build`.
3. `cp .env.example .env`, fill secrets. `SQLITE_PATH=/opt/loop-pal/loop.sqlite`.
4. `cp loop-pal.service.example /etc/systemd/system/loop-pal.service`; `systemctl enable --now loop-pal`.
5. `cp Caddyfile.example /etc/caddy/Caddyfile` (set your domain); `systemctl reload caddy`.
6. Verify: `curl https://pal.example.com/healthz` → `ok`.

## Client wiring

Build the Flutter app with:

```
--dart-define=PAL_BASE_URL=https://pal.example.com
--dart-define=PAL_PROVISIONING_KEY=<same as server PAL_PROVISIONING_KEY>
```

Without `PAL_BASE_URL` the app stays on `MockPalService`.

## Environment

| Var | Required | Notes |
| --- | --- | --- |
| `OPENROUTER_API_KEY` | yes | OpenRouter API key (`sk-or-...`). Server-side only. |
| `PAL_PROVISIONING_KEY` | yes | Gates `POST /v1/register`; ships in the app build. |
| `PAL_MODEL` | no | OpenRouter model slug. Default: a cheap/fast model. |
| `OPENROUTER_BASE_URL` | no | Defaults to `https://openrouter.ai/api/v1`. |
| `PORT` | no | Default `8080`. |
| `SQLITE_PATH` | no | Default `./loop.sqlite`. |
| `CORS_ORIGINS` | no | Comma-separated allowed browser origins. |

## Endpoints

`POST /v1/{chat,parse,review,suggest-workout,post-workout-note}` (Bearer token),
`POST /v1/register` (provisioning key → token), `GET /healthz`.

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
