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

export interface InsightsContext {
  range: 'day' | 'week' | 'month'
  spent: number
  budget: number
  moveMinutes: number
  moveTarget: number
  ritualsKept: number
  ritualsTarget: number
  activeDays: number
  streakDays: number
  topCategory: string
  topCategoryPct: number
  spendByWeekday: number[]
  entries: string[]
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

You can act, not just talk. When the user tells you they did or spent something, asks to change a goal, or asks for a workout routine, call the matching tool — for example "add $5 for coffee" calls log_expense, "ran 30 min" calls log_movement, "set my budget to $60" calls set_daily_budget, "build me a push day" calls create_routine. Only call a tool when the user clearly wants that change; for questions, just answer. After acting, confirm in one short sentence.

Reply in 1-3 short sentences. Friendly, specific, no filler. Never say "amazing" or "great job" — be observational and warm instead.`
}

export function reviewPrompt(c: ReviewContext): string {
  return `Write a 2-3 sentence warm, specific, editorial reflection on this month's tracking data. Avoid hype words like "amazing" or "crushed it". Be specific and observational.

Data: $${c.spent} spent (down ${c.spentDeltaPct}% vs last month), ${c.hoursMoved}h moved (up ${c.movedDeltaPct}%), ${c.activeDays} active days, ${c.ritualsKept}/${c.ritualsTarget} rituals kept (${c.ritualsPct}%). Current ${c.streakDays}-day move streak. Top category: ${c.topCategory} ${c.topCategoryPct}%. Pattern: ${c.discoveredPattern}.`
}

export function insightsPrompt(c: InsightsContext): string {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
  const byDay = weekdays.map((d, i) => `${d} $${c.spendByWeekday[i] ?? 0}`).join(', ')
  const entries = c.entries.length ? c.entries.join('\n') : '(none)'
  const shape = `{"headline": string|null, "lede": string|null, "suggestion": string|null, "wins": [{"colorToken": "money"|"move"|"rituals", "title": string, "sub": string}], "patterns": [{"colorToken": "money"|"move"|"rituals", "title": string, "detail": string}]}`

  const byRange: Record<InsightsContext['range'], string> = {
    day: 'Range is "day": fill "headline" only with one observation about today versus the goals. Leave "lede" and "suggestion" null, and "wins" and "patterns" empty.',
    week: 'Range is "week": fill "headline" and a 1-sentence "lede" sub-headline, up to 3 "wins", up to 3 "patterns", and one concrete "suggestion".',
    month: 'Range is "month": fill up to 3 "patterns". "headline", "lede" and "suggestion" may be null; leave "wins" empty.',
  }

  return `Reflect on this ${c.range}'s tracking data. Be specific and observational. Avoid hype words like "amazing", "crushed it", or "great job".

Data: $${c.spent} of $${c.budget} budget, ${c.moveMinutes} of ${c.moveTarget} move minutes, ${c.ritualsKept}/${c.ritualsTarget} rituals kept, ${c.activeDays} active days, ${c.streakDays}-day move streak. Top category: ${c.topCategory} ${c.topCategoryPct}%.
Spend by weekday: ${byDay}.
Entries:
${entries}

Only make claims grounded in this data: use the spend-by-weekday numbers for day-of-week patterns, the top category for spending patterns, and the streak for streaks. Do not invent numbers that are not derivable from the data. Set "colorToken" to the metric each item is about (money, move or rituals).

${byRange[c.range]}

Return strictly this JSON shape: ${shape}
"wins" and "patterns" must always be arrays (use [] when empty). No prose, no code fence. Output only the JSON object.`
}

export function parsePrompt(input: string): string {
  return `Parse this free-form log into JSON. User said: "${input}"
Return strictly: {"type": "money|move|rituals", "amount": number|null, "duration": number|null, "category": string|null, "title": string, "note": string|null}
- type: "money" for spending/income, "move" for workouts/activity, "rituals" for habits/routines.
- amount: dollars for money (positive magnitude, no sign or symbol), else null.
- duration: minutes for move, else null.
- category: a short money category (e.g. Coffee, Dining, Transport), else null.
- title: a short human label for the entry.
Example: "add $5 for coffee" -> {"type":"money","amount":5,"duration":null,"category":"Coffee","title":"Coffee","note":null}
Example: "ran 30 min" -> {"type":"move","amount":null,"duration":30,"category":null,"title":"Run","note":null}
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

export interface ReceiptInput {
  from: string
  subject: string
  text: string
}

export function receiptPrompt(e: ReceiptInput): string {
  // body is truncated upstream; keep the prompt itself bounded too.
  const body = e.text.length > 4000 ? e.text.slice(0, 4000) : e.text
  return `Extract purchase details from this email. It may or may not be a purchase receipt.
From: ${e.from}
Subject: ${e.subject}
Body:
${body}

Return strictly: {"isReceipt": boolean, "merchant": string|null, "amount": number|null, "category": string|null}
- isReceipt: true only if this is a receipt/order confirmation for something the user paid for.
- merchant: the store/brand name (not the email sender domain).
- amount: the total charged as a positive number, no currency symbol. null if not found.
- category: one of Shopping, Food, Transport, Bills, Entertainment, Health, Travel, Other.
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

export interface RoutineExercise {
  id: string
  name: string
  group: string
  equipment: string | null
}

export function routinePrompt(goal: string, exercises: RoutineExercise[]): string {
  const list = exercises
    .map((e) => `${e.id}: ${e.name} (${e.group}${e.equipment ? `, ${e.equipment}` : ''})`)
    .join('\n')
  return `Design a workout routine for this goal: "${goal}".

Choose from ONLY these exercises (use the exact id):
${list}

Decide which exercises fit, how many, and the sets — reps and weight (kg) for strength, or duration (minutes) for cardio/timed work. Omit fields that don't apply to a set.

Return strictly this JSON, no prose:
{"name": string, "tag": "upper|lower|full|cardio|custom", "estMin": number, "rationale": "one short sentence", "exercises": [{"exerciseId": string, "sets": [{"reps": number|null, "weight": number|null, "duration": number|null}]}]}
- exerciseId MUST be one of the ids listed above.
- tag: pick the closest of upper, lower, full, cardio, custom.
- Output only the JSON object.`
}
