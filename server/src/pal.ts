import { z } from 'zod'
import {
  chatSystemPrompt, reviewPrompt, insightsPrompt, parsePrompt, suggestPrompt, postWorkoutPrompt, routinePrompt, agendaPrompt, suggestionsPrompt, memoryPatternsPrompt, nutritionEstimatePrompt, leadLinesPrompt,
  type ChatContext, type ReviewContext, type InsightsContext, type SuggestContext, type PostWorkoutContext, type RoutineExercise, type AgendaTargets, type PlanFact,
} from './prompts.js'
import { MAX_PATTERNS, type MemoryOp, type MemoryDigest, type MemoryPattern } from './memory.js'
import { ENTRY_TYPES, DIMENSIONS, SPEND_CATEGORIES, USD, spendCategory, type CurrencyDescriptor } from './product.js'

const MAX_TOKENS = 1024
// insights and routine JSON run long; a 1024 cut-off truncates the object.
const INSIGHTS_MAX_TOKENS = 2048
const ROUTINE_MAX_TOKENS = 4096
// one sentence of at most 20 words per open item, and a day holds a handful of them.
const LINES_MAX_TOKENS = 1024
// reasoning models (deepseek-v4.1-flash) spend hidden reasoning tokens out of max_tokens and
// truncate the answer; Pal's prompts carry every fact the reply needs, so reasoning stays off.
const REASONING_OFF = { enabled: false }
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
        body: JSON.stringify({ model: this.model, max_tokens: MAX_TOKENS, reasoning: REASONING_OFF, usage: { include: true }, ...extra }),
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

// DESIGN.md gives emphasis by size, never bold, and every Pal surface renders
// the model's text as plain text. the prompts ask for plain text; this holds it
// when the model slips: **bold**, *italic*, `code` and # headings lose their marks.
export function plainText(s: string): string {
  return s
    .replace(/\*\*(.+?)\*\*/gs, '$1')
    .replace(/__(.+?)__/gs, '$1')
    .replace(/(^|[^\w*])\*(?=\S)([^*\n]*?\S)\*(?![\w*])/g, '$1$2')
    .replace(/(^|[^\w])_(?=\S)([^_\n]*?\S)_(?!\w)/g, '$1$2')
    .replace(/`([^`\n]+)`/g, '$1')
    .replace(/^#{1,6}\s+/gm, '')
}

// a reply that shows its working: reasoning is off, so the model sometimes
// counts, doubts and corrects itself in the words the user reads.
const THINKING_ALOUD = /\blet me (re-?count|count again|re-?check|check again|think)\b|\bre-?counting\b|\bscratch that\b|(^|[.!?]\s+)(wait|hmm|oops)[,.!]/i

export function thinksAloud(reply: string): boolean {
  return THINKING_ALOUD.test(reply)
}

// a muscle or group named after a negation in the same clause ("haven't hit
// your legs"), checked against what the listed workouts trained.
const DENIAL = /\b(?:haven'?t|hasn'?t|have not|has not|not|no|missed|skipped|neglected|without)\b([^.;:!?]*)/gi

export function deniesRecent(reason: string, recent: SuggestContext['recentWorkouts']): boolean {
  const stems = new Set(
    recent
      .flatMap((w) => `${w.muscles},${w.groups ?? ''}`.split(','))
      .map((t) => t.trim().toLowerCase().replace(/s$/, ''))
      .filter((t) => t.length > 0),
  )
  for (const [, clause] of reason.matchAll(DENIAL)) {
    const words = clause.toLowerCase().match(/[a-z]+/g) ?? []
    if (words.some((w) => stems.has(w.replace(/s$/, '')))) return true
  }
  return false
}

// the catalog's own group and muscle words are the vocabulary: a rationale that
// names one the chosen exercises do not carry claims work the routine skips.
export function overclaims(routine: Pick<GeneratedRoutine, 'rationale' | 'exercises'>, catalog: RoutineExercise[]): boolean {
  const text = routine.rationale?.toLowerCase()
  if (!text) return false
  const termsOf = (e: RoutineExercise) => [e.group, e.muscle ?? ''].map((t) => t.trim().toLowerCase()).filter((t) => t.length > 0)
  const chosenIds = new Set(routine.exercises.map((e) => e.exerciseId))
  const trained = new Set(catalog.filter((e) => chosenIds.has(e.id)).flatMap(termsOf))
  const vocabulary = new Set(catalog.flatMap(termsOf))
  const stem = (t: string) => t.replace(/s$/, '').replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
  return [...vocabulary].some((t) => !trained.has(t) && new RegExp(`\\b${stem(t)}s?\\b`).test(text))
}

// the money amounts today's entry lines state, in the user's currency.
function statedAmounts(ctx: ChatContext): number[] {
  return ctx.todayEntries.flatMap((line) => moneyAmounts(line, ctx.currency))
}

function fallbackReason(routineId: string, ctx: SuggestContext): string {
  const name = ctx.availableRoutines.find((r) => r.id === routineId)?.name
  return name !== undefined && name === ctx.plannedToday
    ? 'It is the one your plan has for today.'
    : 'It balances what you have trained lately.'
}

// a model-written string the app shows as Pal's words.
const prose = z.string().transform(plainText)

export const parseSchema = z.object({
  type: z.enum(ENTRY_TYPES),
  amount: z.number().nullable(),
  duration: z.number().nullable(),
  // a category off the user's list would open a new bucket beside an envelope.
  category: z.string().nullable().transform(spendCategory),
  title: z.string(),
  note: z.string().nullable(),
  // off-list values coerce to 'expense', mirroring routineSchema.tag's catch().
  direction: z.enum(['expense', 'income']).nullable().catch('expense'),
})
export type ParsedEntry = z.infer<typeof parseSchema>

export const nutritionEstimateSchema = z.object({
  name: z.string(),
  calLo: z.number(),
  calHi: z.number(),
  confidence: z.enum(['high', 'med', 'low']).catch('low'),
})
export type NutritionEstimate = z.infer<typeof nutritionEstimateSchema>

export const suggestSchema = z.object({ routineId: z.string(), reason: prose })
export type Suggestion = z.infer<typeof suggestSchema>

const colorToken = z.enum(DIMENSIONS)
// the model sometimes writes a pattern in the wins shape ({title, sub}); read `sub` as `detail`.
const patternDetail = <T extends z.ZodTypeAny>(schema: T) =>
  z.preprocess((p) => {
    const o = p as Record<string, unknown> | null
    return o && typeof o === 'object' && o.detail === undefined && typeof o.sub === 'string' ? { ...o, detail: o.sub } : p
  }, schema)
export const insightsSchema = z.object({
  headline: prose.nullable(),
  lede: prose.nullable(),
  suggestion: prose.nullable(),
  correlationNarration: prose.nullable().optional(),
  wins: z.array(z.object({ colorToken, title: prose, sub: prose })).default([]),
  patterns: z.array(patternDetail(z.object({ colorToken, title: prose, detail: prose }))).default([]),
})
export type Insights = z.infer<typeof insightsSchema>

export const memoryPatternsSchema = z.object({
  patterns: z.array(patternDetail(z.object({
    colorToken: z.enum(DIMENSIONS).catch('money'),
    title: prose,
    detail: prose,
  }))).default([]),
})

// --- Pal Home agenda (/v1/agenda) -------------------------------------------
// The model picks each proposal's `kind` and copy; the server derives the pillar
// tag, colour, icons and the client action from that kind, so the model can
// never name a bad icon or an action the client cannot perform. an off-list
// kind is dropped, never coerced.
const agendaProposalKinds = ['reschedule_workout', 'close_out', 'add_ritual'] as const
const agendaAutopilotKinds = ['spend_nudge', 'routine_reminders'] as const
type ProposalKind = (typeof agendaProposalKinds)[number]

const PROPOSAL_PRESENTATION: Record<ProposalKind, { tag: string; colorToken: string; icon: string; approveIcon: string }> = {
  reschedule_workout: { tag: 'Workout', colorToken: 'move', icon: 'figure.run', approveIcon: 'arrow.triangle.2.circlepath' },
  close_out: { tag: 'Rituals', colorToken: 'rituals', icon: 'moon.stars.fill', approveIcon: 'play.fill' },
  add_ritual: { tag: 'Rituals', colorToken: 'rituals', icon: 'sparkles', approveIcon: 'plus' },
}

const isProposalKind = (k: string): k is ProposalKind => (agendaProposalKinds as readonly string[]).includes(k)

const WEEKDAY_MIN = 1
const WEEKDAY_MAX = 7

export const agendaModelSchema = z.object({
  proposals: z.array(z.object({
    kind: z.string(),
    title: prose,
    body: prose,
    approveLabel: prose,
    doneLabel: prose,
    ritual: z.object({ routineId: z.string(), step: z.string() }).nullish().catch(null),
    slot: z.object({ weekday: z.number(), routineId: z.string() }).nullish().catch(null),
  })).default([]),
  autopilot: z.array(z.object({ kind: z.string(), subtitle: prose })).default([]),
})
type AgendaProposal = z.infer<typeof agendaModelSchema>['proposals'][number]

const escapeRe = (s: string) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')

// the amounts written in the user's currency in `text`, as numbers. `bare`
// also counts numbers written without the symbol.
export function moneyAmounts(text: string, c: CurrencyDescriptor = USD, bare = false): number[] {
  const num = `\\d[\\d${escapeRe(c.group)}]*(?:${escapeRe(c.decimal)}\\d+)?`
  const sym = escapeRe(c.symbol)
  const pattern = bare ? `(${num})` : c.symbolBefore ? `${sym}\\s?(${num})` : `(${num})\\s?${sym}`
  return [...text.matchAll(new RegExp(pattern, 'g'))].map((m) =>
    Number(m[1].split(c.group).join('').replace(c.decimal, '.')))
}

// a button names only amounts its proposal states: the agenda prompt's old
// example anchored "Hold $40" under a $0.15 overage.
export function labelsAgree(p: Pick<AgendaProposal, 'title' | 'body' | 'approveLabel' | 'doneLabel'>, c?: CurrencyDescriptor): boolean {
  const stated = new Set(moneyAmounts(`${p.title} ${p.body}`, c, true))
  return [p.approveLabel, p.doneLabel].every((label) => moneyAmounts(label, c).every((n) => stated.has(n)))
}

// --- Pal's line per open item of the day (/v1/agenda `lines`) ----------------
export const leadLinesModelSchema = z.object({
  lines: z.array(z.object({ key: z.string(), line: prose })).default([]),
})

export interface LeadLine {
  key: string
  line: string
}

const NUMBER_WORDS = ['zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten',
  'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen', 'sixteen', 'seventeen', 'eighteen', 'nineteen', 'twenty']
const STATED_NUMBER = new RegExp(`\\d+|\\b(?:${NUMBER_WORDS.join('|')})\\b`, 'gi')

// every number `text` states, in digits or as a word; a time gives its hour and minutes.
function statedNumbers(text: string): number[] {
  return [...text.matchAll(STATED_NUMBER)].map(([m]) => (/\d/.test(m) ? Number(m) : NUMBER_WORDS.indexOf(m.toLowerCase())))
}

// a line states only numbers its item's facts hold: the model words the item,
// it never counts steps or moves a time on its own.
export function lineAgrees(line: string, fact: PlanFact): boolean {
  const held = new Set(statedNumbers([fact.title, fact.when, fact.steps ?? '', fact.why].join(' ')))
  return statedNumbers(line).every((n) => held.has(n))
}

// the payload an approval acts on must name something that exists and would
// change something: a duplicate step or an unchanged slot is a no-op approve.
export function proposalValid(p: AgendaProposal, targets: AgendaTargets, currency?: CurrencyDescriptor): boolean {
  if (!labelsAgree(p, currency)) return false
  if (p.kind === 'add_ritual') {
    const step = p.ritual?.step.trim().toLowerCase()
    const routine = targets.rituals.find((r) => r.id === p.ritual?.routineId)
    return !!step && !!routine && !routine.steps.some((existing) => existing.trim().toLowerCase() === step)
  }
  if (p.kind === 'reschedule_workout') {
    const slot = p.slot
    if (!slot || !Number.isInteger(slot.weekday) || slot.weekday < WEEKDAY_MIN || slot.weekday > WEEKDAY_MAX) return false
    if (!targets.workouts.some((w) => w.id === slot.routineId)) return false
    const current = targets.week.find((d) => d.weekday === slot.weekday)?.routineId ?? null
    return current !== slot.routineId
  }
  return true
}

// a proposal's id names its kind and target, never its position: the client
// saves what the user approved or put off by id for the day, and a refetch
// that reorders the agenda must not hand that state to another proposal.
export function proposalId(kind: ProposalKind, p: Pick<AgendaProposal, 'ritual' | 'slot'>): string {
  switch (kind) {
    case 'reschedule_workout':
      return `${kind}:${p.slot?.weekday}:${p.slot?.routineId}`
    case 'add_ritual':
      return `${kind}:${p.ritual?.routineId}:${p.ritual?.step.trim().toLowerCase()}`
    case 'close_out':
      return kind
  }
}

// The wire shape the client decodes (icons/action resolved, streak echoed).
export interface AgendaResult {
  proposals: Array<{
    id: string; tag: string; colorToken: string; icon: string; title: string; body: string; approveLabel: string
    approveIcon: string; doneLabel: string; action: ProposalKind
    ritual: { routineId: string; step: string } | null; slot: { weekday: number; routineId: string } | null
  }>
  autopilot: Array<{ id: string; subtitle: string }>
  streakDays: number
}

// --- Pal quick-pick suggestions (/v1/suggestions) ---------------------------
// The model picks each chip's `kind` (and the copy); the server derives the
// SF-symbol icon from that kind. Off-list kinds coerce to 'generic'.
const suggestionKinds = ['log_money', 'log_move', 'log_ritual', 'ask', 'routine_goal', 'generic'] as const

const SUGGESTION_ICON: Record<(typeof suggestionKinds)[number], string> = {
  log_money: 'dollarsign.circle.fill',
  log_move: 'figure.run',
  log_ritual: 'sparkles',
  ask: 'chart.bar.fill',
  routine_goal: 'flame.fill',
  generic: 'sparkles',
}

const suggestionEntry = z.object({
  type: z.enum(ENTRY_TYPES),
  title: z.string(),
  amount: z.number().nullable().optional(),
  category: z.string().nullable().optional(),
  minutes: z.number().nullable().optional(),
}).nullable().optional()

export const suggestionsModelSchema = z.object({
  suggestions: z.array(z.object({
    kind: z.enum(suggestionKinds).catch('generic'),
    // chips include an 'accent' pillar (ask chips); off-list values coerce.
    colorToken: z.enum(['money', 'move', 'rituals', 'accent']).catch('accent'),
    label: prose,
    entry: suggestionEntry,
  })).default([]),
})

export interface SuggestionsResult {
  suggestions: Array<{
    label: string
    icon: string
    colorToken: string
    entry: { type: 'money' | 'move' | 'rituals'; title: string; amount: number | null; category: string | null; minutes: number | null } | null
  }>
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
  rationale: prose.nullable().optional(),
  exercises: z.array(z.object({ exerciseId: z.string(), sets: z.array(routineSetSchema) })),
})
export type GeneratedRoutine = z.infer<typeof routineSchema>

const NO_JSON = 'no JSON object found in model output'

// Pull a JSON object out of a model reply: tolerate code fences and surrounding prose.
export function extractJson(raw: string): unknown {
  let s = raw.trim()
  const fence = s.match(/```(?:json)?\s*([\s\S]*?)```/i)
  if (fence) s = fence[1].trim()
  const start = s.indexOf('{')
  const end = s.lastIndexOf('}')
  if (start === -1 || end === -1 || end < start) {
    throw new Error(NO_JSON)
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
  | { kind: 'log_meal'; name: string; slot: string | null; calLo: number; calHi: number; confidence: 'high' | 'med' | 'low' }

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
    const category = spendCategory(p.category)
    return { kind: 'log_expense', amount: p.amount, category, title: p.title ?? category ?? 'Expense', note: p.note ?? null }
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
  log_meal: (a) => {
    const p = z.object({
      name: z.string().trim().min(1), slot: optStr,
      calLo: posInt, calHi: posInt,
      confidence: z.enum(['high', 'med', 'low']).catch('low'),
    }).parse(a)
    return { kind: 'log_meal', name: p.name, slot: p.slot ?? null, calLo: p.calLo, calHi: Math.max(p.calLo, p.calHi), confidence: p.confidence }
  },
}

// OpenAI-format tool specs advertised to the model on /chat.
const obj = (properties: Record<string, unknown>, required: string[]) => ({ type: 'object', properties, required, additionalProperties: false })
const numProp = (description: string) => ({ type: 'number', description })
const strProp = (description: string) => ({ type: 'string', description })
const tool = (name: string, description: string, parameters: unknown) => ({ type: 'function', function: { name, description, parameters } })

export const CHAT_TOOLS = [
  tool('log_expense', 'Record money the user spent. Use a positive amount in the user\'s own currency.',
    obj({ amount: numProp('amount spent, positive, in the user\'s own currency (expand k/m suffixes: 12k -> 12000)'), category: { type: 'string', enum: SPEND_CATEGORIES, description: 'the spend category; prepared food and drinks are Food & Drink' }, title: strProp('short label that keeps the place or merchant when the user names one, e.g. "Dinner at Tartine" or "Coffee"'), note: strProp('optional note') }, ['amount'])),
  tool('log_income', 'Record money the user received. Positive amount in the user\'s own currency.',
    obj({ amount: numProp('amount received, positive, in the user\'s own currency (expand k/m suffixes: 12k -> 12000)'), title: strProp('short label, e.g. "paycheck"'), note: strProp('optional note') }, ['amount'])),
  tool('log_movement', 'Record a workout or movement session by its duration in minutes.',
    obj({ durationMinutes: numProp('minutes of movement'), calories: numProp('kcal burned during the session, if known'), title: strProp('short label, e.g. "run"'), note: strProp('optional note') }, ['durationMinutes'])),
  tool('log_ritual', 'Record a completed ritual/routine the user did.',
    obj({ title: strProp('the ritual name, e.g. "morning pages"'), note: strProp('optional note') }, ['title'])),
  tool('log_meal', 'Record a meal or drink the user ate, with your own calorie estimate. Use when the user says they ate or drank something (not when they only spent money on it).',
    obj({ name: strProp('short meal name, e.g. "burrito"'), slot: strProp('Breakfast, Lunch, Dinner, Snack, or Drink'), calLo: numProp('low end of the calorie estimate'), calHi: numProp('high end of the calorie estimate'), confidence: strProp('your confidence: high, med, or low') }, ['name', 'calLo', 'calHi'])),
  tool('set_daily_budget', "Change the user's daily spending budget, in the user's own currency.",
    obj({ dailyBudget: numProp('new daily budget in the user\'s own currency (expand k/m suffixes: 12k -> 12000)') }, ['dailyBudget'])),
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
      a.kind !== 'log_ritual' &&
      a.kind !== 'log_meal',
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

// a model reply that is not JSON or misses the schema; a second draw usually lands.
const isBadOutput = (err: unknown) =>
  err instanceof SyntaxError || (err instanceof Error && (err.name === 'ZodError' || err.message === NO_JSON))

export class Pal {
  constructor(private readonly client: CompletionClient) {}

  // one JSON completion read by `parse`, drawn once more when the output is
  // malformed. upstream errors are not retried here: the client retries the
  // transient ones.
  private async completeJson<T>(prompt: string, opts: { maxTokens?: number; temperature?: number }, parse: (json: unknown) => T): Promise<T> {
    const draw = async () => parse(extractJson(await this.client.complete([{ role: 'user', content: prompt }], { json: true, ...opts })))
    try {
      return await draw()
    } catch (err) {
      if (!isBadOutput(err)) throw err
      return draw()
    }
  }

  async chat(history: Array<{ role: 'user' | 'assistant'; text: string }>, message: string, ctx: ChatContext, memory?: MemoryDigest): Promise<ChatResult> {
    // keep only the most recent turns; system + new user message are always included and don't count.
    const recent = history.slice(-MAX_HISTORY_MESSAGES)
    const messages: ChatMessage[] = [
      { role: 'system', content: chatSystemPrompt(ctx, memory) },
      ...recent.map((m) => ({ role: m.role, content: m.text })),
      { role: 'user', content: message },
    ]
    let res = await this.client.completeWithTools(messages, CHAT_TOOLS)
    // nothing is applied until the client gets the result, so a reply that
    // shows its working is drawn once more, tools and all.
    if (thinksAloud(res.content)) res = await this.client.completeWithTools(messages, CHAT_TOOLS)
    const actions = toolCallsToActions(res.toolCalls)
    const memoryOps = toolCallsToMemoryOps(res.toolCalls)
    const reply = plainText(res.content) || synthReply(actions)
    return { reply, actions, memoryOps }
  }

  async review(ctx: ReviewContext, memory?: MemoryDigest): Promise<string> {
    return plainText(await this.client.complete([{ role: 'user', content: reviewPrompt(ctx, memory) }]))
  }

  async insights(ctx: InsightsContext, memory?: MemoryDigest): Promise<Insights> {
    return this.completeJson(insightsPrompt(ctx, memory), { maxTokens: INSIGHTS_MAX_TOKENS, temperature: 0 }, (j) => insightsSchema.parse(j))
  }

  async refreshPatterns(ctx: InsightsContext, digest: MemoryDigest): Promise<MemoryPattern[]> {
    const parsed = await this.completeJson(memoryPatternsPrompt(ctx, digest), { maxTokens: INSIGHTS_MAX_TOKENS, temperature: 0 }, (j) => memoryPatternsSchema.parse(j))
    return parsed.patterns.slice(0, MAX_PATTERNS)
  }

  async postWorkoutNote(ctx: PostWorkoutContext): Promise<string> {
    return plainText(await this.client.complete([{ role: 'user', content: postWorkoutPrompt(ctx) }]))
  }

  async parse(text: string): Promise<ParsedEntry> {
    return this.completeJson(parsePrompt(text), { temperature: 0 }, (j) => parseSchema.parse(j))
  }

  async estimateMeal(description: string): Promise<NutritionEstimate> {
    return this.completeJson(nutritionEstimatePrompt(description), { temperature: 0 }, (j) => nutritionEstimateSchema.parse(j))
  }

  async suggestWorkout(another: boolean, ctx: SuggestContext): Promise<Suggestion> {
    const nudge = another ? '\n\nPick a DIFFERENT routine than you would normally default to.' : ''
    const draw = () => this.completeJson(suggestPrompt(ctx) + nudge, {}, (j) => suggestSchema.parse(j))
    let pick = await draw()
    // a reason that says trained muscles went untrained is redrawn once; still
    // wrong, the pick stands with a reason that claims nothing.
    if (deniesRecent(pick.reason, ctx.recentWorkouts)) pick = await draw()
    if (deniesRecent(pick.reason, ctx.recentWorkouts)) pick = { ...pick, reason: fallbackReason(pick.routineId, ctx) }
    return pick
  }

  async agenda(ctx: ChatContext, targets: AgendaTargets, memory?: MemoryDigest): Promise<AgendaResult> {
    const draw = async () => {
      const parsed = await this.completeJson(agendaPrompt(ctx, memory, targets), { maxTokens: INSIGHTS_MAX_TOKENS, temperature: 0 }, (j) => agendaModelSchema.parse(j))
      return { ...parsed, proposals: parsed.proposals.filter((p) => isProposalKind(p.kind)) }
    }
    const valid = (p: AgendaProposal) => proposalValid(p, targets, ctx.currency)
    let parsed = await draw()
    // a proposal that names a missing target, a no-op change or an amount it
    // never states is redrawn once; one still invalid after that is dropped.
    if (!parsed.proposals.every(valid)) parsed = await draw()
    const seen = new Set<string>()
    return {
      proposals: parsed.proposals.filter(valid).flatMap((p) => {
        const kind = p.kind as ProposalKind
        const id = proposalId(kind, p)
        // the client keys what the user settled by id, so one id is one proposal.
        if (seen.has(id)) return []
        seen.add(id)
        const pres = PROPOSAL_PRESENTATION[kind]
        return [{
          id,
          tag: pres.tag,
          colorToken: pres.colorToken,
          icon: pres.icon,
          title: p.title,
          body: p.body,
          approveLabel: p.approveLabel,
          approveIcon: pres.approveIcon,
          doneLabel: p.doneLabel,
          action: kind,
          ritual: kind === 'add_ritual' && p.ritual ? { routineId: p.ritual.routineId, step: p.ritual.step.trim() } : null,
          slot: kind === 'reschedule_workout' ? p.slot ?? null : null,
        }]
      }),
      autopilot: agendaAutopilotKinds.flatMap((kind) => {
        const first = parsed.autopilot.find((a) => a.kind === kind)
        return first ? [{ id: kind, subtitle: first.subtitle }] : []
      }),
      streakDays: ctx.moveStreakDays,
    }
  }

  // no redraw when a line disagrees: the app falls back to the item's own sentence.
  async leadLines(plan: PlanFact[]): Promise<LeadLine[]> {
    if (plan.length === 0) return []
    const parsed = await this.completeJson(leadLinesPrompt(plan), { maxTokens: LINES_MAX_TOKENS, temperature: 0 }, (j) => leadLinesModelSchema.parse(j))
    const unanswered = new Map(plan.map((f) => [f.key, f]))
    const lines: LeadLine[] = []
    for (const { key, line } of parsed.lines) {
      const fact = unanswered.get(key)
      const text = line.trim()
      if (!fact || !text) continue
      unanswered.delete(key)
      if (lineAgrees(text, fact)) lines.push({ key, line: text })
    }
    return lines
  }

  async suggestions(surface: 'composer' | 'routineGoal', ctx: ChatContext | SuggestContext): Promise<SuggestionsResult> {
    const parsed = await this.completeJson(suggestionsPrompt(surface, ctx), { maxTokens: INSIGHTS_MAX_TOKENS, temperature: 0 }, (j) => suggestionsModelSchema.parse(j))
    // a one-tap log with an amount today's entries never state ("Late snack
    // $6.50") would log a number the model made up, so that chip is dropped.
    const stated = surface === 'composer' ? statedAmounts(ctx as ChatContext) : null
    const grounded = (s: (typeof parsed.suggestions)[number]) =>
      stated === null || s.entry?.type !== 'money' || s.entry.amount == null ||
      stated.some((a) => Math.abs(a - Math.abs(s.entry!.amount!)) < 0.005)
    return {
      suggestions: parsed.suggestions.filter(grounded).map((s) => ({
        label: s.label,
        icon: SUGGESTION_ICON[s.kind],
        colorToken: s.colorToken,
        entry: s.entry
          ? {
              type: s.entry.type,
              title: s.entry.title,
              amount: s.entry.amount ?? null,
              category: spendCategory(s.entry.category),
              minutes: s.entry.minutes ?? null,
            }
          : null,
      })),
    }
  }

  async generateRoutine(goal: string, exercises: RoutineExercise[], memory?: MemoryDigest): Promise<GeneratedRoutine> {
    // drop any exercise the model invented — the client can only resolve catalog ids.
    const known = new Set(exercises.map((e) => e.id))
    const draw = async (): Promise<GeneratedRoutine> => {
      const parsed = await this.completeJson(routinePrompt(goal, exercises, memory), { maxTokens: ROUTINE_MAX_TOKENS }, (j) => routineSchema.parse(j))
      const routine = { ...parsed, exercises: parsed.exercises.filter((e) => known.has(e.exerciseId)) }
      // a rationale naming a group or muscle no chosen exercise trains is dropped:
      // the routine stands on its own and the screen shows it without one.
      return overclaims(routine, exercises) ? { ...routine, rationale: null } : routine
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
