import type { z } from 'zod'
import type { widgetSnapshotBody } from '../../../src/schemas.js'

export type WidgetSnapshot = z.infer<typeof widgetSnapshotBody>

export class D1WidgetStore {
  constructor(private readonly db: D1Database) {}

  async set(snapshot: WidgetSnapshot, updatedAt: number): Promise<void> {
    await this.db.prepare(`
      INSERT INTO widget_snapshot (id, data, updated_at) VALUES (1, ?, ?)
      ON CONFLICT(id) DO UPDATE SET data = excluded.data, updated_at = excluded.updated_at
    `).bind(JSON.stringify(snapshot), updatedAt).run()
  }

  async get(): Promise<WidgetSnapshot | null> {
    const row = await this.db.prepare('SELECT data FROM widget_snapshot WHERE id = 1')
      .first<{ data: string }>()
    return row ? (JSON.parse(row.data) as WidgetSnapshot) : null
  }
}
