# Phase 6 — Cutover runbook (empty-start)

Revised 2026-07-31. **Executed 2026-08-01** — see [Execution record](#execution-record-2026-08-01).
This is the ordered procedure for pointing `opal.kael.life` at the Cloudflare Worker.

**The DigitalOcean droplet has been destroyed and no backup was kept.** The owner
accepted the data loss — single-user app, nothing worth recovering. That decision
removes the entire data-migration half of this phase and, more importantly, removes
the rollback target. Read [What changed](#what-changed-from-the-data-migration-version)
before following any step.

## What changed from the data-migration version

The previous revision of this runbook (2026-07-30) assumed a running droplet: freeze
writes, export `loop.sqlite`, import per table into D1, compare row counts, flip the
domain, keep the droplet stopped-but-intact as a fallback. Four of those steps no
longer have a subject.

| Previous step | Now |
|---|---|
| Freeze writes (`systemctl stop opal-api`) | Gone — nothing is running |
| Export via `server/scripts/export-loop-sqlite.mjs` | Gone — no host to run it on. The script is now dead code; remove in Phase 7 |
| Per-table import into D1 | Gone — D1 starts empty |
| Source-vs-D1 row-count parity check | Gone — no source to compare against |
| Rollback by restarting the old API | **Gone — this is the significant one** |

Two consequences worth stating plainly:

1. **The app is already down.** `opal.kael.life` resolves to a destroyed host, so every
   Pal call, Health ingest, and widget refresh is failing right now. This is a service
   restore, not a scheduled swap. There is no maintenance window to protect.
2. **There is no floor under a bad deploy.** If the Worker misbehaves after the domain
   is attached, the only recovery is fixing the Worker. That makes the green CI deploy
   in the preconditions a hard gate rather than a nicety.

## What is permanently lost

| Table | Loss | Recovery |
|---|---|---|
| `device_tokens` | All device tokens | Self-healing. The client clears its stored token on a 401 and re-registers (`lib/controllers/providers.dart`), so the cost is one extra round trip on first use |
| `pal_facts`, `pal_patterns` | All Pal memory | None. Pal starts with no learned facts or patterns |
| `health_metrics` | Server-side Health history | Partial. Apple Health on the phone is the origin — re-running the Health Shortcut backfills whatever range the Shortcut supports |
| `widget_snapshot` | One row | Rewritten on the next widget refresh |

## Preconditions

- [ ] **Web origin allowlist set.** `CORS_ORIGINS` in `server/worker/wrangler.toml`
      currently ships as `""`, which rejects every browser origin. The Node
      `server/.env.example` documented `http://localhost:8080` for the web preview, and
      no CI workflow publishes the Flutter web build anywhere, so localhost is the
      likely correct value — confirm before setting it. This is a `vars` entry, so it
      deploys with the Worker.
- [ ] **Device enrollment key set on the Worker.** `npx wrangler secret list` shows
      `PAL_PROVISIONING_KEY` and `OPENROUTER_API_KEY`. The enrollment key must equal the
      value compiled into the app and widget via
      `--dart-define=PAL_PROVISIONING_KEY=...` (read at
      `lib/controllers/providers.dart:138`). The droplet was never the authority here.
      If the value is unknown, choose a new one, set it on the Worker, and rebuild the
      app and widget with the matching `--dart-define`.
- [ ] **A green run of the Worker deploy workflow** (`.github/workflows/worker.yml`:
      test → bundle-size check → `wrangler deploy` → `/healthz` healthcheck), with
      `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`, and `WORKER_BASE_URL` configured
      in the repository. Never yet run.
- [ ] **`kael.life` active as a Cloudflare zone.**
- [ ] **Stale DNS cleared.** `opal.kael.life` most likely still has an A record pointing
      at the destroyed droplet's IP. Expect the custom-domain attach to refuse a
      conflicting record; delete it in the Cloudflare dashboard first.

Native email sync (Phase 4B) is no longer a precondition. It was one only because
attaching the domain would kill the old Node `/v1/email/{test,sync}` routes — those
routes died with the droplet, so there is nothing left to preserve by waiting.

## Step 1 — apply the schema migration

```
cd server/worker
npx wrangler d1 time-travel info opal
npm run migrate:remote
```

Record the Time Travel bookmark first. It is the only rollback for a database mistake,
and the free recovery window is 7 days.

`migrate:remote` runs `wrangler d1 migrations apply opal --remote` against the single
production D1 database (`opal`, id `495d49f3-…`). One migration file exists,
`server/worker/migrations/0001_init.sql`, creating the five tables.

## Step 2 — clear leftover test rows

Phases 2 through 4 ran live verification against this same production D1 database, so
it holds test device tokens and possibly test Pal and Health rows. Nothing in it is
worth keeping, but leftover rows would leave the app reading stale test state.

```
npx wrangler d1 execute opal --remote --file=./scripts/counts.sql
```

If any count is non-zero:

```
npx wrangler d1 execute opal --remote --command \
  "DELETE FROM device_tokens; DELETE FROM pal_facts; DELETE FROM pal_patterns; DELETE FROM health_metrics; DELETE FROM widget_snapshot;"
```

Re-run `counts.sql` and confirm all five report zero. That zeroed output is the
expected starting state — not a failure.

## Step 3 — attach the custom domain

In `server/worker/wrangler.toml`:

```toml
[[routes]]
pattern = "opal.kael.life"
custom_domain = true
```

**This is the cutover trigger.** Merging it makes the next CI `wrangler deploy` claim
the production hostname. `wrangler deploy --dry-run` accepted this block during the
2026-07-30 rehearsal with no bundle-size change, but it was reverted and never merged.

Land it only after Steps 1 and 2 pass and the deploy workflow has gone green at least
once. Watch the merge.

## Step 4 — live checks against `opal.kael.life`

- [ ] `GET /healthz`
- [ ] App launch — expect **one** re-registration, since the device token store was
      wiped with the droplet. A second launch should not re-register.
- [ ] Pal chat, parse, nutrition estimate, insights, routine
- [ ] Memory add, then read, then delete — starting from empty
- [ ] Health ingest from the Shortcut, then the day read. Backfill as far as the
      Shortcut allows if the history matters
- [ ] iOS widget snapshot POST and GET
- [ ] CORS from the web build, against whatever origin was set in the preconditions
- [ ] Native on-device email sync (Phase 4B) — committed in `e16834b` and `0d7e04c`
      with unit coverage, but never run against a real Gmail account. First real
      exercise happens here

## Step 5 — monitor

Watch a normal usage cycle before declaring the migration done: `wrangler tail`
outcomes and exceptions, CPU time per request (Phase 4 measured 8–15 ms against the
10 ms Free-tier budget on the heaviest route — the number to keep an eye on), D1
read/write counts against the free daily limits, and OpenRouter spend.

## Rollback

| Failure | Action |
|---|---|
| Bad schema migration or accidental data deletion | `wrangler d1 time-travel restore opal --bookmark <Step 1 bookmark>`, within 7 days |
| Worker broken after cutover | **Fix forward.** Reverting the `[[routes]]` block only un-claims the hostname; it restores nothing, because the old API no longer exists. The app stays down until the Worker works |

## Rehearsal record (2026-07-30)

Local only — miniflare D1 on wrangler 4.113.0, no network, no `--remote`. Most of this
rehearsal covered the export/import path that the teardown made moot. The rows that
still apply to an empty start:

| Check | Result |
|---|---|
| `0001_init.sql` applies to an empty D1 | 7 commands, clean |
| `scripts/counts.sql` runs on D1 unchanged, via `--file` | yes |
| `[[routes]] custom_domain` block accepted by `wrangler deploy --dry-run` | yes; 192.33 KiB / gzip 38.75 KiB, unchanged. Reverted, not committed |

Superseded by the teardown, retained only as evidence the schema and tooling behave:
data-only export produced five per-table files (2 / 3 / 1 / 800 / 1 rows); per-table
import into a fresh D1 succeeded for all five; awkward values (apostrophe, Vietnamese
diacritics, `₫`, embedded newline, backslash) round-tripped byte-identical; a file that
errors mid-way rolls back whole; re-importing an already-imported table fails on the
primary key.

Schema parity between the Node SQLite schema (`server/src/store.ts`, `memory.ts`,
`health.ts`, `widget.ts`) and `0001_init.sql` was verified exact on 2026-07-30. That
finding no longer matters for import, but it does confirm the Worker's D1 stores were
built against the same shape the Node app used.

## Execution record (2026-08-01)

Cutover completed. `opal.kael.life` serves the Worker.

Preconditions, as found rather than as assumed:

- **`CORS_ORIGINS`** — set to `http://localhost:8080`, the value the droplet used
  (`server/.env`). Confirmed no CI workflow publishes the Flutter web build, so no
  hosted browser origin needed preserving. Open item 1 closed.
- **`PAL_PROVISIONING_KEY`** — verified equal to `dart_defines/prod.json` by registering
  a throwaway device against the `workers.dev` staging URL before arming the cutover
  (HTTP 200). No rotation and no app rebuild needed. Open item 2 closed.
- **Repository settings** — `CLOUDFLARE_ACCOUNT_ID` and `WORKER_BASE_URL` were unset and
  were added. `WORKER_BASE_URL` points at the `workers.dev` URL, not `opal.kael.life`, so
  the post-deploy healthcheck does not race DNS propagation on the deploy that creates
  the record. Open item 3 closed by the green run below.
- **Stale DNS** — `opal.kael.life` still had an `A` record at the destroyed droplet's
  `178.128.81.14`. Deleted before deploying, as this runbook anticipated.

Steps as run:

| Step | Result |
|---|---|
| 1 — schema | Already applied; all five tables resolved. Pre-clear bookmark `00000005-00000002-000050ba-e53d7b9e7b72128efed2a987caf47680` |
| 2 — clear test rows | Found 8 `device_tokens`, 2 `health_metrics`, 1 `widget_snapshot`; `pal_facts` and `pal_patterns` empty. Cleared; all five re-read as 0 |
| 3 — attach domain | `[[routes]]` committed in `f03e5a5`; CI run `30701867068` green (test → size → deploy → healthcheck) in 27s |
| 4 — live checks | Partial — see below |
| 5 — monitor | Outstanding |

Live checks against `opal.kael.life`:

| Check | Result |
|---|---|
| DNS | Resolves to Cloudflare anycast, no longer the droplet IP |
| `GET /healthz` | 200 `ok` |
| `POST /v1/register` | 200, 64-char token issued from an empty `device_tokens` |
| `GET /v1/memory` | 200 `{"facts":[],"patterns":[]}` — correct empty start |
| `GET /v1/memory` unauthenticated | 401, as expected |
| CORS preflight from `http://localhost:8080` | 204 with matching `Allow-Origin`, `Allow-Headers`, `Allow-Methods` |
| `POST /v1/parse` (live OpenRouter) | 200, `pho 45k and a coffee 25k` → `{money, 70000, Dining, "Pho and Coffee", expense}` |

The device token minted for these checks was deleted afterwards; `device_tokens` is back
to 0 rows.

Still unverified, all device-side and none reachable from a Windows/Node session: app
launch and its single expected re-registration, Pal chat/nutrition/insights/routine,
Health ingest from the Shortcut, the iOS widget snapshot round trip, and the first real
Gmail run of native on-device email sync (Phase 4B). Step 5 monitoring has not started.

## Open items

1. ~~`.github/workflows/deploy.yml`, the SSH/rsync deploy to the droplet, now targets a
   host that does not exist and will fail on any `server/**` push outside
   `server/worker/**`.~~ **Closed 2026-08-02** — deleted in Phase 7 cleanup.
2. ~~`server/scripts/export-loop-sqlite.mjs` is dead code.~~ **Closed 2026-08-02** —
   deleted in Phase 7 cleanup.
3. **Still open.** Run the device-side live checks listed in the execution record, then
   Step 5 monitoring. These need a phone, the Health Shortcut, and a real Gmail account,
   so they cannot be run from a desktop session.

   Phase 7 cleanup went ahead without them, which is a deliberate call worth stating:
   the cleanup deletes code that was already unreachable — the droplet is destroyed, so
   the Node backend had no host and the `/v1/email/{test,sync}` routes it served no
   longer answered. Keeping it would not have provided a rollback. **But if the first
   real Gmail sync fails, the reference implementation of the server-side scan is now
   only in git history** (`server/src/{imap,email,receipts}.ts` at `797fe23`). The
   deterministic logic was ported to Dart in `e16834b`/`0d7e04c` with unit coverage, so
   the port is testable without it — that is the reason this was judged acceptable
   rather than merely convenient.

## Remaining device-side checks

Carried forward from Step 4. Nothing below has been exercised against production:

- [ ] App launch — expect **one** re-registration (the token store started empty).
      A second launch must not re-register.
- [ ] Pal chat, nutrition estimate, insights, routine on device
- [ ] Memory add → read → delete, from empty
- [ ] Health ingest from the Shortcut, then the day read; backfill as far as the
      Shortcut allows
- [ ] iOS widget snapshot POST and GET
- [ ] Native on-device email sync against a real Gmail account (first ever real run)
- [ ] Step 5 monitoring across a normal usage cycle: `wrangler tail` exceptions, CPU
      time per request against the 10 ms budget, D1 read/write counts, OpenRouter spend
