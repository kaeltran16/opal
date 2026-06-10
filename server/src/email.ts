import type { CompletionClient } from './pal.js'
import type { ImapCreds, MailboxClient } from './imap.js'
import { filterBySender, extractReceipt } from './receipts.js'

/** Wire shape returned to the client; maps 1:1 onto `EmailImportItem`. */
export interface EmailImportDto {
  id: string
  merchant: string
  /** Negative = expense (client convention). */
  amount: number
  receivedAt: string // ISO 8601
  category: string | null
}

// most-recent N inbox messages scanned per sync (bounds IMAP + LLM work)
const MAX_SCAN = 50

/**
 * Pull-model email worker (U24): given per-request IMAP creds, fetches inbox
 * messages since the client's last sync, keeps allowlisted senders, and
 * model-extracts receipts. Holds no state and stores no credentials — dedup is
 * the client's job (by `sourceRef`). The {@link MailboxClient} and
 * {@link CompletionClient} are injected so this is testable without a network.
 */
export class EmailWorker {
  constructor(
    private readonly mailbox: MailboxClient,
    private readonly completion: CompletionClient,
  ) {}

  /** Verify credentials only (Setup screen's Test-connection). */
  async test(creds: ImapCreds): Promise<void> {
    await this.mailbox.verify(creds)
  }

  /** Scan since [since] and return the receipts found (deduped within the batch). */
  async sync(creds: ImapCreds, senderFilters: string[], since: Date): Promise<EmailImportDto[]> {
    const emails = await this.mailbox.fetchSince(creds, since, MAX_SCAN)
    const candidates = filterBySender(emails, senderFilters)

    const out: EmailImportDto[] = []
    const seen = new Set<string>()
    for (const email of candidates) {
      if (seen.has(email.messageId)) continue
      const fields = await extractReceipt(email, this.completion)
      if (!fields) continue
      seen.add(email.messageId)
      out.push({
        id: email.messageId,
        merchant: fields.merchant,
        amount: -Math.abs(fields.amount), // receipts are expenses
        receivedAt: email.date.toISOString(),
        category: fields.category,
      })
    }
    return out
  }
}
