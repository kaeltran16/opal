import { describe, it, expect } from 'vitest'
import { chatSystemPrompt, reviewPrompt, insightsPrompt, parsePrompt, suggestPrompt, postWorkoutPrompt, routinePrompt, receiptsBatchPrompt } from './prompts.js'

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

  it('chat system prompt tells Pal it can take logging/goal actions via tools', () => {
    const p = chatSystemPrompt({
      userName: 'Kael', todayEntries: [], dailyBudget: 60, moveGoalMin: 30, ritualGoal: 5,
      spentToday: 0, movedTodayMin: 0, ritualsDoneToday: 0, weekSpent: 0, weekBudget: 420,
      weekMovedMin: 0, weekRitualsDone: 0, weekRitualGoal: 35, moveStreakDays: 0,
    })
    expect(p.toLowerCase()).toContain('tool')
    expect(p.toLowerCase()).toContain('log')
  })

  it('parse prompt embeds the raw input', () => {
    expect(parsePrompt('coffee 5')).toContain('"coffee 5"')
    expect(parsePrompt('coffee 5')).toContain('money|move|rituals')
  })

  it('parse prompt includes a worked example to anchor the format', () => {
    expect(parsePrompt('coffee 5')).toContain('Example')
  })

  it('parse prompt asks for a direction and includes an income example', () => {
    const p = parsePrompt('got paid 500')
    expect(p).toContain('direction')
    expect(p).toContain('"direction":"income"')
  })

  it('review prompt embeds the numbers and is month-worded for a month range', () => {
    const p = reviewPrompt({
      range: 'month', spent: 1840, spentDeltaPct: -12, hoursMoved: 18, movedDeltaPct: 8,
      activeDays: 22, ritualsKept: 120, ritualsTarget: 150, ritualsPct: 80,
      streakDays: 12, topCategory: 'Food', topCategoryPct: 34,
    })
    expect(p).toContain('$1840')
    expect(p).toContain('12-day move streak')
    expect(p).toContain('Food 34%')
    expect(p).toContain("this month's tracking data")
    expect(p).toContain('down 12% vs last month')
    expect(p).toContain('up 8% vs last month')
  })

  it('review prompt is week-worded for a week range', () => {
    const p = reviewPrompt({
      range: 'week', spent: 200, spentDeltaPct: 5, hoursMoved: 4, movedDeltaPct: -10,
      activeDays: 5, ritualsKept: 28, ritualsTarget: 35, ritualsPct: 80,
      streakDays: 6, topCategory: 'Food', topCategoryPct: 34,
    })
    expect(p).toContain("this week's tracking data")
    expect(p).toContain('up 5% vs last week')
    expect(p).toContain('down 10% vs last week')
  })

  it('review prompt omits delta phrases when a delta is null', () => {
    const p = reviewPrompt({
      range: 'month', spent: 1840, spentDeltaPct: null, hoursMoved: 18, movedDeltaPct: null,
      activeDays: 22, ritualsKept: 120, ritualsTarget: 150, ritualsPct: 80,
      streakDays: 12, topCategory: 'Food', topCategoryPct: 34,
    })
    expect(p).not.toContain('vs last month')
    expect(p).toContain('$1840 spent,')
  })

  it('insights prompt embeds data, weekday spend, and tailors to range', () => {
    const p = insightsPrompt({
      range: 'week', spent: 200, budget: 420, moveMinutes: 140, moveTarget: 210,
      ritualsKept: 18, ritualsTarget: 35, activeDays: 5, streakDays: 11,
      topCategory: 'Food', topCategoryPct: 34, spendByWeekday: [10, 20, 30, 40, 50, 25, 25], entries: ['08:00 Coffee'],
    })
    expect(p).toContain('$200 of $420')
    expect(p).toContain('Food 34%')
    expect(p).toContain('11-day move streak')
    expect(p).toContain('Mon $10')
    expect(p).toContain('08:00 Coffee')
    expect(p).toContain('Range is "week"')
    expect(p).toContain('colorToken')
  })

  it('insights prompt for a day range fills only the headline', () => {
    const p = insightsPrompt({
      range: 'day', spent: 12, budget: 60, moveMinutes: 20, moveTarget: 30,
      ritualsKept: 3, ritualsTarget: 5, activeDays: 1, streakDays: 11,
      topCategory: 'Food', topCategoryPct: 34, spendByWeekday: [12, 0, 0, 0, 0, 0, 0], entries: [],
    })
    expect(p).toContain('Range is "day"')
    expect(p).toContain('fill "headline" only')
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

  it('routine prompt embeds the goal and lists exercises by id (equipment optional)', () => {
    const p = routinePrompt('build a push day', [
      { id: 'e1', name: 'Bench Press', group: 'Push', equipment: 'Barbell' },
      { id: 'e2', name: 'Push-up', group: 'Push', equipment: null },
    ])
    expect(p).toContain('build a push day')
    expect(p).toContain('e1: Bench Press (Push, Barbell)')
    expect(p).toContain('e2: Push-up (Push)')
    expect(p).toContain('upper|lower|full|cardio|custom')
  })

  it('receipts batch prompt numbers each email and asks for one indexed result each', () => {
    const p = receiptsBatchPrompt([
      { from: 'receipts@amazon.com', subject: 'Your order', text: 'Order total $42.99' },
      { from: 'rides@uber.com', subject: 'Trip', text: 'Total $18.40' },
    ])
    expect(p).toContain('Email 1:')
    expect(p).toContain('Email 2:')
    expect(p).toContain('receipts@amazon.com')
    expect(p).toContain('Order total $42.99')
    expect(p).toContain('"results": [{"index": number')
    expect(p).toContain('Shopping, Food, Transport, Bills, Entertainment, Health, Travel, Other')
  })

  it('receipts batch prompt truncates each body to 4000 chars', () => {
    const long = 'x'.repeat(5000)
    const p = receiptsBatchPrompt([{ from: 'a@b.com', subject: 's', text: long }])
    expect(p).not.toContain('x'.repeat(4001))
    expect(p).toContain('x'.repeat(4000))
  })
})
