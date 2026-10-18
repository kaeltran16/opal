/// Deterministic, on-device receipt pre-filtering (migration phase 4B).
///
/// Ported from the server's `receipts.ts` / `redact.ts` so the trust boundary
/// moves to the client: the Worker only ever sees sanitized candidates. Keep the
/// behaviour of these functions in step with the server originals — the Worker
/// re-applies [redactPii] as defense-in-depth and the two must agree.
library;

/// Most-recent inbox messages scanned per sync (bounds IMAP + LLM work).
const int kMaxScan = 50;

/// Candidates per `/v1/email/extract` request. One request == one LLM call.
const int kBatchSize = 8;

/// Wire bounds from the Worker's `emailCandidate` schema. Truncating here keeps
/// a long body from being rejected as a 400 for the whole batch.
const int kMaxIdChars = 998;
const int kMaxFromChars = 320;
const int kMaxSubjectChars = 1000;
const int kMaxBodyChars = 8000;

final _email = RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b');

// 13-19 digits, contiguous or grouped by single spaces/hyphens (Visa/MC/Amex)
final _card = RegExp(r'\b\d(?:[ -]?\d){12,18}\b');

// 3-3-4 with required separators; contiguous runs fall to _longNumber instead
final _phone = RegExp(r'(?:\+\d{1,3}[ .-]?)?\(?\d{3}\)?[ .-]\d{3}[ .-]\d{4}\b');

// 9+ contiguous digits: order/account numbers. Amounts use separators/decimals,
// so they never form a run this long.
final _longNumber = RegExp(r'\b\d{9,}\b');

/// Masks personal identifiers in free-form email text.
///
/// Amounts, merchant names and dates are deliberately left intact — the
/// extractor needs them. Order matters: cards win the `[card]` label before the
/// generic long-number rule. Idempotent.
String redactPii(String input) => input
    .replaceAll(_email, '[email]')
    .replaceAll(_card, '[card]')
    .replaceAll(_phone, '[phone]')
    .replaceAll(_longNumber, '[number]');

// Subjects/bodies that are NEVER a completed purchase regardless of body
// content. Deliberately narrow so a real receipt is never dropped — in
// particular, payment-state wording ("order confirmation", "awaiting payment")
// is left out because a paid order confirmation IS a receipt; the model judges
// those with full context.
const _nonReceiptMarkers = [
  // promotional
  'unsubscribe',
  'refer a friend',
  'invite friends',
  '% off',
  'sale ends',
  // review / feedback requests
  'rate your',
  'how was your',
  'share your feedback',
  'leave a review',
  // fulfilment / logistics status, not a charge
  'out for delivery',
  'has been delivered',
  'delivery completed',
  'has shipped',
  'shipping confirmation',
  'tracking number',
  'track your order',
  'đã giao hàng thành công', // (vi) delivered successfully — logistics, not a charge
  // money moving the other way
  'refund',
];

// Vietnamese promotional wording, matched against the SUBJECT ONLY. Unlike the
// markers above, these discount/offer phrases legitimately appear inside a real
// receipt's body — a food-delivery receipt lists a "giảm giá" discount line — so
// body-matching them would drop genuine receipts.
const _promoSubjectMarkers = [
  'khuyến mãi', // promotion
  'giảm giá', // discount
  'ưu đãi', // offer
  'miễn phí', // free
  'chăm lo', // promotional
  'đặc biệt', // special (offer)
];

/// True when an email is almost certainly not a completed purchase
/// (promotional, delivery/tracking status, refund).
///
/// Lets the client skip it before the paid extraction call. Deliberately narrow
/// — the model still judges everything that survives.
bool isLikelyNonReceipt({required String subject, required String text}) {
  final hay = '$subject\n$text'.toLowerCase();
  if (_nonReceiptMarkers.any(hay.contains)) return true;
  final lowerSubject = subject.toLowerCase();
  return _promoSubjectMarkers.any(lowerSubject.contains);
}

/// Keeps only emails whose sender matches one of [filters] (substring, case
/// insensitive), matched against both address and display name.
///
/// An empty filter list drops nothing — the model still gates on isReceipt.
List<T> filterBySender<T>(
  List<T> emails,
  List<String> filters, {
  required String Function(T) from,
  required String Function(T) fromName,
}) {
  final needles = filters
      .map((f) => f.trim().toLowerCase())
      .where((f) => f.isNotEmpty)
      .toList();
  if (needles.isEmpty) return emails;
  return emails.where((e) {
    final hay = '${from(e)} ${fromName(e)}'.toLowerCase();
    return needles.any(hay.contains);
  }).toList();
}

// two-label public suffixes this app's senders use, instead of the full Public
// Suffix List. A sender under an unlisted one collapses to the bare suffix
// (`com.br`), so add its suffix here when such a sender appears.
const _twoLabelSuffixes = {
  'com.vn',
  'net.vn',
  'org.vn',
  'edu.vn',
  'gov.vn',
  'co.uk',
  'com.au',
  'co.jp',
  'com.sg',
  'com.my',
  'co.id',
  'co.th',
};

/// The registrable domain of a sender address, lowercased, so
/// `info@mail.shopee.vn` and `no-reply@shopee.vn` give `shopee.vn` and
/// `info@card.vib.com.vn` gives `vib.com.vn`. Null when [address] has no domain.
String? senderDomain(String address) {
  final at = address.lastIndexOf('@');
  if (at < 0) return null;
  final labels = address
      .substring(at + 1)
      .trim()
      .toLowerCase()
      .split('.')
      .where((l) => l.isNotEmpty)
      .toList();
  if (labels.isEmpty) return null;
  String last(int n) =>
      labels.skip(labels.length < n ? 0 : labels.length - n).join('.');
  return last(_twoLabelSuffixes.contains(last(2)) ? 3 : 2);
}

/// Truncates to [max] characters, or returns [value] unchanged when shorter.
String boundText(String value, int max) =>
    value.length <= max ? value : value.substring(0, max);

final _htmlDropped = RegExp(
  r'<!--.*?-->|<(head|style|script)\b.*?</\1\s*>',
  caseSensitive: false,
  dotAll: true,
);
final _htmlBreak = RegExp(
  r'<br\s*/?>|</(p|div|tr|li|h[1-6]|table)\s*>',
  caseSensitive: false,
);
final _htmlTag = RegExp(r'<[^>]*>');
final _numericEntity = RegExp(r'&#(x[0-9a-f]+|\d+);', caseSensitive: false);
const _namedEntities = {
  '&nbsp;': ' ',
  '&lt;': '<',
  '&gt;': '>',
  '&quot;': '"',
  '&apos;': "'",
};

/// Plain text of an HTML email body, so the extractor sees the receipt rather
/// than markup. An HTML-only receipt otherwise spends the [kMaxBodyChars]
/// budget on its `<head>` and styles before any amount appears.
///
/// Mirrors what the old server got from mailparser's `text`: block ends become
/// line breaks, cells on one row stay on one line. Not a full HTML parser —
/// enough for receipt templates.
String htmlToText(String html) {
  final text = html
      .replaceAll(_htmlDropped, '')
      .replaceAll(_htmlBreak, '\n')
      .replaceAll(_htmlTag, ' ')
      .replaceAllMapped(_numericEntity, (m) {
        final code = m[1]!;
        return String.fromCharCode(
          code[0].toLowerCase() == 'x'
              ? int.parse(code.substring(1), radix: 16)
              : int.parse(code),
        );
      });
  // &amp; last, so an escaped entity (`&amp;lt;`) is not decoded twice
  final decoded = _namedEntities.entries
      .fold(text, (s, e) => s.replaceAll(e.key, e.value))
      .replaceAll('&amp;', '&');
  return decoded
      .split('\n')
      .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
      .where((line) => line.isNotEmpty)
      .join('\n');
}
