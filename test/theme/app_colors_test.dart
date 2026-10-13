import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/theme/app_colors.dart';

void main() {
  test('light neutrals equal the DESIGN.md section 3 table', () {
    final c = AppColors.light();
    expect(c.bg, const Color(0xFFF7F1E8));
    expect(c.surface, const Color(0xFFFEFAEF));
    expect(c.surface2, const Color(0xFFEEE6DC));
    expect(c.hair, const Color(0xFFE6DED3));
    expect(c.ink, const Color(0xFF1E2427));
    expect(c.ink2, const Color(0xFF4A4741));
    expect(c.ink3, const Color(0xFF5A5958));
    expect(c.ink4, const Color(0xFFA8A5A0));
    expect(c.track, const Color(0xFFD9D0C3));
  });

  test('dark neutrals equal the DESIGN.md section 3 table', () {
    final c = AppColors.dark();
    expect(c.bg, const Color(0xFF101418));
    expect(c.surface, const Color(0xFF1A1F24));
    expect(c.surface2, const Color(0xFF242A30));
    expect(c.hair, const Color(0xFF2E353C));
    expect(c.ink, const Color(0xFFF7F1E8));
    expect(c.ink2, const Color(0xFFD3D1CE));
    expect(c.ink3, const Color(0xFFA8A5A0));
    expect(c.ink4, const Color(0xFF5A5958));
    expect(c.track, const Color(0xFF39424A));
  });

  test('state colours equal the DESIGN.md section 3 state table', () {
    final light = AppColors.light();
    expect(light.thriving, const Color(0xFF2A72DE));
    expect(light.thrivingInk, const Color(0xFF2056A6));
    expect(light.good, const Color(0xFF5C6F5D));
    expect(light.goodInk, const Color(0xFF4C5E4D));
    expect(light.watch, const Color(0xFFAF751B));
    expect(light.watchInk, const Color(0xFF86570F));
    expect(light.care, const Color(0xFFD22C15));
    expect(light.careInk, const Color(0xFFB32410));

    final dark = AppColors.dark();
    expect(dark.thriving, const Color(0xFF7FB0F5));
    expect(dark.good, const Color(0xFFA3BBA4));
    expect(dark.watch, const Color(0xFFE0B060));
    expect(dark.care, const Color(0xFFF58A78));
    expect(dark.thrivingInk, dark.thriving);
    expect(dark.goodInk, dark.good);
    expect(dark.watchInk, dark.watch);
    expect(dark.careInk, dark.care);
  });

  for (final c in [AppColors.light(), AppColors.dark()]) {
    final mode = c.brightness.name;

    test('$mode: neutrals are opaque', () {
      for (final color in [c.bg, c.surface, c.surface2, c.hair, c.ink, c.ink2, c.ink3, c.ink4, c.track]) {
        expect(color.a, 1.0);
      }
    });

    test('$mode: fill, red and dangerInk alias the neutrals and care', () {
      expect(c.fill, c.surface2);
      expect(c.red, c.care);
      expect(c.dangerInk, c.careInk);
    });
  }

  test('scrim and shadow are kept', () {
    final light = AppColors.light();
    final dark = AppColors.dark();
    expect(light.scrim.a, closeTo(0.40, 0.001));
    expect(dark.scrim.a, closeTo(0.40, 0.001));
    expect(light.shadow.a, lessThan(dark.shadow.a));
  });

  test('ring colours keep the values the area hues had', () {
    final light = AppColors.light();
    final dark = AppColors.dark();
    expect(light.ringMove, const Color(0xFF34C759));
    expect(light.ringRoutines, const Color(0xFFAF52DE));
    expect(dark.ringMove, const Color(0xFF30D158));
    expect(dark.ringRoutines, const Color(0xFFBF5AF2));
  });

  test('copyWith(brightness:) returns the other palette', () {
    final dark = AppColors.light().copyWith(brightness: Brightness.dark);
    final ref = AppColors.dark();
    expect(dark.brightness, Brightness.dark);
    expect(dark.bg, ref.bg);
    expect(dark.ink, ref.ink);
    expect(dark.care, ref.care);
    expect(dark.ringMove, ref.ringMove);
    expect(dark.ringRoutines, ref.ringRoutines);

    final light = ref.copyWith(brightness: Brightness.light);
    expect(light.brightness, Brightness.light);
    expect(light.bg, AppColors.light().bg);
    expect(ref.copyWith().bg, ref.bg);
  });

  test('lerp at 0 and 1 keeps the state, track and ring tokens', () {
    final a = AppColors.light();
    final b = AppColors.dark();
    List<Color> tokens(AppColors c) => [
          c.track,
          c.thriving, c.good, c.watch, c.care,
          c.thrivingInk, c.goodInk, c.watchInk, c.careInk,
          c.ringMove, c.ringRoutines,
        ];
    expect(tokens(a.lerp(b, 0)), tokens(a));
    expect(tokens(a.lerp(b, 1)), tokens(b));
  });

  test('lerp interpolates between the palettes', () {
    final a = AppColors.light();
    final b = AppColors.dark();
    final mid = a.lerp(b, 0.5);
    expect(mid.shadow, Color.lerp(a.shadow, b.shadow, 0.5));
    expect(mid.care, Color.lerp(a.care, b.care, 0.5));
    expect(mid.track, Color.lerp(a.track, b.track, 0.5));
    expect(mid.ringMove, Color.lerp(a.ringMove, b.ringMove, 0.5));
    expect(mid.ringRoutines, Color.lerp(a.ringRoutines, b.ringRoutines, 0.5));
  });
}
