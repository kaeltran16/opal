import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/profile_controller.dart';
import '../../controllers/rituals_controller.dart';
import '../../models/models.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/controls.dart';
import '../../widgets/press_scale.dart';

// top clears the status bar.
const _padTop = 52.0;
const _padSide = 16.0;
const _padBottom = 48.0;
const _target = 44.0;
// pulls the close glyph onto the gutter while its 44 box overhangs it.
const _closeBleed = 10.0;
const _closeIcon = 22.0;
const _progressGap = 16.0;
const _barGap = 8.0;
const _cardGap = 28.0;
const _cardPad = 16.0;
const _cardInnerGap = 16.0;
const _stepIcon = 28.0;
const _titleNoteGap = 6.0;
const _pillHeight = 48.0;
const _pillIcon = 18.0;
const _pillIconGap = 8.0;
const _controlsGap = 8.0;
const _controlInset = 12.0;
const _backIcon = 16.0;
const _backIconGap = 4.0;
const _upNextGap = 24.0;
const _upNextInnerGap = 4.0;
const _rowGap = 8.0;
const _leadTop = 20.0;
const _leadMaxWidth = 330.0;
const _numberGap = 28.0;
const _streakGap = 16.0;
const _streakIcon = 16.0;
const _streakIconGap = 6.0;
const _footMinGap = 32.0;
const _switchDuration = Duration(milliseconds: 320);
const _switchCurve = Cubic(0.22, 1, 0.36, 1);
const _slideFrom = Offset(0, 0.06);

String _steps(int n) => n == 1 ? 'step' : 'steps';

/// Screen 13b — full-screen guided Routine Player.
///
/// Walks one [RitualStep] at a time in a single card with a "Mark done" pill
/// that records the step (via `completeStep`) and advances. Opens at the
/// routine's first incomplete step and ends on a summary of what got done.
class RoutinePlayerScreen extends ConsumerStatefulWidget {
  const RoutinePlayerScreen({super.key, required this.routineId});

  final String routineId;

  @override
  ConsumerState<RoutinePlayerScreen> createState() =>
      _RoutinePlayerScreenState();
}

class _RoutinePlayerScreenState extends ConsumerState<RoutinePlayerScreen> {
  /// Current step index; null until seeded from the first-incomplete step once
  /// the routine loads. `>= steps.length` means the finished view.
  int? _idx;

  void _seed(RitualsState state, RitualRoutine routine) {
    _idx ??= state.firstIncompleteStep(routine);
  }

  void _toRoutines() => context.go('/rituals');

  // back to wherever the player was opened from (Today, an area page); a deep
  // link has nothing under it, so it lands on the routines.
  void _close() => context.canPop() ? context.pop() : _toRoutines();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final async = ref.watch(ritualsControllerProvider);

    return Scaffold(
      backgroundColor: c.bg,
      body: async.when(
        loading: () => const SizedBox.shrink(),
        error: (e, _) {
          debugPrint('RoutinePlayerScreen failed to load routine '
              '${widget.routineId}: $e');
          return _Missing(
            title: "Couldn't load routine",
            body: 'Try again in a moment.',
            pill: 'Back to routines',
            onPill: _toRoutines,
            onClose: _close,
          );
        },
        data: (state) {
          final matches =
              state.routines.where((r) => r.id == widget.routineId);
          final routine = matches.isEmpty ? null : matches.first;
          if (routine == null) {
            return _Missing(
              title: 'Routine not found',
              body: 'It may have been deleted.',
              pill: 'Back to routines',
              onPill: _toRoutines,
              onClose: _close,
            );
          }
          if (routine.steps.isEmpty) {
            return _Missing(
              heading: routine.name,
              title: 'No steps yet',
              body: 'Add a step to ${routine.name} to start it.',
              pill: 'Manage routines',
              onPill: () => context.goNamed(AppRoute.areaManageRoutines.name),
              onClose: _close,
            );
          }
          _seed(state, routine);
          final total = routine.steps.length;
          void go(int i) => setState(() => _idx = i.clamp(0, total));
          return _Player(
            routine: routine,
            idx: _idx!,
            done: state.doneFor(routine.id),
            onClose: _close,
            onRoutines: _toRoutines,
            onBack: () => go(_idx! - 1),
            onSkip: () => go(_idx! + 1),
            onMarkDone: () {
              ref
                  .read(ritualsControllerProvider.notifier)
                  .completeStep(routine, _idx!);
              go(_idx! + 1);
            },
          );
        },
      ),
    );
  }
}

/// The board's page frame: header row, then [children] in a column that fills
/// the screen and scrolls when it can't.
class _Frame extends StatelessWidget {
  const _Frame({
    required this.heading,
    required this.onClose,
    required this.children,
  });

  final String heading;
  final VoidCallback onClose;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                _padSide, _padTop, _padSide, _padBottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: _target,
                  child: Row(
                    children: [
                      Transform.translate(
                        offset: const Offset(-_closeBleed, 0),
                        child: PressScale(
                          onTap: onClose,
                          semanticLabel: 'Close',
                          child: SizedBox.square(
                            dimension: _target,
                            child: Center(
                              child: AppIcon('xmark',
                                  size: _closeIcon, color: c.ink),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          heading,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.label.copyWith(color: c.ink3),
                        ),
                      ),
                      const SizedBox(width: _target),
                    ],
                  ),
                ),
                ...children,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Player extends StatelessWidget {
  const _Player({
    required this.routine,
    required this.idx,
    required this.done,
    required this.onClose,
    required this.onRoutines,
    required this.onBack,
    required this.onSkip,
    required this.onMarkDone,
  });

  final RitualRoutine routine;
  final int idx;
  final Set<int> done;
  final VoidCallback onClose;
  final VoidCallback onRoutines;
  final VoidCallback onBack;
  final VoidCallback onSkip;
  final VoidCallback onMarkDone;

  @override
  Widget build(BuildContext context) {
    final total = routine.steps.length;
    final doneCount = done.length;
    if (idx >= total) {
      return _Frame(
        heading: 'Done · ${routine.name}',
        onClose: onClose,
        children: [
          _Finished(
              name: routine.name, doneCount: doneCount, total: total),
          const Spacer(),
          const SizedBox(height: _footMinGap),
          _PrimaryPill(
            label: 'Back to routines',
            onTap: onRoutines,
          ),
        ],
      );
    }

    final c = context.colors;
    final step = routine.steps[idx];
    final doneText = '$doneCount of $total done';
    final caption = AppType.caption.copyWith(
      color: c.ink3,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final hasNext = idx + 1 < total;

    return _Frame(
      heading: routine.name,
      onClose: onClose,
      children: [
        const SizedBox(height: _progressGap),
        Row(
          children: [
            Expanded(child: Text('Step ${idx + 1} of $total', style: caption)),
            Text(doneText, style: caption),
          ],
        ),
        const SizedBox(height: _barGap),
        // the caption above already reads the progress; the bar only draws it.
        ExcludeSemantics(
          child: ProgressBar(value: doneCount / total, color: c.ink),
        ),
        const SizedBox(height: _cardGap),
        AnimatedSwitcher(
          duration: _switchDuration,
          switchInCurve: _switchCurve,
          // each step slides up and fades; only the incoming card animates.
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(begin: _slideFrom, end: Offset.zero)
                  .animate(animation),
              child: child,
            ),
          ),
          child: _StepCard(
            key: ValueKey(idx),
            step: step,
            idx: idx,
            stepDone: done.contains(idx),
            onMarkDone: onMarkDone,
          ),
        ),
        const SizedBox(height: _controlsGap),
        Row(
          children: [
            _TextControl(
              label: 'Back',
              icon: 'chevron.left',
              padding: const EdgeInsets.only(right: _controlInset),
              onTap: idx > 0 ? onBack : null,
            ),
            const Spacer(),
            _TextControl(
              label: 'Skip',
              padding: const EdgeInsets.only(left: _controlInset),
              onTap: onSkip,
            ),
          ],
        ),
        if (hasNext) ...[
          const SizedBox(height: _upNextGap),
          Text('Up next', style: AppType.label.copyWith(color: c.ink3)),
          const SizedBox(height: _upNextInnerGap),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(routine.steps[idx + 1].title,
                    style: AppType.callout.copyWith(color: c.ink)),
              ),
              const SizedBox(width: _rowGap),
              Text(
                'Step ${idx + 2}',
                style: AppType.subhead.copyWith(
                  color: c.ink3,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    super.key,
    required this.step,
    required this.idx,
    required this.stepDone,
    required this.onMarkDone,
  });

  final RitualStep step;
  final int idx;
  final bool stepDone;
  final VoidCallback onMarkDone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(_cardPad),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: AppIcon.line(step.icon.isEmpty ? 'sparkles' : step.icon,
                size: _stepIcon, color: c.ink2),
          ),
          const SizedBox(height: _cardInnerGap),
          Text(step.title, style: AppType.title.copyWith(color: c.ink)),
          if (step.note.isNotEmpty) ...[
            const SizedBox(height: _titleNoteGap),
            Text(step.note, style: AppType.body.copyWith(color: c.ink2)),
          ],
          const SizedBox(height: _cardInnerGap),
          _PrimaryPill(
            label: stepDone ? 'Next step' : 'Mark done',
            icon: 'checkmark',
            onTap: onMarkDone,
          ),
        ],
      ),
    );
  }
}

class _Finished extends ConsumerWidget {
  const _Finished({
    required this.name,
    required this.doneCount,
    required this.total,
  });

  final String name;
  final int doneCount;
  final int total;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    // real consecutive-day ritual streak from persisted completions (includes
    // today's just-finished routine); not the never-incremented seed value.
    final streak = ref.watch(profileStatsProvider).asData?.value.longestStreak;
    final lead = doneCount >= total
        ? '$name is done.'
        : '$name, $doneCount of $total done.';
    final subhead = AppType.subhead.copyWith(color: c.ink2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: _leadTop),
        Semantics(
          liveRegion: true,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _leadMaxWidth),
            child: Text(lead, style: AppType.lead.copyWith(color: c.ink)),
          ),
        ),
        const SizedBox(height: _numberGap),
        Text.rich(
          TextSpan(
            text: '$doneCount',
            children: [
              TextSpan(
                text: ' of $total ${_steps(total)}',
                style: AppType.subhead.copyWith(color: c.ink3),
              ),
            ],
          ),
          style: AppType.display.copyWith(color: c.ink),
        ),
        Text('done today', style: subhead),
        if (streak != null && streak > 0) ...[
          const SizedBox(height: _streakGap),
          Row(
            children: [
              AppIcon('flame.fill', size: _streakIcon, color: c.ink2),
              const SizedBox(width: _streakIconGap),
              Text(
                '$streak-day streak',
                style: subhead.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// A screen with no step to show: no steps, not found, or a load error.
class _Missing extends StatelessWidget {
  const _Missing({
    this.heading = '',
    required this.title,
    required this.body,
    required this.pill,
    required this.onPill,
    required this.onClose,
  });

  final String heading;
  final String title;
  final String body;
  final String pill;
  final VoidCallback onPill;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return _Frame(
      heading: heading,
      onClose: onClose,
      children: [
        const SizedBox(height: _leadTop),
        Text(title, style: AppType.title.copyWith(color: c.ink)),
        const SizedBox(height: _titleNoteGap),
        Text(body, style: AppType.body.copyWith(color: c.ink2)),
        const Spacer(),
        const SizedBox(height: _footMinGap),
        _PrimaryPill(label: pill, onTap: onPill),
      ],
    );
  }
}

/// The screen's one primary pill: ink fill, bg text.
class _PrimaryPill extends StatelessWidget {
  const _PrimaryPill({required this.label, required this.onTap, this.icon});

  final String label;
  final VoidCallback onTap;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PressScale(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        height: _pillHeight,
        decoration: BoxDecoration(
          color: c.ink,
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              AppIcon(icon!, size: _pillIcon, color: c.bg),
              const SizedBox(width: _pillIconGap),
            ],
            Text(label, style: AppType.headline.copyWith(color: c.bg)),
          ],
        ),
      ),
    );
  }
}

/// Back and Skip: a 44-tall text control. Null [onTap] draws it disabled.
class _TextControl extends StatelessWidget {
  const _TextControl({
    required this.label,
    required this.padding,
    this.icon,
    this.onTap,
  });

  final String label;
  final EdgeInsets padding;
  final String? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onTap != null;
    final color = enabled ? c.ink2 : c.ink3;
    final control = PressScale(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        height: _target,
        padding: padding,
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              AppIcon(icon!, size: _backIcon, color: color),
              const SizedBox(width: _backIconGap),
            ],
            Text(label,
                style: AppType.subhead
                    .copyWith(fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
    if (enabled) return control;
    // press scale drops its semantics without a tap, so announce it as off.
    return Semantics(
      button: true,
      enabled: false,
      label: label,
      excludeSemantics: true,
      child: control,
    );
  }
}
