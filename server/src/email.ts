import type { TextCompleter } from './pal.js'
import type { ImapCreds, MailboxClient, RawEmail } from './imap.js'
import { filterBySender, extractReceipts, BATCH_SIZE } from './receipts.js'

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

// concurrent extractions in flight; bounds upstream load while staying well
// under the client's whole-request timeout (lib/.../real_email_sync_service.dart)
const EXTRACT_CONCURRENCY = 4

/** Minimal logger seam; pino's logger is structurally compatible. */
export interface SyncLogger {
  error(obj: unknown, msg?: string): void
}

/** Result of a sync: receipts found plus whether the scan window was capped. */
export interface SyncResult {
  items: EmailImportDto[]
  /** true when MAX_SCAN may have hidden older messages (see Bug C). */
  truncated: boolean
}

/**
 * Pull-model email worker (U24): given per-request IMAP creds, fetches inbox
 * messages since the client's last sync, keeps allowlisted senders, and
 * model-extracts receipts. Holds no state and stores no credentials — dedup is
 * the client's job (by `sourceRef`). The {@link MailboxClient} and
 * {@link TextCompleter} are injected so this is testable without a network.
 */
export class EmailWorker {
  constructor(
    private readonly mailbox: MailboxClient,
    private readonly completion: TextCompleter,
    private readonly logger?: SyncLogger,
  ) {}

  /** Verify credentials only (Setup screen's Test-connection). */
  async test(creds: ImapCreds): Promise<void> {
    await this.mailbox.verify(creds)
  }

  /** Scan since [since] and return the receipts found (deduped within the batch). */
  async sync(creds: ImapCreds, senderFilters: string[], since: Date): Promise<SyncResult> {
    const emails = await this.mailbox.fetchSince(creds, since, MAX_SCAN)
    // heuristic: a full page means older messages may have been left unscanned.
    // fetchSince caps to the most recent MAX_SCAN and can't report the true total.
    const truncated = emails.length >= MAX_SCAN

    // dedupe by messageId before extraction so a repeated non-receipt id is
    // never sent to the model twice (Bug B).
    const seen = new Set<string>()
    const candidates = filterBySender(emails, senderFilters).filter((e) => {
      if (seen.has(e.messageId)) return false
      seen.add(e.messageId)
      return true
    })

    // chunk into batches (one LLM call each), then run those through a bounded
    // pool with per-batch failure tolerance: one upstream error skips that
    // batch's emails, never the others (Bug A). Each batch carries its emails'
    // absolute candidate offset so results stay in input order.
    const batches: { offset: number; emails: RawEmail[] }[] = []
    for (let i = 0; i < candidates.length; i += BATCH_SIZE) {
      batches.push({ offset: i, emails: candidates.slice(i, i + BATCH_SIZE) })
    }

    const results: (EmailImportDto | null)[] = new Array(candidates.length).fill(null)
    let failures = 0
    let next = 0
    const work = async (): Promise<void> => {
      while (next < batches.length) {
        const { offset, emails: batch } = batches[next++]
        try {
          const fields = await extractReceipts(batch, this.completion)
          fields.forEach((f, j) => {
            if (!f) return
            const email = batch[j]
            results[offset + j] = {
              id: email.messageId,
              merchant: f.merchant,
              amount: -Math.abs(f.amount), // receipts are expenses
              receivedAt: email.date.toISOString(),
              category: f.category,
            }
          })
        } catch (err) {
          failures += batch.length
          this.logger?.error(err, `email extraction failed for batch at offset ${offset}`)
        }
      }
    }
    await Promise.all(Array.from({ length: Math.min(EXTRACT_CONCURRENCY, batches.length) }, work))

    if (failures > 0 && !this.logger) {
      // no per-email logger available; surface the aggregate at least once.
      console.error(`email sync: ${failures} extraction(s) failed and were skipped`)
    }

    return { items: results.filter((r): r is EmailImportDto => r !== null), truncated }
  }
}
