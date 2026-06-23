import 'package:flutter/material.dart';

import '../../../controllers/sleep_controller.dart';
import '../../../theme/theme.dart';
import '../../../util/mood_scale.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/controls.dart';

// ─── StageSplitBar ───────────────────────────────────────────────────────────

/// Four-segment proportional bar (Deep / REM / Core / Awake) with a legend row.
///
/// [light] = true renders on the dark indigo hero (white-ish shades);
/// false renders on a surface card (sleep-token shades).
class StageSplitBar extends StatelessWidget {
  const StageSplitBar({
    super.key,
    required this.deepMinutes,
    required this.remMinutes,
    required this.coreMinutes,
    required this.awakeMinutes,
    required this.light,
  });

  final int deepMinutes;
  final int remMinutes;
  final int coreMinutes;
  final int awakeMinutes;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final totalInt = deepMinutes + remMinutes + coreMinutes + awakeMinutes;
    final total = totalInt < 1 ? 1.0 : totalInt.toDouble();

    // alpha hex suffixes from prototype: b3≈0.70, 73≈0.45, 3a≈0.23
    final stages = [
      _Stage(
        label: 'Deep',
        minutes: deepMinutes,
        color: light ? Colors.white : c.sleep,
      ),
      _Stage(
        label: 'REM',
        minutes: remMinutes,
        color: light
            ? Colors.white.withValues(alpha: 0.70)
            : c.sleep.withValues(alpha: 0.70),
      ),
      _Stage(
        label: 'Core',
        minutes: coreMinutes,
        color: light
            ? Colors.white.withValues(alpha: 0.45)
            : c.sleep.withValues(alpha: 0.45),
      ),
      _Stage(
        label: 'Awake',
        minutes: awakeMinutes,
        color: light
            ? Colors.white.withValues(alpha: 0.23)
            : c.sleep.withValues(alpha: 0.23),
      ),
    ];

    final textColor =
        light ? Colors.white.withValues(alpha: 0.75) : c.ink3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // proportional bar: flex row, height 8, gap 2
        SizedBox(
          height: 8,
          child: Row(
            children: [
              for (var i = 0; i < stages.length; i++) ...[
                if (i > 0) const SizedBox(width: 2),
                Flexible(
                  flex: ((stages[i].minutes / total) * 1000).round().clamp(3, 1000),
                  child: Container(
                    decoration: BoxDecoration(
                      color: stages[i].color,
                      borderRadius: BorderRadius.circular(Radii.pill),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: Spacing.sm),
        // legend row
        Row(
          children: [
            for (var i = 0; i < stages.length; i++) ...[
              if (i > 0) const SizedBox(width: Spacing.sm),
              _StageLegendItem(stage: stages[i], textColor: textColor),
            ],
          ],
        ),
      ],
    );
  }
}

class _Stage {
  const _Stage({required this.label, required this.minutes, required this.color});
  final String label;
  final int minutes;
  final Color color;
}

class _StageLegendItem extends StatelessWidget {
  const _StageLegendItem({required this.stage, required this.textColor});
  final _Stage stage;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: stage.color,
            borderRadius: BorderRadius.circular(Radii.xs),
          ),
        ),
        const SizedBox(width: Spacing.xxs),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              stage.label.toUpperCase(),
              style: AppFonts.sf(
                size: 10.5,
                weight: FontWeight.w600,
                color: textColor,
              ),
            ),
            Text(
              hmShort(stage.minutes),
              style: AppFonts.sf(
                size: 13.5,
                weight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── DurationBig ─────────────────────────────────────────────────────────────

/// Large "Xh Ym" duration display with a delta-from-usual sub-line.
///
/// [light] = true renders on the hero (white text); false renders on surface.
class DurationBig extends StatelessWidget {
  const DurationBig({
    super.key,
    required this.minutes,
    required this.usualMinutes,
    required this.light,
    this.size = 44,
  });

  final int minutes;
  final int usualMinutes;
  final bool light;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final mainColor = light ? Colors.white : c.ink;
    final subColor = light
        ? Colors.white.withValues(alpha: 0.75)
        : c.ink3;

    final h = minutes ~/ 60;
    final m = minutes % 60;
    final delta = minutes - usualMinutes;
    final absDelta = delta.abs();

    String deltaText;
    String? deltaIcon;
    if (delta == 0 || usualMinutes == 0) {
      deltaText = usualMinutes == 0 ? '' : 'right on your usual';
      deltaIcon = null;
    } else {
      deltaText =
          '${hm(absDelta)} ${delta > 0 ? 'more' : 'less'} than your usual';
      deltaIcon = delta > 0 ? 'arrow.up' : 'arrow.down';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // big number row
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '$h',
              style: AppFonts.sfr(
                size: size,
                weight: FontWeight.w700,
                color: mainColor,
                letterSpacing: -1.2,
              ),
            ),
            Text(
              'h',
              style: AppFonts.sfr(
                size: size * 0.4,
                weight: FontWeight.w600,
                color: subColor,
              ),
            ),
            const SizedBox(width: Spacing.xxs),
            Text(
              m.toString().padLeft(2, '0'),
              style: AppFonts.sfr(
                size: size,
                weight: FontWeight.w700,
                color: mainColor,
                letterSpacing: -1.2,
              ),
            ),
            Text(
              'm',
              style: AppFonts.sfr(
                size: size * 0.4,
                weight: FontWeight.w600,
                color: subColor,
              ),
            ),
          ],
        ),
        // delta sub-line
        if (deltaText.isNotEmpty) ...[
          const SizedBox(height: Spacing.xxs),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (deltaIcon != null) ...[
                AppIcon(deltaIcon, size: 12, color: subColor),
                const SizedBox(width: Spacing.xxs),
              ],
              Text(
                deltaText,
                style: AppFonts.sf(
                  size: 12.5,
                  color: subColor,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ─── SleepTrendChart ─────────────────────────────────────────────────────────

/// Week/Month toggling bar chart with a dashed usual line.
///
/// [week] is a list of [SleepBar] from the controller (up to 7 nights);
/// [month] is up to 30 nights' asleepMinutes ascending.
class SleepTrendChart extends StatefulWidget {
  const SleepTrendChart({
    super.key,
    required this.week,
    required this.month,
    required this.usualMinutes,
  });

  final List<SleepBar> week;
  final List<int> month;
  final int usualMinutes;

  @override
  State<SleepTrendChart> createState() => _SleepTrendChartState();
}

enum _TrendMode { week, month }

class _SleepTrendChartState extends State<SleepTrendChart> {
  _TrendMode _mode = _TrendMode.week;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isWeek = _mode == _TrendMode.week;

    final series = isWeek
        ? widget.week.map((b) => b.minutes).toList()
        : widget.month;

    final maxVal = [
      ...series,
      widget.usualMinutes + 60,
    ].fold<int>(1, (a, b) => a > b ? a : b);

    // usualY: fraction from bottom (0 = bottom, 1 = top)
    final usualFrac = widget.usualMinutes / maxVal;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Spacing.lg, 0, Spacing.lg, Spacing.xl),
      child: Container(
        padding: const EdgeInsets.all(Spacing.lg),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.lg),
          boxShadow: [BoxShadow(color: c.hair, blurRadius: 0.5)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // header
            Row(
              children: [
                Text(
                  'Recent nights',
                  style: AppFonts.sf(
                    size: 14,
                    weight: FontWeight.w700,
                    color: c.ink,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 132,
                  child: Segmented<_TrendMode>(
                    options: const [
                      (_TrendMode.week, 'Week'),
                      (_TrendMode.month, 'Month'),
                    ],
                    value: _mode,
                    onChanged: (v) => setState(() => _mode = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.md),
            // chart area
            SizedBox(
              height: 92,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // dashed usual line
                  Positioned(
                    bottom: (usualFrac * 92).clamp(0.0, 88.0),
                    left: 0,
                    right: 0,
                    child: _DashedLine(color: c.sleep.withValues(alpha: 0.5)),
                  ),
                  // 'USUAL' label at right of the line
                  Positioned(
                    bottom: (usualFrac * 92).clamp(0.0, 88.0) + 2,
                    right: 0,
                    child: Text(
                      'USUAL',
                      style: AppFonts.sf(
                        size: 9.5,
                        weight: FontWeight.w700,
                        color: c.sleep,
                      ),
                    ),
                  ),
                  // bars row
                  Positioned.fill(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 0; i < series.length; i++) ...[
                          if (i > 0)
                            SizedBox(width: isWeek ? 7 : 2.5),
                          Expanded(
                            child: _TrendBar(
                              minutes: series[i],
                              maxVal: maxVal,
                              isToday: isWeek
                                  ? widget.week[i].isToday
                                  : i == series.length - 1,
                              isWeek: isWeek,
                              sleepColor: c.sleep,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // weekday letters (week mode only)
            if (isWeek && widget.week.isNotEmpty) ...[
              const SizedBox(height: Spacing.xs),
              Row(
                children: [
                  for (var i = 0; i < widget.week.length; i++) ...[
                    if (i > 0) const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        widget.week[i].dayLetter,
                        textAlign: TextAlign.center,
                        style: AppFonts.sf(
                          size: 10.5,
                          weight: widget.week[i].isToday
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: widget.week[i].isToday ? c.sleep : c.ink3,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: Spacing.md),
            // footer hairline + sentence
            Container(height: 0.5, color: c.hair),
            const SizedBox(height: Spacing.sm),
            Text(
              'Your usual is about ${hm(widget.usualMinutes)} a night'
              '${isWeek ? ' this fortnight' : ' over the last 30 nights'}.',
              style: AppFonts.sf(size: 12.5, color: c.ink3),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendBar extends StatelessWidget {
  const _TrendBar({
    required this.minutes,
    required this.maxVal,
    required this.isToday,
    required this.isWeek,
    required this.sleepColor,
  });

  final int minutes;
  final int maxVal;
  final bool isToday;
  final bool isWeek;
  final Color sleepColor;

  @override
  Widget build(BuildContext context) {
    // alpha hex: 5e≈0.37 (week), 40≈0.25 (month)
    final color = isToday
        ? sleepColor
        : sleepColor.withValues(alpha: isWeek ? 0.37 : 0.25);
    final frac = maxVal > 0 ? minutes / maxVal : 0.0;
    final radius = isWeek ? 6.0 : 3.0;

    return Align(
      alignment: Alignment.bottomCenter,
      child: FractionallySizedBox(
        heightFactor: frac.clamp(0.04, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
    );
  }
}

class _DashedLine extends StatelessWidget {
  const _DashedLine({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      child: CustomPaint(painter: _DashedLinePainter(color: color)),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dashW = 4.0;
    const gapW = 3.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset((x + dashW).clamp(0.0, size.width), 0), paint);
      x += dashW + gapW;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter old) => old.color != color;
}
