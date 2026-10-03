import 'package:flutter/material.dart';

import '../theme/theme.dart';

const int _noonHour = 12;
const int _eveningHour = 18;

/// The landscape's mood for [now]: morning before 12:00, afternoon before
/// 18:00, evening after.
DayPhase phaseFor(DateTime now) {
  if (now.hour < _noonHour) return DayPhase.morning;
  if (now.hour < _eveningHour) return DayPhase.afternoon;
  return DayPhase.evening;
}

// the prototype's board: every measurement below is in these units and scales
// with the widget's width.
const double _designWidth = 390;
const double _designHeight = 382;
const double _skyHeight = 380;
const double _sunRadius = 75;
const double _hillsTop = 190;
const double _fadeTop = 320;

// the glow holds this share of its peak alpha at 30% of the radius. the
// prototype's three glows sit at 0.59, 0.60 and 0.56 of their peaks.
const double _sunMidShare = 0.58;
const List<double> _sunStops = [0, 0.3, 1];

const Duration _crossFade = Duration(milliseconds: 700);

/// The drawn time-of-day landscape behind the top of Today: sky, sun glow and
/// three hill layers, fading into `bg` at its foot. Sized from its width.
class DayScene extends StatelessWidget {
  const DayScene({super.key, required this.phase});

  final DayPhase phase;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scene = CustomPaint(
      key: ValueKey(phase),
      size: Size.infinite,
      painter: _ScenePainter(
        palette: scenePalette(phase, colors.brightness),
        bg: colors.bg,
      ),
    );
    return ExcludeSemantics(
      child: AspectRatio(
        aspectRatio: _designWidth / _designHeight,
        child: MediaQuery.disableAnimationsOf(context)
            ? scene
            : AnimatedSwitcher(
                duration: _crossFade,
                switchInCurve: Curves.easeInOut,
                switchOutCurve: Curves.easeInOut,
                child: scene,
              ),
      ),
    );
  }
}

class _ScenePainter extends CustomPainter {
  const _ScenePainter({required this.palette, required this.bg});

  final ScenePalette palette;
  final Color bg;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / _designWidth;
    canvas.save();
    // the afternoon sun hangs past the top edge.
    canvas.clipRect(Offset.zero & size);
    canvas.scale(scale);
    _paintSky(canvas);
    _paintSun(canvas);
    _paintHills(canvas);
    _paintFade(canvas);
    canvas.restore();
  }

  void _paintSky(Canvas canvas) {
    const sky = Rect.fromLTWH(0, 0, _designWidth, _skyHeight);
    canvas.drawRect(
      sky,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: palette.sky,
          stops: palette.skyStops,
        ).createShader(sky),
    );
  }

  void _paintSun(Canvas canvas) {
    final center = palette.sunCenter.alongSize(
      const Size(_designWidth, _skyHeight),
    );
    final glow = Rect.fromCircle(center: center, radius: _sunRadius);
    final sun = palette.sun;
    canvas.drawCircle(
      center,
      _sunRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            sun,
            sun.withValues(alpha: sun.a * _sunMidShare),
            sun.withValues(alpha: 0),
          ],
          stops: _sunStops,
        ).createShader(glow),
    );
  }

  void _paintHills(Canvas canvas) {
    canvas.save();
    canvas.translate(0, _hillsTop);
    canvas.drawPath(_farHill, Paint()..color = palette.far);
    canvas.drawPath(_midHill, Paint()..color = palette.mid);
    canvas.drawPath(_nearHill, Paint()..color = palette.near);
    canvas.restore();
  }

  void _paintFade(Canvas canvas) {
    const fade = Rect.fromLTRB(0, _fadeTop, _designWidth, _designHeight);
    canvas.drawRect(
      fade,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [bg.withValues(alpha: 0), bg],
        ).createShader(fade),
    );
  }

  @override
  bool shouldRepaint(_ScenePainter old) =>
      old.palette != palette || old.bg != bg;
}

// the prototype's three svg paths, in a 390 by 190 band.
const double _bandHeight = 190;

Path _hill(double startY, List<double> c1, List<double> c2) => Path()
  ..moveTo(0, startY)
  ..cubicTo(c1[0], c1[1], c1[2], c1[3], c1[4], c1[5])
  ..cubicTo(c2[0], c2[1], c2[2], c2[3], c2[4], c2[5])
  ..lineTo(_designWidth, _bandHeight)
  ..lineTo(0, _bandHeight)
  ..close();

final Path _farHill = _hill(
  90,
  [60, 50, 120, 40, 180, 70],
  [240, 100, 300, 60, 390, 40],
);
final Path _midHill = _hill(
  120,
  [80, 90, 140, 130, 210, 110],
  [280, 90, 330, 120, 390, 100],
);
final Path _nearHill = _hill(
  150,
  [70, 130, 150, 160, 230, 145],
  [300, 132, 350, 150, 390, 140],
);
