import { z } from 'zod'

export const registerBody = z.object({
  provisioningKey: z.string().min(1),
  deviceId: z.string().min(1),
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
})
export const insightsBody = z.object({ context: insightsContext })

// the client posts the insights-shaped aggregates it already assembles; the
// server pairs them with stored memory to re-derive patterns.
export const memoryRefreshBody = z.object({ context: insightsContext })

export const suggestContext = z.object({
  recentWorkouts: z.array(z.object({ routineName: z.string(), date: z.string(), muscles: z.string() })),
  dayOfWeek: z.string(),
  availableRoutines: z.array(z.object({ id: z.string(), name: z.string() })),
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
  surface: z.enum(['composer', 'newEntry', 'routineGoal']),
  // composer/newEntry send chat context; routineGoal sends suggest context.
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

const imapCreds = {
  host: z.string().min(1),
  port: z.number().int().positive(),
  address: z.string().min(1),
  appPassword: z.string().min(1),
}
export const emailTestBody = z.object(imapCreds)
export const emailSyncBody = z.object({
  ...imapCreds,
  senderFilters: z.array(z.string()).default([]),
  // epoch ms of the client's last sync; null = first sync (default window applied server-side)
  since: z.number().nullable().default(null),
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

// Pre-computed rings progress the app pushes for the iOS widget to read back.
export const widgetSnapshotBody = z.object({
  moneyRing: z.number().finite(),
  moveRing: z.number().finite(),
  ritualsRing: z.number().finite(),
  moneySpent: z.number().finite(),
  dailyBudget: z.number().finite(),
  moveKcal: z.number().int(),
  dailyMoveKcal: z.number().int(),
  ritualsDone: z.number().int(),
  dailyRitualTarget: z.number().int(),
})
