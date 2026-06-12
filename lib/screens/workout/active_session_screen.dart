import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/workout_session_controller.dart';
import '../../models/models.dart';
import '../../router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../util/format.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/press_scale.dart';

const _white = Color(0xFFFFFFFF);

/// Screen 09 — the live workout (focus route, no tab bar).
///
/// Reads [WorkoutSessionController] (keyed by [routineId]) and renders the
/// colored header band + elapsed timer, the rest-timer banner, the current-
/// exercise card with its set table, the "Add set" affordance, the up-next card,
/// and the exercise progress dots. Logging the active set delegates to the
/// controller (which owns the engine + real rest timer); Finish confirms then
/// pushes the post-workout summary. The widget is dumb — all logic lives in the
/// controller/engine.
class ActiveSessionScreen extends ConsumerStatefulWidget {
  const ActiveSessionScreen({super.key, required this.routineId});

  final String routineId;

  @override
  ConsumerState<ActiveSessionScreen> createState() =>
      _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends ConsumerState<ActiveSessionScreen> {
  // ticks the header elapsed clock; the controller's rest timer is separate.
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final routineId = widget.routineId;
    final c = context.colors;
    final async = ref.watch(workoutSessionControllerProvider(routineId));

    return Scaffold(
      backgroundColor: c.bg,
      body: async.when(
        loading: () => Center(
          child: Text('…',
              style:
                  AppFonts.sf(size: 17, color: c.ink3, letterSpacing: -0.43)),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              "Couldn't start the session.\n$e",
              textAlign: TextAlign.center,
              style: AppFonts.sf(size: 15, color: c.ink3, letterSpacing: -0.24),
            ),
          ),
        ),
        data: (state) => _Body(routineId: routineId, state: state),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.routineId, required this.state});

  final String routineId;
  final ActiveSessionState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final controller =
        workoutSessionControllerProvider(routineId).notifier;

    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        _Header(
          state: state,
          onBack: () => context.pop(),
          onFinish: () => _confirmFinish(context, ref),
        ),
        if (state.isResting)
          _RestBanner(
            restRemaining: state.restRemaining,
            onAddTime: () => ref.read(controller).addRestTime(),
            onSkip: () => ref.read(controller).skipRest(),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          child: state.isComplete
              ? _CompleteCard(c: c)
              : _CurrentExerciseCard(
                  state: state,
                  onLog: () {
                    final set = state.currentSet;
                    if (set == null) return;
                    ref.read(controller).logCurrentSet(
                          weightKg: set.weightKg,
                          reps: set.reps,
                        );
                  },
                  onAddSet: () => ref.read(controller).addSet(),
                ),
        ),
        if (state.nextExercise != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _UpNextCard(state: state),
          ),
      ],
    );
  }

  Future<void> _confirmFinish(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finish workout?'),
        content: const Text('This ends the session and shows your summary.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep going'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Finish'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final workout =
        ref.read(workoutSessionControllerProvider(routineId).notifier).finish();
    context.pushReplacementNamed(AppRoute.postWorkout.name, extra: workout);
  }
}

// ─── Header band ─────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.state,
    required this.onBack,
    required this.onFinish,
  });

  final ActiveSessionState state;
  final VoidCallback onBack;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final move = c.move;
    final name = state.activeWorkout.name;
    final exCount = state.exerciseIds.length;
    final exNum = (state.currentExerciseIndex + 1).clamp(1, exCount);

    final completed = state.sets.where((s) => s.done).length;
    final total = state.sets.length;
    final volume = state.activeWorkout.totalVolumeKg;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 54, 16, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [move, move.withValues(alpha: 0.93)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _CircleButton(
                icon: 'chevron.down',
                onTap: onBack,
                background: _white.withValues(alpha: 0.2),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '● ${name.toUpperCase()}',
                      style: AppFonts.mono(
                        size: 10,
                        weight: FontWeight.w700,
                        color: _white.withValues(alpha: 0.75),
                        letterSpacing: 1.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _elapsed(state.activeWorkout.startedAt),
                      style: AppFonts.sfr(
                        size: 32,
                        color: _white,
                        letterSpacing: -0.6,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onFinish,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                    color: _white,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    'Finish',
                    style: AppFonts.sf(
                      size: 13,
                      weight: FontWeight.w700,
                      color: move,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ProgressDots(count: exCount, current: state.currentExerciseIndex),
          const SizedBox(height: 18),
          _HeaderStats(
            exerciseLabel: '$exNum/$exCount',
            setsLabel: '$completed/$total',
            volumeLabel: formatWeight(volume),
          ),
        ],
      ),
    );
  }

  static String _elapsed(DateTime startedAt) {
    final d = DateTime.now().difference(startedAt);
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.count, required this.current});
  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.5),
            child: Container(
              width: i == current ? 24 : 6,
              height: 4,
              decoration: BoxDecoration(
                color: i <= current
                    ? _white
                    : _white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
      ],
    );
  }
}

class _HeaderStats extends StatelessWidget {
  const _HeaderStats({
    required this.exerciseLabel,
    required this.setsLabel,
    required this.volumeLabel,
  });
  final String exerciseLabel;
  final String setsLabel;
  final String volumeLabel;

  @override
  Widget build(BuildContext context) {
    Widget cell(String value, String label) => Expanded(
          child: Container(
            color: const Color(0x1F000000),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              children: [
                Text(
                  value,
                  style: AppFonts.sfr(
                      size: 16, color: _white, letterSpacing: -0.2, height: 1),
                ),
                const SizedBox(height: 2),
                Text(
                  label.toUpperCase(),
                  style: AppFonts.sf(
                    size: 9,
                    weight: FontWeight.w600,
                    color: _white.withValues(alpha: 0.75),
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        );

    return Container(
      decoration: BoxDecoration(
        color: _white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          cell(exerciseLabel, 'Exercise'),
          const SizedBox(width: 1),
          cell(setsLabel, 'Sets'),
          const SizedBox(width: 1),
          cell(volumeLabel, 'Volume'),
        ],
      ),
    );
  }
}

// ─── Rest banner ─────────────────────────────────────────────────────────────

class _RestBanner extends StatefulWidget {
  const _RestBanner({
    required this.restRemaining,
    required this.onAddTime,
    required this.onSkip,
  });

  final int restRemaining;
  final VoidCallback onAddTime;
  final VoidCallback onSkip;

  @override
  State<_RestBanner> createState() => _RestBannerState();
}

class _RestBannerState extends State<_RestBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: const Duration(seconds: 1))
        ..repeat();

  // The controller exposes only the remaining seconds, so capture the high-water
  // mark across this rest period (incl. +30s bumps) as the progress denominator.
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _total = widget.restRemaining;
  }

  @override
  void didUpdateWidget(_RestBanner old) {
    super.didUpdateWidget(old);
    if (widget.restRemaining > _total) _total = widget.restRemaining;
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final m = (widget.restRemaining ~/ 60).toString();
    final s = (widget.restRemaining % 60).toString().padLeft(2, '0');
    final elapsedFrac =
        _total <= 0 ? 0.0 : (1 - widget.restRemaining / _total).clamp(0.0, 1.0);

    return Container(
      color: c.accent,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Stack(
        children: [
          // left-anchored progress fill that grows as rest elapses.
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: elapsedFrac,
                child: ColoredBox(color: _white.withValues(alpha: 0.12)),
              ),
            ),
          ),
          Row(
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: RotationTransition(
                  turns: _spin,
                  child: CustomPaint(
                    painter: _RestSpinnerPainter(
                        color: _white.withValues(alpha: 0.3)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'REST',
                    style: AppFonts.sf(
                      size: 10,
                      weight: FontWeight.w700,
                      color: _white.withValues(alpha: 0.85),
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    '$m:$s',
                    style: AppFonts.sfr(
                        size: 22, color: _white, letterSpacing: -0.3),
                  ),
                ],
              ),
              const Spacer(),
              PressScale(
                onTap: widget.onAddTime,
                semanticLabel: 'Add 30 seconds rest',
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: _white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text('+30s',
                      style: AppFonts.sf(
                          size: 12,
                          weight: FontWeight.w600,
                          color: _white,
                          letterSpacing: -0.08)),
                ),
              ),
              const SizedBox(width: 6),
              PressScale(
                onTap: widget.onSkip,
                semanticLabel: 'Skip rest',
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: _white,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text('Skip',
                      style: AppFonts.sf(
                          size: 12,
                          weight: FontWeight.w700,
                          color: c.accent,
                          letterSpacing: -0.08)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A 270° arc used as the rest-timer spinner (rotated by a RotationTransition).
class _RestSpinnerPainter extends CustomPainter {
  _RestSpinnerPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..color = color;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: (size.shortestSide - 2.5) / 2,
    );
    canvas.drawArc(rect, 0, 4.71239, false, paint); // ~270°
  }

  @override
  bool shouldRepaint(_RestSpinnerPainter old) => old.color != color;
}

// ─── Current exercise card ───────────────────────────────────────────────────

class _CurrentExerciseCard extends StatelessWidget {
  const _CurrentExerciseCard({
    required this.state,
    required this.onLog,
    required this.onAddSet,
  });

  final ActiveSessionState state;
  final VoidCallback onLog;
  final VoidCallback onAddSet;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final exercise = state.currentExercise;
    final sets = state.currentExerciseSets;
    final activeId = state.currentSet?.id;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: c.hair, blurRadius: 0, spreadRadius: 0.5),
          const BoxShadow(
              color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [c.move, c.move.withValues(alpha: 0.8)],
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Center(
                  child: AppIcon(exercise?.icon ?? 'dumbbell.fill',
                      size: 26, color: _white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '● Now · exercise ${state.currentExerciseIndex + 1}',
                      style: AppFonts.sf(
                          size: 10,
                          weight: FontWeight.w700,
                          color: c.move,
                          letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      exercise?.name ?? 'Exercise',
                      style: AppFonts.sfr(
                          size: 22, color: c.ink, letterSpacing: -0.4),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      [exercise?.muscle, exercise?.equipment]
                          .where((x) => x != null && x.isNotEmpty)
                          .join(' · '),
                      style: AppFonts.sf(
                          size: 12, color: c.ink3, letterSpacing: -0.08),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // decorative menu trigger; no-op like the app's other ellipsis buttons
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: c.fill, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: AppIcon('ellipsis', size: 13, color: c.ink2),
              ),
            ],
          ),
          if (exercise?.pr != null) ...[
            const SizedBox(height: 14),
            _PrChip(pr: exercise!.pr!),
          ],
          const SizedBox(height: 14),
          for (var i = 0; i < sets.length; i++) ...[
            _SetRow(
              number: i + 1,
              set: sets[i],
              isActive: sets[i].id == activeId,
              onLog: onLog,
            ),
            if (i != sets.length - 1) const SizedBox(height: 8),
          ],
          const SizedBox(height: 10),
          _AddSetButton(onTap: onAddSet),
        ],
      ),
    );
  }
}

class _PrChip extends StatelessWidget {
  const _PrChip({required this.pr});
  final ExercisePR pr;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.money.withValues(alpha: 0.07),
        border: Border.all(color: c.money.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          AppIcon('star.fill', size: 12, color: c.money),
          const SizedBox(width: 8),
          Text('Your PR:',
              style: AppFonts.sf(
                  size: 12,
                  weight: FontWeight.w600,
                  color: c.ink2,
                  letterSpacing: -0.08)),
          const SizedBox(width: 6),
          Text('${formatWeight(pr.weightKg)}kg × ${pr.reps}',
              style: AppFonts.sfr(
                  size: 13, color: c.ink, letterSpacing: -0.1)),
          const Spacer(),
          Text('Beat it today?',
              style: AppFonts.sf(
                  size: 11, color: c.ink3, letterSpacing: -0.08)),
        ],
      ),
    );
  }
}

/// A single set row: done (compact), active (input-ready hero), or upcoming.
class _SetRow extends StatelessWidget {
  const _SetRow({
    required this.number,
    required this.set,
    required this.isActive,
    required this.onLog,
  });

  final int number;
  final SetLog set;
  final bool isActive;
  final VoidCallback onLog;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (set.done) return _doneRow(c);
    if (isActive) return _activeRow(c);
    return _upcomingRow(c);
  }

  Widget _doneRow(AppColors c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: c.move.withValues(alpha: 0.055),
          border: Border.all(color: c.move.withValues(alpha: 0.13)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: c.move, shape: BoxShape.circle),
              child: AppIcon('checkmark', size: 12, color: _white),
            ),
            const SizedBox(width: 12),
            Text('SET $number',
                style: AppFonts.sf(
                    size: 13,
                    weight: FontWeight.w700,
                    color: c.ink3,
                    letterSpacing: 0.3)),
            const Spacer(),
            if (set.isPR) ...[
              AppIcon('star.fill', size: 11, color: c.money),
              const SizedBox(width: 6),
            ],
            Text(
              '${formatWeight(set.weightKg)}kg × ${set.reps}',
              style: AppFonts.sfr(
                  size: 17, color: c.ink, letterSpacing: -0.2),
            ),
          ],
        ),
      );

  Widget _activeRow(AppColors c) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [c.accentTint, c.accent.withValues(alpha: 0.08)],
          ),
          border: Border.all(color: c.accent, width: 1.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: c.accent,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text('SET $number',
                      style: AppFonts.sf(
                          size: 11,
                          weight: FontWeight.w700,
                          color: _white,
                          letterSpacing: 0.5)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Target: ${formatWeight(set.weightKg)}kg × ${set.reps} reps',
                    style: AppFonts.sf(
                        size: 11, color: c.ink3, letterSpacing: -0.08),
                  ),
                ),
                Text('ACTIVE',
                    style: AppFonts.sf(
                        size: 10,
                        weight: FontWeight.w700,
                        color: c.accent,
                        letterSpacing: 0.8)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _valueBox(c, 'Weight', formatWeight(set.weightKg), 'kg')),
                const SizedBox(width: 10),
                Expanded(child: _valueBox(c, 'Reps', '${set.reps}', null)),
              ],
            ),
            const SizedBox(height: 10),
            PressScale(
              onTap: onLog,
              semanticLabel: 'Complete set',
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: c.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppIcon('checkmark', size: 13, color: _white),
                    const SizedBox(width: 6),
                    Text('Complete set',
                        style: AppFonts.sf(
                            size: 14,
                            weight: FontWeight.w700,
                            color: _white,
                            letterSpacing: -0.1)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  Widget _valueBox(AppColors c, String label, String value, String? unit) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(label.toUpperCase(),
                style: AppFonts.sf(
                    size: 9,
                    weight: FontWeight.w700,
                    color: c.ink3,
                    letterSpacing: 0.8)),
            const SizedBox(height: 2),
            Text.rich(
              TextSpan(
                text: value,
                style: AppFonts.sfr(
                    size: 28, color: c.ink, letterSpacing: -0.5, height: 1.1),
                children: unit == null
                    ? null
                    : [
                        TextSpan(
                          text: unit,
                          style: AppFonts.sf(
                              size: 13,
                              weight: FontWeight.w500,
                              color: c.ink3),
                        ),
                      ],
              ),
            ),
          ],
        ),
      );

  Widget _upcomingRow(AppColors c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: c.fill,
          border: Border.all(color: c.hair),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: c.ink4, width: 1.5),
              ),
              child: Text('$number',
                  style: AppFonts.sf(
                      size: 12, weight: FontWeight.w700, color: c.ink3)),
            ),
            const SizedBox(width: 12),
            Text('SET $number',
                style: AppFonts.sf(
                    size: 13,
                    weight: FontWeight.w700,
                    color: c.ink3,
                    letterSpacing: 0.3)),
            const Spacer(),
            Text('${formatWeight(set.weightKg)}kg × ${set.reps}',
                style: AppFonts.sfr(
                    size: 15,
                    weight: FontWeight.w500,
                    color: c.ink3,
                    letterSpacing: -0.2)),
          ],
        ),
      );
}

class _AddSetButton extends StatelessWidget {
  const _AddSetButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PressScale(
      onTap: onTap,
      semanticLabel: 'Add set',
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: c.hair, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIcon('plus', size: 12, color: c.ink3),
            const SizedBox(width: 6),
            Text('Add set',
                style: AppFonts.sf(
                    size: 14,
                    weight: FontWeight.w600,
                    color: c.ink3,
                    letterSpacing: -0.1)),
          ],
        ),
      ),
    );
  }
}

// ─── Up next ─────────────────────────────────────────────────────────────────

class _UpNextCard extends StatelessWidget {
  const _UpNextCard({required this.state});
  final ActiveSessionState state;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final next = state.nextExercise!;
    final nextId = state.exerciseIds[state.currentExerciseIndex + 1];
    final nextSets =
        state.sets.where((s) => s.exerciseId == nextId).toList();
    final first = nextSets.isEmpty ? null : nextSets.first;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: c.hair, blurRadius: 0, spreadRadius: 0.5),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: c.fill,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('NEXT',
                style: AppFonts.sf(
                    size: 9,
                    weight: FontWeight.w700,
                    color: c.ink3,
                    letterSpacing: 1)),
          ),
          const SizedBox(width: 12),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: c.move.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: AppIcon(next.icon, size: 18, color: c.move),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(next.name,
                    style: AppFonts.sf(
                        size: 15,
                        weight: FontWeight.w600,
                        color: c.ink,
                        letterSpacing: -0.24)),
                if (first != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    '${nextSets.length} sets · ${formatWeight(first.weightKg)}kg × ${first.reps}',
                    style: AppFonts.sf(
                        size: 12, color: c.ink3, letterSpacing: -0.08),
                  ),
                ],
              ],
            ),
          ),
          AppIcon('chevron.right', size: 13, color: c.ink4),
        ],
      ),
    );
  }
}

class _CompleteCard extends StatelessWidget {
  const _CompleteCard({required this.c});
  final AppColors c;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: c.hair, blurRadius: 0, spreadRadius: 0.5),
        ],
      ),
      child: Column(
        children: [
          AppIcon('checkmark', size: 28, color: c.move),
          const SizedBox(height: 12),
          Text('All sets logged',
              style: AppFonts.sfr(size: 18, color: c.ink, letterSpacing: -0.3)),
          const SizedBox(height: 4),
          Text('Tap Finish to see your summary.',
              style: AppFonts.sf(size: 13, color: c.ink3, letterSpacing: -0.08)),
        ],
      ),
    );
  }
}

// ─── Shared bits ─────────────────────────────────────────────────────────────

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.onTap,
    required this.background,
  });
  final String icon;
  final VoidCallback onTap;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: background, shape: BoxShape.circle),
            child: AppIcon(icon, size: 14, color: _white),
          ),
        ),
      ),
    );
  }
}
