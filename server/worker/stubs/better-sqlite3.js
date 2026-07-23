// Alias target for better-sqlite3. The MemoryStore/TokenStore classes that use it
// are dead code in the Worker (D1 stores replace them). Constructing this throws,
// which is correct: it must never run in the Worker.
export default class Database {
  constructor() {
    throw new Error('better-sqlite3 is not available in the Worker (dead code path)')
  }
}
