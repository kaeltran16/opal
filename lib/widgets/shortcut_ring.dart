import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../analysis/area_state.dart';
import '../theme/theme.dart';
import 'app_icon.dart';
import 'state_colors.dart';

const double _size = 56;
const double _stroke = 3;
const double _radius = (_size - _stroke) / 2;
const double _iconSize = 20;
const double _checkSize = 14;
const double _checkGlyph = 10;
const double _minTarget = 44;
const double _top = -math.pi / 2;
const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

/// One glance on Today: an arc for [fraction], the number it states and the
/// state word. The whole column is one button.
class ShortcutRing extends StatelessWidget {
  const ShortcutRing({
    super.key,
    required this.icon,
    required this.value,
    required this.state,
    required this.fraction,
    required this.semanticLabel,
    required this.onTap,
  });

  final String icon;
  final String value;
  final AreaState state;
  final double fraction;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final turn = fraction.isFinite ? fraction.clamp(0.0, 1.0) : 0.0;
    final end = _top + 2 * math.pi * turn;
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      // excluding the subtree drops the detector's own tap action.
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: _minTarget, minHeight: _minTarget),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: _size,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size.square(_size),
                      painter: _RingPainter(
                        turn: turn,
                        fill: c.surface,
                        track: c.track,
                        arc: c.arcFor(state),
                      ),
                    ),
                    AppIcon(icon, size: _iconSize, color: c.ink),
                    if (state == AreaState.thriving)
                      Positioned(
                        left: _size / 2 + _radius * math.cos(end) - _checkSize / 2,
                        top: _size / 2 + _radius * math.sin(end) - _checkSize / 2,
                        child: Container(
                          width: _checkSize,
                          height: _checkSize,
                          decoration: BoxDecoration(color: c.thriving, shape: BoxShape.circle),
                          child: AppIcon('checkmark', size: _checkGlyph, color: c.bg),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: Spacing.xs),
              // a long amount shrinks rather than truncating to a wrong number.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  maxLines: 1,
                  style: AppType.headline.copyWith(color: c.ink, fontFeatures: _tabular),
                ),
              ),
              Text(
                state.word,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.caption.copyWith(color: c.wordInkFor(state)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.turn,
    required this.fill,
    required this.track,
    required this.arc,
  });

  final double turn;
  final Color fill;
  final Color track;
  final Color arc;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    canvas.drawCircle(center, _radius, Paint()..color = fill);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, _radius, stroke..color = track);
    if (turn > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: _radius),
        _top,
        2 * math.pi * turn,
        false,
        stroke..color = arc,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.turn != turn || old.fill != fill || old.track != track || old.arc != arc;
}
