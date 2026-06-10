import { describe, it, expect } from 'vitest'
import { extractBearer } from './auth.js'

describe('extractBearer', () => {
  it('pulls the token from a Bearer header', () => {
    expect(extractBearer('Bearer abc123')).toBe('abc123')
  })
  it('returns null for a missing or malformed header', () => {
    expect(extractBearer(undefined)).toBeNull()
    expect(extractBearer('Basic abc')).toBeNull()
    expect(extractBearer('Bearer')).toBeNull()
  })
})
