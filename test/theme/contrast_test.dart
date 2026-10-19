import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/theme/app_colors.dart';
import 'package:opal/theme/contrast.dart';
import 'package:opal/theme/scene_palette.dart';

const double _text = 4.5;
const double _nonText = 3.0;
// neighbouring rings stay apart without hue. DESIGN.md section 3.
const double _ringLightness = 1.5;

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

    // every pair below the bar, so one run names them all.
    void expectOnGrounds(Map<String, Color> colors, double min) {
      final short = [
        for (final MapEntry(key: name, value: color) in colors.entries)
          for (final MapEntry(key: groundName, value: ground) in grounds.entries)
            if (contrastRatio(color, ground) < min)
              '$name on $groundName is ${contrastRatio(color, ground).toStringAsFixed(2)}',
      ];
      expect(short, isEmpty);
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

    test('$mode: dangerInk reaches 4.5:1 on surface', () {
      expect(contrastRatio(c.dangerInk, c.surface), greaterThanOrEqualTo(_text));
    });

    test('$mode: the ring colours differ in lightness by 1.5:1 or more', () {
      final ratio = contrastRatio(c.ringMove, c.ringRoutines);
      expect(ratio, greaterThanOrEqualTo(_ringLightness),
          reason: 'ringMove against ringRoutines is ${ratio.toStringAsFixed(2)}');
    });

    for (final phase in DayPhase.values) {
      test('$mode: ink reaches 4.5:1 on the ${phase.name} sky and hills', () {
        final p = scenePalette(phase, c.brightness);
        expect(p.sky.length, p.skyStops.length);
        final short = [
          for (final ground in [...p.sky, p.far, p.mid, p.near])
            if (contrastRatio(c.ink, ground) < _text)
              '$ground is ${contrastRatio(c.ink, ground).toStringAsFixed(2)}',
        ];
        expect(short, isEmpty);
      });
    }
  }
}
