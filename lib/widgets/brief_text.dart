import 'package:flutter/material.dart';

import '../screens/today/today_logic.dart';
import '../theme/theme.dart';
import '../util/format.dart';

const double _chipMinHeight = 44;
// rounded figures sized to sit inside the brief's 38pt lines.
final _chipText = AppFonts.sfr(size: 18, weight: FontWeight.w800, height: 1.4);

/// Pal's lead sentence followed by a client-built number sentence whose
/// figures are tappable chips. The figures come from [numbers] (local data),
/// never from the model, so the lead can stay qualitative.
class BriefText extends StatelessWidget {
  const BriefText({
    super.key,
    required this.lead,
    required this.numbers,
    required this.currency,
    required this.onChip,
  });

  final String lead;
  final GlanceNumbers numbers;
  final Currency currency;
  final void Function(TodayArea) onChip;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final n = numbers;
    final spent = formatCurrency(n.spent, currency);
    final hasBudget = n.budget > 0;
    final budget = formatCurrency(n.budget, currency);

    final money = hasBudget
        ? _chip(c, TodayArea.money, '$spent of $budget', 'Spent $spent of $budget, open Money')
        : _chip(c, TodayArea.money, '$spent spent', 'Spent $spent, open Money');
    final move = _chip(
      c,
      TodayArea.move,
      '${n.moveKcal} kcal',
      n.moveGoal > 0
          ? 'Moved ${n.moveKcal} of ${n.moveGoal} kcal, open Move'
          : 'Moved ${n.moveKcal} kcal, open Move',
    );
    final routines = n.routinesTotal > 0
        ? _chip(
            c,
            TodayArea.routines,
            '${n.routinesDone} of ${n.routinesTotal} ${n.routinesTotal == 1 ? 'routine' : 'routines'}',
            '${n.routinesDone} of ${n.routinesTotal} routines done, open Routines',
          )
        : null;

    // without a budget "you've spent $38 spent" would read wrong, so the
    // money chip trails the sentence instead.
    final clauses = <(String, InlineSpan)>[
      if (hasBudget) ('spent ', money),
      ('moved ', move),
      if (routines != null) ('done ', routines),
    ];

    return Text.rich(
      TextSpan(
        style: AppType.brief.copyWith(color: c.ink),
        children: [
          if (lead.isNotEmpty) TextSpan(text: '$lead '),
          const TextSpan(text: "You've "),
          for (var i = 0; i < clauses.length; i++) ...[
            if (i > 0) TextSpan(text: i == clauses.length - 1 ? ' and ' : ', '),
            TextSpan(text: clauses[i].$1),
            clauses[i].$2,
          ],
          if (!hasBudget) ...[const TextSpan(text: ', with '), money],
          const TextSpan(text: '.'),
        ],
      ),
    );
  }

  InlineSpan _chip(AppColors c, TodayArea area, String text, String label) {
    final (ink, tint) = switch (area) {
      TodayArea.money => (c.moneyInk, c.moneyTint),
      TodayArea.move => (c.moveInk, c.moveTint),
      _ => (c.ritualsInk, c.ritualsTint),
    };
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChip(area),
          // the tap target is 44 tall; the visible pill stays prose-sized.
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _chipMinHeight),
            child: Align(
              widthFactor: 1,
              heightFactor: 1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.xs),
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
                child: Text(
                  text,
                  style: _chipText.copyWith(color: ink),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
