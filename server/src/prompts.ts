export interface ChatContext {
  userName: string
  todayEntries: string[]
  dailyBudget: number
  moveGoalMin: number
  ritualGoal: number
  spentToday: number
  movedTodayMin: number
  ritualsDoneToday: number
  weekSpent: number
  weekBudget: number
  weekMovedMin: number
  weekRitualsDone: number
  weekRitualGoal: number
  moveStreakDays: number
}

export interface ReviewContext {
  spent: number
  spentDeltaPct: number
  hoursMoved: number
  movedDeltaPct: number
  activeDays: number
  ritualsKept: number
  ritualsTarget: number
  ritualsPct: number
  streakDays: number
  topCategory: string
  topCategoryPct: number
  discoveredPattern: string
}

export interface SuggestContext {
  recentWorkouts: Array<{ routineName: string; date: string; muscles: string }>
  dayOfWeek: string
  availableRoutines: Array<{ id: string; name: string }>
}

export interface PostWorkoutContext {
  routineName: string
  setCount: number
  volumeKg: number
  prCount: number
  prExercises: string[]
  lastSessionVolumeKg: number | null
  daysAgoLastSession: number | null
}

export function chatSystemPrompt(c: ChatContext): string {
  const entries = c.todayEntries.length ? c.todayEntries.join('\n') : '(none yet)'
  return `You are Pal, a gentle, concise coach in an iOS app that tracks money, movement and daily rituals.

Today's entries for ${c.userName}:
${entries}

Daily budget $${c.dailyBudget}, move goal ${c.moveGoalMin}min, ritual goal ${c.ritualGoal}.
Spent $${c.spentToday} so far, moved ${c.movedTodayMin}min, ${c.ritualsDoneToday}/${c.ritualGoal} rituals done.

Week: $${c.weekSpent} of $${c.weekBudget} spent, ${c.weekMovedMin}min moved, ${c.weekRitualsDone}/${c.weekRitualGoal} rituals. ${c.moveStreakDays}-day move streak.

Reply in 1-3 short sentences. Friendly, specific, no filler. Never say "amazing" or "great job" — be observational and warm instead.`
}

export function reviewPrompt(c: ReviewContext): string {
  return `Write a 2-3 sentence warm, specific, editorial reflection on this month's tracking data. Avoid hype words like "amazing" or "crushed it". Be specific and observational.

Data: $${c.spent} spent (down ${c.spentDeltaPct}% vs last month), ${c.hoursMoved}h moved (up ${c.movedDeltaPct}%), ${c.activeDays} active days, ${c.ritualsKept}/${c.ritualsTarget} rituals kept (${c.ritualsPct}%). Current ${c.streakDays}-day move streak. Top category: ${c.topCategory} ${c.topCategoryPct}%. Pattern: ${c.discoveredPattern}.`
}

export function parsePrompt(input: string): string {
  return `Parse this free-form log into JSON. User said: "${input}"
Return strictly: {"type": "money|move|rituals", "amount": number|null, "duration": number|null, "category": string|null, "title": string, "note": string|null}
No prose. Output only the JSON object. If ambiguous, guess from context.`
}

export function suggestPrompt(c: SuggestContext): string {
  const recent = c.recentWorkouts.length
    ? c.recentWorkouts.map((w) => `${w.routineName} — ${w.date} — ${w.muscles}`).join('\n')
    : '(none this week)'
  const available = c.availableRoutines.map((r) => `${r.id}: ${r.name}`).join(', ')
  return `The user logged these workouts this week:
${recent}

Today is ${c.dayOfWeek}. Pick ONE routine from ${available} that balances their recent volume. Return strictly:
{"routineId": string, "reason": "one sentence, specific, observational"}
No prose. Output only the JSON object.`
}

export function postWorkoutPrompt(c: PostWorkoutContext): string {
  const last =
    c.lastSessionVolumeKg !== null && c.daysAgoLastSession !== null
      ? `Their last session of the same routine was ${c.lastSessionVolumeKg}kg, ${c.daysAgoLastSession} days ago.`
      : 'This is their first recorded session of this routine.'
  return `User just finished ${c.routineName}: ${c.setCount} sets, ${c.volumeKg}kg total, ${c.prCount} PRs on ${c.prExercises.join(', ') || 'none'}. ${last}

Write 1-2 sentences observing the trend and recommending one concrete change next session (e.g. add 2.5kg, add a set, drop weight and focus on form). Warm, specific, no hype.`
}
