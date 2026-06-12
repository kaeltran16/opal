import { describe, it, expect } from 'vitest'
import { EmailWorker } from './email.js'
import { ImapAuthError, type ImapCreds, type MailboxClient, type RawEmail } from './imap.js'
import type { TextCompleter } from './pal.js'

const creds: ImapCreds = { host: 'imap.gmail.com', port: 993, address: 'a@b.com', appPassword: 'pw' }

function mailbox(emails: RawEmail[]): MailboxClient {
  return { verify: async () => {}, fetchSince: async () => emails }
}

function raw(id: string, from: string): RawEmail {
  return { messageId: id, from, fromName: from, subject: 's', date: new Date('2026-06-09T10:00:00Z'), text: 'total $10' }
}

// returns a batch envelope with one indexed result per "From:" line in the
// prompt: a receipt for amazon senders, "not a receipt" otherwise.
const completion: TextCompleter = {
  complete: async (msgs) => {
    const froms = [...msgs[0].content.matchAll(/^From: (.+)$/gm)].map((m) => m[1])
    const results = froms.map((from, index) =>
      from.includes('amazon')
        ? { index, isReceipt: true, merchant: 'Amazon', amount: 10, category: 'Shopping' }
        : { index, isReceipt: false, merchant: null, amount: null, category: null },
    )
    return JSON.stringify({ results })
  },
}

describe('EmailWorker.sync', () => {
  it('returns receipts as negative-amount items', async () => {
    const worker = new EmailWorker(mailbox([raw('m1', 'receipts@amazon.com')]), completion)
    const { items } = await worker.sync(creds, [], new Date(0))
    expect(items).toHaveLength(1)
    expect(items[0]).toMatchObject({ id: 'm1', merchant: 'Amazon', amount: -10, category: 'Shopping' })
    expect(items[0].receivedAt).toBe('2026-06-09T10:00:00.000Z')
  })

  it('drops non-receipt emails', async () => {
    const worker = new EmailWorker(mailbox([raw('m1', 'news@spam.com')]), completion)
    expect((await worker.sync(creds, [], new Date(0))).items).toHaveLength(0)
  })

  it('applies the sender allowlist before extraction', async () => {
    const worker = new EmailWorker(
      mailbox([raw('m1', 'receipts@amazon.com'), raw('m2', 'receipts@amazon.com')]),
      completion,
    )
    const { items } = await worker.sync(creds, ['othersender.com'], new Date(0))
    expect(items).toHaveLength(0)
  })

  it('dedupes repeated message-ids within a batch', async () => {
    const worker = new EmailWorker(
      mailbox([raw('dup', 'receipts@amazon.com'), raw('dup', 'receipts@amazon.com')]),
      completion,
    )
    expect((await worker.sync(creds, [], new Date(0))).items).toHaveLength(1)
  })

  it('dedupes before extraction, even for non-receipts (Bug B)', async () => {
    let calls = 0
    const counting: TextCompleter = {
      complete: async (msgs) => {
        calls++
        return completion.complete(msgs)
      },
    }
    // duplicate non-receipt id: must reach the model exactly once
    const worker = new EmailWorker(
      mailbox([raw('dup', 'news@spam.com'), raw('dup', 'news@spam.com')]),
      counting,
    )
    await worker.sync(creds, [], new Date(0))
    expect(calls).toBe(1)
  })

  it('keeps other batches when one batch fails, logs once (Bug A)', async () => {
    // 9 amazon receipts → batch 0 = m0..m7, batch 1 = m8. Fail the second batch
    // (it contains m8) and the first batch's results must survive.
    const flaky: TextCompleter = {
      complete: async (msgs) => {
        if (msgs[0].content.includes('m8 boom')) throw new Error('upstream blew up')
        return completion.complete(msgs)
      },
    }
    const emails = Array.from({ length: 9 }, (_, i) => raw(`m${i}`, 'receipts@amazon.com'))
    emails[8] = { ...emails[8], text: 'm8 boom' }
    const logged: unknown[] = []
    const worker = new EmailWorker(mailbox(emails), flaky, { error: (e) => logged.push(e) })
    const { items } = await worker.sync(creds, [], new Date(0))
    expect(items.map((i) => i.id)).toEqual(emails.slice(0, 8).map((e) => e.messageId))
    expect(logged).toHaveLength(1)
  })

  it('chunks candidates into batches of 8 (one LLM call each)', async () => {
    let calls = 0
    const counting: TextCompleter = {
      complete: async (msgs) => { calls++; return completion.complete(msgs) },
    }
    const emails = Array.from({ length: 10 }, (_, i) => raw(`m${i}`, 'receipts@amazon.com'))
    const worker = new EmailWorker(mailbox(emails), counting)
    const { items } = await worker.sync(creds, [], new Date(0))
    expect(calls).toBe(2) // 8 + 2
    expect(items).toHaveLength(10)
  })

  it('preserves input candidate order under concurrency', async () => {
    // many receipts with staggered completion times; output must stay in order
    const emails = Array.from({ length: 12 }, (_, i) => raw(`m${i}`, 'receipts@amazon.com'))
    const jittery: TextCompleter = {
      complete: async (msgs) => {
        await new Promise((r) => setTimeout(r, Math.floor(Math.random() * 5)))
        return completion.complete(msgs)
      },
    }
    const worker = new EmailWorker(mailbox(emails), jittery)
    const { items } = await worker.sync(creds, [], new Date(0))
    expect(items.map((i) => i.id)).toEqual(emails.map((e) => e.messageId))
  })

  it('flags truncated when a full page is returned (Bug C)', async () => {
    const full = Array.from({ length: 50 }, (_, i) => raw(`m${i}`, 'news@spam.com'))
    const worker = new EmailWorker(mailbox(full), completion)
    expect((await worker.sync(creds, [], new Date(0))).truncated).toBe(true)
  })

  it('does not flag truncated for a partial page', async () => {
    const worker = new EmailWorker(mailbox([raw('m1', 'news@spam.com')]), completion)
    expect((await worker.sync(creds, [], new Date(0))).truncated).toBe(false)
  })
})

describe('EmailWorker.test', () => {
  it('propagates an IMAP auth failure', async () => {
    const failing: MailboxClient = {
      verify: async () => { throw new ImapAuthError('bad') },
      fetchSince: async () => [],
    }
    await expect(new EmailWorker(failing, completion).test(creds)).rejects.toBeInstanceOf(ImapAuthError)
  })
})
