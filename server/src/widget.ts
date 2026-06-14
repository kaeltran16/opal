import Database from 'better-sqlite3'

/// Today's pre-computed rings progress, written by the app and read by the iOS
/// home-screen widget. The widget can't share an App Group with the app on a
/// free Apple team, so it fetches this snapshot over HTTP instead.
export type WidgetSnapshot = {
  moneyRing: number
  moveRing: number
  ritualsRing: number
  moneySpent: number
  dailyBudget: number
  moveKcal: number
  dailyMoveKcal: number
  ritualsDone: number
  dailyRitualTarget: number
}

/// Single-tenant: one snapshot for the whole server (mirrors HealthStore, which
/// is keyed only by date). Stored as a JSON blob so the field set lives in one
/// place (the zod schema) rather than being mirrored across columns.
export class WidgetSnapshotStore {
  private db: Database.Database
  private setStmt: Database.Statement

  constructor(path: string) {
    this.db = new Database(path)
    this.db.pragma('journal_mode = WAL')
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS widget_snapshot (
        id         INTEGER PRIMARY KEY CHECK (id = 1),
        data       TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    `)
    this.setStmt = this.db.prepare(`
      INSERT INTO widget_snapshot (id, data, updated_at) VALUES (1, @data, @updatedAt)
      ON CONFLICT(id) DO UPDATE SET data = excluded.data, updated_at = excluded.updated_at
    `)
  }

  set(snapshot: WidgetSnapshot, updatedAt: number): void {
    this.setStmt.run({ data: JSON.stringify(snapshot), updatedAt })
  }

  get(): WidgetSnapshot | null {
    const row = this.db
      .prepare('SELECT data FROM widget_snapshot WHERE id = 1')
      .get() as { data: string } | undefined
    return row ? (JSON.parse(row.data) as WidgetSnapshot) : null
  }
}
