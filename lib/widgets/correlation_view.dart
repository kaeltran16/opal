import 'dart:math' show max;

import '../analysis/correlations.dart';

/// A breakdown group's display data: label, formatted value, and proportional
/// bar fraction in [0,1] where 1.0 == the larger mean.
class CompareItem {
  const CompareItem({
    required this.label,
    required this.value,
    required this.frac,
  });

  final String label;
  final String value;

  /// Proportion of the larger mean (always [0,1]; larger group == 1.0).
  final double frac;
}

/// Pure presentation helper wrapping a [Correlation].
///
/// Maps engine data to named display sections consumed by CorrelationCard and
/// the trust sheet. No Flutter dependency — everything is plain Dart strings,
/// doubles, and records.
class CorrelationView {
  const CorrelationView(this.correlation);

  final Correlation correlation;

  // ---------------------------------------------------------------------------
  // Title

  /// Title-cased dimension nouns joined with ' × ', e.g. 'Sleep × Spending'.
  String get pairLabel {
    return '${_titleCase(dimensionNoun(correlation.a))} × '
        '${_titleCase(dimensionNoun(correlation.b))}';
  }

  // ---------------------------------------------------------------------------
  // Comparison bars (only when breakdown is present)

  /// The active/highlighted group (e.g. "After short nights"). Null when no breakdown.
  CompareItem? get compareLow {
    final bd = correlation.breakdown;
    if (bd == null) return null;
    return CompareItem(
      label: 'After ${activeDayLabel(bd.binaryDim)}',
      value: formatValue(bd.continuousDim, bd.meanWhenActive),
      frac: _frac(bd.meanWhenActive, bd.meanWhenInactive),
    );
  }

  /// The inactive group (e.g. "After other nights"). Null when no breakdown.
  CompareItem? get compareHigh {
    final bd = correlation.breakdown;
    if (bd == null) return null;
    return CompareItem(
      label: 'After ${inactiveDayLabel(bd.binaryDim)}',
      value: formatValue(bd.continuousDim, bd.meanWhenInactive),
      frac: _frac(bd.meanWhenInactive, bd.meanWhenActive),
    );
  }

  // ---------------------------------------------------------------------------
  // Stats rows

  /// Labeled value pairs for the stats table.
  ///
  /// Each record is `(label, value)`. Non-empty only when breakdown is present.
  /// Rows: active count, inactive count, and optionally a ratio difference row
  /// (omitted when meanWhenInactive == 0 to avoid divide-by-zero).
  List<(String, String)> get numbers {
    final bd = correlation.breakdown;
    if (bd == null) return const [];

    final rows = <(String, String)>[
      (
        '${bd.countActive} ${activeDayLabel(bd.binaryDim)}',
        formatValue(bd.continuousDim, bd.meanWhenActive),
      ),
      (
        '${bd.countInactive} ${inactiveDayLabel(bd.binaryDim)}',
        formatValue(bd.continuousDim, bd.meanWhenInactive),
      ),
    ];

    if (bd.meanWhenInactive != 0) {
      final ratio = (bd.meanWhenActive / bd.meanWhenInactive).toStringAsFixed(1);
      rows.add(('Difference', '${ratio}×'));
    }

    return rows;
  }

  // ---------------------------------------------------------------------------
  // Footer / provenance

  /// Data provenance line. Always contains 'last ${n} days'.
  String get source {
    final n = correlation.n;
    final hasSleep = correlation.involves(Dimension.sleep);
    if (hasSleep) {
      return 'Apple Health + computed from your data · last $n days';
    }
    return 'Computed from your data · last $n days';
  }

  /// Honest context note explaining why Opal surfaces this.
  String get why =>
      "Opal shows this because it held across enough days to be more than "
      "noise — an observation about two things moving together, not a cause.";

  // ---------------------------------------------------------------------------
  // Body copy (visual emphasis is the card's responsibility)

  /// The factual summary sentence from the engine.
  String get line => correlation.summary;

  /// Same as [line]; kept as a separate getter so the card can apply different
  /// typographic weight to the claim independently.
  String get claim => correlation.summary;

  // ---------------------------------------------------------------------------
  // Helpers

  /// Returns this item's fraction of the larger mean; 0 when both are zero.
  static double _frac(double own, double other) {
    final larger = max(own, other);
    return larger == 0 ? 0 : own / larger;
  }

  static String _titleCase(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
