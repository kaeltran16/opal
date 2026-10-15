import { describe, it, expect, vi } from 'vitest'
import {
  Pal, OpenRouterClient, OpenRouterError, extractJson, toolCallsToActions, toolCallsToMemoryOps, parseSchema, synthReply,
  insightsSchema, nutritionEstimateSchema, memoryPatternsSchema, plainText, moneyAmounts, labelsAgree, lineAgrees, thinksAloud, deniesRecent, overclaims,
  CHAT_TOOLS, type CompletionClient, type CompletionResult, type ToolCall, type ChatMessage,
} from './pal.js'
import { SPEND_CATEGORIES } from './product.js'
import { leadLinesPrompt, type PlanFact } from './prompts.js'

// Most methods only need complete(); chat() uses completeWithTools().
function fakeClient(reply: string): CompletionClient {
  return {
    complete: vi.fn(async () => reply),
    completeWithTools: vi.fn(async () => ({ content: reply, toolCalls: [] })),
  }
}

function fakeToolClient(result: CompletionResult): CompletionClient {
  return {
    complete: vi.fn(async () => ''),
    completeWithTools: vi.fn(async () => result),
  }
}

const toolCall = (name: string, args: unknown): ToolCall => ({ name, arguments: JSON.stringify(args) })

describe('Pal.agenda', () => {
  const ctx = {
    userName: 'Mira', todayEntries: [], dailyBudget: 85, moveGoalKcal: 60, ritualGoal: 5,
    spentToday: 60, movedTodayKcal: 66, ritualsDoneToday: 4,
    weekSpent: 435, weekBudget: 595, weekMovedKcal: 296, weekRitualsDone: 26, weekRitualGoal: 35,
    moveStreakDays: 11, hourOfDay: 8, weekday: 6,
  }

  it('derives icons/approveIcon/action from kind and echoes the streak', async () => {
    const model = JSON.stringify({
      proposals: [{
        kind: 'close_out', colorToken: 'rituals', tag: 'Rituals', title: 'Close out tonight',
        body: 'A 5-min wind-down closes your ring.', approveLabel: 'Start close-out', doneLabel: 'Close-out queued',
      }],
      autopilot: [{ kind: 'bills_watch', colorToken: 'money', title: 'Rent watch', subtitle: 'Alerts if low', enabled: true }],
    })
    const res = await new Pal(fakeClient(model)).agenda(ctx)

    expect(res.proposals[0]).toMatchObject({
      icon: 'moon.stars.fill', approveIcon: 'play.fill', action: 'close_out', colorToken: 'rituals',
    })
    expect(res.proposals[0].id).toBe('close_out-0')
    expect(res.autopilot[0].icon).toBe('house.fill')
    expect(res.streakDays).toBe(11)
  })

  it('gives an add_ritual proposal its own action', async () => {
    const model = JSON.stringify({
      proposals: [{
        kind: 'add_ritual', colorToken: 'rituals', tag: 'Rituals', title: 'Add a 2-min wind-down ritual',
        body: 'A short wind-down could anchor it.', approveLabel: 'Add ritual', doneLabel: 'Added',
      }],
      autopilot: [],
    })
    const res = await new Pal(fakeClient(model)).agenda(ctx)
    expect(res.proposals[0]).toMatchObject({ icon: 'sparkles', approveIcon: 'plus', action: 'add_ritual' })
  })

  it('coerces an unknown proposal kind to the generic (non-navigating) presentation', async () => {
    const model = JSON.stringify({
      proposals: [{
        kind: 'teleport', colorToken: 'move', tag: 'Workout', title: 'x', body: 'y',
        approveLabel: 'Do it', doneLabel: 'Done',
      }],
      autopilot: [],
    })
    const res = await new Pal(fakeClient(model)).agenda(ctx)
    expect(res.proposals[0]).toMatchObject({ icon: 'sparkles', approveIcon: 'checkmark', action: null })
  })
})

describe('Pal JSON routes', () => {
  const SUGGEST_CTX = { recentWorkouts: [], dayOfWeek: 'Wednesday', availableRoutines: [{ id: 'r1', name: 'Legs' }] }
  const replies = (...texts: string[]): CompletionClient => {
    const queue = [...texts]
    return { complete: vi.fn(async () => queue.shift() ?? ''), completeWithTools: vi.fn() }
  }

  it('draws once more when the model output is not the schema, and returns the second draw', async () => {
    const client = replies('{"A": "What is the correct format?"}', '{"routineId": "r1", "reason": "legs are fresh"}')
    expect(await new Pal(client).suggestWorkout(false, SUGGEST_CTX)).toEqual({ routineId: 'r1', reason: 'legs are fresh' })
    expect(client.complete).toHaveBeenCalledTimes(2)
  })

  it('draws at most twice on malformed output', async () => {
    const client = replies('not json', 'still not json', '{"routineId": "r1", "reason": "x"}')
    await expect(new Pal(client).suggestWorkout(false, SUGGEST_CTX)).rejects.toThrow()
    expect(client.complete).toHaveBeenCalledTimes(2)
  })

  it('redraws a reason that says trained muscles went untrained, then falls back', async () => {
    const ctx = {
      ...SUGGEST_CTX,
      recentWorkouts: [{ routineName: 'Leg Day', date: 'Yesterday', muscles: 'Quads, Back', groups: 'Legs, Pull' }],
      plannedToday: 'Legs',
    }
    const wrong = '{"routineId": "r1", "reason": "Your recent workouts have not hit your legs."}'
    const right = '{"routineId": "r1", "reason": "Push is fresh after yesterday on legs."}'
    expect(await new Pal(replies(wrong, right)).suggestWorkout(false, ctx)).toEqual({ routineId: 'r1', reason: 'Push is fresh after yesterday on legs.' })
    expect(await new Pal(replies(wrong, wrong)).suggestWorkout(false, ctx)).toEqual({ routineId: 'r1', reason: 'It is the one your plan has for today.' })
  })

  it('does not redraw on an upstream error', async () => {
    const client: CompletionClient = {
      complete: vi.fn(async () => { throw new OpenRouterError(502, 'down') }),
      completeWithTools: vi.fn(),
    }
    await expect(new Pal(client).suggestWorkout(false, SUGGEST_CTX)).rejects.toBeInstanceOf(OpenRouterError)
    expect(client.complete).toHaveBeenCalledTimes(1)
  })
})

describe('extractJson', () => {
  it('parses a bare JSON object', () => {
    expect(extractJson('{"a":1}')).toEqual({ a: 1 })
  })
  it('tolerates markdown code fences and surrounding prose', () => {
    expect(extractJson('Sure:\n```json\n{"a":1}\n```\n')).toEqual({ a: 1 })
  })
  it('throws when no object is present', () => {
    expect(() => extractJson('no json here')).toThrow()
  })
})

describe('OpenRouterClient', () => {
  const okResponse = () =>
    new Response(JSON.stringify({ choices: [{ message: { content: '{}' } }] }), { status: 200 })

  it('sends response_format only when JSON output is requested', async () => {
    let body: Record<string, unknown> = {}
    const capture = (async (_url, init) => {
      body = JSON.parse(String((init as RequestInit).body))
      return okResponse()
    }) as typeof fetch
    const client = new OpenRouterClient('k', 'm', 'http://x', capture)

    await client.complete([{ role: 'user', content: 'hi' }])
    expect(body.response_format).toBeUndefined()

    await client.complete([{ role: 'user', content: 'hi' }], { json: true })
    expect(body.response_format).toEqual({ type: 'json_object' })
  })

  it('defaults max_tokens and lets opts.maxTokens override it', async () => {
    let body: Record<string, unknown> = {}
    const capture = (async (_url, init) => {
      body = JSON.parse(String((init as RequestInit).body))
      return okResponse()
    }) as typeof fetch
    const client = new OpenRouterClient('k', 'm', 'http://x', capture)

    await client.complete([{ role: 'user', content: 'hi' }])
    expect(body.max_tokens).toBe(1024)

    await client.complete([{ role: 'user', content: 'hi' }], { maxTokens: 4096 })
    expect(body.max_tokens).toBe(4096)
  })

  it('sends temperature only when opts.temperature is provided', async () => {
    let body: Record<string, unknown> = {}
    const capture = (async (_url, init) => {
      body = JSON.parse(String((init as RequestInit).body))
      return okResponse()
    }) as typeof fetch
    const client = new OpenRouterClient('k', 'm', 'http://x', capture)

    await client.complete([{ role: 'user', content: 'hi' }])
    expect(body.temperature).toBeUndefined()

    await client.complete([{ role: 'user', content: 'hi' }], { temperature: 0 })
    expect(body.temperature).toBe(0)
  })

  it('turns provider reasoning off on every call so it cannot eat the output cap', async () => {
    const bodies: Array<Record<string, unknown>> = []
    const capture = (async (_url, init) => {
      bodies.push(JSON.parse(String((init as RequestInit).body)))
      return okResponse()
    }) as typeof fetch
    const client = new OpenRouterClient('k', 'm', 'http://x', capture)

    await client.complete([{ role: 'user', content: 'hi' }], { json: true, maxTokens: 2048 })
    await client.completeWithTools([{ role: 'user', content: 'hi' }], [])
    expect(bodies.map((b) => b.reasoning)).toEqual([{ enabled: false }, { enabled: false }])
  })

  it('opts into usage accounting so the provider reports cost', async () => {
    let body: Record<string, unknown> = {}
    const capture = (async (_url, init) => {
      body = JSON.parse(String((init as RequestInit).body))
      return okResponse()
    }) as typeof fetch
    await new OpenRouterClient('k', 'm', 'http://x', capture).complete([{ role: 'user', content: 'hi' }])
    expect(body.usage).toEqual({ include: true })
  })

  it('surfaces the provider-reported cost at the top level of the usage log', async () => {
    const withCost = (async () =>
      new Response(JSON.stringify({ choices: [{ message: { content: '{}' }, finish_reason: 'stop' }], usage: { total_tokens: 42, cost: 0.00014 } }), { status: 200 })) as typeof fetch
    const logged: Array<{ obj: unknown }> = []
    const logger = { info: (obj: unknown) => logged.push({ obj }) }
    await new OpenRouterClient('k', 'm', 'http://x', withCost, 30_000, logger).complete([{ role: 'user', content: 'hi' }])
    expect(logged[0].obj).toMatchObject({ cost: 0.00014 })
  })

  it('throws OpenRouterError(502) when the model output is truncated (finish_reason length)', async () => {
    const truncated = (async () =>
      new Response(JSON.stringify({ choices: [{ message: { content: '{"a":' }, finish_reason: 'length' }] }), { status: 200 })) as typeof fetch
    const client = new OpenRouterClient('k', 'm', 'http://x', truncated)
    await expect(client.complete([{ role: 'user', content: 'hi' }], { json: true }))
      .rejects.toMatchObject({ status: 502 })
  })

  it('retries once on a 429 and succeeds on the second attempt', async () => {
    let calls = 0
    const flaky = (async () => {
      calls += 1
      return calls === 1
        ? new Response('rate limited', { status: 429 })
        : okResponse()
    }) as typeof fetch
    // retryDelayMs=0 keeps the test fast
    const client = new OpenRouterClient('k', 'm', 'http://x', flaky, 30_000, undefined, 0)
    await client.complete([{ role: 'user', content: 'hi' }])
    expect(calls).toBe(2)
  })

  it('retries once on a 5xx and succeeds on the second attempt', async () => {
    let calls = 0
    const flaky = (async () => {
      calls += 1
      return calls === 1 ? new Response('boom', { status: 503 }) : okResponse()
    }) as typeof fetch
    const client = new OpenRouterClient('k', 'm', 'http://x', flaky, 30_000, undefined, 0)
    await client.complete([{ role: 'user', content: 'hi' }])
    expect(calls).toBe(2)
  })

  it('retries once on a network error and succeeds on the second attempt', async () => {
    let calls = 0
    const flaky = (async () => {
      calls += 1
      if (calls === 1) throw new Error('ECONNRESET')
      return okResponse()
    }) as typeof fetch
    const client = new OpenRouterClient('k', 'm', 'http://x', flaky, 30_000, undefined, 0)
    await client.complete([{ role: 'user', content: 'hi' }])
    expect(calls).toBe(2)
  })

  it('does not retry a 400 (a client error will not improve)', async () => {
    let calls = 0
    const bad = (async () => {
      calls += 1
      return new Response('bad request', { status: 400 })
    }) as typeof fetch
    const client = new OpenRouterClient('k', 'm', 'http://x', bad, 30_000, undefined, 0)
    await expect(client.complete([{ role: 'user', content: 'hi' }])).rejects.toMatchObject({ status: 400 })
    expect(calls).toBe(1)
  })

  it('logs ms, model and usage after a successful completion', async () => {
    const withUsage = (async () =>
      new Response(JSON.stringify({ choices: [{ message: { content: '{}' }, finish_reason: 'stop' }], usage: { total_tokens: 42 } }), { status: 200 })) as typeof fetch
    const logged: Array<{ obj: unknown; msg?: string }> = []
    const logger = { info: (obj: unknown, msg?: string) => logged.push({ obj, msg }) }
    const client = new OpenRouterClient('k', 'gpt-x', 'http://x', withUsage, 30_000, logger)
    await client.complete([{ role: 'user', content: 'hi' }])
    expect(logged).toHaveLength(1)
    expect(logged[0].obj).toMatchObject({ model: 'gpt-x', usage: { total_tokens: 42 }, finish_reason: 'stop' })
    expect((logged[0].obj as { ms: number }).ms).toBeGreaterThanOrEqual(0)
  })

  it('errors (OpenRouterError) when a request exceeds the timeout', async () => {
    // a fetch that never resolves on its own — only the abort signal ends it
    const hanging = ((_url, init) =>
      new Promise<Response>((_resolve, reject) => {
        (init as RequestInit).signal?.addEventListener('abort', () => reject(new Error('aborted')))
      })) as typeof fetch
    const client = new OpenRouterClient('k', 'm', 'http://x', hanging, 5)

    await expect(client.complete([{ role: 'user', content: 'hi' }])).rejects.toBeInstanceOf(OpenRouterError)
  })
})

describe('toolCallsToActions', () => {
  it('maps a log_expense tool call, defaulting title and coercing a positive amount', () => {
    const actions = toolCallsToActions([toolCall('log_expense', { amount: -5, category: 'Food & Drink' })])
    expect(actions).toEqual([
      { kind: 'log_expense', amount: 5, category: 'Food & Drink', title: 'Food & Drink', note: null },
    ])
  })

  it('keeps an expense in the spend categories: canonical spelling, off-list dropped', () => {
    const [matched, offList] = toolCallsToActions([
      toolCall('log_expense', { amount: 32, category: 'food & drink', title: 'Dinner at Tartine' }),
      toolCall('log_expense', { amount: 32, category: 'Dining', title: 'Dinner at Tartine' }),
    ])
    expect(matched).toMatchObject({ category: 'Food & Drink', title: 'Dinner at Tartine' })
    expect(offList).toMatchObject({ category: null, title: 'Dinner at Tartine' })
  })

  it('advertises the spend categories as the log_expense enum and asks to keep the merchant', () => {
    const spec = CHAT_TOOLS.find((t) => t.function.name === 'log_expense')!.function.parameters as {
      properties: { category: { enum: readonly string[] }; title: { description: string } }
    }
    expect(spec.properties.category.enum).toEqual(SPEND_CATEGORIES)
    expect(spec.properties.title.description).toContain('Dinner at Tartine')
  })

  it('maps every supported mutation', () => {
    const actions = toolCallsToActions([
      toolCall('log_income', { amount: 1200, title: 'Paycheck' }),
      toolCall('log_movement', { durationMinutes: 30, calories: 240, title: 'Run' }),
      toolCall('log_ritual', { title: 'Morning pages' }),
      toolCall('set_daily_budget', { dailyBudget: 60 }),
      toolCall('set_move_goal', { dailyMoveKcal: 45 }),
      toolCall('set_ritual_goal', { dailyRitualTarget: 4 }),
      toolCall('create_routine', { goal: 'a push day' }),
    ])
    expect(actions.map((a) => a.kind)).toEqual([
      'log_income', 'log_movement', 'log_ritual', 'set_daily_budget', 'set_move_goal', 'set_ritual_goal', 'create_routine',
    ])
    expect(actions[1]).toMatchObject({ kind: 'log_movement', calories: 240 })
  })

  it('confirms a set_move_goal in kcal', () => {
    const actions = toolCallsToActions([toolCall('set_move_goal', { dailyMoveKcal: 45 })])
    expect(actions).toEqual([{ kind: 'set_move_goal', dailyMoveKcal: 45 }])
    expect(synthReply(actions)).toContain('set your move goal to 45 kcal')
  })

  it('drops unknown tools and calls with invalid args', () => {
    const actions = toolCallsToActions([
      toolCall('delete_everything', {}),
      toolCall('log_expense', { category: 'Coffee' }), // no amount
      toolCall('set_daily_budget', { dailyBudget: 'lots' }), // wrong type
      { name: 'log_ritual', arguments: 'not json' },
    ])
    expect(actions).toEqual([])
  })

  it('maps a log_meal tool call carrying the model calorie estimate', () => {
    const actions = toolCallsToActions([toolCall('log_meal', { name: 'Burrito', slot: 'Lunch', calLo: 520, calHi: 820, confidence: 'med' })])
    expect(actions).toEqual([{ kind: 'log_meal', name: 'Burrito', slot: 'Lunch', calLo: 520, calHi: 820, confidence: 'med' }])
  })
  it('drops a log_meal with no calorie range', () => {
    expect(toolCallsToActions([toolCall('log_meal', { name: 'Burrito' })])).toEqual([])
  })
})

describe('parseSchema', () => {
  const base = { type: 'money' as const, amount: 5, duration: null, category: null, title: 'x', note: null }

  it('accepts income and expense directions', () => {
    expect(parseSchema.parse({ ...base, direction: 'income' }).direction).toBe('income')
    expect(parseSchema.parse({ ...base, direction: 'expense' }).direction).toBe('expense')
  })

  it('accepts a null direction', () => {
    expect(parseSchema.parse({ ...base, direction: null }).direction).toBeNull()
  })

  it('coerces an off-list direction to expense', () => {
    expect(parseSchema.parse({ ...base, direction: 'refund' }).direction).toBe('expense')
  })
})

describe('insights colour tokens', () => {
  it('accepts a nutrition colour token on a pattern', () => {
    const parsed = insightsSchema.parse({
      headline: null, lede: null, suggestion: null,
      wins: [], patterns: [{ colorToken: 'nutrition', title: 't', detail: 'd' }],
    })
    expect(parsed.patterns[0].colorToken).toBe('nutrition')
  })

  it('reads a pattern written in the wins shape ({title, sub}) as its detail', () => {
    const pattern = { colorToken: 'money', title: 'Spending is front-loaded', sub: 'Mon to Wed hold it all.' }
    const parsed = insightsSchema.parse({ headline: null, lede: null, suggestion: null, wins: [], patterns: [pattern] })
    expect(parsed.patterns[0]).toEqual({ colorToken: 'money', title: 'Spending is front-loaded', detail: 'Mon to Wed hold it all.' })
    expect(memoryPatternsSchema.parse({ patterns: [pattern] }).patterns[0].detail).toBe('Mon to Wed hold it all.')
  })
})

describe('nutritionEstimateSchema', () => {
  it('parses a calorie estimate', () => {
    expect(nutritionEstimateSchema.parse({ name: 'Burrito', calLo: 520, calHi: 820, confidence: 'med' }))
      .toEqual({ name: 'Burrito', calLo: 520, calHi: 820, confidence: 'med' })
  })
  it('coerces an off-list confidence to low', () => {
    expect(nutritionEstimateSchema.parse({ name: 'x', calLo: 1, calHi: 2, confidence: 'maybe' }).confidence).toBe('low')
  })
})

describe('deniesRecent', () => {
  const recent = [{ routineName: 'Leg Day', date: 'Yesterday', muscles: 'Quads, Back', groups: 'Legs, Pull' }]

  it('flags a negation naming a trained muscle or group', () => {
    expect(deniesRecent("Your recent workouts haven't hit your legs.", recent)).toBe(true)
    expect(deniesRecent('No back work lately, so pull it is.', recent)).toBe(true)
  })

  it('leaves alone a reason that agrees with the workouts', () => {
    expect(deniesRecent('Legs were yesterday, so upper body is fresh.', recent)).toBe(false)
    expect(deniesRecent('You have not trained chest this week.', recent)).toBe(false)
  })
})

describe('thinksAloud', () => {
  it('flags a reply that recounts or corrects itself', () => {
    expect(thinksAloud('Six steps today: read, stretch... that is five, plus... let me recount: Five steps.')).toBe(true)
    expect(thinksAloud('Three left. Wait, you finished Midday, so two.')).toBe(true)
    expect(thinksAloud('Five steps: read, stretch, tea, journal, lights out.')).toBe(false)
    expect(thinksAloud("Wait until payday before the next big buy.")).toBe(false)
    expect(thinksAloud('Actually, you are under budget by $4.')).toBe(false)
  })
})

describe('Pal', () => {
  it('chat draws once more when the reply shows its working', async () => {
    const replies = ['Six steps... let me recount: five steps.', 'Five steps: read, stretch, tea, journal, lights out.']
    const client: CompletionClient = {
      complete: vi.fn(),
      completeWithTools: vi.fn(async () => ({ content: replies.shift() ?? '', toolCalls: [] })),
    }
    const result = await new Pal(client).chat([], 'how many routine steps today?', baseChatCtx())
    expect(result.reply).toBe('Five steps: read, stretch, tea, journal, lights out.')
    expect(client.completeWithTools).toHaveBeenCalledTimes(2)
  })

  it('chat returns the model text with no actions when no tool is called', async () => {
    const client = fakeToolClient({ content: 'You spent the most on Friday.', toolCalls: [] })
    const pal = new Pal(client)
    const result = await pal.chat([], 'why was friday expensive?', baseChatCtx())
    expect(result.reply).toBe('You spent the most on Friday.')
    expect(result.actions).toEqual([])
    expect(client.completeWithTools).toHaveBeenCalledOnce()
  })

  it('chat caps history to the most recent 20 turns; system + new user always sent', async () => {
    let sent: ChatMessage[] = []
    const client: CompletionClient = {
      complete: vi.fn(async () => ''),
      completeWithTools: vi.fn(async (m: ChatMessage[]) => {
        sent = m
        return { content: 'ok', toolCalls: [] }
      }),
    }
    const history = Array.from({ length: 50 }, (_, i) => ({ role: 'user' as const, text: `m${i}` }))
    await new Pal(client).chat(history, 'newest', baseChatCtx())
    // 1 system + 20 history + 1 new user
    expect(sent).toHaveLength(22)
    expect(sent[0].role).toBe('system')
    expect(sent[1].content).toBe('m30') // oldest kept is the 20th-from-last
    expect(sent.at(-1)?.content).toBe('newest')
  })

  it('chat surfaces a logged tool call but does not synthesize a restatement', async () => {
    const client = fakeToolClient({
      content: '',
      toolCalls: [toolCall('log_expense', { amount: 5, category: 'Food & Drink', title: 'coffee' })],
    })
    const pal = new Pal(client)
    const result = await pal.chat([], 'add $5 for coffee', baseChatCtx())
    expect(result.actions).toEqual([
      { kind: 'log_expense', amount: 5, category: 'Food & Drink', title: 'coffee', note: null },
    ])
    // the client renders a confirmation card for the log, so an empty model
    // reply stays empty — synthReply no longer restates logged entries.
    expect(result.reply).toBe('')
  })

  it('chat synthesizes a reply for a goal change when content is empty', async () => {
    const client = fakeToolClient({
      content: '',
      toolCalls: [toolCall('set_daily_budget', { dailyBudget: 60 })],
    })
    const pal = new Pal(client)
    const result = await pal.chat([], 'set my budget to 60', baseChatCtx())
    expect(result.actions).toEqual([{ kind: 'set_daily_budget', dailyBudget: 60 }])
    expect(result.reply).toContain('daily budget')
  })

  it('chat prefers the model reply text over the synthesized one when both are present', async () => {
    const client = fakeToolClient({
      content: 'Logged it — that puts you at $25 today.',
      toolCalls: [toolCall('log_expense', { amount: 5, title: 'coffee' })],
    })
    const pal = new Pal(client)
    const result = await pal.chat([], 'add $5 for coffee', baseChatCtx())
    expect(result.reply).toBe('Logged it — that puts you at $25 today.')
    expect(result.actions).toHaveLength(1)
  })

  it('asks the model for JSON on parse but not on the free-text review', async () => {
    const opts: Array<unknown> = []
    const client: CompletionClient = {
      complete: vi.fn(async (_m, o) => {
        opts.push(o)
        return '{"type":"money","amount":5,"duration":null,"category":null,"title":"x","note":null}'
      }),
      completeWithTools: vi.fn(async () => ({ content: '', toolCalls: [] })),
    }
    const pal = new Pal(client)
    await pal.parse('coffee 5')
    expect(opts.at(-1)).toEqual({ json: true, temperature: 0 })
    await pal.review({
      range: 'month', spent: 1, spentDeltaPct: null, kcalMoved: 0, movedDeltaPct: null, activeDays: 0,
      ritualsKept: 0, ritualsTarget: 0, ritualsPct: 0, streakDays: 0,
      topCategory: 'Food', topCategoryPct: 0,
    })
    expect(opts.at(-1)).toBeUndefined()
  })

  it('insights requests a 2048 max_tokens cap', async () => {
    let opts: unknown
    const client: CompletionClient = {
      complete: vi.fn(async (_m, o) => {
        opts = o
        return JSON.stringify({ headline: 'h', lede: null, suggestion: null })
      }),
      completeWithTools: vi.fn(async () => ({ content: '', toolCalls: [] })),
    }
    await new Pal(client).insights(baseInsightsCtx())
    expect(opts).toMatchObject({ maxTokens: 2048 })
  })

  it('generateRoutine requests a 4096 max_tokens cap', async () => {
    let opts: unknown
    const client: CompletionClient = {
      complete: vi.fn(async (_m, o) => {
        opts = o
        return JSON.stringify({ name: 'X', tag: 'full', exercises: [] })
      }),
      completeWithTools: vi.fn(async () => ({ content: '', toolCalls: [] })),
    }
    await new Pal(client).generateRoutine('push', [])
    expect(opts).toMatchObject({ maxTokens: 4096 })
  })

  it('parse returns the structured object', async () => {
    const parsed = { type: 'money', amount: 5, duration: null, category: 'Food & Drink', title: 'Coffee', note: null, direction: 'expense' }
    const client = fakeClient('```json\n' + JSON.stringify(parsed) + '\n```')
    const pal = new Pal(client)
    const result = await pal.parse('coffee 5')
    expect(result).toEqual(parsed)
  })

  it('insights parses headline, wins and patterns, tolerating a code fence', async () => {
    const reply = {
      headline: 'Spending eased mid-week.', lede: 'A calmer week than last.', suggestion: 'Try a no-spend Friday.',
      wins: [{ colorToken: 'move', title: 'Moved 5 days', sub: 'matched your target' }],
      patterns: [{ colorToken: 'money', title: 'Weekends spike', sub: 'ignored', detail: 'Sat and Sun lead spend' }],
    }
    const client = fakeClient('```json\n' + JSON.stringify(reply) + '\n```')
    const pal = new Pal(client)
    const result = await pal.insights(baseInsightsCtx())
    expect(result.headline).toBe('Spending eased mid-week.')
    expect(result.wins).toHaveLength(1)
    expect(result.wins[0].colorToken).toBe('move')
    expect(result.patterns[0].detail).toBe('Sat and Sun lead spend')
  })

  it('insights defaults wins and patterns to empty arrays when omitted', async () => {
    const client = fakeClient(JSON.stringify({ headline: 'Today is on budget.', lede: null, suggestion: null }))
    const pal = new Pal(client)
    const result = await pal.insights(baseInsightsCtx())
    expect(result.wins).toEqual([])
    expect(result.patterns).toEqual([])
  })

  it('suggestWorkout returns routineId + reason', async () => {
    const parsed = { routineId: 'r2', reason: 'Legs are rested.' }
    const client = fakeClient(JSON.stringify(parsed))
    const pal = new Pal(client)
    const result = await pal.suggestWorkout(false, {
      recentWorkouts: [], dayOfWeek: 'Wed', availableRoutines: [{ id: 'r2', name: 'Legs' }],
    })
    expect(result).toEqual(parsed)
  })

  it('generateRoutine parses the draft, tolerating a code fence', async () => {
    const draft = {
      name: 'Push Day', tag: 'upper', estMin: 45, rationale: 'compound first',
      exercises: [{ exerciseId: 'e1', sets: [{ reps: 8, weight: 40, duration: null }] }],
    }
    const client = fakeClient('```json\n' + JSON.stringify(draft) + '\n```')
    const pal = new Pal(client)
    const result = await pal.generateRoutine('push', [{ id: 'e1', name: 'Bench', group: 'Push', equipment: 'Barbell' }])
    expect(result).toEqual(draft)
  })

  it('generateRoutine drops a rationale naming work the chosen exercises skip', async () => {
    const catalog = [
      { id: 'press', name: 'DB Press', group: 'Push', muscle: 'Chest', equipment: 'Dumbbell' },
      { id: 'row', name: 'Row', group: 'Pull', muscle: 'Back', equipment: 'Dumbbell' },
      { id: 'plank', name: 'Plank', group: 'Core', muscle: 'Abs', equipment: null },
    ]
    const draft = (rationale: string) => JSON.stringify({
      name: 'Quick', tag: 'upper', rationale,
      exercises: [{ exerciseId: 'press', sets: [{ reps: 8 }] }, { exerciseId: 'plank', sets: [{ duration: 1 }] }],
    })
    const over = await new Pal(fakeClient(draft('Hits your chest, back and core.'))).generateRoutine('quick', catalog)
    expect(over.rationale).toBeNull()
    const fair = await new Pal(fakeClient(draft('Presses for chest, a plank for core.'))).generateRoutine('quick', catalog)
    expect(fair.rationale).toBe('Presses for chest, a plank for core.')
  })

  it('overclaims reads the catalog groups and muscles, plural or not', () => {
    const catalog = [
      { id: 'squat', name: 'Squat', group: 'Legs', muscle: 'Quads', equipment: null },
      { id: 'curl', name: 'Curl', group: 'Pull', muscle: 'Biceps', equipment: null },
    ]
    const routine = (rationale: string) => ({ rationale, exercises: [{ exerciseId: 'curl', sets: [] }] })
    expect(overclaims(routine('Pull work for your biceps.'), catalog)).toBe(false)
    expect(overclaims(routine('Curls, then your leg work.'), catalog)).toBe(true)
    expect(overclaims({ rationale: null, exercises: [] }, catalog)).toBe(false)
  })

  it('generateRoutine drops exercises whose id is not in the catalog', async () => {
    const draft = {
      name: 'Full', tag: 'full',
      exercises: [
        { exerciseId: 'e1', sets: [{ reps: 10 }] },
        { exerciseId: 'ghost', sets: [{ reps: 5 }] },
      ],
    }
    const client = fakeClient(JSON.stringify(draft))
    const pal = new Pal(client)
    const result = await pal.generateRoutine('full body', [{ id: 'e1', name: 'Squat', group: 'Legs', equipment: null }])
    expect(result.exercises).toHaveLength(1)
    expect(result.exercises[0].exerciseId).toBe('e1')
  })

  it('generateRoutine retries once when the first draft has no catalog exercises', async () => {
    const ghost = JSON.stringify({ name: 'X', tag: 'full', exercises: [{ exerciseId: 'ghost', sets: [{ reps: 5 }] }] })
    const good = JSON.stringify({ name: 'X', tag: 'full', exercises: [{ exerciseId: 'e1', sets: [{ reps: 8 }] }] })
    let calls = 0
    const client: CompletionClient = {
      complete: vi.fn(async () => {
        calls += 1
        return calls === 1 ? ghost : good
      }),
      completeWithTools: vi.fn(async () => ({ content: '', toolCalls: [] })),
    }
    const result = await new Pal(client).generateRoutine('full', [{ id: 'e1', name: 'Squat', group: 'Legs', equipment: null }])
    expect(calls).toBe(2)
    expect(result.exercises).toHaveLength(1)
    expect(result.exercises[0].exerciseId).toBe('e1')
  })

  it('generateRoutine throws when both drafts have no catalog exercises', async () => {
    const ghost = JSON.stringify({ name: 'X', tag: 'full', exercises: [{ exerciseId: 'ghost', sets: [{ reps: 5 }] }] })
    const client = fakeClient(ghost)
    await expect(new Pal(client).generateRoutine('full', [{ id: 'e1', name: 'Squat', group: 'Legs', equipment: null }]))
      .rejects.toThrow(/no exercises/)
  })

  it('generateRoutine does not retry when the catalog itself is empty', async () => {
    const client = fakeClient(JSON.stringify({ name: 'X', tag: 'full', exercises: [] }))
    const result = await new Pal(client).generateRoutine('x', [])
    expect(result.exercises).toEqual([])
    expect(client.complete).toHaveBeenCalledOnce()
  })

  it('generateRoutine coerces an off-list tag to custom (client RoutineTag.fromWire would throw)', async () => {
    const client = fakeClient(JSON.stringify({ name: 'X', tag: 'strength', exercises: [] }))
    const pal = new Pal(client)
    const result = await pal.generateRoutine('x', [])
    expect(result.tag).toBe('custom')
  })
})

function baseInsightsCtx() {
  return {
    range: 'week' as const, spent: 200, budget: 420, moveKcal: 1400, moveTargetKcal: 2100,
    ritualsKept: 18, ritualsTarget: 35, activeDays: 5, streakDays: 11,
    topCategory: 'Food', topCategoryPct: 34, spendByWeekday: [10, 20, 30, 40, 50, 25, 25], entries: [],
  }
}

const insightsCtxFixture = {
  range: 'week' as const, spent: 200, budget: 420, moveKcal: 1400, moveTargetKcal: 2100,
  ritualsKept: 18, ritualsTarget: 35, activeDays: 5, streakDays: 11,
  topCategory: 'Food', topCategoryPct: 34, spendByWeekday: [10, 20, 30, 40, 50, 25, 25], entries: ['08:00 Coffee'],
}

describe('refreshPatterns', () => {
  it('parses and caps patterns from the model', async () => {
    const many = Array.from({ length: 8 }, (_, i) => ({ colorToken: 'money', title: `t${i}`, detail: 'd' }))
    const client: CompletionClient = {
      complete: async () => JSON.stringify({ patterns: many }),
      completeWithTools: async () => ({ content: '', toolCalls: [] }),
    }
    const pal = new Pal(client)
    const out = await pal.refreshPatterns(insightsCtxFixture, { facts: [], patterns: [] })
    expect(out).toHaveLength(5) // MAX_PATTERNS
    expect(out[0]).toEqual({ colorToken: 'money', title: 't0', detail: 'd' })
  })

  it('coerces an off-list colorToken', async () => {
    const client: CompletionClient = {
      complete: async () => JSON.stringify({ patterns: [{ colorToken: 'bogus', title: 't', detail: 'd' }] }),
      completeWithTools: async () => ({ content: '', toolCalls: [] }),
    }
    const out = await new Pal(client).refreshPatterns(insightsCtxFixture, { facts: [], patterns: [] })
    expect(['money', 'move', 'rituals']).toContain(out[0].colorToken)
  })
})

describe('agenda no longer fabricates memory', () => {
  it('omits a memory field from the result', async () => {
    const client: CompletionClient = {
      complete: async () => JSON.stringify({ proposals: [], autopilot: [] }),
      completeWithTools: async () => ({ content: '', toolCalls: [] }),
    }
    const res = await new Pal(client).agenda(baseChatCtx(), { facts: [], patterns: [] })
    expect('memory' in res).toBe(false)
    expect(res.proposals).toEqual([])
  })
})

describe('chat memory ops', () => {
  it('extracts remember/forget as memoryOps, not client actions', async () => {
    const client = fakeToolClient({
      content: '',
      toolCalls: [
        toolCall('remember', { fact: 'training for a marathon' }),
        toolCall('forget', { id: 'f-9' }),
        toolCall('log_expense', { amount: 5, category: 'Coffee', title: 'coffee' }),
      ],
    })
    const res = await new Pal(client).chat([], 'hi', baseChatCtx())
    expect(res.memoryOps).toEqual([
      { op: 'remember', text: 'training for a marathon' },
      { op: 'forget', id: 'f-9' },
    ])
    // the expense is still a client action; memory tools are not.
    expect(res.actions).toHaveLength(1)
    expect(res.actions[0]).toMatchObject({ kind: 'log_expense' })
  })

  it('drops malformed memory tool calls', () => {
    const ops = toolCallsToMemoryOps([
      { name: 'remember', arguments: '{bad json' },
      { name: 'remember', arguments: JSON.stringify({ fact: '' }) }, // empty -> dropped
      { name: 'forget', arguments: JSON.stringify({}) },             // no id -> dropped
    ])
    expect(ops).toEqual([])
  })
})

function baseChatCtx() {
  return {
    userName: 'Kael', todayEntries: [], dailyBudget: 60, moveGoalKcal: 400, ritualGoal: 5,
    spentToday: 0, movedTodayKcal: 0, ritualsDoneToday: 0,
    weekSpent: 0, weekBudget: 420, weekMovedKcal: 0, weekRitualsDone: 0, weekRitualGoal: 35, moveStreakDays: 0,
    hourOfDay: 8, weekday: 6,
  }
}

describe('Pal.suggestions', () => {
  it('maps model output to chips and derives icons from kind', async () => {
    const raw = JSON.stringify({
      suggestions: [
        { kind: 'log_money', colorToken: 'money', label: 'Coffee, $5',
          entry: { type: 'money', title: 'Coffee', amount: -5, category: 'Food & Drink', minutes: null } },
        { kind: 'ask', colorToken: 'accent', label: "How's my week?" },
      ],
    })
    const pal = new Pal(fakeClient(raw))
    const ctx = { ...baseChatCtx(), todayEntries: ['8:10 AM Coffee (money, −$5)'] }
    const out = await pal.suggestions('composer', ctx as never)
    expect(out.suggestions).toHaveLength(2)
    expect(out.suggestions[0].icon).toBe('dollarsign.circle.fill') // derived from kind
    expect(out.suggestions[0].entry?.amount).toBe(-5)
    expect(out.suggestions[1].entry).toBeNull()
  })

  it('drops a log chip whose amount no entry today states', async () => {
    const raw = JSON.stringify({
      suggestions: [
        { kind: 'log_money', colorToken: 'money', label: 'Late snack $6.50',
          entry: { type: 'money', title: 'Late snack', amount: -6.5, category: 'Food & Drink', minutes: null } },
        { kind: 'log_money', colorToken: 'money', label: 'Another coffee, $5',
          entry: { type: 'money', title: 'Coffee', amount: -5, category: 'Food & Drink', minutes: null } },
        { kind: 'ask', colorToken: 'accent', label: 'How am I pacing?' },
      ],
    })
    const ctx = { ...baseChatCtx(), todayEntries: ['8:10 AM Coffee (money, −$5)', '12:30 PM Lunch (money, −$14.20)'] }
    const out = await new Pal(fakeClient(raw)).suggestions('composer', ctx as never)
    expect(out.suggestions.map((s) => s.label)).toEqual(['Another coffee, $5', 'How am I pacing?'])
  })

  it('coerces unknown kind/colorToken to safe defaults', async () => {
    const raw = JSON.stringify({ suggestions: [{ kind: 'bogus', colorToken: 'neon', label: 'X' }] })
    const pal = new Pal(fakeClient(raw))
    const out = await pal.suggestions('composer', baseChatCtx() as never)
    expect(out.suggestions[0].icon).toBe('sparkles') // generic
    expect(out.suggestions[0].colorToken).toBe('accent')
  })
})

describe('plainText', () => {
  it('drops bold, italic, code and heading marks', () => {
    expect(plainText('Tonight: **where did the money go?**')).toBe('Tonight: where did the money go?')
    expect(plainText('__Held__ and *noted* and _kept_')).toBe('Held and noted and kept')
    expect(plainText('Run `close_out` now')).toBe('Run close_out now')
    expect(plainText('## Tonight\nOne prompt.')).toBe('Tonight\nOne prompt.')
  })

  it('leaves plain asterisks and underscores in words alone', () => {
    expect(plainText('3 * 4 sets, snake_case_name')).toBe('3 * 4 sets, snake_case_name')
    expect(plainText('$96.15 spent, over by $11.15.')).toBe('$96.15 spent, over by $11.15.')
  })
})

describe('moneyAmounts', () => {
  it('reads amounts written with the currency symbol', () => {
    expect(moneyAmounts('Hold $40 of the $1,250.50')).toEqual([40, 1250.5])
    expect(moneyAmounts('Cover 4 days')).toEqual([])
  })

  it('reads amounts in a trailing-symbol currency', () => {
    const vnd = { symbol: '₫', symbolBefore: false, decimals: 0, group: '.', decimal: ',' }
    expect(moneyAmounts('Giữ 150.000 ₫', vnd)).toEqual([150000])
  })
})

describe('labelsAgree', () => {
  const proposal = { title: 'Cover the $0.15 overage', body: 'You are 0.15 over today.', approveLabel: 'Hold $0.15', doneLabel: 'Held $0.15' }

  it('accepts labels whose amounts the title or body state', () => {
    expect(labelsAgree(proposal)).toBe(true)
    expect(labelsAgree({ ...proposal, approveLabel: 'Hold it', doneLabel: 'Held' })).toBe(true)
  })

  it('rejects a button amount the proposal never states', () => {
    expect(labelsAgree({ ...proposal, approveLabel: 'Hold $40' })).toBe(false)
    expect(labelsAgree({ ...proposal, doneLabel: 'Held $40' })).toBe(false)
  })

  it('rejects a rounded amount: the button says what will happen', () => {
    expect(labelsAgree({ title: 'Pause $11.15 of spend', body: 'Over by $11.15.', approveLabel: 'Hold $11', doneLabel: 'Held $11' })).toBe(false)
  })
})

describe('Pal.agenda amount agreement', () => {
  const ctx = {
    userName: 'Kael', todayEntries: [], dailyBudget: 85, moveGoalKcal: 500, ritualGoal: 3,
    spentToday: 85.15, movedTodayKcal: 0, ritualsDoneToday: 0,
    weekSpent: 85.15, weekBudget: 595, weekMovedKcal: 0, weekRitualsDone: 0, weekRitualGoal: 21,
    moveStreakDays: 0, hourOfDay: 20, weekday: 4,
  }
  const proposal = (approveLabel: string, title = 'Cover the $0.15 overage') => ({
    kind: 'hold_funds', colorToken: 'money', tag: 'Money', title, body: 'Today is over by $0.15.', approveLabel, doneLabel: 'Held',
  })
  const draws = (...replies: unknown[]): CompletionClient => {
    const queue = replies.map((r) => JSON.stringify(r))
    return { complete: vi.fn(async () => queue.shift() ?? ''), completeWithTools: vi.fn() }
  }

  it('keeps a draw whose labels agree without a second call', async () => {
    const client = draws({ proposals: [proposal('Hold $0.15')], autopilot: [] })
    const res = await new Pal(client).agenda(ctx)
    expect(res.proposals.map((p) => p.approveLabel)).toEqual(['Hold $0.15'])
    expect(client.complete).toHaveBeenCalledTimes(1)
  })

  it('redraws once when a label names an amount its proposal does not state', async () => {
    const client = draws(
      { proposals: [proposal('Hold $40')], autopilot: [] },
      { proposals: [proposal('Hold $0.15')], autopilot: [] },
    )
    const res = await new Pal(client).agenda(ctx)
    expect(client.complete).toHaveBeenCalledTimes(2)
    expect(res.proposals.map((p) => p.approveLabel)).toEqual(['Hold $0.15'])
  })

  it('drops a proposal still off after the redraw and keeps the rest', async () => {
    const off = { proposals: [proposal('Hold $40'), proposal('Close out', 'Close out tonight')], autopilot: [] }
    const client = draws(off, off)
    const res = await new Pal(client).agenda(ctx)
    expect(client.complete).toHaveBeenCalledTimes(2)
    expect(res.proposals.map((p) => p.title)).toEqual(['Close out tonight'])
    expect(res.proposals[0].id).toBe('hold_funds-0')
  })
})

describe('Pal surfaces return plain text', () => {
  it('chat strips markdown from the reply', async () => {
    const pal = new Pal(fakeClient('Tonight: **what did today cost you?**'))
    const res = await pal.chat([], 'reflection prompt', {
      userName: 'Kael', todayEntries: [], dailyBudget: 85, moveGoalKcal: 500, ritualGoal: 3,
      spentToday: 0, movedTodayKcal: 0, ritualsDoneToday: 0, weekSpent: 0, weekBudget: 595, weekMovedKcal: 0,
      weekRitualsDone: 0, weekRitualGoal: 21, moveStreakDays: 0, hourOfDay: 20, weekday: 4,
    })
    expect(res.reply).toBe('Tonight: what did today cost you?')
  })

  it('review and the post-workout note strip markdown', async () => {
    const pal = new Pal(fakeClient('A *quieter* week, **11 days** on the streak.'))
    const review = await pal.review({ range: 'week', spent: 0, spentDeltaPct: null, kcalMoved: 0, movedDeltaPct: null, activeDays: 0, ritualsKept: 0, ritualsTarget: 0, ritualsPct: 0, streakDays: 11, topCategory: 'Food', topCategoryPct: 0 })
    const note = await pal.postWorkoutNote({ routineName: 'Legs', setCount: 3, volumeKg: 900, prCount: 0, prExercises: [], lastSessionVolumeKg: null, daysAgoLastSession: null })
    expect(review).toBe('A quieter week, 11 days on the streak.')
    expect(note).toBe('A quieter week, 11 days on the streak.')
  })

  it('insights fields strip markdown', () => {
    const parsed = insightsSchema.parse({
      headline: '**Over by $11.15** today', lede: null, suggestion: '*Skip* the Lyft', correlationNarration: null,
      wins: [{ colorToken: 'move', title: '**Streak**', sub: '11 days' }], patterns: [],
    })
    expect(parsed.headline).toBe('Over by $11.15 today')
    expect(parsed.suggestion).toBe('Skip the Lyft')
    expect(parsed.wins[0].title).toBe('Streak')
  })
})

describe('lineAgrees', () => {
  const fact: PlanFact = { key: 'k', title: 'Close out', when: '9:30 PM', status: 'upcoming', steps: '2 of 4 steps', why: 'Ends the day.' }

  it('keeps a line whose numbers its facts hold, in digits or words', () => {
    expect(lineAgrees('Two steps left before bed.', fact)).toBe(true)
    expect(lineAgrees('You are 2 of 4 steps in.', fact)).toBe(true)
    expect(lineAgrees('Wind down at 9:30 tonight.', fact)).toBe(true)
    expect(lineAgrees('Close the day calmly.', fact)).toBe(true)
  })

  it('drops a line stating a number its facts do not hold', () => {
    expect(lineAgrees('Three steps left before bed.', fact)).toBe(false)
    expect(lineAgrees('Only 3 steps to go.', fact)).toBe(false)
    expect(lineAgrees('Wind down at 10:30 tonight.', fact)).toBe(false)
    expect(lineAgrees('Twenty minutes is enough.', fact)).toBe(false)
  })

  it('reads number words only as whole words', () => {
    expect(lineAgrees('Someone often needs this.', fact)).toBe(true)
    expect(lineAgrees('No one else will.', { ...fact, steps: null })).toBe(false)
  })

  it('reads number words in the facts too', () => {
    expect(lineAgrees('3 steps and you are done.', { ...fact, steps: 'Three steps' })).toBe(true)
  })
})

describe('Pal.leadLines', () => {
  const plan: PlanFact[] = [
    { key: 'close|upcoming|2 of 4 steps', title: 'Close out', when: '9:30 PM', status: 'upcoming', steps: '2 of 4 steps', why: 'Ends the day.' },
    { key: 'legs|due|', title: 'Legs', when: '6:00 PM', status: 'due', steps: null, why: 'Planned for today.' },
  ]
  const lines = (...entries: Array<{ key: string; line: string }>) => fakeClient(JSON.stringify({ lines: entries }))

  it('returns the lines keyed by request key', async () => {
    const res = await new Pal(lines(
      { key: 'close|upcoming|2 of 4 steps', line: 'Two steps left to close the day.' },
      { key: 'legs|due|', line: 'Legs are on the plan now.' },
    )).leadLines(plan)
    expect(res).toEqual([
      { key: 'close|upcoming|2 of 4 steps', line: 'Two steps left to close the day.' },
      { key: 'legs|due|', line: 'Legs are on the plan now.' },
    ])
  })

  it('drops unknown keys and repeats', async () => {
    const res = await new Pal(lines(
      { key: 'legs|due|', line: 'Legs are on the plan now.' },
      { key: 'made-up', line: 'Something else.' },
      { key: 'legs|due|', line: 'A second take on legs.' },
    )).leadLines(plan)
    expect(res).toEqual([{ key: 'legs|due|', line: 'Legs are on the plan now.' }])
  })

  it('strips markup from a line', async () => {
    const res = await new Pal(lines({ key: 'legs|due|', line: '**Legs** are on the plan now.' })).leadLines(plan)
    expect(res).toEqual([{ key: 'legs|due|', line: 'Legs are on the plan now.' }])
  })

  it('drops a line stating a number its facts do not hold', async () => {
    const res = await new Pal(lines(
      { key: 'close|upcoming|2 of 4 steps', line: 'Three steps left to close the day.' },
      { key: 'legs|due|', line: 'Legs at 6:00 keeps the week on plan.' },
    )).leadLines(plan)
    expect(res).toEqual([{ key: 'legs|due|', line: 'Legs at 6:00 keeps the week on plan.' }])
  })

  it('makes no model call for an empty plan', async () => {
    const client = fakeClient('{}')
    expect(await new Pal(client).leadLines([])).toEqual([])
    expect(client.complete).not.toHaveBeenCalled()
  })

  it('asks at temperature 0 for JSON', async () => {
    const client = lines()
    await new Pal(client).leadLines(plan)
    expect(client.complete).toHaveBeenCalledWith(
      [{ role: 'user', content: leadLinesPrompt(plan) }],
      expect.objectContaining({ json: true, temperature: 0 }),
    )
  })
})
