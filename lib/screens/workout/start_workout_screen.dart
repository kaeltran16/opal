import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/providers.dart';
import '../../controllers/start_workout_controller.dart';
import '../../models/models.dart';
import '../../router.dart';
import '../../services/pal/pal_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
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

    return async.when(
      loading: () => Center(
        child: Text('…',
            style: AppFonts.sf(size: 17, color: c.ink3, letterSpacing: -0.43)),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text("Couldn't load workouts.\n$e",
              textAlign: TextAlign.center,
              style: AppFonts.sf(size: 15, color: c.ink3, letterSpacing: -0.24)),
        ),
      ),
      data: (state) => _Body(state: state),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.state});
  final StartWorkoutState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final exerciseCount = ref.watch(exercisesProvider).asData?.value.length;

    void openSession(String routineId) => context.pushNamed(
          'activeSession',
          pathParameters: {'routineId': routineId},
        );

    return ListView(
      padding: const EdgeInsets.only(bottom: 110),
      children: [
        LargeTitleNavBar(
          title: 'Start workout',
          subtitle: 'Pick a routine or freestyle',
          leading: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).maybePop(),
            child: AppIcon('chevron.left', size: 20, color: c.accent),
          ),
        ),

        // --- Pal's pick gradient card ---------------------------------------
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 22),
          child: _PalPickCard(state: state, onStart: openSession),
        ),

        // --- Strength grid ---------------------------------------------------
        if (state.strength.isNotEmpty) ...[
          _SectionHeader('Strength · ${state.strength.length}'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.35,
              children: [
                for (final r in state.strength)
                  _RoutineCard(routine: r, onTap: () => openSession(r.id)),
              ],
            ),
          ),
        ],

        // --- Cardio rows -----------------------------------------------------
        if (state.cardio.isNotEmpty) ...[
          const SizedBox(height: 22),
          _SectionHeader('Cardio · ${state.cardio.length}'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Column(
              children: [
                for (final r in state.cardio) ...[
                  _CardioRow(routine: r, onTap: () => openSession(r.id)),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ],

        // --- Quick actions ---------------------------------------------------
        const SizedBox(height: 22),
        InsetSection(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
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
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Text(text.toUpperCase(),
          style: AppFonts.sf(
              size: 12,
              weight: FontWeight.w700,
              color: c.ink3,
              letterSpacing: 0.8)),
    );
  }
}

/// Pal's-pick gradient card. Renders the current [WorkoutSuggestion] (title +
/// rationale + est min/focus), an "Another" pill that re-requests a different
/// pick, and a Start CTA that opens the picked routine's session.
class _PalPickCard extends ConsumerWidget {
  const _PalPickCard({required this.state, required this.onStart});
  final StartWorkoutState state;
  final ValueChanged<String> onStart;

  /// Resolve the routine the Start CTA should open: the suggestion's routineId
  /// when present, else the first strength routine. Null disables Start.
  String? _targetId(WorkoutSuggestion? s) =>
      s?.routineId ?? state.firstStrength?.id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final async = ref.watch(palPickControllerProvider);
    final loading = async.isLoading;
    final suggestion = async.asData?.value;
    final targetId = _targetId(suggestion);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.move, c.accent],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
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
              padding: const EdgeInsets.all(18),
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
              const SizedBox(width: 8),
              Text("PAL'S PICK FOR TODAY",
                  style: AppFonts.sf(
                      size: 11,
                      weight: FontWeight.w700,
                      color: _white.withValues(alpha: 0.85),
                      letterSpacing: 1.2)),
            ],
          ),
          const SizedBox(height: 12),

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
                height: 1.1),
          ),

          // Meta (est min · focus).
          if (suggestion != null && _meta(suggestion).isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(_meta(suggestion),
                style: AppFonts.sf(
                    size: 13,
                    color: _white.withValues(alpha: 0.7),
                    letterSpacing: -0.08)),
          ],
          const SizedBox(height: 12),

          // Rationale.
          Text(
            async.when(
              loading: () => 'Pal is picking your session…',
              error: (_, _) => "Pal couldn't pick one just now — go freestyle.",
              data: (s) => s.rationale,
            ),
            style: AppFonts.sf(
                size: 14,
                color: _white.withValues(alpha: loading ? 0.3 : 0.88),
                letterSpacing: -0.2,
                height: 1.45),
          ),
          const SizedBox(height: 16),

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
              const SizedBox(width: 8),
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
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
              color: _white, borderRadius: BorderRadius.circular(100)),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon('play.fill', size: 12, color: c.move),
              const SizedBox(width: 6),
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.sf(
                        size: 15,
                        weight: FontWeight.w700,
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0x1AFFFFFF),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: const Color(0x33FFFFFF), width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppIcon('sparkles', size: 11, color: _white),
            const SizedBox(width: 5),
            Text(loading ? 'Thinking…' : 'Other',
                style: AppFonts.sf(
                    size: 13, weight: FontWeight.w500, color: _white)),
          ],
        ),
      ),
    );
  }
}

/// One Strength grid card: tag eyebrow + name on a colored band, then exercise
/// count + est. minutes. Tapping opens the routine's session.
class _RoutineCard extends StatelessWidget {
  const _RoutineCard({required this.routine, required this.onTap});
  final Routine routine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final band = _bandColor(c, routine.tag);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
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
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(routine.tag.wire.toUpperCase(),
                              style: AppFonts.sf(
                                  size: 10,
                                  weight: FontWeight.w700,
                                  color: _white.withValues(alpha: 0.8),
                                  letterSpacing: 0.8)),
                          const SizedBox(height: 3),
                          Text(routine.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppFonts.sf(
                                  size: 15,
                                  weight: FontWeight.w700,
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
              // Footer stats.
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _MiniStat(
                          value: '${routine.exerciseCount}', label: 'EXERCISES'),
                      const SizedBox(width: 14),
                      _MiniStat(value: '${_estMinutes(routine)}', label: 'EST'),
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

/// One Cardio row: move-tinted icon panel + name + est. minutes + play affordance.
class _CardioRow extends StatelessWidget {
  const _CardioRow({required this.routine, required this.onTap});
  final Routine routine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
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
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(routine.name,
                            style: AppFonts.sf(
                                size: 16,
                                weight: FontWeight.w600,
                                color: c.ink,
                                letterSpacing: -0.3)),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text('${_estMinutes(routine)}',
                                style: AppFonts.sfr(
                                    size: 16,
                                    weight: FontWeight.w700,
                                    color: c.ink,
                                    letterSpacing: -0.2)),
                            const SizedBox(width: 2),
                            Text('min',
                                style: AppFonts.sf(
                                    size: 11,
                                    color: c.ink3,
                                    letterSpacing: -0.08)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 14),
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
                height: 1)),
        const SizedBox(height: 1),
        Text(label,
            style: AppFonts.sf(
                size: 9,
                weight: FontWeight.w600,
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

/// Rough session-length estimate (minutes): total target sets across the
/// routine times the rest interval, plus per-set work, rounded to 5 min. Pure
/// display heuristic — the prototype hard-codes `estMin` per routine.
int _estMinutes(Routine routine) {
  final totalSets =
      routine.exercises.fold<int>(0, (s, e) => s + e.targetSets);
  if (totalSets == 0) return routine.restSeconds ~/ 60;
  // ~ rest + 35s of work per set.
  final seconds = totalSets * (routine.restSeconds + 35);
  final minutes = (seconds / 60).round();
  return (minutes / 5).round() * 5;
}
