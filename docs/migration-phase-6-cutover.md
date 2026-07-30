# Phase 6 — Data migration and cutover runbook

Prepared 2026-07-30. **Not executed.** This is the ordered procedure for moving
`loop.sqlite` into D1 and moving `opal.kael.life` from the droplet to the Worker.
Every command below was checked against the installed wrangler surface; none were
run against production.

Steps 2–4 were rehearsed end-to-end on 2026-07-30 against a stand-in SQLite
database and a throwaway local D1 — see [Dry run](#dry-run-2026-07-30). The
commands and the export script below are the rehearsed ones.

## Preconditions

- [ ] Phase 4 Part B (native email adapter) verified on device, or an accepted
      decision to cut over with email sync still served by the old routes. Cutover
      moves the domain, so the Node `/v1/email/{test,sync}` routes stop being
      reachable at `opal.kael.life` the moment the route flips.
- [ ] A green run of `.github/workflows/worker.yml`, including the `/healthz`
      healthcheck, with `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`, and
      `WORKER_BASE_URL` configured.
- [ ] `loop.sqlite` pulled from DigitalOcean and openable locally. Phase 0 confirmed
      it recoverable but the pull is still outstanding
      (`docs/migration-phase-0-findings.md`, section 4 item 1).
- [ ] `kael.life` active as a Cloudflare zone.
- [ ] Worker runtime secrets present: `npx wrangler secret list` shows
      `OPENROUTER_API_KEY` and `PAL_PROVISIONING_KEY`. The provisioning key must be
      the **same value** the droplet uses, or every client re-registration fails.
- [ ] `CORS_ORIGINS` in `server/worker/wrangler.toml` set to the droplet's live
      value. It currently ships as `""`, which disables CORS entirely — the web
      build breaks at cutover if this is not copied across from
      `/opt/opal-api/.env`. This is a `vars` change, so it deploys with the Worker.

## Schema parity (verified 2026-07-30)

The Node schema (`server/src/store.ts`, `memory.ts`, `health.ts`, `widget.ts`) and
`server/worker/migrations/0001_init.sql` match exactly: same five tables, same
columns, types, NOT NULLs, primary keys, the `widget_snapshot` `id = 1` check, and
`idx_pal_facts_token`. No transform is needed — the import is data-only.

## Step 1 — freeze writes

On the droplet:

```
sudo systemctl stop opal-api
```

The window is personal-use only; the app surfaces its normal offline/error paths.
Do not skip this — a write landing after the export is silently lost.

## Step 2 — export data only

The migration creates the schema, so export rows without DDL. Use the export
script — it needs no `sqlite3` CLI on the droplet (`better-sqlite3` is already an
API dependency), emits data only, and writes **one file per table** so a large
`health_metrics` never has to be split by hand:

```
cd /opt/opal-api
node scripts/export-loop-sqlite.mjs ./loop.sqlite ./d1-import
```

The script reaches the droplet with the next `server/**` deploy (`deploy.yml`
rsyncs the whole `server/` tree). If the merge that adds it has not been deployed,
`scp` it across instead — it depends only on `better-sqlite3`, already installed
there.

It prints the source-side row counts — record them, they are the Step 4
comparison. The equivalent with the CLI, if it is installed and preferred, is
`.mode insert` per table (not `.dump`, which drags in DDL, `sqlite_sequence`, and
transaction noise).

**`d1-import/data-device_tokens.sql` contains live bearer device tokens.** Treat
the whole directory as a credential file: never commit it, keep it out of the repo
tree, and delete it once the import is verified.

## Step 3 — apply the migration, clear staging rows, then import

Note the pre-import Time Travel bookmark first — it is the rollback for a bad
import:

```
cd server/worker
npx wrangler d1 time-travel info opal
```

Then the schema:

```
npm run migrate:remote
```

**Check what is already in the remote database before importing.** Phases 2–4 ran
live verification against this same `opal` D1, so it holds test device tokens and
possibly test Pal/Health rows. An import on top of them fails on the
`device_tokens` primary key or the `device_id` unique index:

```
npx wrangler d1 execute opal --remote --file=./scripts/counts.sql
```

If any count is non-zero, those rows are staging artifacts with nothing to
preserve — clear them, in the maintenance window, right before the import:

```
npx wrangler d1 execute opal --remote --command \
  "DELETE FROM device_tokens; DELETE FROM pal_facts; DELETE FROM pal_patterns; DELETE FROM health_metrics; DELETE FROM widget_snapshot;"
```

Then import, one file per table (order is free — the schema has no foreign keys):

```
for t in device_tokens pal_facts pal_patterns health_metrics widget_snapshot; do
  npx wrangler d1 execute opal --remote --file=/opt/opal-api/d1-import/data-$t.sql
done
```

A file that hits an error leaves **no** rows behind — verified locally: a file
whose second statement violated a primary key rolled back its first, successful
insert. So a failed table is retryable as-is; a *succeeded* one is not, since the
inserts are plain `INSERT` and re-running conflicts. Retry the failing file only.

## Step 4 — validate

```
npx wrangler d1 execute opal --remote --file=./scripts/counts.sql
```

`scripts/counts.sql` runs unchanged on both databases, so this output is directly
comparable to Step 2's. All five counts must match. Then spot-check one real row
per table — a device token resolving, a `pal_facts` row for that token, the current
`widget_snapshot`, and a recent `health_metrics` day.

Include at least one `pal_facts` row containing an apostrophe or non-ASCII text in
the spot-check. Quoting is where a hand-rolled dump usually breaks, and it is the
one class of corruption the counts cannot see.

## Step 5 — attach the custom domain

Declarative and reviewable, in `server/worker/wrangler.toml`:

```toml
[[routes]]
pattern = "opal.kael.life"
custom_domain = true
```

**This is the cutover trigger.** Merging that change makes the next CI
`wrangler deploy` claim the production hostname — the same
migration-before-merge ordering hazard recorded in
`docs/migration-phase-5-deployment.md`. Land it only after Step 4 passes, during
the maintenance window, with the merge watched.

## Step 6 — live checks against `opal.kael.life`

- [ ] `GET /healthz`
- [ ] App launch with an existing device token (no re-register prompt)
- [ ] Pal chat, parse, nutrition estimate, insights, routine
- [ ] Memory read / add / delete
- [ ] Health ingest from the Shortcut, then the day read
- [ ] iOS widget snapshot POST and GET
- [ ] Native email sync end-to-end, if Part B shipped
- [ ] CORS from the web build

## Step 7 — monitor before dismantling

Watch for at least a normal usage cycle: `wrangler tail` outcomes and exceptions,
CPU per request (Phase 4 measured 8–15 ms against the 10 ms Free budget for the
heaviest route — this is the number to keep an eye on), D1 read/write counts
against the free daily limits, and OpenRouter spend. Leave the droplet stopped but
intact. Phase 7 removes it.

## Rollback

| Failure | Action |
|---|---|
| Bad import | `wrangler d1 time-travel restore opal --bookmark <Step 3 bookmark>` |
| Worker broken after cutover | Revert the `[[routes]]` commit and deploy; re-`systemctl start opal-api` on the droplet |
| Data unrecoverable | Initialize D1 empty. Clients recover auth through the existing 401-clear-and-register path; server-only Pal memory and Health history are lost — this is the roadmap's accepted worst case |

## Dry run (2026-07-30)

Steps 2–4 rehearsed with no production access and no network. A stand-in SQLite
database was built with the Node schema and deliberately awkward values — an
apostrophe, Vietnamese diacritics, `₫`, an embedded newline, a backslash — plus 800
`health_metrics` rows (two metrics a day for 400 days) as a plausible worst case for
the largest table. `wrangler d1 migrations apply --local --persist-to <tmp>` created
a throwaway D1, and the export ran through `scripts/export-loop-sqlite.mjs`.

| Check | Result |
|---|---|
| Migration applies to an empty D1 | 7 commands, `0001_init.sql` ✅ |
| Export emits five data-only files | 2 / 3 / 1 / 800 / 1 rows |
| Per-table import into fresh D1 | all five succeeded |
| `counts.sql` parity, source vs D1 | 2 / 3 / 1 / 800 / 1 — exact match |
| Awkward values round-trip | apostrophe, diacritics, `₫`, newline, backslash all byte-identical after import |
| `counts.sql` runs on D1 unchanged | yes, via `--file` |
| Re-import of an already-imported table | fails `UNIQUE constraint failed: pal_facts.id`, row count unchanged |
| Partial failure inside one file | first insert rolled back — the file is all-or-nothing |
| `[[routes]] custom_domain` block | `wrangler deploy --dry-run` accepts it; 192.33 KiB / gzip 38.75 KiB unchanged. Reverted, not committed — merging it is the cutover trigger |

Not covered by the dry run: anything `--remote`. Every result above is local
(miniflare D1), on wrangler 4.113.0. Also unverified is the real shape of the
production data — the stand-in matches the schema, not the row counts.

## Open items

1. The `loop.sqlite` pull is still outstanding and gates Steps 2–4.
2. Whether to cut over before Phase 4 Part B — see Preconditions.
3. `wrangler d1 import` does not exist in wrangler 4.113.0 (`d1 execute --file` is
   the only file ingest path), and the size ceiling for `--file` is undocumented in
   its help output. Per-table files keep each one small; if `health_metrics` still
   trips a limit, split it by date range.
4. Whether the remote `opal` D1 currently holds staging rows is unknown from here —
   Step 3 checks it. If it holds anything worth keeping (it should not), the DELETE
   there is destructive.
