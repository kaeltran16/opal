import { describe, it, expect, beforeEach } from 'vitest'
import { MemoryStore, MAX_FACTS } from './memory.js'

describe('MemoryStore', () => {
  let store: MemoryStore
  beforeEach(() => { store = new MemoryStore(':memory:') })

  it('adds and lists facts per token', () => {
    const f = store.addFact('tok-1', 'training for a marathon in October')
    expect(f.id).toBeTruthy()
    expect(store.listFacts('tok-1')).toEqual([f])
    expect(store.listFacts('tok-2')).toEqual([]) // isolated per token
  })

  it('forgets a fact by id', () => {
    const f = store.addFact('tok-1', 'vegetarian')
    store.forgetFact('tok-1', f.id)
    expect(store.listFacts('tok-1')).toEqual([])
  })

  it('caps facts at MAX_FACTS, dropping the oldest', () => {
    for (let i = 0; i < MAX_FACTS + 3; i++) store.addFact('tok-1', `fact ${i}`)
    const facts = store.listFacts('tok-1')
    expect(facts).toHaveLength(MAX_FACTS)
    expect(facts[0].text).toBe('fact 3')      // 0,1,2 dropped
    expect(facts[facts.length - 1].text).toBe(`fact ${MAX_FACTS + 2}`)
  })

  it('fully rewrites patterns (does not append)', () => {
    store.setPatterns('tok-1', [{ colorToken: 'money', title: 'a', detail: 'x' }])
    store.setPatterns('tok-1', [{ colorToken: 'move', title: 'b', detail: 'y' }])
    expect(store.getPatterns('tok-1')).toEqual([{ colorToken: 'move', title: 'b', detail: 'y' }])
  })

  it('assembles a digest and wipes all memory for a token', () => {
    store.addFact('tok-1', 'rent due on the 1st')
    store.setPatterns('tok-1', [{ colorToken: 'rituals', title: 'b', detail: 'y' }])
    const d = store.digest('tok-1')
    expect(d.facts).toHaveLength(1)
    expect(d.patterns).toHaveLength(1)
    store.wipe('tok-1')
    expect(store.digest('tok-1')).toEqual({ facts: [], patterns: [] })
  })

  it('applies remember/forget ops in order', () => {
    const facts = store.listFacts('tok-1')
    expect(facts).toEqual([])
    store.applyOps('tok-1', [{ op: 'remember', text: 'keeps a dog' }])
    const f = store.listFacts('tok-1')[0]
    store.applyOps('tok-1', [{ op: 'forget', id: f.id }, { op: 'remember', text: 'two dogs' }])
    expect(store.listFacts('tok-1').map((x) => x.text)).toEqual(['two dogs'])
  })
})
