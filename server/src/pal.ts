import { z } from 'zod'
import {
  chatSystemPrompt, reviewPrompt, parsePrompt, suggestPrompt, postWorkoutPrompt,
  type ChatContext, type ReviewContext, type SuggestContext, type PostWorkoutContext,
} from './prompts.js'

const MAX_TOKENS = 1024

export interface ChatMessage {
  role: 'system' | 'user' | 'assistant'
  content: string
}

// The narrow seam Pal calls — keeps the wrapper testable without a network.
export interface CompletionClient {
  complete(messages: ChatMessage[]): Promise<string>
}

// Raised on a non-2xx (or network failure) from the LLM provider; mapped to 502 upstream.
export class OpenRouterError extends Error {
  constructor(readonly status: number, message: string) {
    super(message)
    this.name = 'OpenRouterError'
  }
}

/// OpenAI-compatible chat-completions client pointed at OpenRouter.
export class OpenRouterClient implements CompletionClient {
  constructor(
    private readonly apiKey: string,
    private readonly model: string,
    private readonly baseUrl: string,
    private readonly fetchImpl: typeof fetch = fetch,
  ) {}

  async complete(messages: ChatMessage[]): Promise<string> {
    let res: Response
    try {
      res = await this.fetchImpl(`${this.baseUrl}/chat/completions`, {
        method: 'POST',
        headers: {
          authorization: `Bearer ${this.apiKey}`,
          'content-type': 'application/json',
        },
        body: JSON.stringify({ model: this.model, max_tokens: MAX_TOKENS, messages }),
      })
    } catch (err) {
      throw new OpenRouterError(0, `network error: ${String(err)}`)
    }
    if (!res.ok) {
      const body = await res.text().catch(() => '')
      throw new OpenRouterError(res.status, `openrouter ${res.status}: ${body.slice(0, 500)}`)
    }
    const data = (await res.json()) as {
      choices?: Array<{ message?: { content?: string } }>
    }
    return data.choices?.[0]?.message?.content?.trim() ?? ''
  }
}

export const parseSchema = z.object({
  type: z.enum(['money', 'move', 'rituals']),
  amount: z.number().nullable(),
  duration: z.number().nullable(),
  category: z.string().nullable(),
  title: z.string(),
  note: z.string().nullable(),
})
export type ParsedEntry = z.infer<typeof parseSchema>

export const suggestSchema = z.object({ routineId: z.string(), reason: z.string() })
export type Suggestion = z.infer<typeof suggestSchema>

// Pull a JSON object out of a model reply: tolerate code fences and surrounding prose.
export function extractJson(raw: string): unknown {
  let s = raw.trim()
  const fence = s.match(/```(?:json)?\s*([\s\S]*?)```/i)
  if (fence) s = fence[1].trim()
  const start = s.indexOf('{')
  const end = s.lastIndexOf('}')
  if (start === -1 || end === -1 || end < start) {
    throw new Error('no JSON object found in model output')
  }
  return JSON.parse(s.slice(start, end + 1))
}

export class Pal {
  constructor(private readonly client: CompletionClient) {}

  async chat(history: Array<{ role: 'user' | 'assistant'; text: string }>, message: string, ctx: ChatContext): Promise<string> {
    const messages: ChatMessage[] = [
      { role: 'system', content: chatSystemPrompt(ctx) },
      ...history.map((m) => ({ role: m.role, content: m.text })),
      { role: 'user', content: message },
    ]
    return this.client.complete(messages)
  }

  async review(ctx: ReviewContext): Promise<string> {
    return this.client.complete([{ role: 'user', content: reviewPrompt(ctx) }])
  }

  async postWorkoutNote(ctx: PostWorkoutContext): Promise<string> {
    return this.client.complete([{ role: 'user', content: postWorkoutPrompt(ctx) }])
  }

  async parse(text: string): Promise<ParsedEntry> {
    const raw = await this.client.complete([{ role: 'user', content: parsePrompt(text) }])
    return parseSchema.parse(extractJson(raw))
  }

  async suggestWorkout(another: boolean, ctx: SuggestContext): Promise<Suggestion> {
    const nudge = another ? '\n\nPick a DIFFERENT routine than you would normally default to.' : ''
    const raw = await this.client.complete([{ role: 'user', content: suggestPrompt(ctx) + nudge }])
    return suggestSchema.parse(extractJson(raw))
  }
}
