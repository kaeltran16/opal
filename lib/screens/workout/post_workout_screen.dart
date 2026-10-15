import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/post_workout_controller.dart';
import '../../controllers/providers.dart';
import '../../controllers/workout_detail_controller.dart' show buildExerciseGroups, ExerciseSets;
import '../../models/models.dart';
import '../../theme/theme.dart';
import '../../util/format.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/contributor_bar.dart';
import '../../widgets/controls.dart';
import '../../widgets/failure_note.dart';
import '../../widgets/nav_bar.dart' show NavIconButton;
import '../../widgets/pal_lead.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/stat_row.dart';

// where the prototype's content starts, just under the status bar.
const double _contentTop = 52;
const double _contentBottom = 48;
const double _minTap = 44;
const double _leadTop = 20;
const double _volumeTop = 28;
const double _recordIcon = 16;
const double _shareIcon = 18;
const double _barRowPad = Spacing.sm + Spacing.xxs;
const double _barHeight = 4;
const String _thousands = ',';
const String _moveRoute = '/move';
const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

/// Screen 10, the post-workout summary (focus route, no tab bar).
///
/// Pal's note leads, then the volume, the new best, the Time / Sets / Records
/// row, the muscles worked and each exercise. "Save to timeline" persists the
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
    final safe = MediaQuery.paddingOf(context);
    final catalog = ref.watch(exercisesProvider).asData?.value ?? const [];
    final saveState = ref.watch(postWorkoutControllerProvider);
    final pr = buildPrHighlight(w, catalog);

    // closing saves, as on iOS: the session is gone once this route is.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close(context, ref, w, saveState);
      },
      child: Scaffold(
        backgroundColor: c.bg,
        body: ListView(
          padding: EdgeInsets.fromLTRB(
            Spacing.lg,
            math.max(_contentTop, safe.top + Spacing.xs),
            Spacing.lg,
            _contentBottom + safe.bottom,
          ),
          children: [
            _Header(name: w.name, onClose: () => _close(context, ref, w, saveState)),
            const SizedBox(height: _leadTop),
            _Note(workout: w),
            const SizedBox(height: _volumeTop),
            _Volume(volumeKg: w.totalVolumeKg),
            if (pr != null) ...[
              const SizedBox(height: Spacing.md),
              _NewBest(pr: pr),
            ],
            const SizedBox(height: Spacing.xxl),
            _Stats(workout: w),
            _MusclesSection(muscles: buildMuscleVolumes(w, catalog)),
            _ExercisesSection(groups: buildExerciseGroups(w, catalog)),
            const SizedBox(height: Spacing.xxxl),
            _Actions(
              saving: saveState == SaveState.saving,
              onSave: () => _save(context, ref, w),
            ),
          ],
        ),
      ),
    );
  }

  /// Leaves for the Move tab, saving first unless a save already ran or is
  /// running (that one navigates when it lands).
  void _close(BuildContext context, WidgetRef ref, Workout w, SaveState saveState) {
    switch (saveState) {
      case SaveState.idle:
        _save(context, ref, w);
      case SaveState.saving:
        break;
      case SaveState.saved:
        context.go(_moveRoute);
    }
  }

  Future<void> _save(BuildContext context, WidgetRef ref, Workout w) async {
    try {
      await ref.read(postWorkoutControllerProvider.notifier).save(w);
      if (context.mounted) context.go(_moveRoute);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(saveFailedCopy)),
      );
    }
  }
}

// ─── Header and lead ─────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.name, required this.onClose});

  final String name;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      spacing: Spacing.sm,
      children: [
        Expanded(
          child: Text('Done · $name',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.label.copyWith(color: c.ink3)),
        ),
        NavIconButton(name: 'xmark', semanticLabel: 'Back to Workout', onTap: onClose),
      ],
    );
  }
}

class _Note extends ConsumerWidget {
  const _Note({required this.workout});

  final Workout workout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final note = ref.watch(postWorkoutNoteProvider(workout));
    return note.when(
      loading: () => const PalLead(text: 'Pal is reading your session…', muted: true),
      error: (_, _) => const PalLead(text: "Pal couldn't write a note just now.", muted: true),
      data: (text) => PalLead(text: text),
    );
  }
}

// ─── Numbers ─────────────────────────────────────────────────────────────────

class _Volume extends StatelessWidget {
  const _Volume({required this.volumeKg});

  final double volumeKg;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // scale a long total down rather than overflow at large text.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(groupThousands('${volumeKg.round()}', _thousands),
              maxLines: 1, style: AppType.display.copyWith(color: c.ink)),
        ),
        Text('kg lifted', style: AppType.subhead.copyWith(color: c.ink2)),
      ],
    );
  }
}

class _NewBest extends StatelessWidget {
  const _NewBest({required this.pr});

  final PrHighlight pr;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: Spacing.xs + Spacing.xxs,
      children: [
        AppIcon('checkmark', size: _recordIcon, color: c.thrivingInk),
        Expanded(
          child: Text('New best · ${pr.exercise}, ${formatWeight(pr.weightKg)} kg',
              style: AppType.subhead.copyWith(color: c.thrivingInk, fontFeatures: _tabular)),
        ),
      ],
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.workout});

  final Workout workout;

  @override
  Widget build(BuildContext context) {
    final done = workout.sets.where((s) => s.done).length;
    // show seconds for a sub-minute session so it doesn't read "0 min".
    final dur = workout.duration;
    final subMinute = dur != null && dur.inMinutes < 1;
    return StatRow(stats: [
      Stat(
        value: subMinute ? '${dur.inSeconds}' : '${dur?.inMinutes ?? 0}',
        unit: subMinute ? 'sec' : 'min',
        label: 'Time',
      ),
      Stat(value: '$done', unit: 'of ${workout.sets.length}', label: 'Sets'),
      Stat(value: '${workout.prCount}', label: 'Records'),
    ]);
  }
}

// ─── Sections ────────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.top, required this.children});

  final String title;
  final double top;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.only(top: top),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.xs),
            child: Semantics(
              header: true,
              child: Text(title, style: AppType.headline.copyWith(color: c.ink)),
            ),
          ),
          for (final child in children)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: _barRowPad),
              child: child,
            ),
        ],
      ),
    );
  }
}

class _MusclesSection extends StatelessWidget {
  const _MusclesSection({required this.muscles});

  final List<MuscleVolume> muscles;

  @override
  Widget build(BuildContext context) {
    if (muscles.isEmpty) return const SizedBox.shrink();
    final total = muscles.fold<double>(0, (s, m) => s + m.volumeKg);
    final top = muscles.fold<double>(0, (m, x) => math.max(m, x.volumeKg));
    return _Section(
      title: 'Muscles worked',
      top: Spacing.xxxl,
      children: [
        for (final m in muscles)
          ContributorBar(
            label: m.muscle,
            value: '${total <= 0 ? 0 : (m.volumeKg / total * 100).round()}%',
            fraction: top <= 0 ? 0 : m.volumeKg / top,
          ),
      ],
    );
  }
}

class _ExercisesSection extends StatelessWidget {
  const _ExercisesSection({required this.groups});

  final List<ExerciseSets> groups;

  @override
  Widget build(BuildContext context) {
    // only completed sets are summarized; drop any group that has none.
    final shown = [
      for (final g in groups)
        if (g.sets.any((s) => s.done))
          ExerciseSets(name: g.name, sets: g.sets.where((s) => s.done).toList()),
    ];
    if (shown.isEmpty) return const SizedBox.shrink();
    double volume(ExerciseSets g) => g.sets.fold<double>(0, (s, x) => s + x.volumeKg);
    final top = shown.fold<double>(0, (m, g) => math.max(m, volume(g)));
    return _Section(
      title: 'By exercise',
      top: Spacing.xxl,
      children: [
        for (final g in shown)
          _ExerciseBar(
            group: g,
            fraction: top <= 0 ? 0 : volume(g) / top,
          ),
      ],
    );
  }
}

/// A [ContributorBar]-shaped row with the state word for a new best beside
/// its value.
class _ExerciseBar extends StatelessWidget {
  const _ExerciseBar({required this.group, required this.fraction});

  final ExerciseSets group;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final heaviest = group.sets.fold<double>(0, (m, s) => math.max(m, s.weightKg));
    final ahead = group.sets.any((s) => s.isPR);
    final radius = BorderRadius.circular(Radii.pill);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Spacing.sm,
      children: [
        MergeSemantics(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            spacing: Spacing.md,
            children: [
              Expanded(child: Text(group.name, style: AppType.subhead.copyWith(color: c.ink2))),
              Text('${group.sets.length} × ${formatWeight(heaviest)} kg',
                  style: AppType.subhead.copyWith(
                      color: c.ink, fontWeight: FontWeight.w600, fontFeatures: _tabular)),
              if (ahead) Text('Ahead', style: AppType.subhead.copyWith(color: c.thrivingInk)),
            ],
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(color: c.track, borderRadius: radius),
          child: FractionallySizedBox(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: fraction.clamp(0.0, 1.0),
            child: Container(
              height: _barHeight,
              decoration: BoxDecoration(color: c.ink, borderRadius: radius),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Actions ─────────────────────────────────────────────────────────────────

class _Actions extends StatelessWidget {
  const _Actions({required this.saving, required this.onSave});

  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      spacing: Spacing.sm,
      children: [
        PressScale(
          // share is a device-only capability; surface it without a dead tap.
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sharing is available on device.')),
          ),
          semanticLabel: 'Share',
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _minTap, minWidth: _minTap),
            child: Padding(
              padding: const EdgeInsets.only(right: Spacing.lg),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: Spacing.sm,
                children: [
                  AppIcon('square.and.arrow.up', size: _shareIcon, color: c.ink),
                  Text('Share', style: AppType.headline.copyWith(color: c.ink)),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: PillButton(
            label: saving ? 'Saving…' : 'Save to timeline',
            onTap: saving ? null : onSave,
          ),
        ),
      ],
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
          padding: const EdgeInsets.all(Spacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: Spacing.xs,
            children: [
              Text('No active session',
                  textAlign: TextAlign.center,
                  style: AppType.title.copyWith(color: c.ink)),
              Text('Your last summary is no longer available.',
                  textAlign: TextAlign.center,
                  style: AppType.subhead.copyWith(color: c.ink3)),
              const SizedBox(height: Spacing.md),
              PillButton(label: 'Back to Workout', onTap: () => context.go(_moveRoute)),
            ],
          ),
        ),
      ),
    );
  }
}
