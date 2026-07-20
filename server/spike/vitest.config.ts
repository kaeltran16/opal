import { fileURLToPath } from 'node:url'
import { defineConfig } from 'vitest/config'
import { cloudflareTest, readD1Migrations } from '@cloudflare/vitest-pool-workers'

const migrations = await readD1Migrations('./migrations')

// The reused server/src modules import 'zod' and 'better-sqlite3', but they live
// outside this project and server/ has no node_modules here. The vitest pool
// resolves via Vite (not wrangler's alias), so map both here: 'zod' to the spike's
// own installed copy, 'better-sqlite3' to the throwing stub (dead code in the Worker).
// wrangler.toml carries the equivalent aliases for `wrangler deploy`.
const abs = (p: string) => fileURLToPath(new URL(p, import.meta.url))

export default defineConfig({
  resolve: {
    alias: [
      { find: /^zod$/, replacement: abs('./node_modules/zod/index.js') },
      { find: /^better-sqlite3$/, replacement: abs('./stubs/better-sqlite3.js') },
    ],
  },
  plugins: [
    cloudflareTest({
      wrangler: { configPath: './wrangler.toml' },
      miniflare: {
        d1Databases: ['DB'],
        bindings: { TEST_MIGRATIONS: migrations, PAL_PROVISIONING_KEY: 'test-prov-key' },
      },
    }),
  ],
})
