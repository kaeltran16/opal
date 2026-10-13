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
    required this.ringMove,
    required this.ringRoutines,
    required this.red,
    required this.dangerInk,
    required this.scrim,
    required this.shadow,
  });

  /// Fully transparent, the same in both themes: an animated fill's "off" end.
  static const Color clear = Color(0x00000000);

  final Brightness brightness;
  final Color bg, surface, surface2;
  final Color ink, ink2, ink3, ink4;
  final Color hair, track, blur, fill;
  // state fills, for arcs, bars and dots: 3:1 on every ground.
  final Color thriving, good, watch, care;
  // state text and icons: 4.5:1 on every ground.
  final Color thrivingInk, goodInk, watchInk, careInk;
  // the activity rings only: the last area hues, kept so the rings stay apart
  // by hue as well as lightness. DESIGN.md section 3.
  final Color ringMove, ringRoutines;
  final Color red;
  // destructive text and icons on surface; red itself fails 4.5:1 there.
  final Color dangerInk;
  final Color scrim;
  final Color shadow;

  static const double _blurAlpha = 0.72;

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
      ringMove: const Color(0xFF34C759),
      ringRoutines: const Color(0xFFAF52DE),
      red: care,
      dangerInk: careInk,
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
      ringMove: const Color(0xFF30D158),
      ringRoutines: const Color(0xFFBF5AF2),
      red: care,
      dangerInk: care,
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
      ringMove: c(ringMove, other.ringMove),
      ringRoutines: c(ringRoutines, other.ringRoutines),
      red: c(red, other.red),
      dangerInk: c(dangerInk, other.dangerInk),
      scrim: c(scrim, other.scrim),
      shadow: c(shadow, other.shadow),
    );
  }
}

/// Convenience accessor: `context.colors`.
extension AppColorsContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
