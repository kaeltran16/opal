import 'mailbox_client.dart';

/// Web stub for [createMailboxClient].
///
/// Browsers cannot open the raw TCP socket IMAP needs, so there is no web
/// implementation by design. The email screens show an explicit unavailable
/// state on web and never construct a mailbox client; this throws only if that
/// gating is ever bypassed.
MailboxClient createMailboxClient() => throw UnsupportedError(
      'IMAP is unavailable on web: browsers cannot open raw TCP sockets. '
      'Email sync is native-only.',
    );
