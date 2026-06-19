import 'package:flutter/widgets.dart';

import '../controllers/insights_money_controller.dart';
import '../theme/theme.dart';

/// A 6-month spend bar chart: one bar per [MonthSpend] (height ∝ total / max),
/// with a dashed average reference line, a value label above each bar and a
/// month label below. The current month is solid + bold; prior months are a
/// faded fill; the partial (current) month is overlaid with a diagonal hatch.
class MonthlyBarChart extends StatelessWidget {
  const MonthlyBarChart({
    super.key,
    required this.months,
    required this.average,
    required this.color,
  });

  final List<MonthSpend> months;
  final double average;
  final Color color;

  static const double _barsHeight = 130;
  static const double _labelGap = 7;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = c.brightness == Brightness.dark;
    final maxV = months.fold<double>(0, (m, e) => e.total > m ? e.total : m);
    final fadedFill = color.withValues(alpha: dark ? 0.33 : 0.2);

    return SizedBox(
      // headroom for the value + month labels so the tallest bar (full
      // _barsHeight) doesn't push the column past the box and overflow.
      height: _barsHeight + 52,
      child: Stack(
        children: [
          // Dashed average reference line, positioned over the bars band.
          if (maxV > 0 && average > 0)
            Positioned(
              left: 0,
              right: 0,
              // bars sit above their value label (~14) at the band bottom.
              bottom: 18 + (average / maxV) * _barsHeight,
              child: CustomPaint(
                size: const Size(double.infinity, 1.5),
                painter: _DashedLinePainter(color: c.ink4),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < months.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: _Bar(
                    month: months[i],
                    isCurrent: i == months.length - 1,
                    heightFrac: maxV == 0 ? 0 : months[i].total / maxV,
                    barsHeight: _barsHeight,
                    labelGap: _labelGap,
                    color: color,
                    fadedFill: fadedFill,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.month,
    required this.isCurrent,
    required this.heightFrac,
    required this.barsHeight,
    required this.labelGap,
    required this.color,
    required this.fadedFill,
  });

  final MonthSpend month;
  final bool isCurrent;
  final double heightFrac;
  final double barsHeight;
  final double labelGap;
  final Color color;
  final Color fadedFill;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final h = (heightFrac.clamp(0.0, 1.0)) * barsHeight;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${(month.total / 1000).toStringAsFixed(1)}k',
          style: AppFonts.sf(
            size: 10,
            weight: FontWeight.w600,
            color: isCurrent ? color : c.ink3,
            tabular: true,
          ),
        ),
        SizedBox(height: labelGap),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 26),
          child: Container(
            height: h,
            decoration: BoxDecoration(
              color: isCurrent ? color : fadedFill,
              borderRadius: BorderRadius.circular(7),
            ),
            clipBehavior: Clip.antiAlias,
            child: month.partial
                ? CustomPaint(
                    painter: _HatchPainter(color: c.bg),
                    size: Size(double.infinity, h),
                  )
                : null,
          ),
        ),
        SizedBox(height: labelGap),
        Text(
          month.label,
          style: AppFonts.sf(
            size: 11,
            weight: isCurrent ? FontWeight.w700 : FontWeight.w500,
            color: isCurrent ? c.ink : c.ink3,
          ),
        ),
      ],
    );
  }
}

/// Diagonal stripe hatch overlaid on the partial (current) month bar — the
/// equivalent of the design's repeating-linear-gradient at 45°.
class _HatchPainter extends CustomPainter {
  _HatchPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    const gap = 6.0;
    // 45° stripes: draw lines whose x-intercept walks across the rect width.
    for (var x = -size.height; x < size.width; x += gap) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_HatchPainter old) => old.color != color;
}

/// A horizontal dashed line (the average reference) spanning the chart width.
class _DashedLinePainter extends CustomPainter {
  _DashedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    const dash = 5.0;
    const gap = 4.0;
    for (var x = 0.0; x < size.width; x += dash + gap) {
      canvas.drawLine(Offset(x, 0), Offset(x + dash, 0), paint);
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter old) => old.color != color;
}
