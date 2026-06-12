import { describe, it, expect, beforeEach } from 'vitest'
import { HealthStore } from './health.js'

describe('HealthStore', () => {
  let store: HealthStore
  beforeEach(() => { store = new HealthStore(':memory:') })

  it('writes metrics and reads them back', () => {
    const n = store.upsert('2026-06-12', { steps: { value: 8423, unit: 'count' } }, '2026-06-12T18:42:00Z')
    expect(n).toBe(1)
    expect(store.get('2026-06-12', 'steps')).toEqual({ value: 8423, unit: 'count' })
  })

  it('overwrites the same day instead of duplicating on a later sync', () => {
    store.upsert('2026-06-12', { steps: { value: 5000, unit: 'count' } }, '2026-06-12T12:00:00Z')
    store.upsert('2026-06-12', { steps: { value: 9100, unit: 'count' } }, '2026-06-12T20:00:00Z')
    expect(store.get('2026-06-12', 'steps')).toEqual({ value: 9100, unit: 'count' })
  })

  it('keeps different days and metrics independent', () => {
    store.upsert('2026-06-11', { steps: { value: 100, unit: 'count' } }, '2026-06-11T20:00:00Z')
    store.upsert('2026-06-12', { steps: { value: 200, unit: 'count' }, avgHeartRate: { value: 72, unit: 'bpm' } }, '2026-06-12T20:00:00Z')
    expect(store.get('2026-06-11', 'steps')?.value).toBe(100)
    expect(store.get('2026-06-12', 'steps')?.value).toBe(200)
    expect(store.get('2026-06-12', 'avgHeartRate')?.value).toBe(72)
  })
})
