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
  // null marks a weekday the period has not reached yet
  spendByWeekday: z.array(z.number().nullable()), daysElapsed: z.number().int().min(0).optional(),
  entries: z.array(z.string()),
  correlation: z.object({ summary: z.string() }).optional(),
  currency: currencyDescriptor.optional(),
})
export const insightsBody = z.object({ context: insightsContext })

// the client posts the insights-shaped aggregates it already assembles; the
// server pairs them with stored memory to re-derive patterns.
export const memoryRefreshBody = z.object({ context: insightsContext })

export const suggestContext = z.object({
  // groups: the exercises' groups (Push, Pull, Legs, Core), beside their primary muscles.
  recentWorkouts: z.array(z.object({ routineName: z.string(), date: z.string(), muscles: z.string(), groups: z.string().optional() })),
  dayOfWeek: z.string(),
  availableRoutines: z.array(z.object({ id: z.string(), name: z.string() })),
  // the weekly plan's routine for today, 'Rest' on a rest day.
  plannedToday: z.string().nullable().optional(),
})
export const suggestBody = z.object({ another: z.boolean(), context: suggestContext })

export const postWorkoutContext = z.object({
  routineName: z.string(), setCount: z.number(), volumeKg: z.number(), prCount: z.number(),
  prExercises: z.array(z.string()), lastSessionVolumeKg: z.number().nullable(), daysAgoLastSession: z.number().nullable(),
  // timed sets: a session of only cardio or holds has no weight to talk about.
  minutes: z.number().nullable().optional(), km: z.number().nullable().optional(),
})
export const postWorkoutBody = z.object({ context: postWorkoutContext })

// one open item of the day, worded on the device; Pal's line for it is written
// from these facts alone. `key` is opaque to the server and only echoed back.
const planText = z.string().max(300)
export const planFact = z.object({
  key: z.string().min(1).max(200),
  title: planText,
  when: planText,
  status: z.enum(['due', 'upcoming', 'missed', 'anytime']),
  steps: planText.nullable(),
  why: planText,
})

// The Pal Home agenda reuses the chat context (today + week + goals + streak).
// what an approval may act on: the ids the model must pick from. the week's
// status is optional: an older client sends none and the prompt states none.
export const agendaTargets = z.object({
  rituals: z.array(z.object({
    id: z.string(), name: z.string(), steps: z.array(z.string()), daysDone: z.number().int().min(0).max(7).optional(),
  })).default([]),
  workouts: z.array(z.object({ id: z.string(), name: z.string() })).default([]),
  week: z.array(z.object({
    weekday: z.number(), routineId: z.string().nullable(), done: z.boolean().optional(), trained: z.boolean().optional(),
  })).default([]),
})
// an older client sends no plan and gets no lines.
export const agendaBody = z.object({
  context: chatContext,
  targets: agendaTargets.default({ rituals: [], workouts: [], week: [] }),
  plan: z.array(planFact).max(20).default([]),
})

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
    // the primary muscle; older clients send none.
    muscle: z.string().nullable().optional(),
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
// strict throughout: a key the widget does not know (a fraction on money) is
// a producer bug, rejected here rather than dropped.
const stateChange = z.object({
  at: z.number().int(),
  state: z.enum(['thriving', 'good', 'watch', 'care']),
  word: z.string().min(1).max(32),
}).strict()
// one entry per minute from midnight to midnight is the most a schedule can hold.
const widgetStates = z.array(stateChange).min(1).max(1441)
  .refine((states) => states.every((s, i) => i === 0 || states[i - 1].at < s.at), {
    message: 'states must be in strictly increasing at order',
  })
const widgetValue = z.string().min(1).max(64)
const ringRow = z.object({
  fraction: z.number().finite().min(0).max(1),
  value: widgetValue,
  states: widgetStates,
}).strict()
const moneyRow = z.object({ value: widgetValue, states: widgetStates }).strict()

export const widgetSnapshotBody = z.object({
  until: z.number().int(),
  move: ringRow,
  routines: ringRow,
  money: moneyRow,
}).strict().superRefine((snap, ctx) => {
  for (const row of ['move', 'routines', 'money'] as const) {
    if (snap[row].states.some((s) => s.at >= snap.until)) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: [row, 'states'],
        message: 'every state must begin before until',
      })
    }
  }
})
