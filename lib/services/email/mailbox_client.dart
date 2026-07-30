/// The narrow IMAP seam the native sync service codes against.
///
/// Kept free of `dart:io` and of `enough_mail` so the sync service stays
/// testable with a fake transport and so the web build never pulls the IMAP
/// stack. Mirrors the server's `MailboxClient` (`server/src/imap.ts`), which
/// this replaces.
library;

/// IMAP credentials, read from the device keychain per sync. Never sent to the
/// Worker.
class ImapCreds {
  const ImapCreds({
    required this.host,
    required this.port,
    required this.address,
    required this.appPassword,
  });

  final String host;
  final int port;
  final String address;
  final String appPassword;
}

/// One fetched email, reduced to the fields receipt detection needs.
class RawEmail {
  const RawEmail({
    required this.messageId,
    required this.from,
    required this.fromName,
    required this.subject,
    required this.date,
    required this.text,
  });

  final String messageId;
  final String from;
  final String fromName;
  final String subject;

  /// The IMAP envelope date. The transaction date is re-derived server-side.
  final DateTime date;
  final String text;
}

/// Raised when IMAP login fails, so the UI can distinguish bad credentials from
/// a transport or upstream failure.
class ImapAuthException implements Exception {
  const ImapAuthException(this.message);
  final String message;

  @override
  String toString() => 'ImapAuthException: $message';
}

/// Raised when the mailbox is unreachable or the transport fails.
class MailboxException implements Exception {
  const MailboxException(this.message);
  final String message;

  @override
  String toString() => 'MailboxException: $message';
}

/// IMAP transport seam.
abstract interface class MailboxClient {
  /// Verifies credentials. Throws [ImapAuthException] on a bad login.
  Future<void> verify(ImapCreds creds);

  /// INBOX messages received on/after [since], capped to the most recent [max].
  Future<List<RawEmail>> fetchSince(ImapCreds creds, DateTime since, int max);
}
