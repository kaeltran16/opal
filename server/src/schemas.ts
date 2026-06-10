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
  spent: z.number(), spentDeltaPct: z.number(), hoursMoved: z.number(), movedDeltaPct: z.number(),
  activeDays: z.number(), ritualsKept: z.number(), ritualsTarget: z.number(), ritualsPct: z.number(),
  streakDays: z.number(), topCategory: z.string(), topCategoryPct: z.number(), discoveredPattern: z.string(),
})
export const reviewBody = z.object({ context: reviewContext })

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
