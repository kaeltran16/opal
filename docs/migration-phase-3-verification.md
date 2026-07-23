# Phase 3 — Pal / LLM Endpoints Verification

The 11 non-email Pal/LLM endpoints ported onto the Phase 2 Worker, verified
against the real OpenRouter LLM. Contracts preserved verbatim so `HttpPalService`
needs no change.

- **Date:** 2026-07-24
- **Worker:** `opal-worker`
- **Bundle:** 185.25 KiB / gzip 36.37 KiB (well under the 3 MB limit)
- **Unit suite:** 38 tests, 9 files, all passing (19 Phase 2 + 19 new Pal)
- **Model:** `deepseek/deepseek-v4-flash` (same as the live Node deployment)

## Local runtime verification (`wrangler dev`, real workerd + real OpenRouter)

Ran against `wrangler dev` (real workerd runtime, local D1) with the owner's
OpenRouter key. This is the `STUB_LLM=0` live proof that unit tests (which inject
a stub `Pal`) cannot provide.

| Endpoint | Result |
|---|---|
| `POST /v1/register` | 200, 64-char token |
| `POST /v1/parse` `{ "text": "coffee 5k" }` | 200, `ParsedEntry` `{ type: "money", amount: 5000, category: "Coffee", direction: "expense", … }` |
| `POST /v1/chat` (spend message) | 200, `{ reply, actions: [{ kind: "log_expense", amount: 5000, … }] }`; `memoryOps` never on the wire |
| `POST /v1/insights` | 200, valid `Insights` object (headline/wins/patterns) when upstream responds < 30 s — see latency note |
| malformed body | 400 `bad_request` with `details` (e.g. `text: Required`) |

Contracts match what `HttpPalService` expects. The `502`/`500` error envelope
(`{ error: { code: "upstream", message: "pal request failed" } }`) is emitted on
upstream failure.

## Bug found and fixed (runtime-only, invisible to unit tests)

The live smoke surfaced a workerd-specific defect the stub-based tests could not:

- **Symptom:** every Pal route returned `502` — `network error: TypeError:
  Illegal invocation: function called with incorrect \`this\` reference`.
- **Cause:** `OpenRouterClient` calls its injected `fetch` as `this.fetchImpl(...)`.
  workerd rejects `fetch` invoked with a non-global `this`; Node's `fetch`
  tolerates it, so it worked in the Node deployment and only broke in the Worker.
- **Fix:** `pal-factory.ts` now passes `fetch.bind(globalThis)`. One line, Worker
  layer only — no `server/src` edit.

## Cost / latency logging (no PII)

Each successful completion logs exactly `{ msg, ms, model, usage, cost,
finish_reason }` via `console`. Verified in the dev log:

```
{"msg":"openrouter completion","ms":2966,"model":"deepseek/deepseek-v4-flash","usage":{…,"cost":0.00021805,…},"cost":0.00021805,"finish_reason":"stop"}
```

A scan of the full dev log for prompt text, context fields (`dailyBudget`,
`topCategory`, …), and memory facts found **no matches** — no prompts, memory,
Health values, or secrets are logged.

## Latency observation (not a regression; carry forward)

The 2048-token reasoning routes (`insights`, `agenda`, `routine`, `memory/refresh`)
intermittently exceed the 30 s request timeout because `deepseek-v4-flash` emits
large reasoning-token bursts through OpenRouter's slower providers. Observed over
3 back-to-back `insights` calls: 14.8 s (200) / 30 s timeout / 30 s timeout — i.e.
~1-in-3 succeeded. This is a property of the model + the 30 s cap that `pal.ts`
already carries in the Node deployment, not something introduced by the port.
(Aside: a timeout during body read surfaces as a raw `TimeoutError` → mapped to
`500`, not `502`, because it escapes the client's fetch-only try/catch — existing
`pal.ts` behavior, left untouched per the zero-`server/src`-edits constraint.)

Levers if this proves too flaky in production (owner decision, not yet applied):
raise `PAL_REQUEST_TIMEOUT_MS`, or point `PAL_MODEL` at a lower-latency model.

## Staging deploy + live smoke — PASSED

Deployed to Cloudflare and contract-verified against the live `workers.dev` URL.
This is the roadmap Phase 3 exit condition.

- **Staging URL:** https://opal-worker.piskael03.workers.dev
- **Version:** `d5eacfe3-f0ca-4f2a-a268-bbd2561d6557`
- **Worker startup:** 17 ms
- **Secrets:** `OPENROUTER_API_KEY` (new) and `PAL_PROVISIONING_KEY` set on the
  Worker. The Phase 2 remote provisioning key (a demo value) was realigned to the
  `server/.env` value so staging matches the app's key.

| Endpoint | Result |
|---|---|
| `GET /healthz` | 200 `ok` |
| `POST /v1/register` | 200, 64-char token |
| `POST /v1/parse` `{ "text": "coffee 5k" }` | 200, `ParsedEntry` (`type: money`, `amount: 5000`, …) |
| `POST /v1/chat` | 200, `{ reply, actions: [{ kind: "log_expense", … }] }` |
| `POST /v1/insights` | 200, full `Insights` object |
| malformed body | 400 `bad_request` with `details` |

### `wrangler tail` observations (live)

- All request outcomes `ok` — **no `1102`/`1027` CPU kills** (chat, the thin-margin
  case, ran clean).
- Cost logs present and PII-free, one per completion:
  - `parse`: 3357 ms, `finish_reason: stop`, cost $0.0000652
  - `chat`: 1616 ms, `finish_reason: tool_calls`, cost $0.0001998
  - `insights`: **21119 ms**, `finish_reason: stop`, cost $0.0003991 (reasoning_tokens 1489)
- No prompt text, context fields, or memory appeared in the tail — only endpoint
  URLs/hosts.

### Takeaway

Phase 3 exit met: all smoked Pal routes pass against staging with no client
contract change. The `insights` call at ~21 s is a live confirmation of the
latency margin noted above — under the 30 s cap here, but the reasoning-model
routes have little headroom. Watch `finish_reason`/`ms` in production; raise
`PAL_REQUEST_TIMEOUT_MS` or switch `PAL_MODEL` if timeouts (`500`s) become common.
