import { z } from 'zod'

export const currencyDescriptor = z.object({
  symbol: z.string(),
  symbolBefore: z.boolean(),
  decimals: z.number().int(),
  group: z.string(),
  decimal: z.string(),
})

export const nutritionEstimateBody = z.object({ text: z.string() })

export const registerBody = z.object({
  provisioningKey: z.string().min(1).max(500),
  deviceId: z.string().min(1).max(200),
})

export const chatContext = z.object({
  userName: z.string(),
  todayEntries: z.array(z.string()),
  dailyBudget: z.number(),
  moveGoalKcal: z.number(),
  ritualGoal: z.number(),
  spentToday: z.number(),
  movedTodayKcal: z.number(),
  ritualsDoneToday: z.number(),
  weekSpent: z.number(),
  weekBudget: z.number(),
  weekMovedKcal: z.number(),
  weekRitualsDone: z.number(),
  weekRitualGoal: z.number(),
  moveStreakDays: z.number(),
  hourOfDay: z.number(),
  weekday: z.number(),
  currency: currencyDescriptor.optional(),
})

export const chatBody = z.object({
  history: z.array(z.object({ role: z.enum(['user', 'assistant']), text: z.string() })),
  message: z.string(),
  context: chatContext,
})

export const parseBody = z.object({ text: z.string() })

export const reviewContext = z.object({
  range: z.enum(['week', 'month']),
  spent: z.number(), spentDeltaPct: z.number().nullable(), kcalMoved: z.number(), movedDeltaPct: z.number().nullable(),
  activeDays: z.number(), ritualsKept: z.number(), ritualsTarget: z.number(), ritualsPct: z.number(),
  streakDays: z.number(), topCategory: z.string(), topCategoryPct: z.number(),
  currency: currencyDescriptor.optional(),
})
export const reviewBody = z.object({ context: reviewContext })

export const insightsContext = z.object({
  range: z.enum(['day', 'month', 'week']),
  spent: z.number(), budget: z.number(),
  moveKcal: z.number(), moveTargetKcal: z.number(),
  ritualsKept: z.number(), ritualsTarget: z.number(),
  activeDays: z.number(), streakDays: z.number(),
  topCategory: z.string(), topCategoryPct: z.number(),
  spendByWeekday: z.array(z.number()), entries: z.array(z.string()),
  correlation: z.object({ summary: z.string() }).optional(),
  currency: currencyDescriptor.optional(),
})
export const insightsBody = z.object({ context: insightsContext })

// the client posts the insights-shaped aggregates it already assembles; the
// server pairs them with stored memory to re-derive patterns.
export const memoryRefreshBody = z.object({ context: insightsContext })

export const suggestContext = z.object({
  recentWorkouts: z.array(z.object({ routineName: z.string(), date: z.string(), muscles: z.string() })),
  dayOfWeek: z.string(),
  availableRoutines: z.array(z.object({ id: z.string(), name: z.string() })),
  // the weekly plan's routine for today, 'Rest' on a rest day.
  plannedToday: z.string().nullable().optional(),
})
export const suggestBody = z.object({ another: z.boolean(), context: suggestContext })

export const postWorkoutContext = z.object({
  routineName: z.string(), setCount: z.number(), volumeKg: z.number(), prCount: z.number(),
  prExercises: z.array(z.string()), lastSessionVolumeKg: z.number().nullable(), daysAgoLastSession: z.number().nullable(),
})
export const postWorkoutBody = z.object({ context: postWorkoutContext })

// The Pal Home agenda reuses the chat context (today + week + goals + streak).
export const agendaBody = z.object({ context: chatContext })

export const suggestionsBody = z.object({
  surface: z.enum(['composer', 'routineGoal']),
  // composer sends chat context; routineGoal sends suggest context.
  context: z.union([chatContext, suggestContext]),
})

export const routineBody = z.object({
  goal: z.string().min(1),
  exercises: z.array(z.object({
    id: z.string(),
    name: z.string(),
    group: z.string(),
    equipment: z.string().nullable(),
  })),
})

const healthMetric = z.enum([
  'steps', 'activeEnergy', 'exerciseMinutes', 'avgHeartRate', 'restingHeartRate', 'sleepMinutes',
])
export const healthIngestBody = z.object({
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),        // local day from the shortcut
  // capturedAt is intentionally NOT accepted: the server stamps its own receive
  // time, and nothing downstream reads it. keeps the iOS Shortcut from having to
  // emit a strict ISO-8601 timestamp.
  metrics: z
    .record(healthMetric, z.object({ value: z.number().finite(), unit: z.string().min(1) }))
    .refine((m) => Object.keys(m).length > 0, 'at least one metric required'),
})

export const healthDayQuery = z.object({
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
})

// display-ready rows the app pushes for the iOS widget to read back; the widget
// never computes a state, it walks the schedule of changes until local midnight.
const stateChange = z.object({
  at: z.number().int(),
  state: z.enum(['thriving', 'good', 'watch', 'care']),
  word: z.string().min(1).max(32),
})
// one entry per minute from midnight to midnight is the most a schedule can hold.
const widgetStates = z.array(stateChange).min(1).max(1441)
const widgetValue = z.string().min(1).max(64)
const ringRow = z.object({
  fraction: z.number().finite().min(0).max(1),
  value: widgetValue,
  states: widgetStates,
})
const moneyRow = z.object({ value: widgetValue, states: widgetStates })

export const widgetSnapshotBody = z.object({
  until: z.number().int(),
  move: ringRow,
  routines: ringRow,
  money: moneyRow,
})
