import 'package:flutter/material.dart';

import '../../../controllers/mood_controller.dart' show MoodBar;
import '../../../theme/theme.dart';
import '../../../util/mood_scale.dart';

// ─── MoodMiniScale ────────────────────────────────────────────────────────────

/// A thin pleasant↔unpleasant rail with a white marker at [t].
///
/// [light] = on the teal hero (white-translucent rail); otherwise uses a
/// gradient from moodColor(0) → moodColor(1) for the normal surface context.
class MoodMiniScale extends StatelessWidget {
  const MoodMiniScale({
    super.key,
    required this.t,
    required this.dark,
    this.light = false,
  });

  final double t;
  final bool dark;
  final bool light;

  @override
  Widget build(BuildContext context) {
    const railH = 6.0;
    const markerSize = 12.0;
    const labelSize = 10.5;

    final labelStyle = AppType.caption2.copyWith(
      fontSize: labelSize,
      color: light ? const Color(0xB3FFFFFF) : context.colors.ink3,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (_, constraints) {
            final trackW = constraints.maxWidth;
            final markerLeft = (t.clamp(0.0, 1.0) * trackW - markerSize / 2)
                .clamp(0.0, trackW - markerSize);
            return SizedBox(
              height: markerSize,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // rail centered vertically in the marker height
                  Positioned(
                    top: (markerSize - railH) / 2,
                    left: 0,
                    right: 0,
                    child: _MiniRail(dark: dark, light: light, height: railH),
                  ),
                  // marker
                  Positioned(
                    left: markerLeft,
                    top: 0,
                    child: Container(
                      width: markerSize,
                      height: markerSize,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: Spacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Unpleasant', style: labelStyle),
            Text('Pleasant', style: labelStyle),
          ],
        ),
      ],
    );
  }
}

class _MiniRail extends StatelessWidget {
  const _MiniRail({required this.dark, required this.light, required this.height});
  final bool dark;
  final bool light;
  final double height;

  @override
  Widget build(BuildContext context) {
    final decoration = light
        ? BoxDecoration(
            color: Colors.white.withValues(alpha: 0.30),
            borderRadius: BorderRadius.circular(Radii.pill),
          )
        : BoxDecoration(
            gradient: LinearGradient(
              colors: [moodColor(0.0, dark), moodColor(0.5, dark), moodColor(1.0, dark)],
              stops: const [0.0, 0.5, 1.0],
            ),
            borderRadius: BorderRadius.circular(Radii.pill),
          );
    return Container(height: height, decoration: decoration);
  }
}

// ─── MoodWeekChart ────────────────────────────────────────────────────────────

/// Midline-anchored week chart: bars rise above midline for >0.5, dip below for
/// <0.5. Today's bar is ringed in moodColor. Days with null value show no bar.
class MoodWeekChart extends StatelessWidget {
  const MoodWeekChart({
    super.key,
    required this.week,
    required this.dark,
  });

  final List<MoodBar> week;
  final bool dark;

  // prototype: H=86, mid=43, half=34
  static const _chartH = 86.0;
  static const _mid = 43.0;
  static const _half = 34.0;
  static const _minBarH = 5.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _chartH,
          child: Stack(
            children: [
              // dashed midline
              Positioned(
                top: _mid - 0.5,
                left: 0,
                right: 0,
                child: _DashedLine(color: c.hair),
              ),
              // bars row
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: week
                    .map((bar) => Expanded(child: _DayBar(bar: bar, dark: dark)))
                    .toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.sm),
        // footer
        Text(
          'Above the line is more pleasant, below is less.',
          style: AppType.caption.copyWith(color: c.ink3),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _DayBar extends StatelessWidget {
  const _DayBar({required this.bar, required this.dark});
  final MoodBar bar;
  final bool dark;

  static const _mid = MoodWeekChart._mid;
  static const _half = MoodWeekChart._half;
  static const _minH = MoodWeekChart._minBarH;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final v = bar.value;
    final color = v != null ? moodColor(v, dark) : c.hair;

    // bar geometry
    double barH = 0;
    double barTop = _mid;
    if (v != null) {
      final off = v - 0.5;
      barH = (off.abs() / 0.5 * _half).clamp(_minH, _half);
      barTop = off >= 0 ? _mid - barH : _mid;
    }

    final letterStyle = AppType.caption2.copyWith(
      fontSize: 11,
      fontWeight: bar.isToday ? FontWeight.w700 : FontWeight.w400,
      color: bar.isToday ? moodColor(v ?? 0.5, dark) : c.ink3,
    );

    return Column(
      children: [
        SizedBox(
          height: MoodWeekChart._chartH - 16, // leave room for letter row
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              if (v != null)
                Positioned(
                  top: barTop,
                  left: 4,
                  right: 4,
                  child: Container(
                    height: barH,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(Radii.xs),
                      // today ring
                      boxShadow: bar.isToday
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.55),
                                blurRadius: 0,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.xxs),
        Text(bar.dayLetter, style: letterStyle, textAlign: TextAlign.center),
      ],
    );
  }
}

class _DashedLine extends StatelessWidget {
  const _DashedLine({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 1),
      painter: _DashedLinePainter(color: color),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  _DashedLinePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5;
    const dash = 4.0;
    const gap = 4.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dash, 0), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter old) => old.color != color;
}

// ─── MoodOrb ─────────────────────────────────────────────────────────────────

/// A morphing orb that shifts shape (via borderRadius) and color with [t].
///
/// Prototype math:
///   squish  = 1 + (t - 0.5) * 0.16   — taller/rounder when pleasant
///   r       = 50 - (t - 0.5) * 14    — borderRadius% of the orb's half-size
///
/// The radial gradient simulates a spherical light source: brighter at t+0.18,
/// core at t, dark edge at t-0.12.
class MoodOrb extends StatelessWidget {
  const MoodOrb({
    super.key,
    required this.t,
    required this.dark,
    this.size = 116,
  });

  final double t;
  final bool dark;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tc = t.clamp(0.0, 1.0);
    final squish = 1.0 + (tc - 0.5) * 0.16;
    // r is a percentage of half-size → convert to pixel radius
    final rPct = 50.0 - (tc - 0.5) * 14.0;
    final rPx = (rPct / 100.0) * (size / 2);

    final core = moodColor(tc, dark);
    final highlight = moodColor((tc + 0.18).clamp(0.0, 1.0), dark);
    final shadow = moodColor((tc - 0.12).clamp(0.0, 1.0), dark);

    // prototype: borderRadius `${r}% ${100-r}% ${r}% ${100-r}% / ${100-r}% ${r}% ${100-r}% ${r}%`
    // CSS blob shape approximated with per-corner elliptical radii.
    final r1 = rPx;
    final borderRadius = BorderRadius.only(
      topLeft: Radius.elliptical(r1, size / 2 - r1),
      topRight: Radius.elliptical(size / 2 - r1, r1),
      bottomLeft: Radius.elliptical(size / 2 - r1, r1),
      bottomRight: Radius.elliptical(r1, size / 2 - r1),
    );

    return Transform.scale(
      scaleX: 1.0,
      scaleY: squish,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          gradient: RadialGradient(
            center: const Alignment(-0.24, -0.36), // 38% 32% from prototype
            radius: 0.85,
            colors: [highlight, core, shadow],
            stops: const [0.0, 0.62, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: core.withValues(alpha: 0.40),
              blurRadius: 40,
              offset: const Offset(0, 14),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── MoodScaleTrack ───────────────────────────────────────────────────────────

/// Interactive gradient rail with a draggable thumb.
///
/// Pointer math (mirrors prototype `setFromX`):
///   f = (localX - 0) / trackWidth, clamped to [0, 1]
///
/// Verified: tap far-right → localX ≈ trackWidth → f ≈ 1.0
///           tap far-left  → localX ≈ 0           → f ≈ 0.0
///           tap center    → localX ≈ width/2     → f ≈ 0.5
class MoodScaleTrack extends StatelessWidget {
  const MoodScaleTrack({
    super.key,
    required this.t,
    required this.onChanged,
    required this.dark,
  });

  final double t;
  final ValueChanged<double> onChanged;
  final bool dark;

  static const _trackH = 44.0;
  static const _railH = 12.0;
  static const _thumbSize = 34.0;
  static const _tickCount = 7;

  void _handlePointer(BuildContext context, Offset globalPosition) {
    final box = context.findRenderObject()! as RenderBox;
    final local = box.globalToLocal(globalPosition);
    final f = (local.dx / box.size.width).clamp(0.0, 1.0);
    onChanged(f);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tc = t.clamp(0.0, 1.0);
    final thumbColor = moodColor(tc, dark);

    final labelStyle = AppType.caption2.copyWith(
      fontSize: 11,
      color: c.ink3,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTapDown: (d) => _handlePointer(context, d.globalPosition),
          onHorizontalDragUpdate: (d) => _handlePointer(context, d.globalPosition),
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            height: _trackH,
            child: LayoutBuilder(
              builder: (_, constraints) {
                final trackW = constraints.maxWidth;
                // thumb center position clamped so thumb stays within track
                final thumbCenter = tc * trackW;
                final thumbLeft =
                    (thumbCenter - _thumbSize / 2).clamp(0.0, trackW - _thumbSize);

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // rail
                    Container(
                      height: _railH,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            moodColor(0.0, dark).withValues(alpha: 0.42),
                            moodColor(0.5, dark).withValues(alpha: 0.42),
                            moodColor(1.0, dark).withValues(alpha: 0.42),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                        borderRadius: BorderRadius.circular(Radii.pill),
                      ),
                    ),
                    // tick dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(_tickCount, (i) {
                        return Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.60),
                            shape: BoxShape.circle,
                          ),
                        );
                      }),
                    ),
                    // thumb
                    Positioned(
                      left: thumbLeft,
                      child: Container(
                        width: _thumbSize,
                        height: _thumbSize,
                        decoration: BoxDecoration(
                          color: thumbColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: thumbColor.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: Spacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Unpleasant', style: labelStyle),
            Text('Pleasant', style: labelStyle),
          ],
        ),
      ],
    );
  }
}

