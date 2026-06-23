/// Renders a weight without a trailing ".0" (e.g. 50.0 -> "50", 92.5 -> "92.5").
String formatWeight(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

/// A display currency. Amounts are stored as raw numbers in the user's chosen
/// currency — switching currency changes formatting only, never stored values
/// (there is no FX conversion). [budgetScale] scales the budget editor's presets
/// and steps so a VND budget offers sane magnitudes (VND ≈ 1000× USD), and
/// [code] is the stable token persisted in settings.
enum Currency {
  usd(
    code: 'USD',
    label: 'US Dollar',
    symbol: '\$',
    symbolBefore: true,
    decimals: 2,
    groupSeparator: ',',
    decimalSeparator: '.',
    budgetScale: 1,
  ),
  vnd(
    code: 'VND',
    label: 'Vietnamese Dong',
    symbol: '₫',
    symbolBefore: false,
    decimals: 0,
    groupSeparator: '.',
    decimalSeparator: ',',
    budgetScale: 1000,
  );

  const Currency({
    required this.code,
    required this.label,
    required this.symbol,
    required this.symbolBefore,
    required this.decimals,
    required this.groupSeparator,
    required this.decimalSeparator,
    required this.budgetScale,
  });

  /// Stable ISO-ish token persisted in settings (survives enum reordering).
  final String code;

  /// Human-readable name for the currency picker.
  final String label;

  /// Currency glyph ('$', '₫').
  final String symbol;

  /// Whether the symbol leads the number ($12) or trails it (12 ₫).
  final bool symbolBefore;

  /// Fractional digits the currency uses (USD 2, VND 0).
  final int decimals;

  /// Thousands separator.
  final String groupSeparator;

  /// Decimal mark.
  final String decimalSeparator;

  /// Multiplier applied to USD-centric budget presets/steps so the budget
  /// editor stays usable in this currency.
  final int budgetScale;

  static Currency fromCode(String? code) => values.firstWhere(
        (c) => c.code == code,
        orElse: () => Currency.usd,
      );

  /// Wire descriptor sent to the Pal proxy so the server renders money in this
  /// currency. Mirrors [formatCurrency]'s inputs; omits the UI-only budgetScale.
  Map<String, Object?> toWire() => {
        'symbol': symbol,
        'symbolBefore': symbolBefore,
        'decimals': decimals,
        'group': groupSeparator,
        'decimal': decimalSeparator,
      };
}

/// Formats [amount] in [currency]: groups thousands, places the symbol per the
/// currency's convention, and renders decimals. For currencies with cents,
/// [trimZeroCents] drops a ".00" tail on whole amounts ($12, not $12.00) while
/// keeping cents when present ($12.50). [withSign] prefixes a minus glyph for
/// negative amounts (the magnitude is formatted regardless).
String formatCurrency(
  num amount,
  Currency currency, {
  bool trimZeroCents = true,
  bool withSign = false,
}) {
  final negative = amount < 0;
  final abs = amount.abs();
  final isWhole = abs == abs.roundToDouble();
  final decimals =
      (currency.decimals > 0 && !(trimZeroCents && isWhole)) ? currency.decimals : 0;
  final fixed = abs.toStringAsFixed(decimals);

  final dotSplit = fixed.split('.');
  final whole = groupThousands(dotSplit[0], currency.groupSeparator);
  final number = dotSplit.length > 1
      ? '$whole${currency.decimalSeparator}${dotSplit[1]}'
      : whole;

  // trailing symbol reads "12 ₫"; leading reads "$12"
  final body = currency.symbolBefore
      ? '${currency.symbol}$number'
      : '$number ${currency.symbol}';
  return withSign && negative ? '−$body' : body;
}

/// Inserts [sep] every three digits from the right ("2500000" -> "2.500.000").
String groupThousands(String digits, String sep) {
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(sep);
    buf.write(digits[i]);
  }
  return buf.toString();
}
