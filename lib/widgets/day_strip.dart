import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'app_icon.dart';
import 'press_scale.dart';

const double _disc = 30;
const double _check = 14;
const double _ring = 1.5;
const double _selectedInset = 3;
const double _letterGap = 6;
const double _minTap = 44;
const double _columnGap = Spacing.xs;
const double _letterTracking = 0.3;

/// One day in a [DayStrip]. [name] is the spoken day ("Monday") for a
/// tappable strip, where single letters repeat.
class DayMark {
  const DayMark({required this.letter, required this.done, required this.today, this.name});

  final String letter;
  final bool done;
  final bool today;
  final String? name;
}

/// Seven discs, one per day: done is a filled `ink` disc with a check,
/// today an `ink` ring, the rest `track`.
class DayStrip extends StatelessWidget {
  const DayStrip({
    super.key,
    required this.days,
    required this.semanticLabel,
    this.onTap,
    this.selected,
  });

  final List<DayMark> days;
  final String semanticLabel;
  final ValueChanged<int>? onTap;
  final int? selected;

  @override
  Widget build(BuildContext context) {
    final onTap = this.onTap;
    final row = Row(
      spacing: _columnGap,
      children: [
        for (final (i, day) in days.indexed)
          Expanded(
            child: onTap == null
                ? _DayColumn(day: day, selected: i == selected)
                : Semantics(
                    selected: i == selected,
                    child: PressScale(
                      onTap: () => onTap(i),
                      semanticLabel: _spoken(day),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: _minTap),
                        child: _DayColumn(day: day, selected: i == selected),
                      ),
                    ),
                  ),
          ),
      ],
    );
    if (onTap != null) return row;
    return Semantics(image: true, label: semanticLabel, excludeSemantics: true, child: row);
  }

  static String _spoken(DayMark day) => [
        day.name ?? day.letter,
        if (day.today) 'today',
        if (day.done) 'trained',
      ].join(', ');
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({required this.day, required this.selected});

  final DayMark day;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ringed = selected || (day.today && !day.done);
    final check = AppIcon('checkmark', size: _check, color: c.bg);
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: _letterGap,
      children: [
        Container(
          width: _disc,
          height: _disc,
          // a selected done day keeps its fill inside the ring, so both read.
          padding: ringed && day.done ? const EdgeInsets.all(_selectedInset) : null,
          decoration: BoxDecoration(
            color: day.done && !ringed ? c.ink : (ringed ? null : c.track),
            shape: BoxShape.circle,
            border: ringed ? Border.all(color: c.ink, width: _ring) : null,
          ),
          alignment: Alignment.center,
          child: !day.done
              ? null
              : ringed
                  ? Container(
                      decoration: BoxDecoration(color: c.ink, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: check,
                    )
                  : check,
        ),
        Text(day.letter,
            maxLines: 1,
            style: AppType.caption.copyWith(
              color: day.today ? c.ink : c.ink3,
              fontWeight: day.today ? FontWeight.w600 : FontWeight.w400,
              letterSpacing: _letterTracking,
            )),
      ],
    );
  }
}
