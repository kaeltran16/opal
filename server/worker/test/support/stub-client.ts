import type { CompletionClient, CompletionResult, TextCompleter } from '../../../src/pal.js'
import { Pal } from '../../../src/pal.js'

// canned client for route tests: returns a fixed completion, or throws to exercise
// the 502/500 error mapping. `error` takes precedence when set.
export class StubClient implements CompletionClient {
  constructor(private readonly canned: { text?: string; tool?: CompletionResult; error?: Error }) {}
  async complete(): Promise<string> {
    if (this.canned.error) throw this.canned.error
    return this.canned.text ?? '{}'
  }
  async completeWithTools(): Promise<CompletionResult> {
    if (this.canned.error) throw this.canned.error
    return this.canned.tool ?? { content: '', toolCalls: [] }
  }
}

export const stubPal = (canned: { text?: string; tool?: CompletionResult; error?: Error }): Pal =>
  new Pal(new StubClient(canned))

// canned TextCompleter for email-extract tests: captures the messages it was
// called with (so redaction can be asserted) and returns fixed text, or throws
// to exercise the 502/500 mapping. `error` takes precedence when set.
export class StubCompleter implements TextCompleter {
  lastMessages: Array<{ role: string; content: string }> = []
  constructor(private readonly canned: { text?: string; error?: Error }) {}
  async complete(messages: Array<{ role: string; content: string }>): Promise<string> {
    this.lastMessages = messages
    if (this.canned.error) throw this.canned.error
    return this.canned.text ?? '{}'
  }
}
