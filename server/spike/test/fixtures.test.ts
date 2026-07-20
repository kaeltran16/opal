import { describe, it, expect } from 'vitest'
import { STUB, CATALOG_N, chatPayload, routinePayload, emailExtractPayload } from '../bench/fixtures'
import { extractJson, routineSchema, insightsSchema } from '../../src/pal'

describe('fixtures worst-case sizing', () => {
  it('chat history is the retained max of 20', () => {
    expect((chatPayload() as any).history).toHaveLength(20)
  })
  it('routine payload sends the full catalog', () => {
    expect((routinePayload() as any).exercises).toHaveLength(CATALOG_N)
  })
  it('email extract sends 8 max-size candidates', () => {
    const p = emailExtractPayload() as any
    expect(p.candidates).toHaveLength(8)
    expect(p.candidates[0].text.length).toBe(8000)
  })
  it('canned routine + insights outputs pass their schemas', () => {
    expect(() => routineSchema.parse(extractJson(STUB.routine.text!))).not.toThrow()
    expect(() => insightsSchema.parse(extractJson(STUB.insights.text!))).not.toThrow()
  })
})
