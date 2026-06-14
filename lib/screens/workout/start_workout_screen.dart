import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/providers.dart';
import '../../controllers/start_workout_controller.dart';
import '../../models/models.dart';
import '../../router.dart';
import '../../services/pal/pal_service.dart';
import '../../theme/theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/inset_section.dart';
import '../../widgets/nav_bar.dart';

const _white = Color(0xFFFFFFFF);

/// Screen 08 — Start workout (pre-session picker).
///
/// A "Pal's pick" gradient card (suggestion title + rationale + est. min/focus,
/// an "Another" pill that re-requests a different pick, and a Start CTA), then a
/// Strength 2-col grid + Cardio rows from [startWorkoutProvider], and a
/// quick-actions section. Selecting any routine → the Active Session via
/// `pushNamed('activeSession', pathParameters: {'routineId': routine.id})`.
///
/// All async/derivation lives in [startWorkoutController]; this widget lays out.
class StartWorkoutScreen extends ConsumerWidget {
  const StartWorkoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final async = ref.watch(startWorkoutProvider);

    // Opaque background so the Cupertino push parallax doesn't show the
    // outgoing page through this one (ghosting). Mirrors the shell's c.bg.
    return ColoredBox(
      color: c.bg,
      child: async.when(
        loading: () => Center(
          child: Text('…',
              style:
                  AppType.body.copyWith(color: c.ink3, letterSpacing: -0.43)),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.xxl),
            child: Text("Couldn't load workouts.\n$e",
                textAlign: TextAlign.center,
                style: AppType.subhead
                    .copyWith(color: c.ink3, letterSpacing: -0.24)),
          ),
        ),
        data: (state) => _Body(state: state),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.state});
  final StartWorkoutState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final exercisesList = ref.watch(exercisesProvider).asData?.value;
    final exerciseCount = exercisesList?.length;

    // exerciseId -> name, for the exercise-preview chips and card mini-stack.
    final exerciseNames = <String, String>{
      for (final e in exercisesList ?? const <Exercise>[]) e.id: e.name,
    };

    void openSession(String routineId) => context.pushNamed(
          'activeSession',
          pathParameters: {'routineId': routineId},
        );

    return LargeTitleScrollView(
      title: 'Start workout',
      subtitle: 'Pick a routine or freestyle',
      leading: NavAction(
        icon: 'chevron.left',
        onTap: () => Navigator.of(context).maybePop(),
        semanticLabel: 'Back',
      ),
      padding: const EdgeInsets.only(bottom: 110), // scroll-tail inset, off-grid
      children: [
        // --- Pal's pick gradient card ---------------------------------------
        Padding(
          padding: const EdgeInsets.fromLTRB(
              Spacing.lg, Spacing.xs, Spacing.lg, Spacing.xxl),
          child: _PalPickCard(
            state: state,
            exerciseNames: exerciseNames,
            onStart: openSession,
          ),
        ),

        // --- Strength grid ---------------------------------------------------
        if (state.strength.isNotEmpty) ...[
          _SectionHeader('Strength · ${state.strength.length}'),
          Padding(
            padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, 0),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: Spacing.md,
              crossAxisSpacing: Spacing.md,
              childAspectRatio: 1.35,
              children: [
                for (final r in state.strength)
                  _RoutineCard(
                    routine: r,
                    exerciseNames: exerciseNames,
                    lastDoneDays: state.daysSinceLastDone(r.id),
                    onTap: () => openSession(r.id),
                  ),
              ],
            ),
          ),
        ],

        // --- Cardio rows -----------------------------------------------------
        if (state.cardio.isNotEmpty) ...[
          const SizedBox(height: Spacing.xxl),
          _SectionHeader('Cardio · ${state.cardio.length}'),
          Padding(
            padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, 0),
            child: Column(
              children: [
                for (final r in state.cardio) ...[
                  _CardioRow(
                    routine: r,
                    lastDoneDays: state.daysSinceLastDone(r.id),
                    onTap: () => openSession(r.id),
                  ),
                  const SizedBox(height: Spacing.md),
                ],
              ],
            ),
          ),
        ],

        // --- Quick actions ---------------------------------------------------
        const SizedBox(height: Spacing.xxl),
        InsetSection(
          margin: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, 0),
          children: [
            ListRow(
              icon: 'sparkles',
              iconBg: c.rituals,
              title: 'Generate with AI',
              subtitle: 'Describe the workout you want',
              onTap: () => context.pushNamed(AppRoute.routineGenerator.name),
            ),
            ListRow(
              icon: 'plus',
              iconBg: c.accent,
              title: 'New routine',
              subtitle: 'Build from scratch',
              onTap: () => context.pushNamed(AppRoute.routineEditor.name),
            ),
            ListRow(
              icon: 'books.vertical.fill',
              iconBg: c.move,
              title: 'Exercise library',
              subtitle: exerciseCount == null
                  ? 'Browse all exercises'
                  : '$exerciseCount exercises',
              onTap: () => context.pushNamed(AppRoute.exerciseLibrary.name),
            ),
            ListRow(
              icon: 'bolt.fill',
              iconBg: c.money,
              title: 'Freestyle session',
              subtitle: 'Log as you go',
              chevron: false,
              last: true,
            ),
          ],
        ),
      ],
    );
  }
}

/// Section eyebrow ("Strength · 4" / "Cardio · 1").
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.xl, 0, Spacing.xl, Spacing.md),
      child: Text(text.toUpperCase(),
          style: AppType.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: c.ink3,
              letterSpacing: 0.8)),
    );
  }
}

/// Pal's-pick gradient card. Renders the current [WorkoutSuggestion] (title +
/// rationale + est min/focus), an "Another" pill that re-requests a different
/// pick, and a Start CTA that opens the picked routine's session.
class _PalPickCard extends ConsumerWidget {
  const _PalPickCard({
    required this.state,
    required this.exerciseNames,
    required this.onStart,
  });
  final StartWorkoutState state;
  final Map<String, String> exerciseNames;
  final ValueChanged<String> onStart;

  /// Resolve the routine the Start CTA should open: the suggestion's routineId
  /// when present, else the first strength routine. Null disables Start.
  String? _targetId(WorkoutSuggestion? s) =>
      s?.routineId ?? state.firstStrength?.id;

  /// The routine the card is previewing (the Start target), if resolvable.
  Routine? _targetRoutine(String? id) {
    if (id == null) return null;
    for (final r in [...state.strength, ...state.cardio]) {
      if (r.id == id) return r;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final async = ref.watch(palPickControllerProvider);
    final loading = async.isLoading;
    final suggestion = async.asData?.value;
    final targetId = _targetId(suggestion);
    final routine = _targetRoutine(targetId);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.lg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.move, c.accent],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.lg),
        child: Stack(
          children: [
            // two soft decorative light blobs.
            Positioned(
              top: -50,
              right: -40,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _white.withValues(alpha: 0.1),
                ),
              ),
            ),
            Positioned(
              bottom: -60,
              left: -30,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _white.withValues(alpha: 0.06),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Spacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Eyebrow.
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: Color(0x33FFFFFF)),
                alignment: Alignment.center,
                child: const AppIcon('sparkles', size: 11, color: _white),
              ),
              const SizedBox(width: Spacing.sm),
              Text("PAL'S PICK FOR TODAY",
                  style: AppType.caption2.copyWith(
                      fontWeight: FontWeight.w700,
                      color: _white.withValues(alpha: 0.85),
                      letterSpacing: 1.2)),
            ],
          ),
          const SizedBox(height: Spacing.md),

          // Title.
          Text(
            async.when(
              loading: () => 'Thinking…',
              error: (_, _) => 'Freestyle session',
              data: (s) => s.title,
            ),
            style: AppFonts.sfr(
                size: 26,
                weight: FontWeight.w700,
                color: _white,
                letterSpacing: -0.5,
                height: 1.1), // sfr 26: no token
          ),

          // Meta sub-line: prefer the resolved routine's own
          // "{n} exercises · {est} min · last done {n}d ago"; else fall back to
          // the suggestion's focus/est meta.
          Builder(builder: (_) {
            final meta = routine != null
                ? _routineMeta(routine)
                : (suggestion == null ? '' : _meta(suggestion));
            if (meta.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: Spacing.xs),
              child: Text(meta,
                  style: AppType.footnote.copyWith(
                      color: _white.withValues(alpha: 0.7),
                      letterSpacing: -0.08)),
            );
          }),
          const SizedBox(height: Spacing.md),

          // Rationale.
          Text(
            async.when(
              loading: () => 'Pal is picking your session…',
              error: (_, _) => "Pal couldn't pick one just now — go freestyle.",
              data: (s) => s.rationale,
            ),
            style: AppType.subhead.copyWith(
                color: _white.withValues(alpha: loading ? 0.3 : 0.88),
                letterSpacing: -0.2,
                height: 1.45),
          ),

          // Exercise-preview chip strip (top names + "+N more").
          if (routine != null && routine.exercises.isNotEmpty) ...[
            const SizedBox(height: Spacing.lg),
            _ExercisePreviewChips(
              routine: routine,
              exerciseNames: exerciseNames,
            ),
          ],
          const SizedBox(height: Spacing.lg),

          // Actions: Start + Another.
          Row(
            children: [
              Expanded(
                child: _StartButton(
                  label: suggestion == null
                      ? 'Start'
                      : 'Start ${suggestion.title}',
                  enabled: !loading && targetId != null,
                  onTap: targetId == null ? null : () => onStart(targetId),
                ),
              ),
              const SizedBox(width: Spacing.sm),
              _AnotherButton(
                loading: loading,
                onTap: loading
                    ? null
                    : () => ref
                        .read(palPickControllerProvider.notifier)
                        .another(),
              ),
            ],
          ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _meta(WorkoutSuggestion s) {
    final parts = <String>[
      if (s.focus != null) s.focus!,
      if (s.estimatedMinutes != null) '${s.estimatedMinutes} min',
    ];
    return parts.join(' · ');
  }

  /// "{n} exercises · {est} min · last done {n}d ago" for the resolved routine.
  String _routineMeta(Routine routine) {
    final lastDone = _lastDoneLabel(state.daysSinceLastDone(routine.id));
    return [
      '${routine.exerciseCount} exercises',
      '${_displayEstMinutes(routine)} min',
      if (lastDone != null) 'last done $lastDone',
    ].join(' · ');
  }
}

/// White-pill Start CTA on the Pal card.
class _StartButton extends StatelessWidget {
  const _StartButton({
    required this.label,
    required this.enabled,
    this.onTap,
  });
  final String label;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: Spacing.md),
          decoration: BoxDecoration(
              color: _white, borderRadius: BorderRadius.circular(Radii.pill)),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon('play.fill', size: 12, color: c.move),
              const SizedBox(width: Spacing.sm),
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.subhead.copyWith(
                        fontWeight: FontWeight.w700,
                        color: c.move,
                        letterSpacing: -0.2)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Translucent "Another" pill that re-requests a different pick.
class _AnotherButton extends StatelessWidget {
  const _AnotherButton({required this.loading, this.onTap});
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: Spacing.lg, vertical: Spacing.md),
        decoration: BoxDecoration(
          color: const Color(0x1AFFFFFF),
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(color: const Color(0x33FFFFFF), width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppIcon('sparkles', size: 11, color: _white),
            const SizedBox(width: Spacing.xs),
            Text(loading ? 'Thinking…' : 'Other',
                style: AppType.footnote
                    .copyWith(fontWeight: FontWeight.w500, color: _white)),
          ],
        ),
      ),
    );
  }
}

/// Rounded translucent pills naming the routine's top exercises, with a final
/// "+N more" pill when the routine has more than [_maxChips] exercises.
class _ExercisePreviewChips extends StatelessWidget {
  const _ExercisePreviewChips({
    required this.routine,
    required this.exerciseNames,
  });
  final Routine routine;
  final Map<String, String> exerciseNames;

  static const int _maxChips = 5;

  @override
  Widget build(BuildContext context) {
    final ordered = routine.orderedExercises;
    final names = [
      for (final ex in ordered.take(_maxChips))
        exerciseNames[ex.exerciseId] ?? ex.exerciseId,
    ];
    final remaining = ordered.length - names.length;

    return Wrap(
      spacing: Spacing.sm,
      runSpacing: Spacing.sm,
      children: [
        for (final name in names) _chip(name),
        if (remaining > 0) _chip('+$remaining more'),
      ],
    );
  }

  Widget _chip(String label) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md, vertical: Spacing.xs),
        decoration: BoxDecoration(
          color: const Color(0x1FFFFFFF),
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(color: const Color(0x26FFFFFF), width: 0.5),
        ),
        child: Text(label,
            style: AppType.caption.copyWith(
                fontWeight: FontWeight.w500,
                color: _white.withValues(alpha: 0.92),
                letterSpacing: -0.1)),
      );
}

/// One Strength grid card: tag eyebrow + name on a colored band, then exercise
/// count + est. minutes. Tapping opens the routine's session.
class _RoutineCard extends StatelessWidget {
  const _RoutineCard({
    required this.routine,
    required this.exerciseNames,
    required this.lastDoneDays,
    required this.onTap,
  });
  final Routine routine;
  final Map<String, String> exerciseNames;
  final int? lastDoneDays;
  final VoidCallback onTap;

  /// Total planned sets across the routine (the "SETS" stat).
  int get _totalSets =>
      routine.exercises.fold<int>(0, (s, e) => s + e.targetSets);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final band = _bandColor(c, routine.tag);
    final lastDone = _lastDoneLabel(lastDoneDays);
    final preview = _exercisePreviewLine(routine, exerciseNames);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.lg),
        child: ColoredBox(
          color: c.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Colored header band with a diagonal-stripe texture.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [band, band.withValues(alpha: 0.85)],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(painter: _BandStripePainter()),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          Spacing.md, Spacing.md, Spacing.md, Spacing.lg),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(routine.tag.wire.toUpperCase(),
                              style: AppType.caption2.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: _white.withValues(alpha: 0.8),
                                  letterSpacing: 0.8)),
                          const SizedBox(height: Spacing.xs),
                          Text(routine.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.subhead.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: _white,
                                  letterSpacing: -0.3,
                                  height: 1.15)),
                        ],
                      ),
                    ),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle, color: Color(0x38FFFFFF)),
                      alignment: Alignment.center,
                      child: const AppIcon('play.fill', size: 11, color: _white),
                    ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Footer: exercise preview line + stats + last-done.
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      Spacing.md, Spacing.sm, Spacing.md, Spacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (preview.isNotEmpty)
                        Text(preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.caption2.copyWith(
                                color: c.ink3,
                                letterSpacing: -0.08)),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _MiniStat(
                              value: '${routine.exerciseCount}',
                              label: 'EXERCISES'),
                          const SizedBox(width: Spacing.lg),
                          _MiniStat(value: '$_totalSets', label: 'SETS'),
                          const SizedBox(width: Spacing.lg),
                          _MiniStat(
                              value: '${_displayEstMinutes(routine)}',
                              label: 'EST'),
                          const Spacer(),
                          if (lastDone != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 1),
                              child: Text(lastDone,
                                  style: AppType.caption2.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: c.ink3,
                                      letterSpacing: -0.08)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One Cardio row: move-tinted icon panel + name + distance/pace (or minutes) +
/// last-done + play affordance.
class _CardioRow extends StatelessWidget {
  const _CardioRow({
    required this.routine,
    required this.lastDoneDays,
    required this.onTap,
  });
  final Routine routine;
  final int? lastDoneDays;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.lg),
        child: ColoredBox(
          color: c.surface,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 72,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [c.move, c.move.withValues(alpha: 0.8)],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const AppIcon('figure.run', size: 28, color: _white),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        Spacing.lg, Spacing.md, Spacing.lg, Spacing.md),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(routine.name,
                            style: AppType.callout.copyWith(
                                fontWeight: FontWeight.w600,
                                color: c.ink,
                                letterSpacing: -0.3)),
                        const SizedBox(height: Spacing.xs),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            // Primary metric: distance if authored, else minutes.
                            Text(
                                routine.distanceKm != null
                                    ? _trimKm(routine.distanceKm!)
                                    : '${_displayEstMinutes(routine)}',
                                style: AppFonts.sfr(
                                    size: 16,
                                    weight: FontWeight.w700,
                                    color: c.ink,
                                    letterSpacing: -0.2)), // sfr 16: no token
                            const SizedBox(width: Spacing.xxs),
                            Text(routine.distanceKm != null ? 'km' : 'min',
                                style: AppType.caption2.copyWith(
                                    color: c.ink3,
                                    letterSpacing: -0.08)),
                            if (routine.pace != null) ...[
                              Text('  ·  ',
                                  style: AppType.caption2
                                      .copyWith(color: c.ink3)),
                              Text(routine.pace!,
                                  style: AppType.footnote.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: c.ink2,
                                      letterSpacing: -0.1)),
                            ],
                          ],
                        ),
                        if (_lastDoneLabel(lastDoneDays) != null) ...[
                          const SizedBox(height: Spacing.xs),
                          Text('last done ${_lastDoneLabel(lastDoneDays)}',
                              style: AppType.caption2.copyWith(
                                  color: c.ink3,
                                  letterSpacing: -0.08)),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: Spacing.lg),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: c.move.withValues(alpha: 0.13)),
                    alignment: Alignment.center,
                    child: AppIcon('play.fill', size: 11, color: c.move),
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

/// Diagonal hairline stripe texture for the routine-card header band (~45°).
class _BandStripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _white.withValues(alpha: 0.07)
      ..strokeWidth = 1;
    const spacing = 14.0;
    for (var d = -size.height; d < size.width + size.height; d += spacing) {
      canvas.drawLine(
        Offset(d, 0),
        Offset(d + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BandStripePainter old) => false;
}

/// Small "big number / UPPERCASE label" stat used in routine cards.
class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: AppFonts.sfr(
                size: 15,
                weight: FontWeight.w700,
                color: c.ink,
                letterSpacing: -0.2,
                height: 1)), // sfr 15: no token
        const SizedBox(height: 1), // hairline gap, off-grid
        Text(label,
            style: AppType.caption2.copyWith(
                fontWeight: FontWeight.w600,
                color: c.ink3,
                letterSpacing: 0.3)),
      ],
    );
  }
}

/// Band color for a strength routine's tag.
Color _bandColor(AppColors c, RoutineTag tag) => switch (tag) {
      RoutineTag.upper => c.move,
      RoutineTag.lower => c.money,
      RoutineTag.full => c.accent,
      RoutineTag.custom => c.rituals,
      RoutineTag.cardio => c.move,
    };

/// Displayed session-length estimate (minutes): the routine's authored
/// [Routine.estMin] when present, else the [_estMinutes] heuristic.
int _displayEstMinutes(Routine routine) => routine.estMin ?? _estMinutes(routine);

/// Rough session-length estimate (minutes): total target sets across the
/// routine times the rest interval, plus per-set work, rounded to 5 min. Pure
/// display heuristic — fallback when a routine has no authored `estMin`.
int _estMinutes(Routine routine) {
  final totalSets =
      routine.exercises.fold<int>(0, (s, e) => s + e.targetSets);
  if (totalSets == 0) return routine.restSeconds ~/ 60;
  // ~ rest + 35s of work per set.
  final seconds = totalSets * (routine.restSeconds + 35);
  final minutes = (seconds / 60).round();
  return (minutes / 5).round() * 5;
}

/// Compact "last done Nd ago" label from a whole-day count, or null. Renders
/// "today" / "1d ago" / "{n}d ago".
String? _lastDoneLabel(int? daysAgo) {
  if (daysAgo == null) return null;
  if (daysAgo <= 0) return 'today';
  return '${daysAgo}d ago';
}

/// Formats a km distance without a trailing ".0" (e.g. 5.0 → "5", 4.8 → "4.8").
String _trimKm(double km) {
  final s = km.toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}

/// Bullet-joined preview of the routine's top exercise names (+ "+N more"),
/// e.g. "Bench · OHP · Incline · +2 more". Empty when no exercises.
String _exercisePreviewLine(Routine routine, Map<String, String> names) {
  const max = 3;
  final ordered = routine.orderedExercises;
  if (ordered.isEmpty) return '';
  final shown = [
    for (final ex in ordered.take(max))
      names[ex.exerciseId] ?? ex.exerciseId,
  ];
  final remaining = ordered.length - shown.length;
  return [
    ...shown,
    if (remaining > 0) '+$remaining more',
  ].join(' · ');
}
