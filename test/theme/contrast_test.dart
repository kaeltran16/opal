import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/theme/app_colors.dart';
import 'package:opal/theme/contrast.dart';
import 'package:opal/theme/scene_palette.dart';

const double _text = 4.5;
const double _nonText = 3.0;

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

  for (final c in [AppColors.light(), AppColors.dark()]) {
    final mode = c.brightness.name;
    final grounds = {'bg': c.bg, 'surface': c.surface, 'surface2': c.surface2};

    void expectOnGrounds(Map<String, Color> colors, double min) {
      colors.forEach((name, color) {
        grounds.forEach((groundName, ground) {
          final ratio = contrastRatio(color, ground);
          expect(ratio, greaterThanOrEqualTo(min),
              reason: '$name on $groundName is ${ratio.toStringAsFixed(2)}');
        });
      });
    }

    test('$mode: state inks reach 4.5:1 on every ground', () {
      expectOnGrounds({
        'thrivingInk': c.thrivingInk,
        'goodInk': c.goodInk,
        'watchInk': c.watchInk,
        'careInk': c.careInk,
      }, _text);
    });

    test('$mode: state fills reach 3:1 on every ground', () {
      expectOnGrounds({
        'thriving': c.thriving,
        'good': c.good,
        'watch': c.watch,
        'care': c.care,
      }, _nonText);
    });

    test('$mode: ink, ink2 and ink3 reach 4.5:1 on every ground', () {
      expectOnGrounds({'ink': c.ink, 'ink2': c.ink2, 'ink3': c.ink3}, _text);
    });

    test('$mode: onAccent reaches 4.5:1 on accent', () {
      expect(contrastRatio(c.onAccent, c.accent), greaterThanOrEqualTo(_text));
    });

    test('$mode: dangerInk reaches 4.5:1 on surface', () {
      expect(contrastRatio(c.dangerInk, c.surface), greaterThanOrEqualTo(_text));
    });

    test('$mode: every area ink reaches 4.5:1 on its tint over surface', () {
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
        final ground = composite(p.$2, c.surface);
        final ratio = contrastRatio(p.$1, ground);
        expect(ratio, greaterThanOrEqualTo(_text),
            reason: '$name is ${ratio.toStringAsFixed(2)}');
      });
    });

    for (final phase in DayPhase.values) {
      test('$mode: ink reaches 4.5:1 on the ${phase.name} sky and hills', () {
        final p = scenePalette(phase, c.brightness);
        expect(p.sky.length, p.skyStops.length);
        for (final ground in [...p.sky, p.far, p.mid, p.near]) {
          final ratio = contrastRatio(c.ink, ground);
          expect(ratio, greaterThanOrEqualTo(_text),
              reason: '$ground is ${ratio.toStringAsFixed(2)}');
        }
      });
    }
  }
}
