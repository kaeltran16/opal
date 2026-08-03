export const MAX_FACTS = 20
export const MAX_PATTERNS = 5

export interface MemoryFact { id: string; text: string }
export interface MemoryPattern { colorToken: string; title: string; detail: string }
export interface MemoryDigest { facts: MemoryFact[]; patterns: MemoryPattern[] }

// a mutation Pal asked for in chat, applied server-side (never a client action).
export type MemoryOp = { op: 'remember'; text: string } | { op: 'forget'; id: string }
