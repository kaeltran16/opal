import 'package:flutter/widgets.dart';

import 'app_text.dart';

/// Named type ramp built on [AppFonts]. Theme-invariant: NO color baked in.
/// Apply color at the call site (`AppType.body.copyWith(color: context.colors.ink)`)
/// or let it inherit from the app-level DefaultTextStyle.
class AppType {
  AppType._();

  static final TextStyle caption = AppFonts.sf(size: 12);
  static final TextStyle subhead = AppFonts.sf(size: 15, letterSpacing: -0.23);
  static final TextStyle callout = AppFonts.sf(size: 16);
  static final TextStyle body = AppFonts.sf(size: 17, letterSpacing: -0.43);
  static final TextStyle headline =
      AppFonts.sf(size: 17, weight: FontWeight.w600, letterSpacing: -0.43);

  // DESIGN.md section 4. large numbers are light; emphasis comes from size.
  static final TextStyle display = AppFonts.sf(
      size: 64, weight: FontWeight.w300, letterSpacing: -1.6, height: 68 / 64, tabular: true);
  static final TextStyle score = AppFonts.sf(
      size: 40, weight: FontWeight.w300, letterSpacing: -0.8, height: 44 / 40, tabular: true);
  // the serif: pal's lead line on today and nothing else.
  static const TextStyle lead = TextStyle(
    fontFamily: serifFamily,
    fontSize: 30,
    fontWeight: FontWeight.w300,
    letterSpacing: -0.6,
    height: 36 / 30,
  );
  static final TextStyle title =
      AppFonts.sf(size: 22, weight: FontWeight.w500, letterSpacing: -0.4, height: 27 / 22);
  static final TextStyle label =
      AppFonts.sf(size: 13, weight: FontWeight.w500, letterSpacing: 0.3, height: 18 / 13);

  /// The bundled serif, declared in pubspec.yaml.
  static const String serifFamily = 'Newsreader';
}
