import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/profile_controller.dart';
import '../../controllers/rituals_controller.dart';
import '../../models/models.dart';
import '../../theme/theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/press_scale.dart';

/// Screen 13b — full-screen guided Routine Player.
///
/// Walks one [RitualStep] at a time: a tone-tinted glyph, "STEP n OF total"
/// eyebrow, title, note, and a "Mark done" button that records the step (via
/// `completeStep`) and advances. Opens at the routine's first incomplete step.
/// When every step is done it shows a completion state with a streak pill.
class RoutinePlayerScreen extends ConsumerStatefulWidget {
  const RoutinePlayerScreen({super.key, required this.routineId});

  final String routineId;

  @override
  ConsumerState<RoutinePlayerScreen> createState() =>
      _RoutinePlayerScreenState();
}

class _RoutinePlayerScreenState extends ConsumerState<RoutinePlayerScreen> {
  /// Current step index; null until seeded from the first-incomplete step once
  /// the routine loads. `>= steps.length` means the completion state.
  int? _idx;

  void _seed(RitualsState state, RitualRoutine routine) {
    _idx ??= state.firstIncompleteStep(routine);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final async = ref.watch(ritualsControllerProvider);

    return Scaffold(
      backgroundColor: c.bg,
      body: async.when(
        loading: () => const SizedBox.shrink(),
        error: (e, _) {
          debugPrint('RoutinePlayerScreen failed to load routine: $e');
          return const _NotFound(message: "Couldn't load routine.");
        },
        data: (state) {
          final matches =
              state.routines.where((r) => r.id == widget.routineId);
          final routine = matches.isEmpty ? null : matches.first;
          if (routine == null || routine.steps.isEmpty) {
            return const _NotFound(message: 'Routine not found.');
          }
          _seed(state, routine);
          return _Player(
            routine: routine,
            idx: _idx!,
            done: state.doneFor(routine.id),
            onBack: () => setState(() => _idx = (_idx! - 1).clamp(0, _idx!)),
            onSkip: () => setState(
                () => _idx = (_idx! + 1).clamp(0, routine.steps.length)),
            onMarkDone: () {
              ref
                  .read(ritualsControllerProvider.notifier)
                  .completeStep(routine, _idx!);
              setState(
                  () => _idx = (_idx! + 1).clamp(0, routine.steps.length));
            },
          );
        },
      ),
    );
  }
}

class _Player extends StatelessWidget {
  const _Player({
    required this.routine,
    required this.idx,
    required this.done,
    required this.onBack,
    required this.onSkip,
    required this.onMarkDone,
  });

  final RitualRoutine routine;
  final int idx;
  final Set<int> done;
  final VoidCallback onBack;
  final VoidCallback onSkip;
  final VoidCallback onMarkDone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tone = c.forType(routine.colorKey);
    final total = routine.steps.length;
    final onDeck = idx < total;
    // already-completed steps stay filled, even when ahead of the cursor.
    final stepDone = onDeck && done.contains(idx);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -1.2),
          radius: 1.0,
          colors: [tone.withValues(alpha: 0.15), c.bg],
          stops: const [0.0, 0.52],
        ),
      ),
      child: Column(
        children: [
          // top bar.
          Padding(
            padding: const EdgeInsets.fromLTRB(Spacing.lg, 54, Spacing.lg, Spacing.sm),
            child: Row(
              children: [
                PressScale(
                  onTap: () => context.go('/rituals'),
                  semanticLabel: 'Close',
                  pressedScale: 0.9,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration:
                            BoxDecoration(color: c.fill, shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: AppIcon('xmark', size: 16, color: c.ink2),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    routine.name.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: AppType.caption2.copyWith(
                      fontWeight: FontWeight.w700,
                      color: c.ink3,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                SizedBox(
                  width: 34,
                  child: Text(
                    '${(idx + 1).clamp(1, total)}/$total',
                    textAlign: TextAlign.right,
                    style: AppFonts.sfr(
                        size: 13, weight: FontWeight.w700, color: c.ink3),
                  ),
                ),
              ],
            ),
          ),
          // segmented progress bar.
          Padding(
            padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.md, Spacing.lg, 0),
            child: Row(
              children: [
                for (var i = 0; i < total; i++) ...[
                  if (i > 0) const SizedBox(width: Spacing.xs),
                  Expanded(
                    child: Container(
                      height: 5,
                      decoration: BoxDecoration(
                        color: (i < idx || done.contains(i)) ? tone : c.fill,
                        borderRadius: BorderRadius.circular(Radii.xs),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: const Cubic(0.22, 1, 0.36, 1),
              // each step slides up + fades, matching the design's ritualStep
              // keyframe; only the incoming child animates.
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.06),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: onDeck
                  ? _StepView(
                      key: ValueKey(idx),
                      step: routine.steps[idx],
                      idx: idx,
                      total: total,
                      tone: tone,
                    )
                  : _CompletionView(
                      key: const ValueKey('done'),
                      routine: routine,
                      tone: tone,
                    ),
            ),
          ),
          // controls.
          Padding(
            padding: const EdgeInsets.fromLTRB(Spacing.xl, 0, Spacing.xl, 40),
            child: onDeck
                ? Column(
                    children: [
                      _PrimaryButton(
                        label: stepDone ? 'Next step' : 'Mark done',
                        icon: 'checkmark',
                        tone: tone,
                        onTap: onMarkDone,
                      ),
                      const SizedBox(height: Spacing.lg),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _SecondaryAction(
                            label: 'Back',
                            icon: 'chevron.left',
                            enabled: idx > 0,
                            onTap: idx > 0 ? onBack : null,
                          ),
                          const SizedBox(width: Spacing.xxl),
                          _SecondaryAction(
                            label: 'Skip',
                            onTap: onSkip,
                          ),
                        ],
                      ),
                    ],
                  )
                : _PrimaryButton(
                    label: 'Back to routines',
                    tone: tone,
                    onTap: () => context.go('/rituals'),
                  ),
          ),
        ],
      ),
    );
  }
}

class _StepView extends StatelessWidget {
  const _StepView({
    super.key,
    required this.step,
    required this.idx,
    required this.total,
    required this.tone,
  });

  final RitualStep step;
  final int idx;
  final int total;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      // 30 has no spacing token; kept literal as a deliberate content inset.
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: tone.withValues(alpha: 0.2)),
              boxShadow: [
                // accent glow, not neutral elevation — kept inline.
                BoxShadow(
                  color: tone.withValues(alpha: 0.2),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: AppIcon(step.icon.isEmpty ? 'sparkles' : step.icon,
                size: 42, color: tone),
          ),
          const SizedBox(height: Spacing.xxl),
          Text(
            'STEP ${idx + 1} OF $total',
            style: AppType.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: tone,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: Spacing.md),
          Text(
            step.title,
            textAlign: TextAlign.center,
            style: AppFonts.sfr(
              size: 32,
              color: c.ink,
              letterSpacing: -0.6,
              height: 1.1,
            ),
          ),
          const SizedBox(height: Spacing.lg),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Text(
              step.note,
              textAlign: TextAlign.center,
              style: AppType.body.copyWith(
                color: c.ink2,
                letterSpacing: -0.2,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletionView extends ConsumerWidget {
  const _CompletionView({super.key, required this.routine, required this.tone});

  final RitualRoutine routine;
  final Color tone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final total = routine.steps.length;
    // real consecutive-day ritual streak from persisted completions (includes
    // today's just-finished routine); not the never-incremented seed value.
    final streak = ref.watch(profileStatsProvider).asData?.value.longestStreak;
    return Padding(
      // 30 has no spacing token; kept literal as a deliberate content inset.
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [tone, tone.withValues(alpha: 0.8)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                // accent glow, not neutral elevation — kept inline.
                BoxShadow(
                  color: tone.withValues(alpha: 0.33),
                  blurRadius: 36,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: AppIcon('checkmark', size: 54, color: c.onAccent),
          ),
          const SizedBox(height: Spacing.xxl),
          Text(
            '${routine.name} complete',
            textAlign: TextAlign.center,
            style: AppFonts.sfr(size: 30, color: c.ink, letterSpacing: -0.6),
          ),
          const SizedBox(height: Spacing.md),
          Text(
            'All $total steps done.',
            textAlign: TextAlign.center,
            style: AppType.callout
                .copyWith(color: c.ink2, letterSpacing: -0.2, height: 1.5),
          ),
          if (streak != null && streak > 0) ...[
            const SizedBox(height: Spacing.lg),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.lg, vertical: Spacing.sm),
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIcon('flame.fill', size: 14, color: tone),
                  const SizedBox(width: Spacing.sm),
                  Text(
                    '$streak-day streak',
                    style: AppType.subhead
                        .copyWith(fontWeight: FontWeight.w700, color: tone),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.tone,
    required this.onTap,
    this.icon,
  });

  final String label;
  final Color tone;
  final VoidCallback onTap;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PressScale(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          color: tone,
          borderRadius: BorderRadius.circular(Radii.lg),
          boxShadow: [
            // accent glow, not neutral elevation — kept inline.
            BoxShadow(
              color: tone.withValues(alpha: 0.3),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              AppIcon(icon!, size: 18, color: c.onAccent),
              const SizedBox(width: Spacing.sm),
            ],
            Text(label,
                style: AppType.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: c.onAccent,
                    letterSpacing: -0.2)),
          ],
        ),
      ),
    );
  }
}

class _SecondaryAction extends StatelessWidget {
  const _SecondaryAction({
    required this.label,
    this.icon,
    this.onTap,
    this.enabled = true,
  });

  final String label;
  final String? icon;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = enabled ? c.ink3 : c.ink4;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              AppIcon(icon!, size: 13, color: color),
              const SizedBox(width: Spacing.xs),
            ],
            Text(label,
                style: AppType.subhead.copyWith(
                    fontWeight: FontWeight.w600,
                    color: color,
                    letterSpacing: -0.2)),
          ],
        ),
      ),
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message,
                textAlign: TextAlign.center,
                style: AppType.body.copyWith(color: c.ink2)),
            const SizedBox(height: Spacing.lg),
            PressScale(
              onTap: () => context.go('/rituals'),
              child: Text('Back to routines',
                  style: AppType.headline.copyWith(color: c.accent)),
            ),
          ],
        ),
      ),
    );
  }
}
