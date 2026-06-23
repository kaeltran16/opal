import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/theme/app_colors.dart';

void main() {
  test('light/dark carry onAccent, scrim, shadow', () {
    final light = AppColors.light(AppAccent.blue);
    final dark = AppColors.dark(AppAccent.blue);
    expect(light.onAccent, const Color(0xFFFFFFFF));
    expect(dark.onAccent, const Color(0xFFFFFFFF));
    expect(light.scrim.a, closeTo(0.40, 0.001));
    expect(dark.scrim.a, closeTo(0.40, 0.001));
    expect(light.shadow.a, lessThan(dark.shadow.a));
  });

  test('copyWith preserves the new tokens across brightness flip', () {
    final dark = AppColors.light(AppAccent.blue).copyWith(brightness: Brightness.dark);
    expect(dark.onAccent, const Color(0xFFFFFFFF));
    expect(dark.scrim.a, closeTo(0.40, 0.001));
  });

  test('lerp interpolates the new tokens', () {
    final a = AppColors.light(AppAccent.blue);
    final b = AppColors.dark(AppAccent.blue);
    final mid = a.lerp(b, 0.5);
    expect(mid.shadow, Color.lerp(a.shadow, b.shadow, 0.5));
    expect(mid.scrim, Color.lerp(a.scrim, b.scrim, 0.5));
  });

  test('light/dark expose teal nutrition token', () {
    expect(AppColors.light(AppAccent.indigo).nutrition, const Color(0xFF0FB5C9));
    expect(AppColors.dark(AppAccent.indigo).nutrition, const Color(0xFF3FD0E0));
  });

  test('forType routes nutrition + copyWith/lerp keep the token', () {
    final c = AppColors.light(AppAccent.indigo);
    expect(c.forType('nutrition'), c.nutrition);
    expect(c.copyWith(accent: const Color(0xFF000000)).nutrition, c.nutrition);
    final mixed = c.lerp(AppColors.dark(AppAccent.indigo), 1.0);
    expect(mixed.nutrition, const Color(0xFF3FD0E0));
  });

  test('sleep & mood tokens resolve via forType in both brightnesses', () {
    final light = AppColors.light(AppAccent.blue);
    final dark = AppColors.dark(AppAccent.blue);
    expect(light.forType('sleep'), const Color(0xFF5B6CDB));
    expect(light.forType('mood'), const Color(0xFF2FA6BC));
    expect(dark.forType('sleep'), const Color(0xFF8491F0));
    expect(dark.forType('mood'), const Color(0xFF56C2DA));
  });

  test('lerp interpolates sleep & mood tokens', () {
    final a = AppColors.light(AppAccent.blue);
    final b = AppColors.dark(AppAccent.blue);
    final mid = a.lerp(b, 0.5) as AppColors;
    expect(mid.sleep, isNot(a.sleep)); // proves sleep is in lerp
    expect(mid.mood, isNot(a.mood));
  });
}
