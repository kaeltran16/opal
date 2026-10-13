import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/move_controller.dart';
import '../../controllers/start_workout_controller.dart';
import '../../controllers/weekly_plan_controller.dart';
import '../../controllers/workout_session_controller.dart';
import '../../router.dart';
import '../../services/pal/pal_service.dart' show WorkoutSuggestion;
import '../../theme/theme.dart';
import '../../util/dates.dart';
import '../../widgets/controls.dart';
import '../../widgets/pal_lead.dart';
import '../../widgets/press_scale.dart';
import 'session_launcher.dart';

const double _cardGap = Spacing.lg;
const double _textButtonHeight = 48;
const Duration _elapsedTick = Duration(seconds: 1);

const String _pickLabel = "Pal's pick for today";
const String _inProgressLabel = 'In progress';
const String _settledLabel = 'Pal';
const String _thinking = 'Thinking…';
const String _loading = '…';
const String _pickError = "Pal couldn't pick one just now.";
const String _todayLabel = 'Today';
const String _errorMeta = 'Today';

/// Pal's lead for the Workout tab and the routine picker: a running session,
/// the day settled, or Pal's pick (loading, failed or ready), first match wins.
class PalPickLead extends ConsumerWidget {
  const PalPickLead({super.key, this.onPicker = false});

  /// On the routine picker the settled state is skipped and a failed pick
  /// points at the list below instead of opening the picker again.
  final bool onPicker;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runningId = ref.watch(runningSessionProvider);
    if (runningId != null) return _InProgress(routineId: runningId);

    if (!onPicker) {
      final settled = _settledLine(ref);
      if (settled != null) return PalLead(label: _settledLabel, text: settled);
    }

    final pick = ref.watch(palPickControllerProvider);
    if (pick.isLoading) {
      return const PalLead(label: _pickLabel, text: _thinking, muted: true);
    }
    final suggestion = pick.value;
    if (pick.hasError || suggestion == null) return _error(context, ref);
    return _pick(context, ref, suggestion);
  }

  /// The fixed sentence once a workout is logged today, or null.
  String? _settledLine(WidgetRef ref) {
    final recent = ref.watch(moveStateProvider).value?.recentSessions ?? const [];
    final done = recent.where((s) => s.relativeDate == _todayLabel).firstOrNull;
    if (done == null) return null;
    final name = done.workout.name;
    final days = ref.watch(weeklyPlanControllerProvider).value?.days ?? const [];
    final today = days.indexWhere((d) => d.today);
    if (today >= 0) {
      for (var i = today + 1; i < days.length; i++) {
        final routine = days[i].routine;
        if (routine != null) return '$name is done. $routine is next, on ${kWeekdays[i]}.';
      }
    }
    return '$name is done.';
  }

  Widget _error(BuildContext context, WidgetRef ref) {
    void retry() => ref.read(palPickControllerProvider.notifier).another();
    return _withCard(
      const PalLead(label: _pickLabel, text: _pickError, muted: true),
      onPicker
          ? ActionCard(
              meta: _errorMeta,
              title: 'Pick a routine below',
              primary: PillButton(label: 'Try again', onTap: retry),
            )
          : ActionCard(
              meta: _errorMeta,
              title: 'Pick a routine',
              primary: PillButton(
                label: 'Start workout',
                onTap: () => context.pushNamed(AppRoute.startWorkout.name),
              ),
              secondary: _TextButton(label: 'Try again', onTap: retry),
            ),
    );
  }

  Widget _pick(BuildContext context, WidgetRef ref, WorkoutSuggestion suggestion) {
    // the first strength routine stands in when Pal's pick maps to none.
    final routineId =
        suggestion.routineId ?? ref.watch(startWorkoutProvider).value?.firstStrength?.id;
    final minutes = suggestion.estimatedMinutes;
    final meta = [
      if (minutes != null) '$minutes min',
      ?suggestion.focus,
    ].join(' · ');
    return _withCard(
      PalLead(label: _pickLabel, text: suggestion.rationale),
      ActionCard(
        meta: meta,
        title: suggestion.title,
        primary: PillButton(
          label: 'Start',
          onTap: () => routineId == null
              ? context.pushNamed(AppRoute.startWorkout.name)
              : openWorkoutSession(context, ref, routineId),
        ),
        secondary: _TextButton(
          label: 'Pick another',
          onTap: () => ref.read(palPickControllerProvider.notifier).another(),
        ),
      ),
    );
  }
}

Widget _withCard(Widget lead, Widget card) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  spacing: _cardGap,
  children: [lead, card],
);

/// The running session: how far in, and Resume. The elapsed clock ticks each
/// second while the tab is on screen.
class _InProgress extends ConsumerStatefulWidget {
  const _InProgress({required this.routineId});

  final String routineId;

  @override
  ConsumerState<_InProgress> createState() => _InProgressState();
}

class _InProgressState extends ConsumerState<_InProgress> {
  Timer? _tick;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // the shell mutes tickers on hidden tabs; the clock follows suit.
    if (TickerMode.valuesOf(context).enabled) {
      _tick ??= Timer.periodic(_elapsedTick, (_) => setState(() {}));
    } else {
      _stop();
    }
  }

  void _stop() {
    _tick?.cancel();
    _tick = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(workoutSessionControllerProvider(widget.routineId)).value;
    if (session == null) {
      return const PalLead(label: _inProgressLabel, text: _loading, muted: true);
    }
    final done = session.sets.where((s) => s.done).length;
    final left = session.sets.length - done;
    final elapsed = clock.now().difference(session.activeWorkout.startedAt);
    final exercise = session.currentExercise?.name;
    return _withCard(
      PalLead(
        label: _inProgressLabel,
        text: '$done ${done == 1 ? 'set' : 'sets'} in, $left to go.',
      ),
      ActionCard(
        meta: [_clock(elapsed), ?exercise].join(' · '),
        title: session.activeWorkout.name,
        primary: PillButton(
          label: 'Resume',
          onTap: () => openWorkoutSession(context, ref, widget.routineId),
        ),
      ),
    );
  }

  static String _clock(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % Duration.secondsPerMinute).toString().padLeft(2, '0')}';
}

/// The card's secondary: a text button in `ink2`, no fill.
class _TextButton extends StatelessWidget {
  const _TextButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PressScale(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        constraints: const BoxConstraints(minHeight: _textButtonHeight),
        padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
        // widthFactor keeps the button its label's width under the card's cap.
        child: Align(
          widthFactor: 1,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.headline.copyWith(color: c.ink2),
          ),
        ),
      ),
    );
  }
}
