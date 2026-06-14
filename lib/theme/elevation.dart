import 'package:flutter/painting.dart';

/// Elevation presets. Pass the themed shadow color (`context.colors.shadow`):
/// shadows vary by mode, so the color is not baked in.
///   boxShadow: Elevation.card(context.colors.shadow)
class Elevation {
  Elevation._();

  static List<BoxShadow> sm(Color color) =>
      [BoxShadow(color: color, blurRadius: 8, offset: const Offset(0, 2))];

  static List<BoxShadow> card(Color color) =>
      [BoxShadow(color: color, blurRadius: 16, offset: const Offset(0, 6))];

  static List<BoxShadow> fab(Color color) =>
      [BoxShadow(color: color, blurRadius: 24, offset: const Offset(0, 8))];
}
