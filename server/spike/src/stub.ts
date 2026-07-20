import type { ChatMessage, CompletionClient, CompletionResult } from '../../src/pal.js'

// A per-request stub of the OpenRouter client. Returns a canned worst-case
// completion so the Worker's deterministic CPU (extractJson + zod validation +
// tool-call parsing) is exercised without a network call or spend.
export interface Canned { text?: string; tool?: CompletionResult }

export class StubClient implements CompletionClient {
  constructor(private readonly canned: Canned) {}

  async complete(_messages: ChatMessage[], _opts?: unknown): Promise<string> {
    return this.canned.text ?? '{}'
  }

  async completeWithTools(_messages: ChatMessage[], _tools: unknown[]): Promise<CompletionResult> {
    return this.canned.tool ?? { content: '', toolCalls: [] }
  }
}
