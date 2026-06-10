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

    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _Hero(workout: w, onClose: () => context.go('/move')),
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
  const _Hero({required this.workout, required this.onClose});
  final Workout workout;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final move = c.move;
    final minutes = workout.duration?.inMinutes ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 56, 16, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [move, move.withValues(alpha: 0.88)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
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
          ),
          const SizedBox(height: 6),
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: AppIcon('checkmark', size: 30, color: _white),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Workout complete',
            textAlign: TextAlign.center,
            style: AppFonts.sfr(size: 26, color: _white, letterSpacing: -0.5),
          ),
          const SizedBox(height: 2),
          Text(
            workout.name,
            textAlign: TextAlign.center,
            style: AppFonts.sf(
              size: 14,
              weight: FontWeight.w500,
              color: _white.withValues(alpha: 0.85),
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _HeroStat(value: '$minutes', unit: 'min', label: 'Time'),
              const SizedBox(width: 1),
              _HeroStat(
                value: (workout.totalVolumeKg / 1000).toStringAsFixed(1),
                unit: 't',
                label: 'Volume',
              ),
              const SizedBox(width: 1),
              _HeroStat(value: '${workout.prCount}', unit: '', label: 'PRs'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.value, required this.unit, required this.label});
  final String value;
  final String unit;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        color: _white.withValues(alpha: 0.16),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Text.rich(
              TextSpan(
                text: value,
                style: AppFonts.sfr(size: 24, color: _white, letterSpacing: -0.4),
                children: unit.isEmpty
                    ? null
                    : [
                        TextSpan(
                          text: ' $unit',
                          style: AppFonts.sf(
                            size: 12,
                            weight: FontWeight.w500,
                            color: _white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label.toUpperCase(),
              style: AppFonts.sf(
                size: 9,
                weight: FontWeight.w700,
                color: _white.withValues(alpha: 0.75),
                letterSpacing: 0.7,
              ),
            ),
          ],
        ),
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
    final palette = [c.move, c.accent, c.money, c.rituals, c.ink3];
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // proportional stacked bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: SizedBox(
                    height: 10,
                    child: Row(
                      children: [
                        for (var i = 0; i < muscles.length; i++)
                          Expanded(
                            // flex by relative volume; floor at 1 so a tiny
                            // contribution still shows as a sliver.
                            flex: total <= 0
                                ? 1
                                : (muscles[i].volumeKg / total * 1000)
                                    .round()
                                    .clamp(1, 1000),
                            child: Container(
                                color: palette[i % palette.length]),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < muscles.length; i++)
                      _MusclePill(
                        color: palette[i % palette.length],
                        label: muscles[i].muscle,
                        volumeKg: muscles[i].volumeKg,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MusclePill extends StatelessWidget {
  const _MusclePill({
    required this.color,
    required this.label,
    required this.volumeKg,
  });
  final Color color;
  final String label;
  final double volumeKg;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: AppFonts.sf(
                  size: 12,
                  weight: FontWeight.w600,
                  color: c.ink,
                  letterSpacing: -0.08)),
          const SizedBox(width: 5),
          Text('${volumeKg.round()}kg',
              style: AppFonts.sfr(size: 11, color: c.ink3, letterSpacing: -0.08)),
        ],
      ),
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
    return Container(
      decoration: BoxDecoration(
        border:
            last ? null : Border(bottom: BorderSide(color: c.hair, width: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(group.name,
              style: AppFonts.sf(
                  size: 16,
                  weight: FontWeight.w600,
                  color: c.ink,
                  letterSpacing: -0.3)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final s in group.sets) _SetChip(set: s)],
          ),
        ],
      ),
    );
  }
}

class _SetChip extends StatelessWidget {
  const _SetChip({required this.set});
  final SetLog set;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pr = set.isPR;
    final weight = set.weightKg == set.weightKg.roundToDouble()
        ? '${set.weightKg.round()}'
        : '${set.weightKg}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: pr ? c.money.withValues(alpha: 0.1) : c.fill,
        border: Border.all(
            color: pr ? c.money.withValues(alpha: 0.3) : c.hair, width: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pr) ...[
            AppIcon('star.fill', size: 10, color: c.money),
            const SizedBox(width: 4),
          ],
          Text('$weight kg × ${set.reps}',
              style: AppFonts.sfr(
                  size: 13,
                  weight: FontWeight.w600,
                  color: pr ? c.money : c.ink,
                  letterSpacing: -0.1)),
        ],
      ),
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
          _ShareButton(),
          const SizedBox(width: 10),
          Expanded(
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
        width: 52,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: c.fill,
          borderRadius: BorderRadius.circular(12),
        ),
        child: AppIcon('square.and.arrow.up', size: 18, color: c.ink2),
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
                    child: Text('Back to Move',
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
