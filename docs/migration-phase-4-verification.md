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

## PENDING — owner-gated live verification (Task 5)

Requires the owner's OpenRouter key with a credit cap (same gate as Phase 3).
Run these on a Node 22.14 machine from `server/worker/`; paste results below.

### Step 1 — local `wrangler dev` smoke (real workerd + real OpenRouter)

```bash
cd server/worker && npx wrangler dev
# second shell — replace TOKEN from a real /v1/register call:
curl -s -X POST localhost:8787/v1/email/extract \
  -H "authorization: Bearer $TOKEN" -H 'content-type: application/json' \
  -d '{"candidates":[{"id":"m1","from":"billing@grab.com","subject":"Grab receipt","text":"Total 45,000d GrabFood on 06 Jan 2026 11:27","envelopeDate":"2026-01-08T09:00:00.000Z"}]}'
```

Expected: `200 { "items": [ { "id":"m1","merchant":…,"amount":<negative>,"receivedAt":"2026-01-06T11:27:00.000Z","category":… } ] }`.
Confirm the dev log shows exactly one `openrouter completion` line with
`{ ms, model, usage, cost, finish_reason }` and **no** candidate body/subject/merchant text.

| Case | Result |
|---|---|
| single receipt candidate | _pending_ |
| dev-log line PII-free | _pending_ |

### Step 2 — staging deploy + re-smoke

```bash
cd server/worker && npx wrangler deploy
# re-run the Step 1 curl against the staging URL:
# https://opal-worker.piskael03.workers.dev/v1/email/extract
# also smoke a full 8-candidate batch (worst-case CPU) and watch `npx wrangler tail`
```

Expected: same `200 { items }`; `wrangler tail` shows `ok` outcome, **no `1102`
CPU kill** on the batch of 8.

| Case | Result |
|---|---|
| staging single candidate | _pending_ |
| staging batch of 8 (CPU / `finish_reason` / `ms`) | _pending_ |
| tail outcomes `ok`, no `1102` | _pending_ |
| tail logs PII-free | _pending_ |

---

## Exit condition (partial)

Phase 4's Worker half is proven here (unit + bundle + redaction), and fully
provable once the owner runs Task 5. The native email adapter (Part B) and true
end-to-end sync remain a handoff to a Flutter/Dart-capable session — not
executable in this Windows/Node environment. Removal of the old
`/v1/email/{test,sync}` routes from the Node app is deferred to Phase 7 (after cutover).
