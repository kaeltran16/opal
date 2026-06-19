import { describe, it, expect, vi } from 'vitest'
import {
  Pal, OpenRouterClient, OpenRouterError, extractJson, toolCallsToActions, parseSchema, synthReply,
  type CompletionClient, type CompletionResult, type ToolCall, type ChatMessage,
} from './pal.js'

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
    moveStreakDays: 11,
  }

  it('derives icons/approveIcon/action from kind and echoes the streak', async () => {
    const model = JSON.stringify({
      proposals: [{
        kind: 'close_out', colorToken: 'rituals', tag: 'Rituals', title: 'Close out tonight',
        body: 'A 5-min wind-down closes your ring.', approveLabel: 'Start close-out', doneLabel: 'Close-out queued',
      }],
      autopilot: [{ kind: 'bills_watch', colorToken: 'money', title: 'Rent watch', subtitle: 'Alerts if low', enabled: true }],
      memory: [{ text: 'Fridays cost the most', meta: 'Ongoing pattern' }],
    })
    const res = await new Pal(fakeClient(model)).agenda(ctx)

    expect(res.proposals[0]).toMatchObject({
      icon: 'moon.stars.fill', approveIcon: 'play.fill', action: 'close_out', colorToken: 'rituals',
    })
    expect(res.proposals[0].id).toBe('close_out-0')
    expect(res.autopilot[0].icon).toBe('house.fill')
    expect(res.memory[0].text).toBe('Fridays cost the most')
    expect(res.streakDays).toBe(11)
  })

  it('coerces an unknown proposal kind to the generic (non-navigating) presentation', async () => {
    const model = JSON.stringify({
      proposals: [{
        kind: 'teleport', colorToken: 'move', tag: 'Workout', title: 'x', body: 'y',
        approveLabel: 'Do it', doneLabel: 'Done',
      }],
      autopilot: [], memory: [],
    })
    const res = await new Pal(fakeClient(model)).agenda(ctx)
    expect(res.proposals[0]).toMatchObject({ icon: 'sparkles', approveIcon: 'checkmark', action: null })
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
    const actions = toolCallsToActions([toolCall('log_expense', { amount: -5, category: 'Coffee' })])
    expect(actions).toEqual([
      { kind: 'log_expense', amount: 5, category: 'Coffee', title: 'Coffee', note: null },
    ])
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

describe('Pal', () => {
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
      toolCalls: [toolCall('log_expense', { amount: 5, category: 'Coffee', title: 'coffee' })],
    })
    const pal = new Pal(client)
    const result = await pal.chat([], 'add $5 for coffee', baseChatCtx())
    expect(result.actions).toEqual([
      { kind: 'log_expense', amount: 5, category: 'Coffee', title: 'coffee', note: null },
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
    const parsed = { type: 'money', amount: 5, duration: null, category: 'Coffee', title: 'Coffee', note: null, direction: 'expense' }
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

function baseChatCtx() {
  return {
    userName: 'Kael', todayEntries: [], dailyBudget: 60, moveGoalKcal: 400, ritualGoal: 5,
    spentToday: 0, movedTodayKcal: 0, ritualsDoneToday: 0,
    weekSpent: 0, weekBudget: 420, weekMovedKcal: 0, weekRitualsDone: 0, weekRitualGoal: 35, moveStreakDays: 0,
  }
}
