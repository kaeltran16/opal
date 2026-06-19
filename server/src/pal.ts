import { z } from 'zod'
import {
  chatSystemPrompt, reviewPrompt, insightsPrompt, parsePrompt, suggestPrompt, postWorkoutPrompt, routinePrompt, agendaPrompt, memoryPatternsPrompt,
  type ChatContext, type ReviewContext, type InsightsContext, type SuggestContext, type PostWorkoutContext, type RoutineExercise,
} from './prompts.js'
import { MAX_PATTERNS, type MemoryOp, type MemoryDigest, type MemoryPattern } from './memory.js'

const MAX_TOKENS = 1024
// insights and routine JSON run long; a 1024 cut-off truncates the object.
const INSIGHTS_MAX_TOKENS = 2048
const ROUTINE_MAX_TOKENS = 4096
// retry a transient upstream failure once after this backoff.
const RETRY_DELAY_MS = 500
// cap chat history sent to the model so long conversations don't grow cost unbounded.
const MAX_HISTORY_MESSAGES = 20

export interface ChatMessage {
  role: 'system' | 'user' | 'assistant'
  content: string
}

// One function call the model asked for; `arguments` is a raw JSON string.
export interface ToolCall {
  name: string
  arguments: string
}

// A tool-enabled completion: free-text `content` and/or `toolCalls`.
export interface CompletionResult {
  content: string
  toolCalls: ToolCall[]
}

// The narrow seam Pal calls — keeps the wrapper testable without a network.
export interface CompletionClient {
  // `json: true` asks the provider for a strict JSON object (response_format).
  // `maxTokens` overrides the default output cap for long replies (defaults to MAX_TOKENS).
  // `temperature` overrides the provider default — pass 0 for deterministic extraction.
  complete(messages: ChatMessage[], opts?: { json?: boolean; maxTokens?: number; temperature?: number }): Promise<string>
  // Tool-enabled variant for chat. `tools` is the OpenAI tool spec array.
  completeWithTools(messages: ChatMessage[], tools: unknown[]): Promise<CompletionResult>
}

// Text-only slice of the client for consumers that never need tools (receipts,
// email extraction) — keeps their test doubles minimal.
export type TextCompleter = Pick<CompletionClient, 'complete'>

// Minimal logger seam for usage/latency observability; pino's logger is structurally compatible.
export interface CompletionLogger {
  info(obj: unknown, msg?: string): void
}

// Raised on a non-2xx (or network failure) from the LLM provider; mapped to 502 upstream.
export class OpenRouterError extends Error {
  constructor(readonly status: number, message: string) {
    super(message)
    this.name = 'OpenRouterError'
  }
}

// 429 (rate limit), 5xx, and network errors (status 0) may clear on retry.
const isTransient = (status: number) => status === 0 || status === 429 || status >= 500
const delay = (ms: number) => new Promise<void>((resolve) => setTimeout(resolve, ms))

/// OpenAI-compatible chat-completions client pointed at OpenRouter.
export class OpenRouterClient implements CompletionClient {
  constructor(
    private readonly apiKey: string,
    private readonly model: string,
    private readonly baseUrl: string,
    private readonly fetchImpl: typeof fetch = fetch,
    private readonly timeoutMs = 30_000,
    private readonly logger?: CompletionLogger,
    private readonly retryDelayMs = RETRY_DELAY_MS,
  ) {}

  // Single POST path: applies model/token defaults, a hard request timeout, and
  // uniform error mapping. Retries a transient failure (429/5xx/network) once.
  // Returns the parsed JSON body.
  private async post(extra: Record<string, unknown>): Promise<unknown> {
    try {
      return await this.attempt(extra)
    } catch (err) {
      if (!(err instanceof OpenRouterError) || !isTransient(err.status)) throw err
      // a 429/5xx/network blip may clear on a second try; non-429 4xx won't.
      await delay(this.retryDelayMs)
      return this.attempt(extra)
    }
  }

  // One fetch attempt with its own timeout; maps failures to OpenRouterError.
  private async attempt(extra: Record<string, unknown>): Promise<unknown> {
    let res: Response
    try {
      res = await this.fetchImpl(`${this.baseUrl}/chat/completions`, {
        method: 'POST',
        headers: {
          authorization: `Bearer ${this.apiKey}`,
          'content-type': 'application/json',
        },
        // usage.include asks OpenRouter to report per-request cost in the usage block.
        body: JSON.stringify({ model: this.model, max_tokens: MAX_TOKENS, usage: { include: true }, ...extra }),
        // extra may override max_tokens; the object spread above lets it.
        signal: AbortSignal.timeout(this.timeoutMs),
      })
    } catch (err) {
      throw new OpenRouterError(0, `network error: ${String(err)}`)
    }
    if (!res.ok) {
      const body = await res.text().catch(() => '')
      throw new OpenRouterError(res.status, `openrouter ${res.status}: ${body.slice(0, 500)}`)
    }
    return res.json()
  }

  async complete(messages: ChatMessage[], opts?: { json?: boolean; maxTokens?: number; temperature?: number }): Promise<string> {
    const cap = opts?.maxTokens ?? MAX_TOKENS
    const started = Date.now()
    const data = (await this.post({
      messages,
      max_tokens: cap,
      ...(opts?.temperature !== undefined ? { temperature: opts.temperature } : {}),
      ...(opts?.json ? { response_format: { type: 'json_object' } } : {}),
    })) as { choices?: Array<{ message?: { content?: string }; finish_reason?: string }>; usage?: unknown }
    const choice = data.choices?.[0]
    if (choice?.finish_reason === 'length') {
      throw new OpenRouterError(502, `model output truncated (finish_reason=length) at max_tokens=${cap}`)
    }
    this.logUsage(started, data.usage, choice?.finish_reason)
    return choice?.message?.content?.trim() ?? ''
  }

  async completeWithTools(messages: ChatMessage[], tools: unknown[]): Promise<CompletionResult> {
    const started = Date.now()
    const data = (await this.post({ messages, tools, tool_choice: 'auto' })) as {
      choices?: Array<{ message?: { content?: string; tool_calls?: Array<{ function?: { name?: string; arguments?: string } }> }; finish_reason?: string }>
      usage?: unknown
    }
    const choice = data.choices?.[0]
    if (choice?.finish_reason === 'length') {
      throw new OpenRouterError(502, `model output truncated (finish_reason=length) at max_tokens=${MAX_TOKENS}`)
    }
    this.logUsage(started, data.usage, choice?.finish_reason)
    const message = choice?.message
    const toolCalls: ToolCall[] = (message?.tool_calls ?? [])
      .map((c) => ({ name: c.function?.name ?? '', arguments: c.function?.arguments ?? '' }))
      .filter((c) => c.name)
    return { content: message?.content?.trim() ?? '', toolCalls }
  }

  private logUsage(started: number, usage: unknown, finish_reason?: string): void {
    // surface cost at the top level so log aggregation can sum spend without parsing usage.
    const cost = (usage as { cost?: number } | undefined)?.cost
    this.logger?.info({ ms: Date.now() - started, model: this.model, usage, cost, finish_reason }, 'openrouter completion')
  }
}

export const parseSchema = z.object({
  type: z.enum(['money', 'move', 'rituals']),
  amount: z.number().nullable(),
  duration: z.number().nullable(),
  category: z.string().nullable(),
  title: z.string(),
  note: z.string().nullable(),
  // off-list values coerce to 'expense', mirroring routineSchema.tag's catch().
  direction: z.enum(['expense', 'income']).nullable().catch('expense'),
})
export type ParsedEntry = z.infer<typeof parseSchema>

export const suggestSchema = z.object({ routineId: z.string(), reason: z.string() })
export type Suggestion = z.infer<typeof suggestSchema>

const colorToken = z.enum(['money', 'move', 'rituals'])
export const insightsSchema = z.object({
  headline: z.string().nullable(),
  lede: z.string().nullable(),
  suggestion: z.string().nullable(),
  wins: z.array(z.object({ colorToken, title: z.string(), sub: z.string() })).default([]),
  patterns: z.array(z.object({ colorToken, title: z.string(), detail: z.string() })).default([]),
})
export type Insights = z.infer<typeof insightsSchema>

export const memoryPatternsSchema = z.object({
  patterns: z.array(z.object({
    colorToken: z.enum(['money', 'move', 'rituals']).catch('money'),
    title: z.string(),
    detail: z.string(),
  })).default([]),
})

// --- Pal Home agenda (/v1/agenda) -------------------------------------------
// The model picks each item's `kind` (and the copy); the server derives the
// SF-symbol icons, approve icon, and navigation action from that kind, so the
// model can never name a bad icon or a navigation it shouldn't (mirrors how
// insights derives its icon from colorToken). off-list kinds coerce to generic.
const agendaProposalKinds = ['reschedule_workout', 'hold_funds', 'close_out', 'add_ritual', 'generic'] as const
const agendaAutopilotKinds = ['bills_watch', 'review_draft', 'spend_nudge', 'generic'] as const

const PROPOSAL_PRESENTATION: Record<(typeof agendaProposalKinds)[number], { icon: string; approveIcon: string; action: string | null }> = {
  reschedule_workout: { icon: 'figure.run', approveIcon: 'arrow.triangle.2.circlepath', action: null },
  hold_funds: { icon: 'dollarsign.circle.fill', approveIcon: 'checkmark', action: null },
  close_out: { icon: 'moon.stars.fill', approveIcon: 'play.fill', action: 'close_out' },
  add_ritual: { icon: 'sparkles', approveIcon: 'plus', action: null },
  generic: { icon: 'sparkles', approveIcon: 'checkmark', action: null },
}
const AUTOPILOT_ICON: Record<(typeof agendaAutopilotKinds)[number], string> = {
  bills_watch: 'house.fill',
  review_draft: 'chart.bar.fill',
  spend_nudge: 'cup.and.saucer.fill',
  generic: 'sparkles',
}

export const agendaModelSchema = z.object({
  proposals: z.array(z.object({
    kind: z.enum(agendaProposalKinds).catch('generic'),
    colorToken,
    tag: z.string(),
    title: z.string(),
    body: z.string(),
    approveLabel: z.string(),
    doneLabel: z.string(),
  })).default([]),
  autopilot: z.array(z.object({
    kind: z.enum(agendaAutopilotKinds).catch('generic'),
    colorToken: z.enum(['money', 'move', 'rituals', 'accent']).catch('accent'),
    title: z.string(),
    subtitle: z.string(),
    enabled: z.boolean(),
  })).default([]),
})

// The wire shape the client decodes (icons/action resolved, streak echoed).
export interface AgendaResult {
  proposals: Array<{ id: string; tag: string; colorToken: string; icon: string; title: string; body: string; approveLabel: string; approveIcon: string; doneLabel: string; action: string | null }>
  autopilot: Array<{ id: string; colorToken: string; icon: string; title: string; subtitle: string; enabled: boolean }>
  streakDays: number
}

const routineSetSchema = z.object({
  reps: z.number().nullable().optional(),
  weight: z.number().nullable().optional(),
  duration: z.number().nullable().optional(),
})
// tag is constrained to the client's RoutineTag wire values; an off-list tag
// would otherwise throw in the client's RoutineTag.fromWire. catch() coerces.
export const routineSchema = z.object({
  name: z.string(),
  tag: z.enum(['upper', 'lower', 'full', 'cardio', 'custom']).catch('custom'),
  estMin: z.number().nullable().optional(),
  rationale: z.string().nullable().optional(),
  exercises: z.array(z.object({ exerciseId: z.string(), sets: z.array(routineSetSchema) })),
})
export type GeneratedRoutine = z.infer<typeof routineSchema>

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

// A mutating action Pal performs from chat, applied client-side (the entry/goals
// stores live on the device). The client executes by `kind`; unknown kinds are
// ignored, so the server can add actions without breaking older clients.
export type PalAction =
  | { kind: 'log_expense'; amount: number; category: string | null; title: string; note: string | null }
  | { kind: 'log_income'; amount: number; title: string; note: string | null }
  | { kind: 'log_movement'; durationMinutes: number; calories?: number; title: string; note: string | null }
  | { kind: 'log_ritual'; title: string; note: string | null }
  | { kind: 'set_daily_budget'; dailyBudget: number }
  | { kind: 'set_move_goal'; dailyMoveKcal: number }
  | { kind: 'set_ritual_goal'; dailyRitualTarget: number }
  // The client fulfills this by calling /v1/routine with its exercise catalog,
  // then saving the result — the catalog never has to ride along on /chat.
  | { kind: 'create_routine'; goal: string; name: string | null }

export interface ChatResult {
  reply: string
  actions: PalAction[]
  memoryOps: MemoryOp[]
}

// money amounts arrive as a magnitude; coerce sign/zero defensively.
const posAmount = z.number().refine((n) => Number.isFinite(n) && n !== 0).transform((n) => Math.abs(n))
const posInt = z.number().int().positive()
const optStr = z.string().trim().min(1).nullish()

// Each tool's arg schema mapped to a validated PalAction. A parse failure (or an
// unknown tool name) drops the call — the model never forces a malformed write.
const TOOL_PARSERS: Record<string, (args: unknown) => PalAction> = {
  log_expense: (a) => {
    const p = z.object({ amount: posAmount, category: optStr, title: optStr, note: optStr }).parse(a)
    return { kind: 'log_expense', amount: p.amount, category: p.category ?? null, title: p.title ?? p.category ?? 'Expense', note: p.note ?? null }
  },
  log_income: (a) => {
    const p = z.object({ amount: posAmount, title: optStr, note: optStr }).parse(a)
    return { kind: 'log_income', amount: p.amount, title: p.title ?? 'Income', note: p.note ?? null }
  },
  log_movement: (a) => {
    const p = z.object({ durationMinutes: posInt, calories: posInt.nullish(), title: optStr, note: optStr }).parse(a)
    return { kind: 'log_movement', durationMinutes: p.durationMinutes, calories: p.calories ?? undefined, title: p.title ?? 'Workout', note: p.note ?? null }
  },
  log_ritual: (a) => {
    const p = z.object({ title: z.string().trim().min(1), note: optStr }).parse(a)
    return { kind: 'log_ritual', title: p.title, note: p.note ?? null }
  },
  set_daily_budget: (a) => ({ kind: 'set_daily_budget', dailyBudget: z.object({ dailyBudget: posAmount }).parse(a).dailyBudget }),
  set_move_goal: (a) => ({ kind: 'set_move_goal', dailyMoveKcal: z.object({ dailyMoveKcal: posInt }).parse(a).dailyMoveKcal }),
  set_ritual_goal: (a) => ({ kind: 'set_ritual_goal', dailyRitualTarget: z.object({ dailyRitualTarget: posInt }).parse(a).dailyRitualTarget }),
  create_routine: (a) => {
    const p = z.object({ goal: z.string().trim().min(1), name: optStr }).parse(a)
    return { kind: 'create_routine', goal: p.goal, name: p.name ?? null }
  },
}

// OpenAI-format tool specs advertised to the model on /chat.
const obj = (properties: Record<string, unknown>, required: string[]) => ({ type: 'object', properties, required, additionalProperties: false })
const numProp = (description: string) => ({ type: 'number', description })
const strProp = (description: string) => ({ type: 'string', description })
const tool = (name: string, description: string, parameters: unknown) => ({ type: 'function', function: { name, description, parameters } })

export const CHAT_TOOLS = [
  tool('log_expense', 'Record money the user spent. Use a positive amount in dollars.',
    obj({ amount: numProp('dollars spent, positive'), category: strProp('e.g. Coffee, Dining, Transport'), title: strProp('short label, e.g. "coffee"'), note: strProp('optional note') }, ['amount'])),
  tool('log_income', 'Record money the user received. Positive amount in dollars.',
    obj({ amount: numProp('dollars received, positive'), title: strProp('short label, e.g. "paycheck"'), note: strProp('optional note') }, ['amount'])),
  tool('log_movement', 'Record a workout or movement session by its duration in minutes.',
    obj({ durationMinutes: numProp('minutes of movement'), calories: numProp('kcal burned during the session, if known'), title: strProp('short label, e.g. "run"'), note: strProp('optional note') }, ['durationMinutes'])),
  tool('log_ritual', 'Record a completed ritual/routine the user did.',
    obj({ title: strProp('the ritual name, e.g. "morning pages"'), note: strProp('optional note') }, ['title'])),
  tool('set_daily_budget', "Change the user's daily spending budget in dollars.",
    obj({ dailyBudget: numProp('new daily budget in dollars') }, ['dailyBudget'])),
  tool('set_move_goal', "Change the user's daily movement goal in kcal.",
    obj({ dailyMoveKcal: numProp('new daily move goal in kcal') }, ['dailyMoveKcal'])),
  tool('set_ritual_goal', "Change the user's daily ritual target (count).",
    obj({ dailyRitualTarget: numProp('new daily ritual target') }, ['dailyRitualTarget'])),
  tool('create_routine', 'Build and save a new workout routine from a free-text goal. Use when the user asks to create, make, build, or design a routine or workout plan.',
    obj({ goal: strProp('what the routine targets, e.g. "push day" or "20-minute cardio"'), name: strProp('optional name for the routine') }, ['goal'])),
  tool('remember', 'Persist a durable fact the user states about themselves (e.g. a goal, a constraint, a preference, a recurring date). Use only for lasting facts, not one-off logs.',
    obj({ fact: strProp('the durable fact, one short sentence') }, ['fact'])),
  tool('forget', 'Drop a previously remembered fact that is now wrong or obsolete. Use the id shown in brackets next to the fact.',
    obj({ id: strProp('the id of the fact to forget, e.g. f-1a2b') }, ['id'])),
]

/// Validate the model's tool calls into PalActions, dropping any that are unknown
/// or fail schema validation.
export function toolCallsToActions(calls: ToolCall[]): PalAction[] {
  const actions: PalAction[] = []
  for (const call of calls) {
    const parser = TOOL_PARSERS[call.name]
    if (!parser) continue
    try {
      actions.push(parser(JSON.parse(call.arguments)))
    } catch {
      // malformed args or non-JSON — skip this action
    }
  }
  return actions
}

// Memory tool calls are applied server-side; they never become client PalActions.
export function toolCallsToMemoryOps(calls: ToolCall[]): MemoryOp[] {
  const ops: MemoryOp[] = []
  for (const call of calls) {
    try {
      const args = JSON.parse(call.arguments)
      if (call.name === 'remember') {
        const fact = z.string().trim().min(1).parse(args.fact)
        ops.push({ op: 'remember', text: fact })
      } else if (call.name === 'forget') {
        const id = z.string().trim().min(1).parse(args.id)
        ops.push({ op: 'forget', id })
      }
    } catch {
      // malformed args or non-JSON — skip this op
    }
  }
  return ops
}

const money = (n: number) => (n % 1 === 0 ? `$${n}` : `$${n.toFixed(2)}`)

/// A concise acknowledgement built deterministically from the applied actions —
/// used only when the model returned tool calls but no prose of its own.
export function synthReply(actions: PalAction[]): string {
  // Logged entries get a confirmation card on the client, so they need no prose
  // here — only goal/routine changes fall back to a deterministic line.
  const ackable = actions.filter(
    (a) =>
      a.kind !== 'log_expense' &&
      a.kind !== 'log_income' &&
      a.kind !== 'log_movement' &&
      a.kind !== 'log_ritual',
  )
  if (ackable.length === 0) return ''
  const parts = ackable.map((a) => {
    switch (a.kind) {
      case 'set_daily_budget': return `set your daily budget to ${money(a.dailyBudget)}`
      case 'set_move_goal': return `set your move goal to ${a.dailyMoveKcal} kcal`
      case 'set_ritual_goal': return `set your ritual target to ${a.dailyRitualTarget}`
      case 'create_routine': return `created a routine for "${a.goal}"`
    }
  })
  const joined = parts.length === 1 ? parts[0] : `${parts.slice(0, -1).join(', ')} and ${parts[parts.length - 1]}`
  return `Done — ${joined}.`
}

export class Pal {
  constructor(private readonly client: CompletionClient) {}

  async chat(history: Array<{ role: 'user' | 'assistant'; text: string }>, message: string, ctx: ChatContext, memory?: MemoryDigest): Promise<ChatResult> {
    // keep only the most recent turns; system + new user message are always included and don't count.
    const recent = history.slice(-MAX_HISTORY_MESSAGES)
    const messages: ChatMessage[] = [
      { role: 'system', content: chatSystemPrompt(ctx, memory) },
      ...recent.map((m) => ({ role: m.role, content: m.text })),
      { role: 'user', content: message },
    ]
    const res = await this.client.completeWithTools(messages, CHAT_TOOLS)
    const actions = toolCallsToActions(res.toolCalls)
    const memoryOps = toolCallsToMemoryOps(res.toolCalls)
    const reply = res.content || synthReply(actions)
    return { reply, actions, memoryOps }
  }

  async review(ctx: ReviewContext, memory?: MemoryDigest): Promise<string> {
    return this.client.complete([{ role: 'user', content: reviewPrompt(ctx, memory) }])
  }

  async insights(ctx: InsightsContext, memory?: MemoryDigest): Promise<Insights> {
    const raw = await this.client.complete([{ role: 'user', content: insightsPrompt(ctx, memory) }], { json: true, maxTokens: INSIGHTS_MAX_TOKENS, temperature: 0 })
    return insightsSchema.parse(extractJson(raw))
  }

  async refreshPatterns(ctx: InsightsContext, digest: MemoryDigest): Promise<MemoryPattern[]> {
    const raw = await this.client.complete(
      [{ role: 'user', content: memoryPatternsPrompt(ctx, digest) }],
      { json: true, maxTokens: INSIGHTS_MAX_TOKENS, temperature: 0 },
    )
    return memoryPatternsSchema.parse(extractJson(raw)).patterns.slice(0, MAX_PATTERNS)
  }

  async postWorkoutNote(ctx: PostWorkoutContext): Promise<string> {
    return this.client.complete([{ role: 'user', content: postWorkoutPrompt(ctx) }])
  }

  async parse(text: string): Promise<ParsedEntry> {
    const raw = await this.client.complete([{ role: 'user', content: parsePrompt(text) }], { json: true, temperature: 0 })
    return parseSchema.parse(extractJson(raw))
  }

  async suggestWorkout(another: boolean, ctx: SuggestContext): Promise<Suggestion> {
    const nudge = another ? '\n\nPick a DIFFERENT routine than you would normally default to.' : ''
    const raw = await this.client.complete([{ role: 'user', content: suggestPrompt(ctx) + nudge }], { json: true })
    return suggestSchema.parse(extractJson(raw))
  }

  async agenda(ctx: ChatContext, memory?: MemoryDigest): Promise<AgendaResult> {
    const raw = await this.client.complete(
      [{ role: 'user', content: agendaPrompt(ctx, memory) }],
      { json: true, maxTokens: INSIGHTS_MAX_TOKENS, temperature: 0 },
    )
    const parsed = agendaModelSchema.parse(extractJson(raw))
    return {
      proposals: parsed.proposals.map((p, i) => {
        const pres = PROPOSAL_PRESENTATION[p.kind]
        return {
          id: `${p.kind}-${i}`,
          tag: p.tag,
          colorToken: p.colorToken,
          icon: pres.icon,
          title: p.title,
          body: p.body,
          approveLabel: p.approveLabel,
          approveIcon: pres.approveIcon,
          doneLabel: p.doneLabel,
          action: pres.action,
        }
      }),
      autopilot: parsed.autopilot.map((a, i) => ({
        id: `${a.kind}-${i}`,
        colorToken: a.colorToken,
        icon: AUTOPILOT_ICON[a.kind],
        title: a.title,
        subtitle: a.subtitle,
        enabled: a.enabled,
      })),
      streakDays: ctx.moveStreakDays,
    }
  }

  async generateRoutine(goal: string, exercises: RoutineExercise[], memory?: MemoryDigest): Promise<GeneratedRoutine> {
    // drop any exercise the model invented — the client can only resolve catalog ids.
    const known = new Set(exercises.map((e) => e.id))
    const draw = async (): Promise<GeneratedRoutine> => {
      const raw = await this.client.complete([{ role: 'user', content: routinePrompt(goal, exercises, memory) }], { json: true, maxTokens: ROUTINE_MAX_TOKENS })
      const parsed = routineSchema.parse(extractJson(raw))
      return { ...parsed, exercises: parsed.exercises.filter((e) => known.has(e.exerciseId)) }
    }
    let routine = await draw()
    // if the model picked only invented ids, one retry usually lands on the catalog.
    // when the catalog itself is empty an empty result is expected — don't retry.
    if (routine.exercises.length === 0 && exercises.length > 0) {
      routine = await draw()
      if (routine.exercises.length === 0) {
        throw new Error('generated routine has no exercises from the provided catalog')
      }
    }
    return routine
  }
}
