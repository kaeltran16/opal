import 'package:flutter/material.dart';

/// User-selectable accent options (persisted via @AppStorage equivalent later).
enum AppAccent { blue, indigo, purple, pink, orange, green, teal, graphite }

extension AppAccentInfo on AppAccent {
  String get label => switch (this) {
        AppAccent.blue => 'Blue',
        AppAccent.indigo => 'Indigo',
        AppAccent.purple => 'Purple',
        AppAccent.pink => 'Pink',
        AppAccent.orange => 'Orange',
        AppAccent.green => 'Green',
        AppAccent.teal => 'Teal',
        AppAccent.graphite => 'Graphite',
      };

  Color light() => switch (this) {
        AppAccent.blue => const Color(0xFF007AFF),
        AppAccent.indigo => const Color(0xFF5856D6),
        AppAccent.purple => const Color(0xFFAF52DE),
        AppAccent.pink => const Color(0xFFFF2D55),
        AppAccent.orange => const Color(0xFFFF9500),
        AppAccent.green => const Color(0xFF34C759),
        AppAccent.teal => const Color(0xFF30B0C7),
        AppAccent.graphite => const Color(0xFF1C1C1E),
      };

  Color dark() => switch (this) {
        AppAccent.blue => const Color(0xFF0A84FF),
        AppAccent.indigo => const Color(0xFF5E5CE6),
        AppAccent.purple => const Color(0xFFBF5AF2),
        AppAccent.pink => const Color(0xFFFF375F),
        AppAccent.orange => const Color(0xFFFF9F0A),
        AppAccent.green => const Color(0xFF30D158),
        AppAccent.teal => const Color(0xFF40C8E0),
        AppAccent.graphite => const Color(0xFFF5F5F7),
      };
}

/// Semantic design tokens from the design handoff, exposed as a
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
    required this.blur,
    required this.fill,
    required this.money,
    required this.moneyTint,
    required this.move,
    required this.moveTint,
    required this.rituals,
    required this.ritualsTint,
    required this.nutrition,
    required this.nutritionTint,
    required this.accent,
    required this.accentTint,
    required this.red,
    required this.onAccent,
    required this.scrim,
    required this.shadow,
  });

  final Brightness brightness;
  final Color bg, surface, surface2;
  final Color ink, ink2, ink3, ink4;
  final Color hair, blur, fill;
  final Color money, moneyTint;
  final Color move, moveTint;
  final Color rituals, ritualsTint;
  final Color nutrition, nutritionTint;
  final Color accent, accentTint;
  final Color red;
  final Color onAccent;
  final Color scrim;
  final Color shadow;

  /// Color for a tracker type token: 'money' | 'move' | 'rituals' | 'nutrition'.
  Color forType(String type) => switch (type) {
        'money' => money,
        'move' => move,
        'rituals' => rituals,
        'nutrition' => nutrition,
        _ => accent,
      };

  factory AppColors.light(AppAccent accent) {
    final a = accent.light();
    return AppColors(
      brightness: Brightness.light,
      bg: const Color(0xFFF2F2F7),
      surface: const Color(0xFFFFFFFF),
      surface2: const Color(0xFFF2F2F7),
      ink: const Color(0xFF000000),
      ink2: const Color.fromRGBO(60, 60, 67, 0.85),
      ink3: const Color.fromRGBO(60, 60, 67, 0.60),
      ink4: const Color.fromRGBO(60, 60, 67, 0.30),
      hair: const Color.fromRGBO(60, 60, 67, 0.12),
      blur: const Color.fromRGBO(242, 242, 247, 0.72),
      fill: const Color.fromRGBO(120, 120, 128, 0.12),
      money: const Color(0xFFFF9500),
      moneyTint: const Color.fromRGBO(255, 149, 0, 0.14),
      move: const Color(0xFF34C759),
      moveTint: const Color.fromRGBO(52, 199, 89, 0.14),
      rituals: const Color(0xFFAF52DE),
      ritualsTint: const Color.fromRGBO(175, 82, 222, 0.14),
      nutrition: const Color(0xFFE2553D),
      nutritionTint: const Color.fromRGBO(226, 85, 61, 0.14),
      accent: a,
      accentTint: a.withValues(alpha: 0.14),
      red: const Color(0xFFFF3B30),
      onAccent: const Color(0xFFFFFFFF),
      scrim: const Color.fromRGBO(0, 0, 0, 0.40),
      shadow: const Color.fromRGBO(0, 0, 0, 0.12),
    );
  }

  factory AppColors.dark(AppAccent accent) {
    final a = accent.dark();
    return AppColors(
      brightness: Brightness.dark,
      bg: const Color(0xFF000000),
      surface: const Color(0xFF1C1C1E),
      surface2: const Color(0xFF2C2C2E),
      ink: const Color(0xFFFFFFFF),
      ink2: const Color.fromRGBO(235, 235, 245, 0.85),
      ink3: const Color.fromRGBO(235, 235, 245, 0.60),
      ink4: const Color.fromRGBO(235, 235, 245, 0.30),
      hair: const Color.fromRGBO(84, 84, 88, 0.65),
      blur: const Color.fromRGBO(0, 0, 0, 0.72),
      fill: const Color.fromRGBO(120, 120, 128, 0.24),
      money: const Color(0xFFFF9F0A),
      moneyTint: const Color.fromRGBO(255, 159, 10, 0.18),
      move: const Color(0xFF30D158),
      moveTint: const Color.fromRGBO(48, 209, 88, 0.18),
      rituals: const Color(0xFFBF5AF2),
      ritualsTint: const Color.fromRGBO(191, 90, 242, 0.18),
      nutrition: const Color(0xFFF06A4D),
      nutritionTint: const Color.fromRGBO(240, 106, 77, 0.18),
      accent: a,
      accentTint: a.withValues(alpha: 0.18),
      red: const Color(0xFFFF453A),
      onAccent: const Color(0xFFFFFFFF),
      scrim: const Color.fromRGBO(0, 0, 0, 0.40),
      shadow: const Color.fromRGBO(0, 0, 0, 0.40),
    );
  }

  @override
  AppColors copyWith({Brightness? brightness, Color? accent}) {
    // Tokens are derived from (brightness, accent). The AppAccent enum can't be
    // recovered from a Color, so rebuild the neutral palette for the target
    // brightness (reusing the existing accent when none is passed) and overlay
    // the requested accent/tint the same way the brightness factory does.
    final b = brightness ?? this.brightness;
    final dark = b == Brightness.dark;
    final base = dark ? AppColors.dark(AppAccent.blue) : AppColors.light(AppAccent.blue);
    final a = accent ?? this.accent;
    return AppColors(
      brightness: b,
      bg: base.bg, surface: base.surface, surface2: base.surface2,
      ink: base.ink, ink2: base.ink2, ink3: base.ink3, ink4: base.ink4,
      hair: base.hair, blur: base.blur, fill: base.fill,
      money: base.money, moneyTint: base.moneyTint,
      move: base.move, moveTint: base.moveTint,
      rituals: base.rituals, ritualsTint: base.ritualsTint,
      nutrition: base.nutrition, nutritionTint: base.nutritionTint,
      accent: a,
      accentTint: a.withValues(alpha: dark ? 0.18 : 0.14),
      red: base.red,
      onAccent: base.onAccent,
      scrim: base.scrim,
      shadow: base.shadow,
    );
  }

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
      blur: c(blur, other.blur),
      fill: c(fill, other.fill),
      money: c(money, other.money),
      moneyTint: c(moneyTint, other.moneyTint),
      move: c(move, other.move),
      moveTint: c(moveTint, other.moveTint),
      rituals: c(rituals, other.rituals),
      ritualsTint: c(ritualsTint, other.ritualsTint),
      nutrition: c(nutrition, other.nutrition),
      nutritionTint: c(nutritionTint, other.nutritionTint),
      accent: c(accent, other.accent),
      accentTint: c(accentTint, other.accentTint),
      red: c(red, other.red),
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
