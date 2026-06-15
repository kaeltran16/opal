import 'package:flutter/widgets.dart';

import 'app_text.dart';

/// Named type ramp built on [AppFonts]. Theme-invariant: NO color baked in.
/// Apply color at the call site (`AppType.body.copyWith(color: context.colors.ink)`)
/// or let it inherit from the app-level DefaultTextStyle.
class AppType {
  AppType._();

  static final TextStyle caption2 = AppFonts.sf(size: 11);
  static final TextStyle caption = AppFonts.sf(size: 12);
  static final TextStyle footnote = AppFonts.sf(size: 13);
  static final TextStyle subhead = AppFonts.sf(size: 15, letterSpacing: -0.23);
  static final TextStyle callout = AppFonts.sf(size: 16);
  static final TextStyle body = AppFonts.sf(size: 17, letterSpacing: -0.43);
  static final TextStyle headline =
      AppFonts.sf(size: 17, weight: FontWeight.w600, letterSpacing: -0.43);
  static final TextStyle title3 = AppFonts.sf(size: 20, weight: FontWeight.w600);
  static final TextStyle title2 = AppFonts.sf(size: 22, weight: FontWeight.w700);
  static final TextStyle title1 = AppFonts.sf(size: 28, weight: FontWeight.w700);
  static final TextStyle large = AppFonts.sf(size: 34, weight: FontWeight.w700);

  // Rounded + tabular — amounts, counts, timers.
  static final TextStyle amount = AppFonts.sfr(size: 34);
  static final TextStyle amountLg = AppFonts.sfr(size: 48);

  // Mono — eyebrows, timestamps.
  static final TextStyle eyebrow = AppFonts.mono(size: 12);
}
