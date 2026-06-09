import 'package:flutter/widgets.dart';

/// Typography helpers mirroring the handoff's SF Pro usage.
///
/// On iOS the default family resolves to San Francisco automatically, so we
/// intentionally leave `fontFamily` null. `sfr` (SF Pro Rounded) has no
/// cross-platform equivalent; on iOS we approximate with the system font +
/// tabular figures, and a rounded face can be bundled later for full fidelity.
class AppFonts {
  AppFonts._();

  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  /// SF Pro Text / Display.
  static TextStyle sf({
    required double size,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double letterSpacing = 0,
    double? height,
    bool tabular = false,
  }) =>
      TextStyle(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
        fontFeatures: tabular ? _tabular : null,
      );

  /// SF Pro Rounded — used for amounts, counts, timers (always tabular).
  static TextStyle sfr({
    required double size,
    FontWeight weight = FontWeight.w700,
    Color? color,
    double letterSpacing = 0,
    double? height,
  }) =>
      TextStyle(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
        fontFeatures: _tabular,
      );

  /// SF Mono — timestamps, eyebrows.
  static TextStyle mono({
    required double size,
    FontWeight weight = FontWeight.w500,
    Color? color,
    double letterSpacing = 0.5,
  }) =>
      TextStyle(
        fontFamily: 'monospace',
        fontFamilyFallback: const ['Menlo', 'Courier New'],
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        fontFeatures: _tabular,
      );
}
