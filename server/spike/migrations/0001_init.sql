-- Mirrors server/src/store.ts and server/src/memory.ts schemas.
CREATE TABLE IF NOT EXISTS device_tokens (
  token      TEXT PRIMARY KEY,
  device_id  TEXT NOT NULL UNIQUE,
  created_at INTEGER NOT NULL
);
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
