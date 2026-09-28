import 'dart:math' as math;
import 'dart:ui';

/// WCAG 2.x contrast ratio between two opaque colors, from 1 to 21.
/// Composite translucent colors onto their background with [composite] first.
double contrastRatio(Color fg, Color bg) {
  final a = _luminance(fg);
  final b = _luminance(bg);
  final hi = math.max(a, b);
  final lo = math.min(a, b);
  return (hi + 0.05) / (lo + 0.05);
}

/// Source-over blend of [top] onto [bottom].
Color composite(Color top, Color bottom) {
  final a = top.a + bottom.a * (1 - top.a);
  if (a == 0) return const Color(0x00000000);
  double ch(double t, double b) => (t * top.a + b * bottom.a * (1 - top.a)) / a;
  return Color.from(
    alpha: a,
    red: ch(top.r, bottom.r),
    green: ch(top.g, bottom.g),
    blue: ch(top.b, bottom.b),
  );
}

double _luminance(Color c) {
  double lin(double v) => v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
}
