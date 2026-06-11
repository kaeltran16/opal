import { describe, it, expect, vi } from 'vitest'
import { Pal, extractJson, type CompletionClient } from './pal.js'

function fakeClient(reply: string) {
  return { complete: vi.fn(async () => reply) } satisfies CompletionClient
}

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

describe('Pal', () => {
  it('chat returns the model text', async () => {
    const client = fakeClient('Nice — logged it.')
    const pal = new Pal(client)
    const reply = await pal.chat([], 'hi', baseChatCtx())
    expect(reply).toBe('Nice — logged it.')
    expect(client.complete).toHaveBeenCalledOnce()
  })

  it('parse returns the structured object', async () => {
    const parsed = { type: 'money', amount: 5, duration: null, category: 'Coffee', title: 'Coffee', note: null }
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

  it('generateRoutine coerces an off-list tag to custom (client RoutineTag.fromWire would throw)', async () => {
    const client = fakeClient(JSON.stringify({ name: 'X', tag: 'strength', exercises: [] }))
    const pal = new Pal(client)
    const result = await pal.generateRoutine('x', [])
    expect(result.tag).toBe('custom')
  })
})

function baseInsightsCtx() {
  return {
    range: 'week' as const, spent: 200, budget: 420, moveMinutes: 140, moveTarget: 210,
    ritualsKept: 18, ritualsTarget: 35, activeDays: 5, streakDays: 11,
    topCategory: 'Food', topCategoryPct: 34, spendByWeekday: [10, 20, 30, 40, 50, 25, 25], entries: [],
  }
}

function baseChatCtx() {
  return {
    userName: 'Kael', todayEntries: [], dailyBudget: 60, moveGoalMin: 30, ritualGoal: 5,
    spentToday: 0, movedTodayMin: 0, ritualsDoneToday: 0,
    weekSpent: 0, weekBudget: 420, weekMovedMin: 0, weekRitualsDone: 0, weekRitualGoal: 35, moveStreakDays: 0,
  }
}
