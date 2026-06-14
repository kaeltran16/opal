import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/rituals_controller.dart';
import '../../models/models.dart';
import '../../theme/theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/nav_bar.dart';
import '../../widgets/press_scale.dart';

/// Screen 13 — Rituals landing, reframed as time-of-day routines.
///
/// Large-title nav "Rituals" + "{done} of {total} steps today", an up-next
/// gradient hero in the active routine's tone color, the "Your day" timeline
/// spine (one node + card per routine, with tappable step rows + a tinted
/// start button), and a dashed "New routine" footer. All math lives in
/// `ritualsControllerProvider`; toggling a step writes/removes a ritual `Entry`.
class RitualsScreen extends ConsumerWidget {
  const RitualsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final async = ref.watch(ritualsControllerProvider);

    return async.when(
      loading: () => Center(
        child: Text('…', style: AppType.body.copyWith(color: c.ink3)),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.xxl),
          child: Text("Couldn't load routines.\n$e",
              textAlign: TextAlign.center,
              style: AppType.subhead
                  .copyWith(color: c.ink3, letterSpacing: -0.24)),
        ),
      ),
      data: (state) => _RitualsBody(state: state),
    );
  }
}

class _RitualsBody extends StatelessWidget {
  const _RitualsBody({required this.state});
  final RitualsState state;

  @override
  Widget build(BuildContext context) {
    return LargeTitleScrollView(
      title: 'Routines',
      subtitle: '${state.doneSteps} of ${state.totalSteps} steps today',
      trailing: NavIconButton(
        name: 'plus',
        semanticLabel: 'New routine',
        onTap: () => context.go('/rituals/manage'),
      ),
      padding: const EdgeInsets.only(bottom: 110),
      children: [
        _UpNextHero(state: state),
        _Timeline(state: state),
        const _NewRoutineButton(),
      ],
    );
  }
}

// ─── Up-next hero ───────────────────────────────────────────────────────────

class _UpNextHero extends StatelessWidget {
  const _UpNextHero({required this.state});
  final RitualsState state;

  static const _minutesPerStep = 5;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final routine = state.upNext;

    if (routine == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.xl),
        child: Container(
          padding: const EdgeInsets.all(Spacing.xxl),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(Radii.xl),
            boxShadow: [BoxShadow(color: c.hair, blurRadius: 0.5)],
          ),
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                    color: c.moveTint, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: AppIcon('checkmark', size: 24, color: c.move),
              ),
              const SizedBox(height: Spacing.md),
              Text('All routines done',
                  style: AppFonts.sfr(
                      size: 20, color: c.ink, letterSpacing: -0.4)),
              const SizedBox(height: Spacing.xs),
              Text('Every step checked off. Rest easy.',
                  textAlign: TextAlign.center,
                  style: AppType.subhead.copyWith(
                      color: c.ink3, letterSpacing: -0.1)),
            ],
          ),
        ),
      );
    }

    final tone = c.forType(routine.colorKey);
    final left = state.stepsLeft(routine);
    final inProgress = state.doneCount(routine.id) > 0;
    final done = state.doneCount(routine.id);

    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.xl),
      child: PressScale(
        onTap: () => context.go('/rituals/player/${routine.id}'),
        pressedScale: 0.985,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.xl),
            boxShadow: [
              // accent glow, not neutral elevation — kept inline.
              BoxShadow(
                color: tone.withValues(alpha: 0.25),
                blurRadius: 34,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Radii.xl),
            child: Stack(
              children: [
                // base tone gradient.
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          tone,
                          tone.withValues(alpha: 0.87),
                          tone.withValues(alpha: 0.69),
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),
                ),
                // translucent white blob, top-right.
                Positioned(
                  top: -50,
                  right: -40,
                  child: Container(
                    width: 170,
                    height: 170,
                    decoration: const BoxDecoration(
                      color: Color(0x1AFFFFFF),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                // diagonal hairline hatch overlay.
                Positioned.fill(
                  child: CustomPaint(
                    painter: _HatchPainter(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(Spacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIcon(routine.icon, size: 13, color: c.onAccent),
                  const SizedBox(width: Spacing.sm),
                  Text(
                    (inProgress
                            ? 'Pick up where you left off'
                            : 'Up next')
                        .toUpperCase(),
                    style: AppType.caption2.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xD9FFFFFF),
                      letterSpacing: 1.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.md),
              Text(
                routine.name,
                style: AppFonts.sfr(
                  size: 28,
                  color: c.onAccent,
                  letterSpacing: -0.6,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: Spacing.xs),
              Text(
                '${routine.time} · $left ${left == 1 ? 'step' : 'steps'} left · ~${left * _minutesPerStep} min',
                style: AppType.subhead.copyWith(
                  color: const Color(0xE6FFFFFF),
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: Spacing.lg),
              // segmented progress pips — one per step, white when done.
              Row(
                children: [
                  for (var i = 0; i < routine.steps.length; i++) ...[
                    if (i > 0) const SizedBox(width: Spacing.xs),
                    Expanded(
                      child: Container(
                        height: 5,
                        decoration: BoxDecoration(
                          color: i < done
                              ? c.onAccent
                              : const Color(0x52FFFFFF),
                          borderRadius: BorderRadius.circular(Radii.xs),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: Spacing.xl),
              Container(
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(
                  color: c.onAccent,
                  borderRadius: BorderRadius.circular(Radii.card),
                  boxShadow: Elevation.card(c.shadow),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIcon('play.fill', size: 15, color: tone),
                    const SizedBox(width: Spacing.sm),
                    Text(
                      inProgress ? 'Continue routine' : 'Begin routine',
                      style: AppType.callout.copyWith(
                        fontWeight: FontWeight.w700,
                        color: tone,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints the hero's diagonal hairline hatch — repeating 1px translucent-white
/// stripes at ~125°, matching the design's `repeating-linear-gradient`.
class _HatchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x0AFFFFFF)
      ..strokeWidth = 1;
    // 125° from horizontal; step 25px along the perpendicular, drawn as long
    // diagonal lines that cover the box corner-to-corner.
    const spacing = 25.0;
    final extent = size.width + size.height;
    for (var d = -size.height; d < extent; d += spacing) {
      // slope for 125° (down-left to up-right), tan(125°) ≈ -1.43.
      canvas.drawLine(
        Offset(d, 0),
        Offset(d + size.height * 1.43, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_HatchPainter old) => false;
}

// ─── Timeline body ──────────────────────────────────────────────────────────

class _Timeline extends StatelessWidget {
  const _Timeline({required this.state});
  final RitualsState state;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (state.routines.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, 0),
        child: Center(
          child: Text('No routines yet. Add one to get started.',
              textAlign: TextAlign.center,
              style: AppType.subhead
                  .copyWith(color: c.ink3, letterSpacing: -0.24)),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Spacing.xs, 0, Spacing.xs, Spacing.md),
            child: Text('YOUR DAY',
                style: AppType.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: c.ink3,
                    letterSpacing: 0.8)),
          ),
          Stack(
            children: [
              // the vertical spine.
              Positioned(
                left: 13,
                top: 8,
                bottom: 24,
                child: Container(width: 2, color: c.hair),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 34),
                child: Column(
                  children: [
                    for (final r in state.routines)
                      _TimelineNode(routine: r, state: state),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimelineNode extends StatelessWidget {
  const _TimelineNode({required this.routine, required this.state});
  final RitualRoutine routine;
  final RitualsState state;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tone = c.forType(routine.colorKey);
    final complete = state.isComplete(routine);
    final done = state.doneCount(routine.id);

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.lg),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // node, hung off the card's left edge over the spine.
          Positioned(
            left: -34,
            top: 16,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: complete ? tone : c.surface,
                shape: BoxShape.circle,
                border: complete ? null : Border.all(color: tone, width: 2),
                boxShadow: [BoxShadow(color: c.bg, blurRadius: 0, spreadRadius: 4)],
              ),
              alignment: Alignment.center,
              child: complete
                  ? AppIcon('checkmark', size: 15, color: c.onAccent)
                  : AppIcon(routine.icon, size: 14, color: tone),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(Radii.lg),
              boxShadow: [BoxShadow(color: c.hair, blurRadius: 0.5)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(routine.name,
                        style: AppType.callout.copyWith(
                            fontWeight: FontWeight.w700,
                            color: c.ink,
                            letterSpacing: -0.3)),
                    const SizedBox(width: Spacing.sm),
                    Text(routine.time,
                        style: AppFonts.sfr(
                            size: 12,
                            weight: FontWeight.w600,
                            color: tone,
                            letterSpacing: -0.1)),
                    const Spacer(),
                    Text('$done/${routine.steps.length}',
                        style: AppFonts.sfr(
                            size: 13,
                            weight: FontWeight.w700,
                            color: c.ink3)),
                  ],
                ),
                const SizedBox(height: Spacing.md),
                for (var i = 0; i < routine.steps.length; i++)
                  _StepRow(
                    routine: routine,
                    index: i,
                    done: state.isStepDone(routine.id, i),
                    tone: tone,
                  ),
                const SizedBox(height: Spacing.md),
                _StartButton(routine: routine, state: state, tone: tone),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends ConsumerWidget {
  const _StepRow({
    required this.routine,
    required this.index,
    required this.done,
    required this.tone,
  });

  final RitualRoutine routine;
  final int index;
  final bool done;
  final Color tone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => ref
          .read(ritualsControllerProvider.notifier)
          .toggleStep(routine, index),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
        child: Row(
          children: [
            // 180ms fill matches the shared CheckButton's check animation.
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: done ? tone : Colors.transparent,
                shape: BoxShape.circle,
                border: done ? null : Border.all(color: c.ink4, width: 1.5),
              ),
              alignment: Alignment.center,
              child: done
                  ? AppIcon('checkmark', size: 11, color: c.onAccent)
                  : null,
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Text(
                routine.steps[index].title,
                // 14.5 has no type token; kept inline to preserve exact size.
                style: AppFonts.sf(
                  size: 14.5,
                  color: done ? c.ink3 : c.ink2,
                  letterSpacing: -0.2,
                ).copyWith(
                  decoration: done ? TextDecoration.lineThrough : null,
                  decorationColor: c.ink3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({
    required this.routine,
    required this.state,
    required this.tone,
  });

  final RitualRoutine routine;
  final RitualsState state;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final complete = state.isComplete(routine);
    final inProgress = state.doneCount(routine.id) > 0;
    final label = complete
        ? 'Run again'
        : inProgress
            ? 'Continue'
            : 'Start';
    final icon = complete ? 'arrow.triangle.2.circlepath' : 'play.fill';

    return PressScale(
      onTap: () => context.go('/rituals/player/${routine.id}'),
      child: Container(
        width: double.infinity,
        height: 38,
        decoration: BoxDecoration(
          color: tone.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(icon, size: 13, color: tone),
            const SizedBox(width: Spacing.sm),
            Text(label,
                style: AppType.subhead.copyWith(
                    fontWeight: FontWeight.w700,
                    color: tone,
                    letterSpacing: -0.2)),
          ],
        ),
      ),
    );
  }
}

// ─── Footer ─────────────────────────────────────────────────────────────────

class _NewRoutineButton extends StatelessWidget {
  const _NewRoutineButton();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.xs, Spacing.lg, 0),
      child: PressScale(
        onTap: () => context.go('/rituals/manage'),
        child: DottedBorderBox(
          color: c.hair,
          radius: Radii.card,
          child: SizedBox(
            height: 46,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIcon('plus', size: 14, color: c.ink3),
                  const SizedBox(width: Spacing.sm),
                  Text('New routine',
                      style: AppType.subhead.copyWith(
                          fontWeight: FontWeight.w600,
                          color: c.ink3,
                          letterSpacing: -0.24)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A rounded box with a dashed border, painted via [CustomPaint] (Flutter has
/// no built-in dashed border).
class DottedBorderBox extends StatelessWidget {
  const DottedBorderBox({
    super.key,
    required this.child,
    required this.color,
    this.radius = Radii.md,
  });

  final Widget child;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(color: color, radius: radius),
      child: child,
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);

    const dash = 5.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dash),
          paint,
        );
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
