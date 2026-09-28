import 'package:flutter/material.dart';

import '../screens/today/today_logic.dart';
import '../theme/theme.dart';
import '../util/format.dart';
import 'app_icon.dart';

const double _minTapHeight = 44;
final _valueText = AppFonts.sfr(size: 32, weight: FontWeight.w800, height: 36 / 32);

/// Today's fallback while Pal's brief is missing: what is left of each daily
/// goal, from local numbers only. No card, just hairline-separated columns.
/// A zero budget or goal shows what was done instead, and zero routines drops
/// that column, so nothing reads as "-$5 left" or "0 of 0".
class WhatsLeftRow extends StatelessWidget {
  const WhatsLeftRow({
    super.key,
    required this.numbers,
    required this.currency,
    required this.onTap,
  });

  final GlanceNumbers numbers;
  final Currency currency;
  final void Function(TodayArea) onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final n = numbers;
    final spent = formatCurrency(n.spent, currency);
    final budget = formatCurrency(n.budget, currency);
    final left = formatCurrency(n.moneyLeft, currency);

    final columns = [
      n.budget > 0
          ? _Column(TodayArea.money, left, 'left to spend',
              'Spent $spent of $budget, $left left', c.moneyInk)
          : _Column(TodayArea.money, spent, 'spent', 'Spent $spent', c.moneyInk),
      n.moveGoal > 0
          ? _Column(TodayArea.move, '${n.kcalToGo}', 'kcal to go',
              'Workout ${n.moveKcal} of ${n.moveGoal} kcal, ${n.kcalToGo} to go', c.moveInk)
          : _Column(TodayArea.move, '${n.moveKcal}', 'kcal moved',
              'Workout ${n.moveKcal} kcal', c.moveInk),
      if (n.routinesTotal > 0)
        _Column(
          TodayArea.routines,
          '${n.routinesLeft}',
          n.routinesLeft == 1 ? 'routine left' : 'routines left',
          'Routines ${n.routinesDone} of ${n.routinesTotal}, ${n.routinesLeft} left',
          c.ritualsInk,
        ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < columns.length; i++)
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: i == 0 ? null : Border(left: BorderSide(color: c.hair, width: 0.5)),
                    ),
                    child: _columnView(context, columns[i]),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIcon('sparkles', size: 12, color: c.ink3),
            const SizedBox(width: Spacing.xs),
            Text("Pal's brief is catching up", style: AppType.footnote.copyWith(color: c.ink3)),
          ],
        ),
      ],
    );
  }

  Widget _columnView(BuildContext context, _Column col) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: col.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(col.area),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _minTapHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(col.value, style: _valueText.copyWith(color: col.ink)),
                const SizedBox(height: Spacing.xxs),
                Text(col.caption,
                    style: AppType.footnote.copyWith(color: c.ink2, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Column {
  const _Column(this.area, this.value, this.caption, this.label, this.ink);

  final TodayArea area;
  final String value, caption, label;
  final Color ink;
}
