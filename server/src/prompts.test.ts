import { describe, it, expect } from 'vitest'
import { chatSystemPrompt, reviewPrompt, parsePrompt, suggestPrompt, postWorkoutPrompt } from './prompts.js'

describe('prompts', () => {
  it('chat system prompt substitutes user data', () => {
    const p = chatSystemPrompt({
      userName: 'Kael', todayEntries: ['08:00 Coffee (money, -$5)'],
      dailyBudget: 60, moveGoalMin: 30, ritualGoal: 5,
      spentToday: 12, movedTodayMin: 20, ritualsDoneToday: 3,
      weekSpent: 200, weekBudget: 420, weekMovedMin: 140, weekRitualsDone: 18,
      weekRitualGoal: 35, moveStreakDays: 11,
    })
    expect(p).toContain('You are Pal')
    expect(p).toContain('Kael')
    expect(p).toContain('08:00 Coffee (money, -$5)')
    expect(p).toContain('Daily budget $60')
    expect(p).toContain('11-day move streak')
    expect(p).toContain('Never say "amazing" or "great job"')
  })

  it('parse prompt embeds the raw input', () => {
    expect(parsePrompt('coffee 5')).toContain('"coffee 5"')
    expect(parsePrompt('coffee 5')).toContain('money|move|rituals')
  })

  it('review prompt embeds the numbers', () => {
    const p = reviewPrompt({
      spent: 1840, spentDeltaPct: 12, hoursMoved: 18, movedDeltaPct: 8,
      activeDays: 22, ritualsKept: 120, ritualsTarget: 150, ritualsPct: 80,
      streakDays: 12, topCategory: 'Food', topCategoryPct: 34, discoveredPattern: 'mornings set the tone',
    })
    expect(p).toContain('$1840')
    expect(p).toContain('12-day move streak')
    expect(p).toContain('Food 34%')
  })

  it('suggest prompt lists routines and day', () => {
    const p = suggestPrompt({
      recentWorkouts: [{ routineName: 'Push A', date: 'Mon', muscles: 'chest' }],
      dayOfWeek: 'Wednesday',
      availableRoutines: [{ id: 'r1', name: 'Push A' }, { id: 'r2', name: 'Legs' }],
    })
    expect(p).toContain('Wednesday')
    expect(p).toContain('Push A')
    expect(p).toContain('routineId')
  })

  it('post-workout prompt includes PRs and trend', () => {
    const p = postWorkoutPrompt({
      routineName: 'Push A', setCount: 18, volumeKg: 5400, prCount: 2,
      prExercises: ['Bench'], lastSessionVolumeKg: 5100, daysAgoLastSession: 4,
    })
    expect(p).toContain('Push A')
    expect(p).toContain('2 PRs')
    expect(p).toContain('Bench')
  })
})
