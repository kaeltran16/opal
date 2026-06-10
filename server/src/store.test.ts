import { describe, it, expect, beforeEach } from 'vitest'
import { TokenStore } from './store.js'

describe('TokenStore', () => {
  let store: TokenStore
  beforeEach(() => { store = new TokenStore(':memory:') })

  it('issues a token and validates it', () => {
    const token = store.issue('device-1')
    expect(token).toHaveLength(64)
    expect(store.isValid(token)).toBe(true)
  })

  it('rejects an unknown token', () => {
    expect(store.isValid('nope')).toBe(false)
  })

  it('revokes a token', () => {
    const token = store.issue('device-2')
    store.revoke(token)
    expect(store.isValid(token)).toBe(false)
  })

  it('reuses the token for a known device instead of duplicating', () => {
    const a = store.issue('device-3')
    const b = store.issue('device-3')
    expect(b).toBe(a)
  })
})
