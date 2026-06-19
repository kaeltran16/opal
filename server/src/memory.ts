import Database from 'better-sqlite3'
import { randomBytes } from 'node:crypto'

export const MAX_FACTS = 20
export const MAX_PATTERNS = 5

export interface MemoryFact { id: string; text: string }
export interface MemoryPattern { colorToken: string; title: string; detail: string }
export interface MemoryDigest { facts: MemoryFact[]; patterns: MemoryPattern[] }

// a mutation Pal asked for in chat, applied server-side (never a client action).
export type MemoryOp = { op: 'remember'; text: string } | { op: 'forget'; id: string }

// per-device memory: user-authored facts + derived patterns, keyed by device token.
export class MemoryStore {
  private db: Database.Database

  constructor(path: string) {
    this.db = new Database(path)
    this.db.pragma('journal_mode = WAL')
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS pal_facts (
        id         TEXT PRIMARY KEY,
        token      TEXT NOT NULL,
        text       TEXT NOT NULL,
        created_at INTEGER NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_pal_facts_token ON pal_facts(token, created_at);
      CREATE TABLE IF NOT EXISTS pal_patterns (
        token      TEXT PRIMARY KEY,
        json       TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      );
    `)
  }

  addFact(token: string, text: string): MemoryFact {
    const id = `f-${randomBytes(8).toString('hex')}`
    this.db.prepare('INSERT INTO pal_facts (id, token, text, created_at) VALUES (?, ?, ?, ?)')
      .run(id, token, text, Date.now())
    // enforce the cap: drop the oldest beyond MAX_FACTS for this token. order by
    // the monotonic rowid, not created_at — many inserts share a millisecond and
    // the random id is no tiebreak, so created_at ordering is nondeterministic.
    this.db.prepare(`
      DELETE FROM pal_facts WHERE token = ? AND id NOT IN (
        SELECT id FROM pal_facts WHERE token = ? ORDER BY rowid DESC LIMIT ?
      )`).run(token, token, MAX_FACTS)
    return { id, text }
  }

  listFacts(token: string): MemoryFact[] {
    return this.db.prepare('SELECT id, text FROM pal_facts WHERE token = ? ORDER BY rowid ASC')
      .all(token) as MemoryFact[]
  }

  forgetFact(token: string, id: string): void {
    this.db.prepare('DELETE FROM pal_facts WHERE token = ? AND id = ?').run(token, id)
  }

  getPatterns(token: string): MemoryPattern[] {
    const row = this.db.prepare('SELECT json FROM pal_patterns WHERE token = ?').get(token) as { json: string } | undefined
    return row ? (JSON.parse(row.json) as MemoryPattern[]) : []
  }

  setPatterns(token: string, patterns: MemoryPattern[]): void {
    const capped = patterns.slice(0, MAX_PATTERNS)
    this.db.prepare(`
      INSERT INTO pal_patterns (token, json, updated_at) VALUES (?, ?, ?)
      ON CONFLICT(token) DO UPDATE SET json = excluded.json, updated_at = excluded.updated_at
    `).run(token, JSON.stringify(capped), Date.now())
  }

  digest(token: string): MemoryDigest {
    return { facts: this.listFacts(token), patterns: this.getPatterns(token) }
  }

  applyOps(token: string, ops: MemoryOp[]): void {
    for (const op of ops) {
      if (op.op === 'remember') this.addFact(token, op.text)
      else this.forgetFact(token, op.id)
    }
  }

  wipe(token: string): void {
    this.db.prepare('DELETE FROM pal_facts WHERE token = ?').run(token)
    this.db.prepare('DELETE FROM pal_patterns WHERE token = ?').run(token)
  }
}
