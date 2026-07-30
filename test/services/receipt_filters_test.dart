import 'package:flutter_test/flutter_test.dart';
import 'package:opal/services/email/receipt_filters.dart';

class _Sender {
  const _Sender(this.from, this.fromName);
  final String from;
  final String fromName;
}

List<_Sender> _filter(List<_Sender> emails, List<String> filters) =>
    filterBySender(
      emails,
      filters,
      from: (e) => e.from,
      fromName: (e) => e.fromName,
    );

void main() {
  group('redactPii', () {
    test('masks email addresses', () {
      expect(
        redactPii('contact user@example.com for help'),
        'contact [email] for help',
      );
    });

    test('masks a card number ahead of the long-number rule', () {
      expect(redactPii('paid with 4111111111111111'), 'paid with [card]');
      expect(redactPii('card 4111 1111 1111 1111 ok'), 'card [card] ok');
    });

    test('masks phone numbers and long order numbers', () {
      expect(redactPii('call 555-123-4567'), 'call [phone]');
      expect(redactPii('order 1234567890'), 'order [number]');
    });

    test('leaves amounts, merchants and dates intact', () {
      const body = 'GrabFood total 45,000d on 06 Jan 2026 11:27';
      expect(redactPii(body), body);
    });

    test('is idempotent, so the worker re-applying it is safe', () {
      const dirty = 'user@example.com paid 4111111111111111';
      final once = redactPii(dirty);
      expect(redactPii(once), once);
    });
  });

  group('isLikelyNonReceipt', () {
    test('drops promotional and logistics mail', () {
      expect(
        isLikelyNonReceipt(subject: 'Deal', text: 'click to unsubscribe'),
        isTrue,
      );
      expect(
        isLikelyNonReceipt(subject: '50% off everything', text: 'shop now'),
        isTrue,
      );
      expect(
        isLikelyNonReceipt(subject: 'Update', text: 'Your order has shipped'),
        isTrue,
      );
      expect(
        isLikelyNonReceipt(subject: 'Refund issued', text: 'we refund you'),
        isTrue,
      );
    });

    test('drops Vietnamese promo wording in the subject', () {
      expect(
        isLikelyNonReceipt(subject: 'Khuyến mãi hôm nay', text: 'xin chào'),
        isTrue,
      );
    });

    test('keeps a Vietnamese discount line inside a real receipt body', () {
      // "giảm giá" is a legitimate line item on a food-delivery receipt, so it
      // must only be a promo signal in the subject.
      expect(
        isLikelyNonReceipt(
          subject: 'Hóa đơn GrabFood',
          text: 'Tổng cộng 45.000d\ngiảm giá 5.000d',
        ),
        isFalse,
      );
    });

    test('keeps a paid order confirmation', () {
      expect(
        isLikelyNonReceipt(
          subject: 'Order confirmation #A12',
          text: 'Total charged 250,000d',
        ),
        isFalse,
      );
    });
  });

  group('filterBySender', () {
    const grab = _Sender('no-reply@grab.com', 'Grab');
    const spam = _Sender('news@promo.io', 'Promo');

    test('keeps everything when no filters are configured', () {
      expect(_filter([grab, spam], []), [grab, spam]);
    });

    test('ignores blank filter entries', () {
      expect(_filter([grab, spam], ['  ', '']), [grab, spam]);
    });

    test('matches address or display name, case insensitively', () {
      expect(_filter([grab, spam], ['GRAB.COM']), [grab]);
      expect(_filter([grab, spam], ['grab']), [grab]);
    });

    test('drops senders that match nothing', () {
      expect(_filter([grab, spam], ['shopee']), isEmpty);
    });
  });

  group('boundText', () {
    test('leaves short text unchanged', () {
      expect(boundText('abc', kMaxBodyChars), 'abc');
    });

    test('truncates to the wire bound', () {
      final long = 'x' * (kMaxBodyChars + 100);
      expect(boundText(long, kMaxBodyChars).length, kMaxBodyChars);
    });
  });
}
