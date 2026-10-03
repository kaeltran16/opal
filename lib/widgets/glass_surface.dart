import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/providers.dart';
import '../theme/theme.dart';

/// Liquid Glass chrome: a blurred, saturated, translucent capsule. Only for
/// the tab bar, the ask bar, sheets and the collapsed top edge bar, never for
/// cards or list content, so at most four [BackdropFilter]s are on screen.
///
/// Reduce Transparency swaps it for a solid `surface` with a hairline border;
/// high contrast adds an opaque fill and a stronger border. Both drop the blur.
class GlassSurface extends ConsumerWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(Radii.pill)),
    this.padding,
  });

  /// The single knob for the manual on-device raster check.
  static const double blurSigma = 30;

  static const double _saturation = 1.8;
  static const double _border = 1.0;
  static const double _hairline = 0.5;
  static const double _highContrastBorder = 1.0;
  static const double _highlightHeight = 1;

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final content = padding == null
        ? child
        : Padding(padding: padding!, child: child);

    if (MediaQuery.highContrastOf(context)) {
      return _solid(
        c,
        content,
        BorderSide(color: c.ink3, width: _highContrastBorder),
      );
    }
    // off until the platform answers, so the first frame never flashes solid.
    if (ref.watch(reduceTransparencyProvider).value ?? false) {
      return _solid(c, content, BorderSide(color: c.hair, width: _hairline));
    }

    // the shadow sits outside the clip so the rounded edge doesn't cut it off.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: Elevation.fab(c.shadow),
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.compose(
            outer: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            inner: ColorFilter.matrix(_saturationMatrix(_saturation)),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: c.glass,
              borderRadius: borderRadius,
              border: Border.all(color: c.glassBorder, width: _border),
            ),
            child: Stack(
              children: [
                content,
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SizedBox(
                    height: _highlightHeight,
                    child: ColoredBox(color: c.glassHighlight),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _solid(AppColors c, Widget content, BorderSide side) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: borderRadius,
        border: Border.fromBorderSide(side),
        boxShadow: Elevation.card(c.shadow),
      ),
      child: content,
    );
  }
}

// rec. 709 luma weights keep perceived brightness while boosting chroma.
List<double> _saturationMatrix(double s) {
  const r = 0.2126, g = 0.7152, b = 0.0722;
  final t = 1 - s;
  // dart format off
  return [
    r * t + s, g * t,     b * t,     0, 0,
    r * t,     g * t + s, b * t,     0, 0,
    r * t,     g * t,     b * t + s, 0, 0,
    0,         0,         0,         1, 0,
  ];
  // dart format on
}
