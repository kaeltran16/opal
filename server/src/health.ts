import Database from 'better-sqlite3'

type Metric = { value: number; unit: string }

export class HealthStore {
  private db: Database.Database
  private upsertStmt: Database.Statement

  constructor(path: string) {
    this.db = new Database(path)
    this.db.pragma('journal_mode = WAL')
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS health_metrics (
        date        TEXT NOT NULL,
        metric      TEXT NOT NULL,
        value       REAL NOT NULL,
        unit        TEXT NOT NULL,
        captured_at TEXT NOT NULL,
        PRIMARY KEY (date, metric)
      )
    `)
    // upsert so a re-run with fresher Health data overwrites the day rather than duplicating
    this.upsertStmt = this.db.prepare(`
      INSERT INTO health_metrics (date, metric, value, unit, captured_at)
      VALUES (@date, @metric, @value, @unit, @capturedAt)
      ON CONFLICT(date, metric) DO UPDATE SET
        value = excluded.value, unit = excluded.unit, captured_at = excluded.captured_at
    `)
  }

  // returns the number of metrics written
  upsert(date: string, metrics: Record<string, Metric>, capturedAt: string): number {
    const entries = Object.entries(metrics)
    const tx = this.db.transaction(() => {
      for (const [metric, { value, unit }] of entries) {
        this.upsertStmt.run({ date, metric, value, unit, capturedAt })
      }
    })
    tx()
    return entries.length
  }

  get(date: string, metric: string): Metric | undefined {
    const row = this.db
      .prepare('SELECT value, unit FROM health_metrics WHERE date = ? AND metric = ?')
      .get(date, metric) as Metric | undefined
    return row
  }
}
