import type { Env as WorkerEnv } from '../src/worker'

// types the `env` that cloudflare:test hands the tests
declare global {
  namespace Cloudflare {
    interface Env extends WorkerEnv {
      TEST_MIGRATIONS: D1Migration[]
    }
  }
}
