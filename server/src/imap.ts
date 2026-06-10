import { ImapFlow } from 'imapflow'
import { simpleParser } from 'mailparser'

/** IMAP credentials sent per-request by the client (never stored server-side). */
export interface ImapCreds {
  host: string
  port: number
  address: string
  appPassword: string
}

/** One fetched email, reduced to the fields receipt parsing needs. */
export interface RawEmail {
  messageId: string
  from: string
  fromName: string
  subject: string
  date: Date
  text: string
}

/** Raised when IMAP login fails (mapped to 401 upstream, distinct from a 502). */
export class ImapAuthError extends Error {
  constructor(message: string) {
    super(message)
    this.name = 'ImapAuthError'
  }
}

/**
 * The narrow IMAP seam the worker codes against — keeps {@link EmailWorker}
 * testable without a network. The real impl is {@link ImapFlowClient}.
 */
export interface MailboxClient {
  /** Verify credentials; throws {@link ImapAuthError} on bad login. */
  verify(creds: ImapCreds): Promise<void>
  /** INBOX messages received on/after [since] (capped to the most recent [max]). */
  fetchSince(creds: ImapCreds, since: Date, max: number): Promise<RawEmail[]>
}

const CONNECT_TIMEOUT_MS = 15_000
const BODY_MAX_BYTES = 64 * 1024

function newClient(creds: ImapCreds): ImapFlow {
  return new ImapFlow({
    host: creds.host,
    port: creds.port,
    secure: true,
    auth: { user: creds.address, pass: creds.appPassword },
    logger: false,
    // bound the handshake so a wrong host can't hang the request
    greetingTimeout: CONNECT_TIMEOUT_MS,
    socketTimeout: CONNECT_TIMEOUT_MS,
  })
}

// imapflow throws AuthenticationFailure; detect it without importing the class.
function isAuthFailure(err: unknown): boolean {
  const e = err as { authenticationFailed?: boolean; responseStatus?: string; name?: string }
  return Boolean(e?.authenticationFailed) || e?.responseStatus === 'NO' || e?.name === 'AuthenticationFailure'
}

export class ImapFlowClient implements MailboxClient {
  async verify(creds: ImapCreds): Promise<void> {
    const client = newClient(creds)
    try {
      await client.connect()
    } catch (err) {
      if (isAuthFailure(err)) throw new ImapAuthError('IMAP authentication failed')
      throw err
    } finally {
      await client.logout().catch(() => {})
    }
  }

  async fetchSince(creds: ImapCreds, since: Date, max: number): Promise<RawEmail[]> {
    const client = newClient(creds)
    try {
      await client.connect()
    } catch (err) {
      if (isAuthFailure(err)) throw new ImapAuthError('IMAP authentication failed')
      throw err
    }

    try {
      const lock = await client.getMailboxLock('INBOX')
      try {
        const uids = (await client.search({ since }, { uid: true })) || []
        if (!uids.length) return []
        // newest first, capped
        const wanted = uids.sort((a, b) => b - a).slice(0, max)

        const out: RawEmail[] = []
        for (const msg of await client.fetchAll(
          wanted,
          { uid: true, envelope: true, source: { start: 0, maxLength: BODY_MAX_BYTES } },
          { uid: true },
        )) {
          const env = msg.envelope
          const sender = env?.from?.[0]
          const parsed = msg.source ? await simpleParser(msg.source) : null
          out.push({
            messageId: env?.messageId ?? `uid-${msg.uid}`,
            from: sender?.address ?? '',
            fromName: sender?.name ?? '',
            subject: env?.subject ?? '',
            date: env?.date ?? new Date(),
            text: (parsed?.text ?? parsed?.html ?? '').toString(),
          })
        }
        return out
      } finally {
        lock.release()
      }
    } finally {
      await client.logout().catch(() => {})
    }
  }
}
