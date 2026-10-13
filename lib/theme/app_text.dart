import 'package:flutter/widgets.dart';

/// Typography helpers mirroring the handoff's SF Pro usage.
///
/// On iOS the default family resolves to San Francisco automatically, so we
/// intentionally leave `fontFamily` null.
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
}
