import 'package:flutter/material.dart';

/// Semantic design tokens from DESIGN.md section 3, exposed as a
/// [ThemeExtension] so any widget can read them via `Theme.of(context)`.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.brightness,
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.ink4,
    required this.hair,
    required this.track,
    required this.blur,
    required this.fill,
    required this.thriving,
    required this.good,
    required this.watch,
    required this.care,
    required this.thrivingInk,
    required this.goodInk,
    required this.watchInk,
    required this.careInk,
    required this.money,
    required this.moneyTint,
    required this.move,
    required this.moveTint,
    required this.rituals,
    required this.ritualsTint,
    required this.nutrition,
    required this.nutritionTint,
    required this.sleep,
    required this.sleepTint,
    required this.mood,
    required this.moodTint,
    required this.accent,
    required this.accentTint,
    required this.moneyInk,
    required this.moveInk,
    required this.ritualsInk,
    required this.nutritionInk,
    required this.sleepInk,
    required this.moodInk,
    required this.accentInk,
    required this.glass,
    required this.glassBorder,
    required this.glassHighlight,
    required this.red,
    required this.dangerInk,
    required this.onAccent,
    required this.scrim,
    required this.shadow,
  });

  final Brightness brightness;
  final Color bg, surface, surface2;
  final Color ink, ink2, ink3, ink4;
  final Color hair, track, blur, fill;
  // state fills, for arcs, bars and dots: 3:1 on every ground.
  final Color thriving, good, watch, care;
  // state text and icons: 4.5:1 on every ground.
  final Color thrivingInk, goodInk, watchInk, careInk;
  final Color money, moneyTint;
  final Color move, moveTint;
  final Color rituals, ritualsTint;
  final Color nutrition, nutritionTint;
  final Color sleep, sleepTint;
  final Color mood, moodTint;
  // the accent is no longer a choice. these alias the neutrals so screens not
  // yet redesigned keep compiling.
  final Color accent, accentTint;
  // text and icons on the matching tint; the area colors fail 4.5:1 there.
  final Color moneyInk, moveInk, ritualsInk, nutritionInk, sleepInk, moodInk;
  final Color accentInk;
  // floating bars only (tab bar, composer).
  final Color glass, glassBorder, glassHighlight;
  final Color red;
  // destructive text and icons on surface; red itself fails 4.5:1 there.
  final Color dangerInk;
  final Color onAccent;
  final Color scrim;
  final Color shadow;

  static const double _glassAlpha = 0.78;
  static const double _blurAlpha = 0.72;

  /// Color for a tracker type token: 'money' | 'move' | 'rituals' | 'nutrition'.
  Color forType(String type) => switch (type) {
        'money' => money,
        'move' => move,
        'rituals' => rituals,
        'nutrition' => nutrition,
        'sleep' => sleep,
        'mood' => mood,
        _ => accent,
      };

  /// Ink for a tracker type token, mirroring [forType].
  Color inkForType(String type) => switch (type) {
        'money' => moneyInk,
        'move' => moveInk,
        'rituals' => ritualsInk,
        'nutrition' => nutritionInk,
        'sleep' => sleepInk,
        'mood' => moodInk,
        _ => accentInk,
      };

  factory AppColors.light() {
    const bg = Color(0xFFF7F1E8);
    const surface = Color(0xFFFEFAEF);
    const surface2 = Color(0xFFEEE6DC);
    const ink = Color(0xFF1E2427);
    const hair = Color(0xFFE6DED3);
    const care = Color(0xFFD22C15);
    const careInk = Color(0xFFB32410);
    return AppColors(
      brightness: Brightness.light,
      bg: bg,
      surface: surface,
      surface2: surface2,
      ink: ink,
      ink2: const Color(0xFF4A4741),
      ink3: const Color(0xFF5A5958),
      ink4: const Color(0xFFA8A5A0),
      hair: hair,
      track: const Color(0xFFD9D0C3),
      blur: bg.withValues(alpha: _blurAlpha),
      fill: surface2,
      thriving: const Color(0xFF2A72DE),
      good: const Color(0xFF5C6F5D),
      watch: const Color(0xFFAF751B),
      care: care,
      thrivingInk: const Color(0xFF2056A6),
      goodInk: const Color(0xFF4C5E4D),
      watchInk: const Color(0xFF86570F),
      careInk: careInk,
      money: const Color(0xFFFF9500),
      moneyTint: const Color.fromRGBO(255, 149, 0, 0.14),
      move: const Color(0xFF34C759),
      moveTint: const Color.fromRGBO(52, 199, 89, 0.14),
      rituals: const Color(0xFFAF52DE),
      ritualsTint: const Color.fromRGBO(175, 82, 222, 0.14),
      nutrition: const Color(0xFF0FB5C9),
      nutritionTint: const Color.fromRGBO(15, 181, 201, 0.14),
      sleep: const Color(0xFF5B6CDB),
      sleepTint: const Color.fromRGBO(91, 108, 219, 0.14),
      mood: const Color(0xFF2FA6BC),
      moodTint: const Color.fromRGBO(47, 166, 188, 0.14),
      accent: ink,
      accentTint: surface2,
      moneyInk: const Color(0xFFAE5200),
      moveInk: const Color(0xFF1E7B34),
      ritualsInk: const Color(0xFF8A2FB8),
      nutritionInk: const Color(0xFF0A7685),
      sleepInk: const Color(0xFF3F4FBF),
      moodInk: const Color(0xFF1B7488),
      accentInk: ink,
      glass: surface.withValues(alpha: _glassAlpha),
      glassBorder: hair,
      glassHighlight: const Color(0x00000000),
      red: care,
      dangerInk: careInk,
      onAccent: bg,
      scrim: const Color.fromRGBO(0, 0, 0, 0.40),
      shadow: const Color.fromRGBO(0, 0, 0, 0.12),
    );
  }

  factory AppColors.dark() {
    const bg = Color(0xFF101418);
    const surface = Color(0xFF1A1F24);
    const surface2 = Color(0xFF242A30);
    const ink = Color(0xFFF7F1E8);
    const hair = Color(0xFF2E353C);
    // in dark, a state's fill and ink share one value.
    const thriving = Color(0xFF7FB0F5);
    const good = Color(0xFFA3BBA4);
    const watch = Color(0xFFE0B060);
    const care = Color(0xFFF58A78);
    return AppColors(
      brightness: Brightness.dark,
      bg: bg,
      surface: surface,
      surface2: surface2,
      ink: ink,
      ink2: const Color(0xFFD3D1CE),
      ink3: const Color(0xFFA8A5A0),
      ink4: const Color(0xFF5A5958),
      hair: hair,
      track: const Color(0xFF39424A),
      blur: bg.withValues(alpha: _blurAlpha),
      fill: surface2,
      thriving: thriving,
      good: good,
      watch: watch,
      care: care,
      thrivingInk: thriving,
      goodInk: good,
      watchInk: watch,
      careInk: care,
      money: const Color(0xFFFF9F0A),
      moneyTint: const Color.fromRGBO(255, 159, 10, 0.18),
      move: const Color(0xFF30D158),
      moveTint: const Color.fromRGBO(48, 209, 88, 0.18),
      rituals: const Color(0xFFBF5AF2),
      ritualsTint: const Color.fromRGBO(191, 90, 242, 0.18),
      nutrition: const Color(0xFF3FD0E0),
      nutritionTint: const Color.fromRGBO(63, 208, 224, 0.18),
      sleep: const Color(0xFF8491F0),
      sleepTint: const Color.fromRGBO(132, 145, 240, 0.20),
      mood: const Color(0xFF56C2DA),
      moodTint: const Color.fromRGBO(86, 194, 218, 0.20),
      accent: ink,
      accentTint: surface2,
      moneyInk: const Color(0xFFFFB340),
      moveInk: const Color(0xFF4CDB73),
      ritualsInk: const Color(0xFFD08CF7),
      nutritionInk: const Color(0xFF6FE0EC),
      sleepInk: const Color(0xFFA3ADF5),
      moodInk: const Color(0xFF7FD3E6),
      accentInk: ink,
      glass: surface.withValues(alpha: _glassAlpha),
      glassBorder: hair,
      glassHighlight: const Color(0x00000000),
      red: care,
      dangerInk: care,
      onAccent: bg,
      scrim: const Color.fromRGBO(0, 0, 0, 0.40),
      shadow: const Color.fromRGBO(0, 0, 0, 0.40),
    );
  }

  @override
  AppColors copyWith({Brightness? brightness}) =>
      (brightness ?? this.brightness) == Brightness.dark
          ? AppColors.dark()
          : AppColors.light();

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      bg: c(bg, other.bg),
      surface: c(surface, other.surface),
      surface2: c(surface2, other.surface2),
      ink: c(ink, other.ink),
      ink2: c(ink2, other.ink2),
      ink3: c(ink3, other.ink3),
      ink4: c(ink4, other.ink4),
      hair: c(hair, other.hair),
      track: c(track, other.track),
      blur: c(blur, other.blur),
      fill: c(fill, other.fill),
      thriving: c(thriving, other.thriving),
      good: c(good, other.good),
      watch: c(watch, other.watch),
      care: c(care, other.care),
      thrivingInk: c(thrivingInk, other.thrivingInk),
      goodInk: c(goodInk, other.goodInk),
      watchInk: c(watchInk, other.watchInk),
      careInk: c(careInk, other.careInk),
      money: c(money, other.money),
      moneyTint: c(moneyTint, other.moneyTint),
      move: c(move, other.move),
      moveTint: c(moveTint, other.moveTint),
      rituals: c(rituals, other.rituals),
      ritualsTint: c(ritualsTint, other.ritualsTint),
      nutrition: c(nutrition, other.nutrition),
      nutritionTint: c(nutritionTint, other.nutritionTint),
      sleep: c(sleep, other.sleep),
      sleepTint: c(sleepTint, other.sleepTint),
      mood: c(mood, other.mood),
      moodTint: c(moodTint, other.moodTint),
      accent: c(accent, other.accent),
      accentTint: c(accentTint, other.accentTint),
      moneyInk: c(moneyInk, other.moneyInk),
      moveInk: c(moveInk, other.moveInk),
      ritualsInk: c(ritualsInk, other.ritualsInk),
      nutritionInk: c(nutritionInk, other.nutritionInk),
      sleepInk: c(sleepInk, other.sleepInk),
      moodInk: c(moodInk, other.moodInk),
      accentInk: c(accentInk, other.accentInk),
      glass: c(glass, other.glass),
      glassBorder: c(glassBorder, other.glassBorder),
      glassHighlight: c(glassHighlight, other.glassHighlight),
      red: c(red, other.red),
      dangerInk: c(dangerInk, other.dangerInk),
      onAccent: c(onAccent, other.onAccent),
      scrim: c(scrim, other.scrim),
      shadow: c(shadow, other.shadow),
    );
  }
}

/// Convenience accessor: `context.colors`.
extension AppColorsContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
