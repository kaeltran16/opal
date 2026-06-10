import Database from 'better-sqlite3'
import { randomBytes } from 'node:crypto'

export class TokenStore {
  private db: Database.Database

  constructor(path: string) {
    this.db = new Database(path)
    this.db.pragma('journal_mode = WAL')
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS device_tokens (
        token      TEXT PRIMARY KEY,
        device_id  TEXT NOT NULL UNIQUE,
        created_at INTEGER NOT NULL
      )
    `)
  }

  // returns existing token for a known device, else issues a new one
  issue(deviceId: string): string {
    const existing = this.db
      .prepare('SELECT token FROM device_tokens WHERE device_id = ?')
      .get(deviceId) as { token: string } | undefined
    if (existing) return existing.token

    const token = randomBytes(32).toString('hex') // 64 hex chars
    this.db
      .prepare('INSERT INTO device_tokens (token, device_id, created_at) VALUES (?, ?, ?)')
      .run(token, deviceId, Date.now())
    return token
  }

  isValid(token: string): boolean {
    const row = this.db
      .prepare('SELECT 1 FROM device_tokens WHERE token = ?')
      .get(token)
    return row !== undefined
  }

  revoke(token: string): void {
    this.db.prepare('DELETE FROM device_tokens WHERE token = ?').run(token)
  }
}
