import 'package:flutter/material.dart';

import '../../../theme/theme.dart';
import '../../../util/mood_scale.dart';

// ─── MoodOrb ─────────────────────────────────────────────────────────────────

/// A morphing orb that shifts shape (via borderRadius) and color with [t].
///
/// Prototype math:
///   squish  = 1 + (t - 0.5) * 0.16   — taller/rounder when pleasant
///   r       = 50 - (t - 0.5) * 14    — borderRadius% of the full orb box
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

  static const _squishFactor = 0.16;
  static const _radiusSwingPct = 14.0;

  @override
  Widget build(BuildContext context) {
    final tc = t.clamp(0.0, 1.0);
    final squish = 1.0 + (tc - 0.5) * _squishFactor;
    // css percentages are of the full box, so a neutral r of 50% is a circle
    final rPct = 50.0 - (tc - 0.5) * _radiusSwingPct;
    final a = (rPct / 100.0) * size;
    final b = size - a;

    final core = moodColor(tc, dark);
    final highlight = moodColor((tc + 0.18).clamp(0.0, 1.0), dark);
    final shadow = moodColor((tc - 0.12).clamp(0.0, 1.0), dark);

    // prototype: borderRadius `${r}% ${100-r}% ${r}% ${100-r}% / ${100-r}% ${r}% ${100-r}% ${r}%`
    final borderRadius = BorderRadius.only(
      topLeft: Radius.elliptical(a, b),
      topRight: Radius.elliptical(b, a),
      bottomRight: Radius.elliptical(a, b),
      bottomLeft: Radius.elliptical(b, a),
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

    final labelStyle = AppType.caption.copyWith(color: c.ink3);

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

