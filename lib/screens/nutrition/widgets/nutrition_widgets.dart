import 'package:flutter/material.dart';

import '../../../models/enums.dart';
import '../../../models/nutrition_meal.dart';
import '../../../theme/theme.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/press_scale.dart';

// ─── ConfidenceChip ──────────────────────────────────────────────────────────

/// 3 ascending bars showing Pal's confidence level, plus a text label.
/// [plain] drops the tinted pill background (used in MealRow).
class ConfidenceChip extends StatelessWidget {
  const ConfidenceChip(this.level, {super.key, this.plain = false});

  final NutritionConfidence level;
  final bool plain;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bars = level.bars;
    final label = level.label;

    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 3 ascending bars: heights 4, 7, 10 px
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: 2),
          Container(
            width: 3,
            height: 4 + i * 3.0,
            decoration: BoxDecoration(
              color: i < bars
                  ? c.nutrition
                  : c.nutrition.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
        ],
        const SizedBox(width: Spacing.xs),
        Text(
          label,
          style: AppFonts.sf(
            size: 12,
            weight: FontWeight.w500,
            color: plain ? c.ink3 : c.nutrition,
          ),
        ),
      ],
    );

    if (plain) return content;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sm,
        vertical: Spacing.xxs,
      ),
      decoration: BoxDecoration(
        color: c.nutritionTint,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: content,
    );
  }
}

// ─── CalRange ────────────────────────────────────────────────────────────────

/// Displays a calorie range as a large "≈ {mid} cal" hero with a sub-line
/// "{lo}–{hi} estimated". [size] controls the mid-value font size (default 32).
/// [light] switches ink to white for use on dark/tinted backgrounds.
class CalRange extends StatelessWidget {
  const CalRange(
    this.range, {
    super.key,
    this.size = 32,
    this.light = false,
  });

  final IntRange range;
  final double size;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final mainColor = light ? Colors.white : c.ink;
    final dimColor = light ? Colors.white70 : c.ink3;

    // Round mid to nearest 10
    final rawMid = (range.lo + range.hi) / 2;
    final mid = ((rawMid / 10).round() * 10).toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '≈',
              style: AppFonts.sfr(
                size: size * 0.42,
                weight: FontWeight.w400,
                color: dimColor,
              ),
            ),
            const SizedBox(width: 3),
            Text(
              mid,
              style: AppFonts.sfr(
                size: size,
                weight: FontWeight.w700,
                color: mainColor,
                height: 0.95,
              ),
            ),
            const SizedBox(width: 3),
            Text(
              'cal',
              style: AppFonts.sf(
                size: size * 0.32,
                weight: FontWeight.w600,
                color: dimColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '${range.lo}–${range.hi} estimated',
          style: AppFonts.sf(size: 12.5, color: dimColor),
        ),
      ],
    );
  }
}

// ─── MacroSplit ───────────────────────────────────────────────────────────────

/// An 8px-tall segmented bar showing the protein/carbs/fat split, with a
/// legend row beneath. [light] switches to white tiers for dark backgrounds.
class MacroSplit extends StatelessWidget {
  const MacroSplit(this.macros, {super.key, this.light = false});

  final Macros macros;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final proteinMid = macros.protein.mid;
    final carbsMid = macros.carbs.mid;
    final fatMid = macros.fat.mid;
    final total = proteinMid + carbsMid + fatMid;

    final segments = [
      _MacroSegment(
        flex: total > 0 ? proteinMid : 1,
        color: light ? Colors.white : c.nutrition,
        label: 'PROTEIN',
        range: macros.protein,
      ),
      _MacroSegment(
        flex: total > 0 ? carbsMid : 1,
        color: light
            ? Colors.white.withValues(alpha: 0.60)
            : c.nutrition.withValues(alpha: 0.60),
        label: 'CARBS',
        range: macros.carbs,
      ),
      _MacroSegment(
        flex: total > 0 ? fatMid : 1,
        color: light
            ? Colors.white.withValues(alpha: 0.30)
            : c.nutrition.withValues(alpha: 0.30),
        label: 'FAT',
        range: macros.fat,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Bar
        ClipRRect(
          borderRadius: BorderRadius.circular(Radii.xs),
          child: Row(
            children: [
              for (var i = 0; i < segments.length; i++) ...[
                if (i > 0) const SizedBox(width: 2),
                Expanded(
                  flex: segments[i].flex,
                  child: Container(
                    height: 8,
                    color: segments[i].color,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: Spacing.sm),
        // Legend
        Row(
          children: [
            for (var i = 0; i < segments.length; i++) ...[
              if (i > 0) const SizedBox(width: Spacing.md),
              _MacroLegendItem(segment: segments[i], light: light),
            ],
          ],
        ),
      ],
    );
  }
}

class _MacroSegment {
  const _MacroSegment({
    required this.flex,
    required this.color,
    required this.label,
    required this.range,
  });
  final int flex;
  final Color color;
  final String label;
  final IntRange range;
}

class _MacroLegendItem extends StatelessWidget {
  const _MacroLegendItem({required this.segment, required this.light});
  final _MacroSegment segment;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final textColor = light ? Colors.white70 : c.ink3;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: segment.color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: Spacing.xxs),
        Text(
          segment.label,
          style: AppFonts.sf(
            size: 11,
            weight: FontWeight.w600,
            letterSpacing: 0.4,
            color: textColor,
          ),
        ),
        const SizedBox(width: Spacing.xxs),
        Text(
          '${segment.range.lo}–${segment.range.hi}g',
          style: AppFonts.sfr(size: 14, color: textColor),
        ),
      ],
    );
  }
}

// ─── SourceTag ────────────────────────────────────────────────────────────────

/// A small inline badge showing where a meal came from (home / takeout / by hand).
class SourceTag extends StatelessWidget {
  const SourceTag(this.source, {super.key});

  final NutritionSource source;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: c.nutritionTint,
        borderRadius: BorderRadius.circular(Radii.xs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(source.icon, size: 11, color: c.nutrition),
          const SizedBox(width: 3),
          Text(
            source.label,
            style: AppFonts.sf(
              size: 11,
              weight: FontWeight.w500,
              color: c.nutrition,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── MealRow ─────────────────────────────────────────────────────────────────

/// A single meal entry row: time · icon tile · name/slot/source · cal range/confidence.
/// Hairline divider below unless [last].
class MealRow extends StatelessWidget {
  const MealRow(
    this.meal, {
    super.key,
    this.last = false,
    this.onTap,
  });

  final NutritionMeal meal;
  final bool last;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PressScale(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.lg,
              vertical: Spacing.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Time — 38px wide, tabular
                SizedBox(
                  width: 38,
                  child: Text(
                    meal.time,
                    style: AppFonts.sfr(
                      size: 13,
                      weight: FontWeight.w500,
                      color: c.ink3,
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                // 32px icon tile
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: c.nutritionTint,
                    borderRadius: BorderRadius.circular(Radii.sm),
                  ),
                  child: Center(
                    child: AppIcon(meal.icon, size: 17, color: c.nutrition),
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                // Name + slot · SourceTag
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        meal.name,
                        style: AppFonts.sf(
                          size: 15,
                          weight: FontWeight.w500,
                          color: c.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            meal.slot,
                            style: AppFonts.sf(size: 12, color: c.ink3),
                          ),
                          const SizedBox(width: Spacing.xs),
                          Text('·',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: c.ink4)),
                          const SizedBox(width: Spacing.xs),
                          SourceTag(meal.source),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                // Right column: cal range + plain confidence chip
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${meal.cal.lo}–${meal.cal.hi}',
                      style: AppFonts.sfr(
                        size: 14,
                        weight: FontWeight.w600,
                        color: c.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    ConfidenceChip(meal.confidence, plain: true),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (!last)
          Divider(
            height: 1,
            thickness: 0.5,
            color: c.hair,
            indent: Spacing.lg + 38 + Spacing.sm + 32 + Spacing.sm,
          ),
      ],
    );
  }
}

// ─── SheetShell ───────────────────────────────────────────────────────────────

/// A modal bottom-sheet frame: scrim + sliding panel with a sticky header row
/// (Cancel · title · primary action) and scrollable [child].
class SheetShell extends StatelessWidget {
  const SheetShell({
    super.key,
    this.title,
    required this.onClose,
    this.primaryLabel,
    this.onPrimary,
    this.primaryEnabled = true,
    required this.child,
  });

  final String? title;
  final VoidCallback onClose;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final bool primaryEnabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Stack(
      children: [
        // Scrim
        GestureDetector(
          onTap: onClose,
          child: Container(color: c.scrim),
        ),
        // Sheet
        Align(
          alignment: Alignment.bottomCenter,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 1.0, end: 0.0),
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return FractionalTranslation(
                translation: Offset(0, value),
                child: child,
              );
            },
            child: Container(
              // Cap the sheet at 94% of the viewport so tall content scrolls
              // inside the body rather than overflowing the column.
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.94,
              ),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(Radii.xxl),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  const SizedBox(height: Spacing.md),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: c.hair,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: Spacing.sm),
                  // Header row
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.lg,
                      vertical: Spacing.sm,
                    ),
                    child: Row(
                      children: [
                        // Cancel
                        GestureDetector(
                          onTap: onClose,
                          child: Text(
                            'Cancel',
                            style: AppFonts.sf(
                              size: 16,
                              weight: FontWeight.w400,
                              color: c.nutrition,
                            ),
                          ),
                        ),
                        // Title
                        Expanded(
                          child: title != null
                              ? Text(
                                  title!,
                                  textAlign: TextAlign.center,
                                  style: AppFonts.sf(
                                    size: 16,
                                    weight: FontWeight.w600,
                                    color: c.ink,
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                        // Primary action
                        if (primaryLabel != null)
                          GestureDetector(
                            onTap: primaryEnabled ? onPrimary : null,
                            child: Text(
                              primaryLabel!,
                              style: AppFonts.sf(
                                size: 16,
                                weight: FontWeight.w600,
                                color:
                                    primaryEnabled ? c.nutrition : c.ink4,
                              ),
                            ),
                          )
                        else
                          const SizedBox(width: 48), // balance Cancel width
                      ],
                    ),
                  ),
                  const Divider(height: 1, thickness: 0.5),
                  // Body — Flexible so a scrollable child shrinks to the
                  // capped height and scrolls instead of overflowing.
                  Flexible(child: child),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── ChipRow ─────────────────────────────────────────────────────────────────

/// A wrap of pill-button chips. Active chip: nutrition bg / white text.
/// Inactive: surface / ink.
class ChipRow extends StatelessWidget {
  const ChipRow(this.options, this.value, this.onChange, {super.key});

  final List<String> options;
  final String value;
  final ValueChanged<String> onChange;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Wrap(
      spacing: Spacing.sm,
      runSpacing: Spacing.sm,
      children: [
        for (final option in options)
          PressScale(
            onTap: () => onChange(option),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md,
                vertical: Spacing.xs,
              ),
              decoration: BoxDecoration(
                color: option == value ? c.nutrition : c.surface,
                borderRadius: BorderRadius.circular(Radii.pill),
                border: option == value
                    ? null
                    : Border.all(color: c.hair, width: 1),
              ),
              child: Text(
                option,
                style: AppFonts.sf(
                  size: 14,
                  weight: FontWeight.w500,
                  color: option == value ? Colors.white : c.ink,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
