import 'package:flutter/painting.dart';

/// Elevation presets. Pass the themed shadow color (`context.colors.shadow`):
/// shadows vary by mode, so the color is not baked in.
///   boxShadow: Elevation.fab(context.colors.shadow)
class Elevation {
  Elevation._();

  static List<BoxShadow> fab(Color color) =>
      [BoxShadow(color: color, blurRadius: 24, offset: const Offset(0, 8))];
}
