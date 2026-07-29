# Phase 4 — Email Extraction Endpoint Verification

A single stateless `POST /v1/email/extract` route added to the Phase 2/3 Worker.
It turns one bounded batch of sanitized receipt candidates (≤8) into importable
expense entries via one reused `extractReceipts` LLM call, preserving the client
import contract (`EmailImportDto`) verbatim. Batching, concurrency, and per-batch
failure isolation stay in the native client's sync loop (Part B handoff).

- **Date:** 2026-07-29
- **Worker:** `opal-worker`
- **Bundle:** 192.33 KiB / gzip 38.75 KiB (Phase 3 was 185.25 KiB; +7 KiB for
  `receipts.ts` + `redact.ts`, well under the 3 MB limit)
- **Unit suite:** 51 tests, 11 files, all passing (46 Phase 2/3 + 8 `email` +
  5 `email-extract` — the 46 already counted the 8 `email` tests once added, so
  the Phase-3 baseline was 38/9)
- **Model:** `deepseek/deepseek-v4-flash` (same as Phase 3 / the live Node deployment)

## Static verification (done in this environment)

| Check | Command | Result |
|---|---|---|
| Unit suite | `npx vitest run` | 51 passed / 11 files |
| `email` module tests | `npx vitest run test/email.test.ts` | 8 passed (wire mapping, non-receipt drop, PII re-redaction, `OpenRouterError` propagation, schema bounds) |
| `email/extract` route tests | `npx vitest run test/email-extract.test.ts` | 5 passed (200 items, empty batch, 400 malformed, 401 no token, 502/500 mapping) |
| Bundle size | `npx wrangler deploy --dry-run --outdir dist` | 192.33 KiB / gzip 38.75 KiB |
| No IMAP/MIME/native deps bundled | `grep -c -E "imapflow\|mailparser\|better-sqlite3" dist/worker.js` | `0` for each — `imap.ts` is a type-only import and erased |

### Typecheck note

A bare `npx tsc --noEmit` reports pre-existing errors in the test files only:
the `cloudflare:test` virtual module is not wired into `tsconfig.json`'s `types`,
and several older tests call the 2-param `worker.fetch` default export with a 3rd
`{} as any` arg. These predate Phase 4 and are unrelated to it. The Phase 4
source (`src/email.ts`, `src/worker.ts`, `src/pal-factory.ts`) and
`test/email.test.ts` are type-clean; the real gate — `vitest run` under
`@cloudflare/vitest-pool-workers` — is 51/51 green.

## Redaction / security boundary (unit-proven)

- `extractFromCandidates` feeds candidate `text`/`subject` through `extractReceipts`,
  which re-applies `redactPii` (idempotent) before the body leaves for the model.
  `test/email.test.ts` asserts a dirty body (`user@example.com`, a 16-digit card)
  reaches the completer as `[email]`/`[card]` with the raw values absent —
  defense-in-depth even though the client redacts first.
- `from` (merchant sender address, not user PII) is intentionally left intact for
  merchant inference.
- The Worker never receives IMAP credentials (client owns transport).
- Only usage/latency/cost is logged (reused Phase 3 `usageLogger`); no candidate
  body, subject, or merchant is ever logged.

---

## Live verification (Task 5) — PASSED

Run against the owner's OpenRouter key (credit-capped), `deepseek/deepseek-v4-flash`.

### Step 1 — local `wrangler dev` (real workerd + real OpenRouter)

Registered a device token, then:

```
POST /v1/email/extract  { candidates: [ grab.com GrabFood 45,000d ] }
-> 200 {"items":[{"id":"m1","merchant":"GrabFood","amount":-45000,
        "receivedAt":"2026-01-06T11:27:00.000Z","category":"Food & Drink"}]}
```

Amount negative, `receivedAt` re-derived from the body (`06 Jan 2026 11:27`, not
the `2026-01-08` envelope), category assigned. The dev log carried exactly one
completion line — `{ ms:4480, model, usage, cost:0.0000938, finish_reason:"stop" }`
— and a scan for the candidate body/subject/merchant/sender returned **0 matches**.

### Step 2 — staging deploy + re-smoke

Deployed `opal-worker` (version `1dc6fa6c-a8ad-49a2-a8f2-f1498295f7c7`, startup
20 ms, upload 192.33 KiB). Smoked the `workers.dev` URL under `wrangler tail`.

| Request | Outcome | CPU | Wall | `finish_reason` | Cost |
|---|---|---|---|---|---|
| single candidate | ok, 200, 7 items→1 | 15 ms | 6734 ms | stop | $0.00012 |
| **batch of 8** | ok, 200, 7 items | **8 ms** | 9446 ms | stop | $0.000268 |

- Single: `{ id:m1, merchant:GrabFood, amount:-45000, receivedAt:2026-01-06T11:27, category:Food & Drink }`.
- Batch of 8: 7 receipts returned in input order (`b1,b2,b3,b4,b5,b7,b8`); the
  promo candidate `b6` ("50% off sale ends … unsubscribe") correctly dropped.
  Categories inferred across Food & Drink / Shopping / Bills & Utilities /
  Entertainment / Groceries / Transport; VN numeric day-first date (`05/01/2026
  14:30`) parsed to `2026-01-05T14:30`.
- **CPU is the headline:** the batch of 8 used **8 ms** of CPU (wall time is
  almost entirely OpenRouter round-trip). The Free-tier `1102` CPU-kill risk the
  plan flagged for the worst-case batch is a non-issue — three orders of
  magnitude of headroom.
- `wrangler tail`: all outcomes `ok`, `exceptions: 0`. A scan of the full tail
  for candidate body/subject/merchant strings returned **0 matches** — only
  request URLs/headers/CF metadata appear, never bodies.

## Exit condition (partial)

Phase 4's Worker half is fully proven: unit (51/51), bundle (192 KiB, no
IMAP/MIME/native deps), redaction defense-in-depth, and now the live
local + staging smoke with a clean batch-of-8 CPU profile and PII-free logs. The
native email adapter (Part B) and true end-to-end sync remain a handoff to a
Flutter/Dart-capable session — not executable in this Windows/Node environment.
Removal of the old `/v1/email/{test,sync}` routes from the Node app is deferred
to Phase 7 (after cutover).
