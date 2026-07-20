// Async D1 ports of server/src/store.ts (TokenStore) and server/src/memory.ts
// (MemoryStore). Prepared statements only. randomBytes -> Web Crypto.

const MAX_FACTS = 20   // server/src/memory.ts
const MAX_PATTERNS = 5 // server/src/memory.ts

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

export interface MemoryFact { id: string; text: string }
export interface MemoryPattern { colorToken: string; title: string; detail: string }
export interface MemoryDigest { facts: MemoryFact[]; patterns: MemoryPattern[] }
export type MemoryOp = { op: 'remember'; text: string } | { op: 'forget'; id: string }

export class D1MemoryStore {
  constructor(private readonly db: D1Database) {}

  async addFact(token: string, text: string): Promise<MemoryFact> {
    const id = `f-${hex(8)}`
    await this.db.prepare('INSERT INTO pal_facts (id, token, text, created_at) VALUES (?, ?, ?, ?)')
      .bind(id, token, text, Date.now()).run()
    // cap: drop oldest beyond MAX_FACTS by monotonic rowid (matches source rationale)
    await this.db.prepare(`
      DELETE FROM pal_facts WHERE token = ? AND id NOT IN (
        SELECT id FROM pal_facts WHERE token = ? ORDER BY rowid DESC LIMIT ?
      )`).bind(token, token, MAX_FACTS).run()
    return { id, text }
  }

  async listFacts(token: string): Promise<MemoryFact[]> {
    const { results } = await this.db
      .prepare('SELECT id, text FROM pal_facts WHERE token = ? ORDER BY rowid ASC')
      .bind(token).all<MemoryFact>()
    return results
  }

  async forgetFact(token: string, id: string): Promise<void> {
    await this.db.prepare('DELETE FROM pal_facts WHERE token = ? AND id = ?').bind(token, id).run()
  }

  async getPatterns(token: string): Promise<MemoryPattern[]> {
    const row = await this.db.prepare('SELECT json FROM pal_patterns WHERE token = ?')
      .bind(token).first<{ json: string }>()
    return row ? (JSON.parse(row.json) as MemoryPattern[]) : []
  }

  async setPatterns(token: string, patterns: MemoryPattern[]): Promise<void> {
    const capped = patterns.slice(0, MAX_PATTERNS)
    await this.db.prepare(`
      INSERT INTO pal_patterns (token, json, updated_at) VALUES (?, ?, ?)
      ON CONFLICT(token) DO UPDATE SET json = excluded.json, updated_at = excluded.updated_at
    `).bind(token, JSON.stringify(capped), Date.now()).run()
  }

  async digest(token: string): Promise<MemoryDigest> {
    return { facts: await this.listFacts(token), patterns: await this.getPatterns(token) }
  }

  async applyOps(token: string, ops: MemoryOp[]): Promise<void> {
    for (const op of ops) {
      if (op.op === 'remember') await this.addFact(token, op.text)
      else await this.forgetFact(token, op.id)
    }
  }

  async wipe(token: string): Promise<void> {
    await this.db.prepare('DELETE FROM pal_facts WHERE token = ?').bind(token).run()
    await this.db.prepare('DELETE FROM pal_patterns WHERE token = ?').bind(token).run()
  }
}
