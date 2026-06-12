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

// returns a receipt for amazon senders, "not a receipt" otherwise
const completion: TextCompleter = {
  complete: async (msgs) => {
    const prompt = msgs[0].content
    return prompt.includes('amazon')
      ? '{"isReceipt": true, "merchant": "Amazon", "amount": 10, "category": "Shopping"}'
      : '{"isReceipt": false, "merchant": null, "amount": null, "category": null}'
  },
}

describe('EmailWorker.sync', () => {
  it('returns receipts as negative-amount items', async () => {
    const worker = new EmailWorker(mailbox([raw('m1', 'receipts@amazon.com')]), completion)
    const items = await worker.sync(creds, [], new Date(0))
    expect(items).toHaveLength(1)
    expect(items[0]).toMatchObject({ id: 'm1', merchant: 'Amazon', amount: -10, category: 'Shopping' })
    expect(items[0].receivedAt).toBe('2026-06-09T10:00:00.000Z')
  })

  it('drops non-receipt emails', async () => {
    const worker = new EmailWorker(mailbox([raw('m1', 'news@spam.com')]), completion)
    expect(await worker.sync(creds, [], new Date(0))).toHaveLength(0)
  })

  it('applies the sender allowlist before extraction', async () => {
    const worker = new EmailWorker(
      mailbox([raw('m1', 'receipts@amazon.com'), raw('m2', 'receipts@amazon.com')]),
      completion,
    )
    const items = await worker.sync(creds, ['othersender.com'], new Date(0))
    expect(items).toHaveLength(0)
  })

  it('dedupes repeated message-ids within a batch', async () => {
    const worker = new EmailWorker(
      mailbox([raw('dup', 'receipts@amazon.com'), raw('dup', 'receipts@amazon.com')]),
      completion,
    )
    expect(await worker.sync(creds, [], new Date(0))).toHaveLength(1)
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
