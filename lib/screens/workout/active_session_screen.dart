import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/workout_session_controller.dart';
import '../../models/models.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../util/format.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/controls.dart';
import '../../widgets/nav_bar.dart' show NavIconButton;
import '../../widgets/press_scale.dart';

// where the prototype's content starts, just under the status bar.
const double _contentTop = 52;
const double _contentBottom = 48;
const double _minTap = 44;
const double _rowMinHeight = 48;
const double _rowDisc = 28;
const double _discGlyph = 14;
const double _hairline = 1;
const double _textIcon = 16;
const double _cardGap = 16;
const double _exerciseTop = 28;
const double _upNextTop = 24;
const double _restGap = 12;
const double _weightStep = 2.5;
const int _repStep = 1;
const int _repFloor = 1;
const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

/// Screen 09, the live workout (focus route, no tab bar).
///
/// Reads [WorkoutSessionController] (keyed by [routineId]). The set card has
/// three states, one at a time: entering (steppers + Complete set), resting
/// (rest clock, +30 s, Skip rest) and finished (See your summary). Weight and
/// reps are stepped on screen and handed to the controller when the set is
/// logged; every other rule lives in the controller and engine.
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

  // the stepped values, seeded from the current set's target and re-seeded
  // whenever the cursor moves to another set.
  String? _seededFor;
  double _weight = 0;
  int _reps = _repFloor;

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

  void _seed(SetLog? set) {
    if (set == null || set.id == _seededFor) return;
    _seededFor = set.id;
    _weight = set.weightKg;
    _reps = math.max(_repFloor, set.reps);
  }

  void _stepWeight(double by) =>
      setState(() => _weight = math.max(0, _weight + by));

  void _stepReps(int by) =>
      setState(() => _reps = math.max(_repFloor, _reps + by));

  WorkoutSessionController get _controller =>
      ref.read(workoutSessionControllerProvider(widget.routineId).notifier);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final async = ref.watch(workoutSessionControllerProvider(widget.routineId));

    return Scaffold(
      backgroundColor: c.bg,
      body: async.when(
        loading: () => Center(
          child: Text('…', style: AppType.body.copyWith(color: c.ink3)),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.xxl),
            child: Text(
              "Couldn't start the session.\n$e",
              textAlign: TextAlign.center,
              style: AppType.subhead.copyWith(color: c.ink3),
            ),
          ),
        ),
        data: (state) {
          _seed(state.currentSet);
          return _body(context, state);
        },
      ),
    );
  }

  Widget _body(BuildContext context, ActiveSessionState state) {
    final safe = MediaQuery.paddingOf(context);
    final shownIndex =
        math.min(state.currentExerciseIndex, state.exerciseIds.length - 1);
    final shownId = shownIndex < 0 ? null : state.exerciseIds[shownIndex];
    final exercise = shownId == null ? null : state.catalog[shownId];
    final shownSets = shownId == null
        ? const <SetLog>[]
        : state.sets.where((s) => s.exerciseId == shownId).toList();

    return ListView(
      padding: EdgeInsets.fromLTRB(
        Spacing.lg,
        math.max(_contentTop, safe.top + Spacing.xs),
        Spacing.lg,
        _contentBottom + safe.bottom,
      ),
      children: [
        _Header(
          name: state.activeWorkout.name,
          startedAt: state.activeWorkout.startedAt,
          onMinimise: () => context.pop(),
          onFinish: () => _confirmFinish(context, state),
        ),
        const SizedBox(height: Spacing.lg),
        _Progress(state: state, shownIndex: shownIndex),
        const SizedBox(height: _exerciseTop),
        _ExerciseHeading(exercise: exercise),
        const SizedBox(height: Spacing.xl),
        _card(context, state, exercise),
        const SizedBox(height: Spacing.sm),
        for (final (i, set) in shownSets.indexed)
          _SetRow(
            number: i + 1,
            set: set,
            current: set.id == state.currentSet?.id,
            resting: state.isResting,
            weight: _weight,
            reps: _reps,
            divided: i > 0,
          ),
        if (!state.isComplete)
          _SetTools(
            canSkip: state.nextExercise != null,
            onAddSet: _controller.addSet,
            onSkip: _controller.skipExercise,
          ),
        if (!state.isComplete && state.nextExercise != null) ...[
          const SizedBox(height: _upNextTop),
          _UpNext(state: state),
        ],
      ],
    );
  }

  Widget _card(BuildContext context, ActiveSessionState state, Exercise? exercise) {
    final set = state.currentSet;
    if (state.isComplete || set == null) {
      final logged = state.sets.where((s) => s.done).length;
      return _FinishedCard(
        logged: logged,
        total: state.sets.length,
        onSummary: () => _finish(context),
      );
    }
    final setNumber = state.currentSetIndex + 1;
    if (state.isResting) {
      return _RestCard(
        remaining: state.restRemaining,
        next: 'set $setNumber · ${formatWeight(_weight)} kg × $_reps',
        onAddTime: _controller.addRestTime,
        onSkip: _controller.skipRest,
      );
    }
    return _EnterCard(
      setLabel: 'Set $setNumber of ${state.currentExerciseSets.length}',
      pr: exercise?.pr,
      weight: _weight,
      reps: _reps,
      onWeight: _stepWeight,
      onReps: _stepReps,
      onComplete: () => _controller.logCurrentSet(weightKg: _weight, reps: _reps),
    );
  }

  Future<void> _confirmFinish(BuildContext context, ActiveSessionState state) async {
    final logged = state.sets.where((s) => s.done).length;
    final confirmed = await showAppSheet<bool>(
      context,
      builder: (ctx) => _FinishSheet(logged: logged, total: state.sets.length),
    );
    if (confirmed != true || !context.mounted) return;
    _finish(context);
  }

  void _finish(BuildContext context) {
    final workout = _controller.finish();
    context.pushReplacementNamed(AppRoute.postWorkout.name, extra: workout);
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.startedAt,
    required this.onMinimise,
    required this.onFinish,
  });

  final String name;
  final DateTime startedAt;
  final VoidCallback onMinimise;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final elapsed = _elapsed(startedAt);
    return Row(
      spacing: Spacing.sm,
      children: [
        NavIconButton(
          name: 'chevron.down',
          semanticLabel: 'Minimise, the session keeps running',
          onTap: onMinimise,
        ),
        Expanded(
          child: Column(
            children: [
              Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.label.copyWith(color: c.ink3)),
              Semantics(
                container: true,
                label: 'Elapsed $elapsed',
                excludeSemantics: true,
                child: Text(elapsed,
                    style: AppType.headline.copyWith(
                        color: c.ink, fontWeight: FontWeight.w400, fontFeatures: _tabular)),
              ),
            ],
          ),
        ),
        _TextButton(label: 'Finish', onTap: onFinish),
      ],
    );
  }

  static String _elapsed(DateTime startedAt) {
    final d = clock.now().difference(startedAt);
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.state, required this.shownIndex});

  final ActiveSessionState state;
  final int shownIndex;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final logged = state.sets.where((s) => s.done).length;
    final total = state.sets.length;
    final style = AppType.caption.copyWith(color: c.ink3, fontFeatures: _tabular);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Spacing.sm,
      children: [
        Row(
          spacing: Spacing.sm,
          children: [
            Expanded(
              child: Text('Exercise ${shownIndex + 1} of ${state.exerciseIds.length}',
                  style: style),
            ),
            Text('$logged of $total sets', style: style),
          ],
        ),
        ProgressBar(value: total == 0 ? 0 : logged / total),
      ],
    );
  }
}

class _ExerciseHeading extends StatelessWidget {
  const _ExerciseHeading({required this.exercise});

  final Exercise? exercise;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final meta = [exercise?.muscle, exercise?.equipment]
        .whereType<String>()
        .where((x) => x.isNotEmpty)
        .join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: Spacing.xxs,
      children: [
        if (meta.isNotEmpty) Text(meta, style: AppType.label.copyWith(color: c.ink3)),
        Semantics(
          header: true,
          child: Text(exercise?.name ?? 'Exercise',
              style: AppType.title.copyWith(color: c.ink)),
        ),
      ],
    );
  }
}

// ─── Set card ────────────────────────────────────────────────────────────────

/// The `surface` card that holds the one live state.
class _Card extends StatelessWidget {
  const _Card({required this.children, this.gap = _cardGap, this.center = false});

  final List<Widget> children;
  final double gap;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.card)),
      child: Column(
        crossAxisAlignment: center ? CrossAxisAlignment.center : CrossAxisAlignment.stretch,
        spacing: gap,
        children: children,
      ),
    );
  }
}

class _EnterCard extends StatelessWidget {
  const _EnterCard({
    required this.setLabel,
    required this.pr,
    required this.weight,
    required this.reps,
    required this.onWeight,
    required this.onReps,
    required this.onComplete,
  });

  final String setLabel;
  final ExercisePR? pr;
  final double weight;
  final int reps;
  final ValueChanged<double> onWeight;
  final ValueChanged<int> onReps;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pr = this.pr;
    final ahead = pr != null && weight > pr.weightKg;
    return _Card(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          spacing: Spacing.sm,
          children: [
            Expanded(
              child: Text(setLabel, style: AppType.label.copyWith(color: c.ink, fontFeatures: _tabular)),
            ),
            if (pr != null)
              Flexible(
                child: Text('Best ${formatWeight(pr.weightKg)} kg × ${pr.reps}',
                    textAlign: TextAlign.end,
                    style: AppType.label.copyWith(color: c.ink3, fontFeatures: _tabular)),
              ),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: Spacing.md,
          children: [
            Expanded(
              child: _Stepper(
                label: 'Weight',
                value: formatWeight(weight),
                unit: 'kg',
                lessLabel: 'Less weight',
                moreLabel: 'More weight',
                onLess: () => onWeight(-_weightStep),
                onMore: () => onWeight(_weightStep),
              ),
            ),
            Expanded(
              child: _Stepper(
                label: 'Reps',
                value: '$reps',
                lessLabel: 'Fewer reps',
                moreLabel: 'More reps',
                onLess: () => onReps(-_repStep),
                onMore: () => onReps(_repStep),
              ),
            ),
          ],
        ),
        if (ahead)
          Text('Ahead of your best by ${formatWeight(weight - pr.weightKg)} kg',
              textAlign: TextAlign.center,
              style: AppType.subhead.copyWith(color: c.thrivingInk, fontFeatures: _tabular)),
        PillButton(label: 'Complete set', icon: 'checkmark', onTap: onComplete),
      ],
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    this.unit,
    required this.lessLabel,
    required this.moreLabel,
    required this.onLess,
    required this.onMore,
  });

  final String label;
  final String value;
  final String? unit;
  final String lessLabel;
  final String moreLabel;
  final VoidCallback onLess;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final unit = this.unit;
    return Column(
      spacing: Spacing.sm,
      children: [
        Text(label, style: AppType.label.copyWith(color: c.ink3)),
        // scale a long value down rather than overflow the column.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: value),
              if (unit != null)
                TextSpan(text: ' $unit', style: AppType.subhead.copyWith(color: c.ink3)),
            ]),
            maxLines: 1,
            style: AppType.score.copyWith(color: c.ink),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: Spacing.sm,
          children: [
            NavIconButton(name: 'minus', semanticLabel: lessLabel, onTap: onLess),
            NavIconButton(name: 'plus', semanticLabel: moreLabel, onTap: onMore),
          ],
        ),
      ],
    );
  }
}

class _RestCard extends StatelessWidget {
  const _RestCard({
    required this.remaining,
    required this.next,
    required this.onAddTime,
    required this.onSkip,
  });

  final int remaining;
  final String next;
  final VoidCallback onAddTime;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final m = remaining ~/ 60;
    final s = (remaining % 60).toString().padLeft(2, '0');
    return _Card(
      gap: _restGap,
      center: true,
      children: [
        Text('Rest', style: AppType.label.copyWith(color: c.ink3)),
        Text('$m:$s', style: AppType.display.copyWith(color: c.ink)),
        Text('Next: $next',
            textAlign: TextAlign.center,
            style: AppType.subhead.copyWith(color: c.ink2, fontFeatures: _tabular)),
        Padding(
          padding: const EdgeInsets.only(top: Spacing.xs),
          child: Row(
            spacing: Spacing.sm,
            children: [
              PillButton(
                label: '+30 s',
                primary: false,
                semanticLabel: 'Add 30 seconds rest',
                onTap: onAddTime,
              ),
              Expanded(child: PillButton(label: 'Skip rest', onTap: onSkip)),
            ],
          ),
        ),
      ],
    );
  }
}

class _FinishedCard extends StatelessWidget {
  const _FinishedCard({required this.logged, required this.total, required this.onSummary});

  final int logged;
  final int total;
  final VoidCallback onSummary;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return _Card(
      gap: Spacing.md + Spacing.xxs,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: Spacing.xxs,
          children: [
            Text('$logged of $total sets',
                style: AppType.label.copyWith(color: c.ink3, fontFeatures: _tabular)),
            Text('All sets logged', style: AppType.title.copyWith(color: c.ink)),
          ],
        ),
        PillButton(label: 'See your summary', onTap: onSummary),
      ],
    );
  }
}

// ─── Set list ────────────────────────────────────────────────────────────────

class _SetRow extends StatelessWidget {
  const _SetRow({
    required this.number,
    required this.set,
    required this.current,
    required this.resting,
    required this.weight,
    required this.reps,
    required this.divided,
  });

  final int number;
  final SetLog set;
  final bool current;
  final bool resting;
  final double weight;
  final int reps;
  final bool divided;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final done = set.done;
    final value = current && !done
        ? '${formatWeight(weight)} kg × $reps'
        : '${formatWeight(set.weightKg)} kg × ${set.reps}';
    return Container(
      constraints: const BoxConstraints(minHeight: _rowMinHeight),
      decoration: divided
          ? BoxDecoration(border: Border(top: BorderSide(color: c.hair, width: _hairline)))
          : null,
      child: Row(
        spacing: Spacing.md,
        children: [
          _disc(c, done),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: 'Set $number'),
                if (current && !resting && !done)
                  TextSpan(text: ' · now', style: AppType.label.copyWith(color: c.ink3)),
              ]),
              style: AppType.callout.copyWith(color: done ? c.ink3 : c.ink),
            ),
          ),
          Text(value,
              style: AppType.subhead.copyWith(
                  color: done ? c.ink3 : c.ink2, fontFeatures: _tabular)),
        ],
      ),
    );
  }

  Widget _disc(AppColors c, bool done) {
    final now = current && !done;
    return Container(
      width: _rowDisc,
      height: _rowDisc,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? c.surface2 : (now ? c.ink : null),
        border: done || now ? null : Border.all(color: c.hair, width: _hairline),
      ),
      child: done
          ? Semantics(
              label: 'Done',
              child: AppIcon('checkmark', size: _discGlyph, color: c.ink3),
            )
          : Text('$number',
              style: AppType.caption.copyWith(
                  color: now ? c.bg : c.ink3, fontFeatures: _tabular)),
    );
  }
}

class _SetTools extends StatelessWidget {
  const _SetTools({required this.canSkip, required this.onAddSet, required this.onSkip});

  final bool canSkip;
  final VoidCallback onAddSet;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.only(top: Spacing.xs),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: c.hair, width: _hairline))),
      child: Row(
        spacing: Spacing.sm,
        children: [
          Flexible(child: _TextButton(label: 'Add set', icon: 'plus', onTap: onAddSet)),
          const Spacer(),
          if (canSkip)
            Flexible(
              child: _TextButton(label: 'Skip exercise', color: c.ink2, onTap: onSkip),
            ),
        ],
      ),
    );
  }
}

class _UpNext extends StatelessWidget {
  const _UpNext({required this.state});

  final ActiveSessionState state;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final next = state.nextExercise!;
    final nextId = state.exerciseIds[state.currentExerciseIndex + 1];
    final count = state.sets.where((s) => s.exerciseId == nextId).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: Spacing.xs,
      children: [
        Text('Up next', style: AppType.label.copyWith(color: c.ink3)),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          spacing: Spacing.sm,
          children: [
            Expanded(child: Text(next.name, style: AppType.callout.copyWith(color: c.ink))),
            Text('$count sets', style: AppType.subhead.copyWith(color: c.ink3)),
          ],
        ),
      ],
    );
  }
}

// ─── Finish sheet ────────────────────────────────────────────────────────────

class _FinishSheet extends StatelessWidget {
  const _FinishSheet({required this.logged, required this.total});

  final int logged;
  final int total;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Spacing.lg,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: Spacing.xs + Spacing.xxs,
          children: [
            Semantics(
              header: true,
              child: Text('Finish workout?', style: AppType.title.copyWith(color: c.ink)),
            ),
            Text(
              '$logged of $total sets logged. This ends the session and shows your summary.',
              style: AppType.subhead.copyWith(color: c.ink2, fontFeatures: _tabular),
            ),
          ],
        ),
        PillButton(label: 'Finish', onTap: () => Navigator.of(context).pop(true)),
        PillButton(
          label: 'Keep going',
          primary: false,
          onTap: () => Navigator.of(context).pop(false),
        ),
      ],
    );
  }
}

// ─── Shared bits ─────────────────────────────────────────────────────────────

/// A `headline` text button with no fill, at least 44 tall.
class _TextButton extends StatelessWidget {
  const _TextButton({required this.label, required this.onTap, this.icon, this.color});

  final String label;
  final VoidCallback onTap;
  final String? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ink = color ?? context.colors.ink;
    final icon = this.icon;
    return PressScale(
      onTap: onTap,
      semanticLabel: label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _minTap, minWidth: _minTap),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: Spacing.xs + Spacing.xxs,
          children: [
            if (icon != null) AppIcon(icon, size: _textIcon, color: ink),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.headline.copyWith(color: ink)),
            ),
          ],
        ),
      ),
    );
  }
}
