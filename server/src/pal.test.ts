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

  it('suggestWorkout returns routineId + reason', async () => {
    const parsed = { routineId: 'r2', reason: 'Legs are rested.' }
    const client = fakeClient(JSON.stringify(parsed))
    const pal = new Pal(client)
    const result = await pal.suggestWorkout(false, {
      recentWorkouts: [], dayOfWeek: 'Wed', availableRoutines: [{ id: 'r2', name: 'Legs' }],
    })
    expect(result).toEqual(parsed)
  })
})

function baseChatCtx() {
  return {
    userName: 'Kael', todayEntries: [], dailyBudget: 60, moveGoalMin: 30, ritualGoal: 5,
    spentToday: 0, movedTodayMin: 0, ritualsDoneToday: 0,
    weekSpent: 0, weekBudget: 420, weekMovedMin: 0, weekRitualsDone: 0, weekRitualGoal: 35, moveStreakDays: 0,
  }
}
