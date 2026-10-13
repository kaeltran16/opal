import 'package:flutter/material.dart';

import '../../../models/enums.dart';
import '../../../models/nutrition_meal.dart';
import '../../../theme/theme.dart';
import '../../../util/format.dart';
import '../../../widgets/contributor_bar.dart';
import '../../../widgets/press_scale.dart';

const double _minTap = 44;
const double _pipWidth = 3;
const double _pipBase = 4;
const double _pipStep = 3;
const int _pipCount = 3;
// kept literal: the canvas puts 10 above a macro row and 12 below it.
const double _macroRowTop = 10;
const double _macroRowBottom = Spacing.md;
const double _handleWidth = 36;
const double _handleHeight = 5;
const double _hairline = 1;
// cap the sheet so tall content scrolls inside the body rather than overflowing.
const double _sheetMaxShare = 0.94;
const Duration _sheetSlide = Duration(milliseconds: 320);

// ─── ConfidenceChip ──────────────────────────────────────────────────────────

/// 3 ascending pips showing Pal's confidence level, plus its word.
class ConfidenceChip extends StatelessWidget {
  // plain is kept for callers; the tinted pill it used to drop is gone.
  const ConfidenceChip(this.level, {super.key, this.plain = false});

  final NutritionConfidence level;
  final bool plain;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < _pipCount; i++) ...[
          if (i > 0) const SizedBox(width: Spacing.xxs),
          Container(
            width: _pipWidth,
            height: _pipBase + i * _pipStep,
            decoration: BoxDecoration(
              color: i < level.bars ? c.ink : c.track,
              borderRadius: BorderRadius.circular(Radii.pill),
            ),
          ),
        ],
        const SizedBox(width: Spacing.xs),
        Text(level.label, style: AppType.label.copyWith(color: c.ink2)),
      ],
    );
  }
}

// ─── CalRange ────────────────────────────────────────────────────────────────

/// A calorie estimate: its mid as a light number, then
/// "kcal, likely {lo}–{hi}". [hero] sets it in `display` rather than `score`.
class CalRange extends StatelessWidget {
  // size and light are kept for callers; the type ramp and the plain sheet
  // ground replaced free sizes and white-on-tint text.
  const CalRange(
    this.range, {
    super.key,
    this.size = 32,
    this.light = false,
    this.hero = false,
  });

  final IntRange range;
  final double size;
  final bool light;
  final bool hero;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          groupThousands('${range.mid}', ','),
          style: (hero ? AppType.display : AppType.score).copyWith(color: c.ink),
        ),
        Text(
          'kcal, likely ${range.lo}–${range.hi}',
          style: AppType.subhead.copyWith(color: c.ink2),
        ),
      ],
    );
  }
}

// ─── MacroSplit ───────────────────────────────────────────────────────────────

/// Protein, carbs and fat as rows, each bar that macro's share of the split.
class MacroSplit extends StatelessWidget {
  // light is kept for callers; there is no tinted panel to sit on any more.
  const MacroSplit(this.macros, {super.key, this.light = false});

  final Macros macros;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Protein', macros.protein),
      ('Carbs', macros.carbs),
      ('Fat', macros.fat),
    ];
    final total = rows.fold<int>(0, (sum, r) => sum + r.$2.mid);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (label, range) in rows)
          Padding(
            padding: const EdgeInsets.only(top: _macroRowTop, bottom: _macroRowBottom),
            child: ContributorBar(
              label: label,
              value: '${range.lo}–${range.hi} g',
              fraction: total > 0 ? range.mid / total : 0,
            ),
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
    final primary = primaryLabel;

    return Stack(
      children: [
        GestureDetector(
          onTap: onClose,
          child: Container(color: c.scrim),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 1.0, end: 0.0),
            duration: _sheetSlide,
            curve: Curves.easeOutCubic,
            builder: (context, value, child) => FractionalTranslation(
              translation: Offset(0, value),
              child: child,
            ),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * _sheetMaxShare,
              ),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.xl)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: Spacing.sm),
                  Container(
                    width: _handleWidth,
                    height: _handleHeight,
                    decoration: BoxDecoration(
                      color: c.track,
                      borderRadius: BorderRadius.circular(Radii.pill),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
                    child: Row(
                      children: [
                        _HeaderButton(
                          label: 'Cancel',
                          color: c.ink2,
                          onTap: onClose,
                        ),
                        Expanded(
                          child: title != null
                              ? Semantics(
                                  header: true,
                                  child: Text(
                                    title!,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppType.headline.copyWith(color: c.ink),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                        if (primary != null)
                          _HeaderButton(
                            label: primary,
                            color: primaryEnabled ? c.ink : c.ink3,
                            bold: true,
                            onTap: primaryEnabled ? onPrimary : null,
                          )
                        else
                          // balances Cancel so the title stays centred.
                          const SizedBox(width: _minTap),
                      ],
                    ),
                  ),
                  Divider(height: _hairline, thickness: _hairline, color: c.hair),
                  // Flexible so a scrollable child shrinks to the capped height
                  // and scrolls instead of overflowing.
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

/// A text button in the sheet header, at least 44 square.
class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.bold = false,
  });

  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final text = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _minTap, minWidth: _minTap),
      child: Align(
        widthFactor: 1,
        child: Text(
          label,
          style: (bold ? AppType.headline : AppType.body).copyWith(color: color),
        ),
      ),
    );
    // a disabled primary still reads as a button, just not an enabled one.
    if (onTap == null) {
      return Semantics(button: true, enabled: false, label: label, excludeSemantics: true, child: text);
    }
    return PressScale(onTap: onTap, semanticLabel: label, child: text);
  }
}

// ─── ChipRow ─────────────────────────────────────────────────────────────────

/// A wrap of pills; the selected one is ink on `surface2`, the rest ink3.
class ChipRow extends StatelessWidget {
  const ChipRow(this.options, this.value, this.onChange, {super.key});

  final List<String> options;
  final String value;
  final ValueChanged<String> onChange;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Wrap(
      spacing: Spacing.xs,
      runSpacing: Spacing.xs,
      children: [
        for (final option in options)
          MergeSemantics(
            child: Semantics(
              selected: option == value,
              child: PressScale(
                onTap: () => onChange(option),
                semanticLabel: option,
                child: Container(
                  constraints: const BoxConstraints(minHeight: _minTap),
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
                  decoration: BoxDecoration(
                    color: option == value ? c.surface2 : null,
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                  child: Align(
                    widthFactor: 1,
                    child: Text(
                      option,
                      style: AppType.subhead.copyWith(
                        color: option == value ? c.ink : c.ink3,
                        fontWeight: option == value ? FontWeight.w600 : null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
