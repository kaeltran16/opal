// Async D1 port of server/src/store.ts TokenStore. Prepared statements; Web Crypto for the token.
function hex(bytes: number): string {
  const b = new Uint8Array(bytes)
  crypto.getRandomValues(b)
  return Array.from(b, (x) => x.toString(16).padStart(2, '0')).join('')
}

export class D1TokenStore {
  constructor(private readonly db: D1Database) {}

  // insert-or-keep then read back, so concurrent registers for one device (device_id is UNIQUE)
  // both get the winner's token instead of one failing the constraint.
  async issue(deviceId: string): Promise<string> {
    await this.db
      .prepare('INSERT INTO device_tokens (token, device_id, created_at) VALUES (?, ?, ?) ON CONFLICT(device_id) DO NOTHING')
      .bind(hex(32), deviceId, Date.now()).run() // 64 hex chars
    const row = await this.db
      .prepare('SELECT token FROM device_tokens WHERE device_id = ?').bind(deviceId)
      .first<{ token: string }>()
    if (!row) throw new Error(`device token missing after insert for ${deviceId}`)
    return row.token
  }

  async isValid(token: string): Promise<boolean> {
    const row = await this.db
      .prepare('SELECT 1 AS ok FROM device_tokens WHERE token = ?').bind(token).first()
    return row !== null
  }
}
