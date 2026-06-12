import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/rituals_controller.dart';
import '../../models/models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
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
            padding: const EdgeInsets.fromLTRB(16, 54, 16, 6),
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
                    style: AppFonts.sf(
                      size: 11,
                      weight: FontWeight.w700,
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
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                for (var i = 0; i < total; i++) ...[
                  if (i > 0) const SizedBox(width: 5),
                  Expanded(
                    child: Container(
                      height: 5,
                      decoration: BoxDecoration(
                        color: (i < idx || done.contains(i)) ? tone : c.fill,
                        borderRadius: BorderRadius.circular(3),
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
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            child: onDeck
                ? Column(
                    children: [
                      _PrimaryButton(
                        label: stepDone ? 'Next step' : 'Mark done',
                        icon: 'checkmark',
                        tone: tone,
                        onTap: onMarkDone,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _SecondaryAction(
                            label: 'Back',
                            icon: 'chevron.left',
                            enabled: idx > 0,
                            onTap: idx > 0 ? onBack : null,
                          ),
                          const SizedBox(width: 24),
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
          const SizedBox(height: 26),
          Text(
            'STEP ${idx + 1} OF $total',
            style: AppFonts.sf(
              size: 12,
              weight: FontWeight.w700,
              color: tone,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 10),
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
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Text(
              step.note,
              textAlign: TextAlign.center,
              style: AppFonts.sf(
                size: 17,
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

class _CompletionView extends StatelessWidget {
  const _CompletionView({super.key, required this.routine, required this.tone});

  final RitualRoutine routine;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final total = routine.steps.length;
    return Padding(
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
                BoxShadow(
                  color: tone.withValues(alpha: 0.33),
                  blurRadius: 36,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const AppIcon('checkmark', size: 54, color: Color(0xFFFFFFFF)),
          ),
          const SizedBox(height: 24),
          Text(
            '${routine.name} complete',
            textAlign: TextAlign.center,
            style: AppFonts.sfr(size: 30, color: c.ink, letterSpacing: -0.6),
          ),
          const SizedBox(height: 10),
          Text(
            'All $total steps done.',
            textAlign: TextAlign.center,
            style: AppFonts.sf(
                size: 16, color: c.ink2, letterSpacing: -0.2, height: 1.5),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon('flame.fill', size: 14, color: tone),
                const SizedBox(width: 7),
                Text(
                  '${routine.streak + 1}-day streak',
                  style: AppFonts.sf(
                      size: 14, weight: FontWeight.w700, color: tone),
                ),
              ],
            ),
          ),
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
    return PressScale(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          color: tone,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
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
              AppIcon(icon!, size: 18, color: const Color(0xFFFFFFFF)),
              const SizedBox(width: 9),
            ],
            Text(label,
                style: AppFonts.sf(
                    size: 17,
                    weight: FontWeight.w700,
                    color: const Color(0xFFFFFFFF),
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
              const SizedBox(width: 4),
            ],
            Text(label,
                style: AppFonts.sf(
                    size: 15,
                    weight: FontWeight.w600,
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message,
                textAlign: TextAlign.center,
                style:
                    AppFonts.sf(size: 17, color: c.ink2, letterSpacing: -0.43)),
            const SizedBox(height: 16),
            PressScale(
              onTap: () => context.go('/rituals'),
              child: Text('Back to routines',
                  style: AppFonts.sf(
                      size: 17,
                      weight: FontWeight.w600,
                      color: c.accent,
                      letterSpacing: -0.43)),
            ),
          ],
        ),
      ),
    );
  }
}
