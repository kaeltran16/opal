# Loop Pal proxy (U22)

Stateless LLM proxy for the Loop app's `PalService`. Forwards to **OpenRouter**
(OpenAI-compatible chat completions) with the handoff prompts. Per-device bearer
tokens (SQLite) gate the endpoints. See
`docs/superpowers/specs/2026-06-10-backend-llm-proxy-design.md`.

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
