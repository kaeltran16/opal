import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/post_workout_controller.dart';
import '../../controllers/providers.dart';
import '../../controllers/workout_detail_controller.dart' show buildExerciseGroups, ExerciseSets;
import '../../models/models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/app_icon.dart';

const _white = Color(0xFFFFFFFF);

/// Screen 10 — Post-Workout Summary (focus route, no tab bar).
///
/// Celebrates a just-finished session: a gradient hero (Time / Volume / PRs),
/// the muscles worked (pills + a proportional stacked bar), per-exercise set
/// chips with PR highlights, and Pal's note. "Save to timeline" persists the
/// [Workout] + a linked move [Entry] (plan SF-5) then returns to the Move tab.
///
/// The finished [workout] arrives via the route's `extra`. A null [workout]
/// (deep link / hot reload with no extra) shows a graceful fallback rather than
/// crashing — the session can't be reconstructed once the active route is gone.
class PostWorkoutScreen extends ConsumerWidget {
  const PostWorkoutScreen({super.key, required this.workout});

  final Workout? workout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = workout;
    if (w == null) return const _NoSession();

    final c = context.colors;
    final catalog = ref.watch(exercisesProvider).asData?.value ?? const [];
    final saveState = ref.watch(postWorkoutControllerProvider);

    final pr = buildPrHighlight(w, catalog);
    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _Hero(workout: w, pr: pr, onClose: () => context.go('/move')),
                if (pr != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                    child: _PrCard(pr: pr),
                  ),
                _MusclesSection(muscles: buildMuscleVolumes(w, catalog)),
                _ExercisesSection(groups: buildExerciseGroups(w, catalog)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: _PalNote(workout: w),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          _ActionBar(
            saveState: saveState,
            onSave: () => _save(context, ref, w),
          ),
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context, WidgetRef ref, Workout w) async {
    try {
      await ref.read(postWorkoutControllerProvider.notifier).save(w);
      if (context.mounted) context.go('/move');
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't save — try again.")),
      );
    }
  }
}

// ─── Hero ────────────────────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  const _Hero({required this.workout, required this.pr, required this.onClose});
  final Workout workout;
  final PrHighlight? pr;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final minutes = workout.duration?.inMinutes ?? 0;
    final doneSets = workout.sets.where((s) => s.done).toList();
    final totalReps = doneSets.fold<int>(0, (s, x) => s + x.reps);

    return ClipRect(
      child: Stack(
        children: [
          // 160° move → accent gradient with two soft decorative blobs.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: const Alignment(-0.6, -1),
                  end: const Alignment(0.6, 1),
                  colors: [c.move, c.accent],
                ),
              ),
            ),
          ),
          Positioned(
            top: -60,
            right: -40,
            child: _Blob(size: 220, alpha: 0.08),
          ),
          Positioned(
            bottom: -80,
            left: -30,
            child: _Blob(size: 180, alpha: 0.06),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _Pill(),
                    const Spacer(),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onClose,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: AppIcon('xmark', size: 13, color: _white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Nice session.',
                  style: AppFonts.sfr(
                      size: 34,
                      weight: FontWeight.w700,
                      color: _white,
                      letterSpacing: -0.7,
                      height: 1.05),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (pr != null) ...[
                      AppIcon('star.fill', size: 12, color: _white),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        pr != null
                            ? 'New PR on ${pr!.exercise} · ${workout.name}'
                            : workout.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.sf(
                          size: 15,
                          weight: FontWeight.w500,
                          color: _white.withValues(alpha: 0.9),
                          letterSpacing: -0.24,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: _white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Row(
                      children: [
                        _HeroStat(value: '$minutes', label: 'Time', unit: 'min'),
                        const SizedBox(width: 1),
                        _HeroStat(
                          value:
                              (workout.totalVolumeKg / 1000).toStringAsFixed(1),
                          label: 'Volume',
                          unit: 'tonnes',
                        ),
                        const SizedBox(width: 1),
                        _HeroStat(
                          value: '${doneSets.length}',
                          label: 'Sets',
                          unit: '$totalReps reps',
                        ),
                        const SizedBox(width: 1),
                        _HeroStat(
                            value: '${workout.prCount}',
                            label: 'PRs',
                            unit: 'records'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.alpha});
  final double size;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _white.withValues(alpha: alpha),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon('checkmark', size: 10, color: _white),
          const SizedBox(width: 5),
          Text('COMPLETE',
              style: AppFonts.sf(
                  size: 10,
                  weight: FontWeight.w700,
                  color: _white,
                  letterSpacing: 1)),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat(
      {required this.value, required this.unit, required this.label});
  final String value;
  final String unit;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        color: const Color(0x24000000),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            Text(
              value,
              style: AppFonts.sfr(
                  size: 24, color: _white, letterSpacing: -0.4, height: 1),
            ),
            const SizedBox(height: 4),
            Text(
              label.toUpperCase(),
              style: AppFonts.sf(
                size: 9,
                weight: FontWeight.w700,
                color: _white.withValues(alpha: 0.85),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              unit,
              style: AppFonts.sf(
                size: 10,
                color: _white.withValues(alpha: 0.7),
                letterSpacing: -0.08,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Standalone "PERSONAL RECORD" card: money-gradient star tile + the PR set.
class _PrCard extends StatelessWidget {
  const _PrCard({required this.pr});
  final PrHighlight pr;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final weight = pr.weightKg == pr.weightKg.roundToDouble()
        ? '${pr.weightKg.round()}'
        : '${pr.weightKg}';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            c.money.withValues(alpha: 0.08),
            c.money.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.money.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [c.money, c.money.withValues(alpha: 0.8)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: c.money.withValues(alpha: 0.33),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: AppIcon('star.fill', size: 22, color: _white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PERSONAL RECORD',
                    style: AppFonts.sf(
                        size: 10,
                        weight: FontWeight.w700,
                        color: c.money,
                        letterSpacing: 0.8)),
                const SizedBox(height: 2),
                Text('${pr.exercise} · ${weight}kg × ${pr.reps}',
                    style: AppFonts.sfr(
                        size: 17,
                        weight: FontWeight.w700,
                        color: c.ink,
                        letterSpacing: -0.3)),
                const SizedBox(height: 2),
                Text('New best this session',
                    style: AppFonts.sf(
                        size: 12, color: c.ink3, letterSpacing: -0.08)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Muscles worked ────────────────────────────────────────────────────────

class _MusclesSection extends StatelessWidget {
  const _MusclesSection({required this.muscles});
  final List<MuscleVolume> muscles;

  @override
  Widget build(BuildContext context) {
    if (muscles.isEmpty) return const SizedBox.shrink();
    final c = context.colors;
    final palette = [c.move, c.accent, c.rituals, c.money, c.ink3];
    final total = muscles.fold<double>(0, (s, m) => s + m.volumeKg);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Muscles worked'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            decoration: BoxDecoration(
                color: c.surface, borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                for (var i = 0; i < muscles.length; i++)
                  Padding(
                    padding: EdgeInsets.only(
                        bottom: i < muscles.length - 1 ? 12 : 0),
                    child: _MuscleRow(
                      color: palette[i % palette.length],
                      label: muscles[i].muscle,
                      volumeKg: muscles[i].volumeKg,
                      percent: total <= 0
                          ? 0
                          : (muscles[i].volumeKg / total * 100).round(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One muscle: name + right-aligned volume + percentage, over its own bar.
class _MuscleRow extends StatelessWidget {
  const _MuscleRow({
    required this.color,
    required this.label,
    required this.volumeKg,
    required this.percent,
  });
  final Color color;
  final String label;
  final double volumeKg;
  final int percent;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(label,
                style: AppFonts.sf(
                    size: 13,
                    weight: FontWeight.w600,
                    color: c.ink,
                    letterSpacing: -0.1)),
            const Spacer(),
            Text('${volumeKg.round()} kg',
                style:
                    AppFonts.sfr(size: 12, color: c.ink3, letterSpacing: -0.08)),
            const SizedBox(width: 8),
            Text('$percent%',
                style: AppFonts.sfr(
                    size: 13,
                    weight: FontWeight.w700,
                    color: color,
                    letterSpacing: -0.1)),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: SizedBox(
            height: 8,
            child: Row(
              children: [
                Expanded(
                  flex: percent.clamp(0, 100),
                  child: ColoredBox(color: color),
                ),
                Expanded(
                  flex: (100 - percent).clamp(0, 100),
                  child: ColoredBox(color: c.fill),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Per-exercise set chips ──────────────────────────────────────────────────

class _ExercisesSection extends StatelessWidget {
  const _ExercisesSection({required this.groups});
  final List<ExerciseSets> groups;

  @override
  Widget build(BuildContext context) {
    // only completed sets are summarized; drop any group that has none.
    final shown = [
      for (final g in groups)
        if (g.sets.any((s) => s.done))
          ExerciseSets(
            name: g.name,
            sets: g.sets.where((s) => s.done).toList(),
          ),
    ];
    if (shown.isEmpty) return const SizedBox.shrink();
    final c = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader('Exercises · ${shown.length}'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Container(
            decoration: BoxDecoration(
                color: c.surface, borderRadius: BorderRadius.circular(14)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < shown.length; i++)
                  _ExerciseRow(group: shown[i], last: i == shown.length - 1),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.group, required this.last});
  final ExerciseSets group;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasPr = group.sets.any((s) => s.isPR);
    final total = group.sets.fold<double>(0, (s, x) => s + x.volumeKg);
    return Container(
      decoration: BoxDecoration(
        border:
            last ? null : Border(bottom: BorderSide(color: c.hair, width: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              if (hasPr) ...[
                Container(
                  width: 18,
                  height: 18,
                  decoration:
                      BoxDecoration(color: c.money, shape: BoxShape.circle),
                  child: AppIcon('star.fill', size: 8, color: _white),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(group.name,
                    style: AppFonts.sf(
                        size: 15,
                        weight: FontWeight.w600,
                        color: c.ink,
                        letterSpacing: -0.24)),
              ),
              Text.rich(
                TextSpan(
                  text: '${total.round()}',
                  style: AppFonts.sfr(
                      size: 13,
                      weight: FontWeight.w600,
                      color: c.ink2,
                      letterSpacing: -0.08),
                  children: [
                    TextSpan(
                      text: ' kg',
                      style: AppFonts.sf(size: 10, color: c.ink3),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _SetBars(sets: group.sets),
        ],
      ),
    );
  }
}

/// Per-set volume bars (scaled to the exercise's max), PR set in money color
/// with a dot marker; "{weight}×{reps}" beneath each bar.
class _SetBars extends StatelessWidget {
  const _SetBars({required this.sets});
  final List<SetLog> sets;

  @override
  Widget build(BuildContext context) {
    final maxVol =
        sets.fold<double>(0, (m, s) => s.volumeKg > m ? s.volumeKg : m);
    return SizedBox(
      height: 60,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < sets.length; i++) ...[
            if (i != 0) const SizedBox(width: 4),
            Expanded(child: _SetBar(set: sets[i], maxVol: maxVol)),
          ],
        ],
      ),
    );
  }
}

class _SetBar extends StatelessWidget {
  const _SetBar({required this.set, required this.maxVol});
  final SetLog set;
  final double maxVol;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pr = set.isPR;
    final frac = maxVol > 0 ? (set.volumeKg / maxVol) : 0.0;
    final weight = set.weightKg == set.weightKg.roundToDouble()
        ? '${set.weightKg.round()}'
        : '${set.weightKg}';
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              // floor at 15% so an empty/light set still reads as a bar.
              heightFactor: frac < 0.15 ? 0.15 : frac,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: pr ? c.money : c.move.withValues(alpha: 0.53),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                        bottom: Radius.circular(2),
                      ),
                    ),
                  ),
                  if (pr)
                    Positioned(
                      top: -3,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: c.money,
                            shape: BoxShape.circle,
                            border: Border.all(color: c.bg, width: 2),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text('$weight×${set.reps}',
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: AppFonts.sfr(
                size: 10,
                weight: FontWeight.w600,
                color: pr ? c.money : c.ink3,
                letterSpacing: -0.08)),
      ],
    );
  }
}

// ─── Pal's note ──────────────────────────────────────────────────────────────

class _PalNote extends ConsumerWidget {
  const _PalNote({required this.workout});
  final Workout workout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final note = ref.watch(postWorkoutNoteProvider(workout));
    final loading = note.isLoading;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.accentTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.accent.withValues(alpha: 0.13), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon('sparkles', size: 12, color: c.accent),
              const SizedBox(width: 6),
              Text("PAL'S NOTE",
                  style: AppFonts.sf(
                      size: 11,
                      weight: FontWeight.w700,
                      color: c.accent,
                      letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            note.when(
              loading: () => 'Pal is reading your session…',
              error: (_, _) => "Pal couldn't write a note just now.",
              data: (text) => text,
            ),
            style: AppFonts.sf(
                size: 14,
                color: loading ? c.ink3 : c.ink,
                letterSpacing: -0.2,
                height: 1.45),
          ),
        ],
      ),
    );
  }
}

// ─── Bottom actions ──────────────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.saveState, required this.onSave});
  final SaveState saveState;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final saving = saveState == SaveState.saving;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.hair, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(child: _ShareButton()),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: saving ? null : onSave,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: saving ? c.move.withValues(alpha: 0.6) : c.move,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (saving) ...[
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _white),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(saving ? 'Saving…' : 'Save to timeline',
                        style: AppFonts.sf(
                            size: 15,
                            weight: FontWeight.w700,
                            color: _white,
                            letterSpacing: -0.2)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      // share is a device-only capability; surface it without a dead tap.
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sharing is available on device.')),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.hair, width: 0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIcon('square.and.arrow.up', size: 16, color: c.ink),
            const SizedBox(width: 6),
            Text('Share',
                style: AppFonts.sf(
                    size: 15,
                    weight: FontWeight.w500,
                    color: c.ink,
                    letterSpacing: -0.24)),
          ],
        ),
      ),
    );
  }
}

// ─── Shared bits ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(text.toUpperCase(),
          style: AppFonts.sf(size: 13, color: c.ink3, letterSpacing: -0.08)),
    );
  }
}

class _NoSession extends StatelessWidget {
  const _NoSession();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon('checkmark', size: 28, color: c.move),
              const SizedBox(height: 12),
              Text('No active session',
                  style:
                      AppFonts.sfr(size: 18, color: c.ink, letterSpacing: -0.3)),
              const SizedBox(height: 4),
              Text('Your last summary is no longer available.',
                  textAlign: TextAlign.center,
                  style:
                      AppFonts.sf(size: 13, color: c.ink3, letterSpacing: -0.08)),
              const SizedBox(height: 16),
              Builder(
                builder: (context) => GestureDetector(
                  onTap: () => context.go('/move'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 11),
                    decoration: BoxDecoration(
                        color: c.move, borderRadius: BorderRadius.circular(100)),
                    child: Text('Back to Workout',
                        style: AppFonts.sf(
                            size: 14,
                            weight: FontWeight.w700,
                            color: _white,
                            letterSpacing: -0.1)),
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
