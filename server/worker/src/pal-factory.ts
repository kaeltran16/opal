import { OpenRouterClient, Pal, type CompletionLogger } from '../../src/pal.js'
import type { Env } from './worker.js'

// logs only usage/latency/cost — never prompts, memory, or Health values.
const usageLogger: CompletionLogger = {
  info: (obj, msg) => console.log(JSON.stringify({ msg, ...(obj as Record<string, unknown>) })),
}

// a fresh Pal per request; the OpenRouterClient holds only config, no per-request state.
export function makePal(env: Env): Pal {
  const client = new OpenRouterClient(
    env.OPENROUTER_API_KEY,
    env.PAL_MODEL ?? 'deepseek/deepseek-v4-flash',
    env.OPENROUTER_BASE_URL ?? 'https://openrouter.ai/api/v1',
    // bind to globalThis: OpenRouterClient calls fetchImpl as a method, and workerd
    // throws "Illegal invocation" if fetch runs with a non-global `this` (Node tolerates it).
    fetch.bind(globalThis),
    Number(env.PAL_REQUEST_TIMEOUT_MS ?? 30_000),
    usageLogger,
  )
  return new Pal(client)
}
