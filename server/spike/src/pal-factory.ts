import { Pal, OpenRouterClient } from '../../src/pal.js'
import { StubClient, type Canned } from './stub.js'
import type { Env } from './worker.js'

// Stub mode isolates Worker CPU (no network, no spend); live mode proves the
// 30s timeout + one retry survive the runtime. Fresh instance per request so the
// canned payload is never shared across concurrent invocations.
export function makePal(env: Env, canned?: Canned): Pal {
  if (env.STUB_LLM === '1' && canned) return new Pal(new StubClient(canned))
  const client = new OpenRouterClient(
    env.OPENROUTER_API_KEY,
    env.PAL_MODEL ?? 'deepseek/deepseek-v4-flash',
    env.OPENROUTER_BASE_URL ?? 'https://openrouter.ai/api/v1',
    fetch,
    Number(env.PAL_REQUEST_TIMEOUT_MS ?? 30_000),
  )
  return new Pal(client)
}
