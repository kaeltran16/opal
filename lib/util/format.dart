/// Renders a weight without a trailing ".0" (e.g. 50.0 -> "50", 92.5 -> "92.5").
String formatWeight(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
