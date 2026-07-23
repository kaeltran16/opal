import { fileURLToPath } from 'node:url'
import { defineConfig } from 'vitest/config'
import { cloudflareTest, readD1Migrations } from '@cloudflare/vitest-pool-workers'

const migrations = await readD1Migrations('./migrations')

// the reused server/src modules import 'zod', but they live outside this project and
// server/ has no node_modules here. the vitest pool resolves via Vite (not wrangler's
// alias), so point 'zod' at the worker's own installed copy. (no better-sqlite3 alias:
// this worker's D1 stores replace it, and neither auth.ts nor schemas.ts imports it.)
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
