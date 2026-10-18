import 'package:clock/clock.dart';
import 'package:enough_mail/enough_mail.dart';

import 'mailbox_client.dart';
import 'receipt_filters.dart';

/// [MailboxClient] over `enough_mail`'s high-level `MailClient` (migration
/// phase 4B). Replaces the server's `ImapFlowClient`.
///
/// Native only — this library pulls `dart:io`. Reach it through
/// [createMailboxClient] so the web build resolves the stub instead.
class ImapMailboxClient implements MailboxClient {
  const ImapMailboxClient({this.timeout = const Duration(seconds: 15)});

  /// Bounds the handshake so a wrong host cannot hang a sync.
  final Duration timeout;

  // mirrors the server's BODY_MAX_BYTES. enough_mail fetches only the envelope
  // of a mail at or above this size; receipts with inline logos (Grab) are, so
  // fetchSince follows up with their text parts alone, never the images.
  static const _downloadSizeLimit = 64 * 1024;

  MailClient _client(ImapCreds creds) => MailClient(
        MailAccount.fromManualSettings(
          name: 'opal',
          email: creds.address,
          incomingHost: creds.host,
          // never connected: only the incoming IMAP config is used, but the
          // factory requires an outgoing host.
          outgoingHost: creds.host,
          password: creds.appPassword,
          incomingPort: creds.port,
        ),
        downloadSizeLimit: _downloadSizeLimit,
      );

  @override
  Future<void> verify(ImapCreds creds) async {
    final client = _client(creds);
    try {
      await client.connect(timeout: timeout);
    } catch (err) {
      throw _mapError(err);
    } finally {
      await _quietly(client);
    }
  }

  @override
  Future<List<RawEmail>> fetchSince(
    ImapCreds creds,
    DateTime since,
    int max,
  ) async {
    final client = _client(creds);
    try {
      await client.connect(timeout: timeout);
    } catch (err) {
      throw _mapError(err);
    }

    try {
      await client.selectInbox();
      // newest `max` messages, then bound by date on-device. The server used an
      // IMAP SINCE search capped to the newest `max`; for any inbox with at
      // most `max` messages since `since` the result set is identical, and the
      // cap behaves the same when it isn't.
      final messages = await client.fetchMessages(count: max);
      final out = <RawEmail>[];
      for (final m in messages) {
        final date = m.decodeDate();
        if (date != null && date.isBefore(since)) continue;
        final full = (m.size ?? 0) < _downloadSizeLimit
            ? m
            : await client.fetchMessageContents(
                m,
                maxSize: _downloadSizeLimit,
                includedInlineTypes: [MediaToptype.text],
              );
        out.add(_toRawEmail(full, date));
      }
      return out;
    } catch (err) {
      throw _mapError(err);
    } finally {
      await _quietly(client);
    }
  }

  RawEmail _toRawEmail(MimeMessage m, DateTime? date) {
    final sender = m.from?.isNotEmpty == true ? m.from!.first : null;
    return RawEmail(
      // a mail without a Message-ID still needs a stable dedup key; the
      // sequence id is stable within this fetch.
      messageId: m.getHeaderValue('message-id') ?? 'seq-${m.sequenceId}',
      from: sender?.email ?? '',
      fromName: sender?.personalName ?? '',
      subject: m.decodeSubject() ?? '',
      date: date ?? clock.now().toUtc(),
      text: m.decodeTextPlainPart() ??
          htmlToText(m.decodeTextHtmlPart() ?? ''),
    );
  }

  Future<void> _quietly(MailClient client) async {
    try {
      await client.disconnect();
    } catch (_) {
      // a failed teardown must not mask the real error
    }
  }

  // enough_mail has no auth-specific exception type, so the IMAP server's
  // rejection wording is the only available signal. Mirrors the server's
  // duck-typed isAuthFailure check.
  Exception _mapError(Object err) {
    final text = err.toString().toLowerCase();
    final isAuth = text.contains('authenticationfailed') ||
        text.contains('invalid credentials') ||
        text.contains('authentication failed') ||
        text.contains('login failed');
    return isAuth
        ? const ImapAuthException('IMAP authentication failed')
        : MailboxException(err.toString());
  }
}

/// The native IMAP client. Resolved by conditional import; see the web stub.
MailboxClient createMailboxClient() => const ImapMailboxClient();
