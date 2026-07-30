# Phase 6 — Data migration and cutover runbook

Prepared 2026-07-30. **Not executed.** This is the ordered procedure for moving
`loop.sqlite` into D1 and moving `opal.kael.life` from the droplet to the Worker.
Every command below was checked against the installed wrangler surface; none were
run against production.

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

The migration creates the schema, so export rows without DDL. `.mode insert` is
used rather than `.dump` because it emits exactly the five tables and no
`sqlite_sequence`, index, or transaction noise:

```
sqlite3 /opt/opal-api/loop.sqlite <<'SQL' > data.sql
.mode insert device_tokens
SELECT * FROM device_tokens;
.mode insert pal_facts
SELECT * FROM pal_facts;
.mode insert pal_patterns
SELECT * FROM pal_patterns;
.mode insert health_metrics
SELECT * FROM health_metrics;
.mode insert widget_snapshot
SELECT * FROM widget_snapshot;
SQL
```

**`data.sql` contains live bearer device tokens.** Treat it as a credential file:
never commit it, keep it out of the repo tree, and delete it once the import is
verified.

Record the source-side counts for comparison:

```
sqlite3 /opt/opal-api/loop.sqlite < server/worker/scripts/counts.sql
```

## Step 3 — apply the migration, then import

```
cd server/worker
npm run migrate:remote                                   # schema first
npx wrangler d1 execute opal --remote --file=./data.sql
```

If `execute` rejects `data.sql` for size, split it per table and run them in the
order above. `health_metrics` is the only table likely to be large.

Note the pre-import Time Travel bookmark first — it is the rollback for a bad
import:

```
npx wrangler d1 time-travel info opal
```

## Step 4 — validate

```
npx wrangler d1 execute opal --remote --file=./scripts/counts.sql
```

`scripts/counts.sql` runs unchanged on both databases, so this output is directly
comparable to Step 2's. All five counts must match. Then spot-check one real row
per table — a device token resolving, a `pal_facts` row for that token, the current
`widget_snapshot`, and a recent `health_metrics` day.

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

## Open items

1. The `loop.sqlite` pull is still outstanding and gates Steps 2–4.
2. Whether to cut over before Phase 4 Part B — see Preconditions.
3. Exact size limit for `wrangler d1 execute --file` is unverified here; treat
   Step 3's split instruction as the contingency rather than a prediction.
