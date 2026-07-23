export interface Metric { value: number; unit: string }

export class D1HealthStore {
  constructor(private readonly db: D1Database) {}

  // returns the number of metrics written. one D1 batch = one transaction.
  async upsert(date: string, metrics: Record<string, Metric>, capturedAt: string): Promise<number> {
    const entries = Object.entries(metrics)
    if (entries.length === 0) return 0
    const stmt = this.db.prepare(`
      INSERT INTO health_metrics (date, metric, value, unit, captured_at)
      VALUES (?, ?, ?, ?, ?)
      ON CONFLICT(date, metric) DO UPDATE SET
        value = excluded.value, unit = excluded.unit, captured_at = excluded.captured_at`)
    await this.db.batch(entries.map(([metric, m]) => stmt.bind(date, metric, m.value, m.unit, capturedAt)))
    return entries.length
  }

  async getDay(date: string): Promise<Record<string, Metric>> {
    const { results } = await this.db
      .prepare('SELECT metric, value, unit FROM health_metrics WHERE date = ?')
      .bind(date).all<{ metric: string; value: number; unit: string }>()
    const out: Record<string, Metric> = {}
    for (const r of results) out[r.metric] = { value: r.value, unit: r.unit }
    return out
  }
}
