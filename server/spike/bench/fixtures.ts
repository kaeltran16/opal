import type { Canned } from '../src/stub.js'

export const CATALOG_N = 36 // full built-in catalog, lib/data/seed/seed_data.dart

const long = (n: number) => 'x'.repeat(n)

// --- Worst-case canned completions (drive the deterministic validation path) ---

// chat uses completeWithTools; return the max tool calls chat parses (actions +
// memory ops), each with realistic args, plus a long reply.
const chatToolCalls = [
  ...Array.from({ length: 8 }, (_, i) => ({ name: 'log_expense', arguments: JSON.stringify({ amount: 12000 + i, category: 'Food & Drink', title: 'coffee', note: long(40) }) })),
  { name: 'set_daily_budget', arguments: JSON.stringify({ dailyBudget: 100000 }) },
  { name: 'create_routine', arguments: JSON.stringify({ goal: long(60), name: 'push' }) },
  ...Array.from({ length: 5 }, (_, i) => ({ name: 'remember', arguments: JSON.stringify({ fact: `fact ${i} ${long(60)}` }) })),
]

// routine: all CATALOG_N exercises, each with 5 sets — maxes the 4096-token budget.
const CATALOG_N_LOCAL = 36
const routineJson = JSON.stringify({
  name: 'Full Program', tag: 'full', estMin: 60, rationale: long(200),
  exercises: Array.from({ length: CATALOG_N_LOCAL }, (_, i) => ({
    exerciseId: `ex-${i}`,
    sets: Array.from({ length: 5 }, () => ({ reps: 10, weight: 60, duration: null })),
  })),
})

// insights: max wins + patterns + long prose.
const insightsJson = JSON.stringify({
  headline: long(80), lede: long(200), suggestion: long(160), correlationNarration: long(200),
  wins: Array.from({ length: 6 }, (_, i) => ({ colorToken: 'money', title: `win ${i}`, sub: long(60) })),
  patterns: Array.from({ length: 6 }, (_, i) => ({ colorToken: 'move', title: `pat ${i}`, detail: long(80) })),
})

// receipts: BATCH_SIZE results, all receipts.
const receiptsJson = JSON.stringify({
  results: Array.from({ length: 8 }, (_, i) => ({ index: i, isReceipt: true, merchant: long(30), amount: 12345 + i, category: 'Shopping' })),
})

export const STUB: { chat: Canned; insights: Canned; routine: Canned; receipts: Canned } = {
  chat: { tool: { content: long(300), toolCalls: chatToolCalls } },
  insights: { text: insightsJson },
  routine: { text: routineJson },
  receipts: { text: receiptsJson },
}

// --- Worst-case request payloads (what the driver POSTs) ---

const fullContext = {
  userName: 'Kael', todayEntries: Array.from({ length: 30 }, (_, i) => `entry ${i} ${long(40)}`),
  dailyBudget: 100000, moveGoalKcal: 600, ritualGoal: 4, spentToday: 42000, movedTodayKcal: 320,
  ritualsDoneToday: 2, weekSpent: 300000, weekBudget: 700000, weekMovedKcal: 2200, weekRitualsDone: 12,
  weekRitualGoal: 28, moveStreakDays: 9, hourOfDay: 14, weekday: 3,
}

export function chatPayload() {
  return {
    history: Array.from({ length: 20 }, (_, i) => ({ role: i % 2 === 0 ? 'user' : 'assistant', text: long(200) })),
    message: long(300), context: fullContext,
  }
}

export function insightsPayload() {
  return {
    context: {
      range: 'month', spent: 300000, budget: 700000, moveKcal: 2200, moveTargetKcal: 3000,
      ritualsKept: 12, ritualsTarget: 28, activeDays: 18, streakDays: 9,
      topCategory: 'Food & Drink', topCategoryPct: 34,
      spendByWeekday: [10, 20, 30, 40, 50, 60, 70], entries: Array.from({ length: 60 }, (_, i) => `entry ${i} ${long(50)}`),
      correlation: { summary: long(200) },
    },
  }
}

export function routinePayload() {
  return {
    goal: 'balanced full-body program', // backend selects from the catalog
    exercises: Array.from({ length: CATALOG_N }, (_, i) => ({
      id: `ex-${i}`, name: `Exercise ${i} ${long(20)}`, group: ['Push', 'Pull', 'Legs', 'Core', 'Cardio'][i % 5], equipment: 'Barbell',
    })),
  }
}

export function emailExtractPayload() {
  return { candidates: Array.from({ length: 8 }, (_, i) => ({ from: `merchant${i}@shop.example`, subject: long(120), text: long(8000) })) }
}
