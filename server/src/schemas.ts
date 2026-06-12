import { z } from 'zod'

export const registerBody = z.object({
  provisioningKey: z.string().min(1),
  deviceId: z.string().min(1),
})

export const chatContext = z.object({
  userName: z.string(),
  todayEntries: z.array(z.string()),
  dailyBudget: z.number(),
  moveGoalMin: z.number(),
  ritualGoal: z.number(),
  spentToday: z.number(),
  movedTodayMin: z.number(),
  ritualsDoneToday: z.number(),
  weekSpent: z.number(),
  weekBudget: z.number(),
  weekMovedMin: z.number(),
  weekRitualsDone: z.number(),
  weekRitualGoal: z.number(),
  moveStreakDays: z.number(),
})

export const chatBody = z.object({
  history: z.array(z.object({ role: z.enum(['user', 'assistant']), text: z.string() })),
  message: z.string(),
  context: chatContext,
})

export const parseBody = z.object({ text: z.string() })

export const reviewContext = z.object({
  range: z.enum(['week', 'month']),
  spent: z.number(), spentDeltaPct: z.number().nullable(), hoursMoved: z.number(), movedDeltaPct: z.number().nullable(),
  activeDays: z.number(), ritualsKept: z.number(), ritualsTarget: z.number(), ritualsPct: z.number(),
  streakDays: z.number(), topCategory: z.string(), topCategoryPct: z.number(),
})
export const reviewBody = z.object({ context: reviewContext })

export const insightsContext = z.object({
  range: z.enum(['day', 'month', 'week']),
  spent: z.number(), budget: z.number(),
  moveMinutes: z.number(), moveTarget: z.number(),
  ritualsKept: z.number(), ritualsTarget: z.number(),
  activeDays: z.number(), streakDays: z.number(),
  topCategory: z.string(), topCategoryPct: z.number(),
  spendByWeekday: z.array(z.number()), entries: z.array(z.string()),
})
export const insightsBody = z.object({ context: insightsContext })

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
