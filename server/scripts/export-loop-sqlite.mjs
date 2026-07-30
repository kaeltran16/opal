// Phase 6 cutover: dump loop.sqlite row data as one INSERT-per-row .sql file per
// table, for `wrangler d1 execute opal --remote --file=...`.
//
// Data only — the D1 migration owns the schema. One file per table so a large
// health_metrics never forces a split by hand, and so a failed import is
// retryable per table.
//
// Runs on the droplet without the sqlite3 CLI installed (better-sqlite3 is
// already a dependency of the API):
//
//   node scripts/export-loop-sqlite.mjs ./loop.sqlite ./d1-import
//
// The device_tokens output contains live bearer tokens. Treat the whole output
// directory as a credential file: never commit it, delete it once the import is
// verified.
import Database from 'better-sqlite3';
import { mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

// same five tables as server/worker/migrations/0001_init.sql; no FKs, so order
// only affects readability
const TABLES = [
  'device_tokens',
  'pal_facts',
  'pal_patterns',
  'health_metrics',
  'widget_snapshot',
];

const [dbPath, outDir] = process.argv.slice(2);
if (!dbPath || !outDir) {
  console.error('usage: node scripts/export-loop-sqlite.mjs <loop.sqlite> <outDir>');
  process.exit(2);
}

// sqlite literal quoting, matching what the sqlite3 CLI's `.mode insert` emits
const quote = (v) => {
  if (v === null || v === undefined) return 'NULL';
  if (typeof v === 'number') return String(v);
  if (Buffer.isBuffer(v)) return `X'${v.toString('hex')}'`;
  return `'${String(v).replace(/'/g, "''")}'`;
};

const db = new Database(dbPath, { readonly: true });
mkdirSync(outDir, { recursive: true });

const counts = {};
for (const table of TABLES) {
  const rows = db.prepare(`SELECT * FROM ${table}`).all();
  counts[table] = rows.length;
  const body = rows
    .map((r) => `INSERT INTO ${table} VALUES(${Object.values(r).map(quote).join(',')});`)
    .join('\n');
  writeFileSync(join(outDir, `data-${table}.sql`), body ? `${body}\n` : '', 'utf8');
}
db.close();

// compare against `wrangler d1 execute opal --remote --file=./scripts/counts.sql`
console.log(JSON.stringify(counts, null, 2));
