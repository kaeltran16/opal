import 'package:flutter/cupertino.dart'
    show showCupertinoDialog, CupertinoAlertDialog, CupertinoDialogAction;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/providers.dart';
import '../../controllers/start_workout_controller.dart';
import '../../models/models.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../widgets/exercise_row.dart';
import '../../widgets/inset_section.dart';
import '../../widgets/nav_bar.dart';
import '../shell/loop_shell.dart' show shellBottomInset;
import 'pal_pick_lead.dart';
import 'session_launcher.dart';

const int _previewNames = 2;
const String _strengthIcon = 'dumbbell';
const String _cardioIcon = 'figure.run';

/// Start workout: Pal's pick as the lead, then every routine by kind and the
/// routine tools. A routine opens through [openWorkoutSession]; a long-press
/// deletes it.
///
/// All async/derivation lives in [startWorkoutController]; this widget lays out.
class StartWorkoutScreen extends ConsumerWidget {
  const StartWorkoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final async = ref.watch(startWorkoutProvider);

    // opaque so the cupertino push parallax doesn't show the outgoing page
    // through this one.
    return ColoredBox(
      color: c.bg,
      child: async.when(
        loading: () => Center(
          child: Text('…', style: AppType.body.copyWith(color: c.ink3)),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.xxl),
            child: Text("Couldn't load workouts.\n$e",
                textAlign: TextAlign.center,
                style: AppType.subhead.copyWith(color: c.ink3)),
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
    final exercisesList = ref.watch(exercisesProvider).asData?.value;
    final exerciseCount = exercisesList?.length;
    final exerciseNames = <String, String>{
      for (final e in exercisesList ?? const <Exercise>[]) e.id: e.name,
    };

    Future<void> confirmDeleteRoutine(Routine r) async {
      final ok = await showCupertinoDialog<bool>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('Delete routine?'),
          content: Text('"${r.name}" will be removed. This can’t be undone.'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (ok == true) {
        await ref.read(routineRepositoryProvider).deleteById(r.id);
      }
    }

    Widget section(String header, List<Routine> routines, String icon) =>
        InsetSection(
          header: header,
          children: [
            for (var i = 0; i < routines.length; i++)
              _RoutineRow(
                routine: routines[i],
                icon: icon,
                detail: _detail(routines[i], exerciseNames),
                first: i == 0,
                onTap: () => openWorkoutSession(context, ref, routines[i].id),
                onLongPress: () => confirmDeleteRoutine(routines[i]),
              ),
          ],
        );

    return LargeTitleScrollView(
      title: 'Start workout',
      subtitle: 'Pick a routine',
      leading: NavAction(
        icon: 'chevron.left',
        onTap: () => Navigator.of(context).maybePop(),
        semanticLabel: 'Back',
      ),
      padding: EdgeInsets.only(bottom: shellBottomInset(context)),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(
              Spacing.lg, Spacing.xs, Spacing.lg, Spacing.xxl),
          child: PalPickLead(onPicker: true),
        ),
        if (state.strength.isNotEmpty)
          section('Strength', state.strength, _strengthIcon),
        if (state.cardio.isNotEmpty)
          section('Cardio', state.cardio, _cardioIcon),
        InsetSection(
          children: [
            ListRow(
              icon: 'wand.and.stars',
              title: 'Generate with Pal',
              onTap: () => context.pushNamed(AppRoute.routineGenerator.name),
            ),
            ListRow(
              icon: 'plus',
              title: 'New routine',
              onTap: () => context.pushNamed(AppRoute.routineEditor.name),
            ),
            ListRow(
              icon: 'book',
              title: 'Exercise library',
              value: exerciseCount == null ? null : '$exerciseCount',
              last: true,
              onTap: () => context.pushNamed(AppRoute.exerciseLibrary.name),
            ),
          ],
        ),
      ],
    );
  }

  /// "{n} exercises · {min} min · {when} · {first names}".
  String _detail(Routine r, Map<String, String> names) {
    final n = r.exerciseCount;
    return [
      '$n ${n == 1 ? 'exercise' : 'exercises'}',
      '${_displayEstMinutes(r)} min',
      _lastDoneLabel(state.daysSinceLastDone(r.id)),
      if (r.exercises.isNotEmpty) _previewLine(r, names),
    ].join(' · ');
  }
}

/// A routine on a hairline. Tap opens it; a long-press offers to delete it.
class _RoutineRow extends StatelessWidget {
  const _RoutineRow({
    required this.routine,
    required this.icon,
    required this.detail,
    required this.first,
    required this.onTap,
    required this.onLongPress,
  });

  final Routine routine;
  final String icon;
  final String detail;
  final bool first;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: ExerciseRow(
        name: routine.name,
        detail: detail,
        icon: icon,
        first: first,
        onTap: onTap,
      ),
    );
  }
}

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

/// "Today" / "Yesterday" / "{n} days ago" / "Never done".
String _lastDoneLabel(int? daysAgo) {
  if (daysAgo == null) return 'Never done';
  if (daysAgo <= 0) return 'Today';
  if (daysAgo == 1) return 'Yesterday';
  return '$daysAgo days ago';
}

/// The routine's first exercise names, then "+N" for the rest, e.g.
/// "Bench press, Incline press, +3".
String _previewLine(Routine routine, Map<String, String> names) {
  final ordered = routine.orderedExercises;
  final shown = [
    for (final ex in ordered.take(_previewNames))
      names[ex.exerciseId] ?? ex.exerciseId,
  ];
  final remaining = ordered.length - shown.length;
  return [...shown, if (remaining > 0) '+$remaining'].join(', ');
}
