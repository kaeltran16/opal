// Async D1 port of server/src/store.ts TokenStore. Prepared statements; Web Crypto for the token.
function hex(bytes: number): string {
  const b = new Uint8Array(bytes)
  crypto.getRandomValues(b)
  return Array.from(b, (x) => x.toString(16).padStart(2, '0')).join('')
}

export class D1TokenStore {
  constructor(private readonly db: D1Database) {}

  async issue(deviceId: string): Promise<string> {
    const existing = await this.db
      .prepare('SELECT token FROM device_tokens WHERE device_id = ?').bind(deviceId)
      .first<{ token: string }>()
    if (existing) return existing.token
    const token = hex(32) // 64 hex chars
    await this.db
      .prepare('INSERT INTO device_tokens (token, device_id, created_at) VALUES (?, ?, ?)')
      .bind(token, deviceId, Date.now()).run()
    return token
  }

  async isValid(token: string): Promise<boolean> {
    const row = await this.db
      .prepare('SELECT 1 AS ok FROM device_tokens WHERE token = ?').bind(token).first()
    return row !== null
  }
}
