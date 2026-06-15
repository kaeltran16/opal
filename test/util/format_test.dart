import 'package:flutter_test/flutter_test.dart';
import 'package:opal/util/format.dart';

void main() {
  // The signed form uses the minus glyph U+2212 ('−'), not ASCII '-'.
  const minus = '−';

  group('formatWeight', () {
    test('drops a trailing .0 but keeps real fractions', () {
      expect(formatWeight(50.0), '50');
      expect(formatWeight(92.5), '92.5');
      expect(formatWeight(0), '0');
    });
  });

  group('formatCurrency — USD (leading symbol, 2 decimals)', () {
    test('trims .00 on whole amounts by default', () {
      expect(formatCurrency(12, Currency.usd), '\$12');
    });

    test('keeps cents when present', () {
      expect(formatCurrency(12.5, Currency.usd), '\$12.50');
    });

    test('trimZeroCents: false keeps the .00 tail', () {
      expect(
        formatCurrency(12, Currency.usd, trimZeroCents: false),
        '\$12.00',
      );
    });

    test('groups thousands with a comma', () {
      expect(formatCurrency(1234567.89, Currency.usd), '\$1,234,567.89');
    });

    test('withSign prefixes the minus glyph for negatives only', () {
      expect(formatCurrency(-4, Currency.usd, withSign: true), '$minus\$4');
      // default (no sign) renders the magnitude only.
      expect(formatCurrency(-4, Currency.usd), '\$4');
      expect(formatCurrency(4, Currency.usd, withSign: true), '\$4');
    });
  });

  group('formatCurrency — VND (trailing symbol, 0 decimals, dot grouping)', () {
    // Build the expected glyph from the enum so the exact symbol always
    // matches; the trailing symbol is joined with a non-breaking space (U+00A0).
    final d = Currency.vnd.symbol;
    const nbsp = ' ';

    test('renders no decimals with a trailing symbol', () {
      expect(formatCurrency(50000, Currency.vnd), '50.000$nbsp$d');
    });

    test('groups thousands with a dot', () {
      expect(formatCurrency(1234567, Currency.vnd), '1.234.567$nbsp$d');
    });

    test('rounds fractional input away (0 decimals)', () {
      expect(formatCurrency(50000.7, Currency.vnd), '50.001$nbsp$d');
    });

    test('withSign prefixes the minus glyph', () {
      expect(
        formatCurrency(-50000, Currency.vnd, withSign: true),
        '${minus}50.000$nbsp$d',
      );
    });
  });

  group('Currency.fromCode', () {
    test('resolves known codes', () {
      expect(Currency.fromCode('USD'), Currency.usd);
      expect(Currency.fromCode('VND'), Currency.vnd);
    });

    test('falls back to USD for null or unknown codes', () {
      expect(Currency.fromCode(null), Currency.usd);
      expect(Currency.fromCode('EUR'), Currency.usd);
      expect(Currency.fromCode(''), Currency.usd);
    });
  });
}
