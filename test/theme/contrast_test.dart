import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/theme/app_colors.dart';
import 'package:opal/theme/contrast.dart';

void main() {
  test('contrastRatio matches WCAG reference values', () {
    expect(contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)), closeTo(21, 0.01));
    expect(contrastRatio(const Color(0xFF777777), const Color(0xFFFFFFFF)), closeTo(4.48, 0.01));
  });

  test('composite blends source-over', () {
    expect(composite(const Color(0x00000000), const Color(0xFFFFFFFF)), const Color(0xFFFFFFFF));
    expect(composite(const Color(0xFF000000), const Color(0xFFFFFFFF)), const Color(0xFF000000));
    final half = composite(const Color(0x80000000), const Color(0xFFFFFFFF));
    expect(half.a, 1.0);
    expect(half.r, closeTo(0.498, 0.01));
  });

  for (final accent in AppAccent.values) {
    for (final dark in [false, true]) {
      final c = dark ? AppColors.dark(accent) : AppColors.light(accent);
      final mode = dark ? 'dark' : 'light';
      test('${accent.name}/$mode: every ink passes 4.5:1 on its tint over surface', () {
        final pairs = {
          'money': (c.moneyInk, c.moneyTint),
          'move': (c.moveInk, c.moveTint),
          'rituals': (c.ritualsInk, c.ritualsTint),
          'nutrition': (c.nutritionInk, c.nutritionTint),
          'sleep': (c.sleepInk, c.sleepTint),
          'mood': (c.moodInk, c.moodTint),
          'accent': (c.accentInk, c.accentTint),
        };
        pairs.forEach((name, p) {
          final bg = composite(p.$2, c.surface);
          expect(contrastRatio(p.$1, bg), greaterThanOrEqualTo(4.5), reason: name);
        });
      });

      test('${accent.name}/$mode: dangerInk passes 4.5:1 on surface', () {
        expect(contrastRatio(c.dangerInk, c.surface), greaterThanOrEqualTo(4.5));
      });
    }
  }
}
