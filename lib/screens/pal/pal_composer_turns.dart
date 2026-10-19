import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../analysis/area_state.dart';
import '../../controllers/providers.dart';
import '../../controllers/today_controller.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../theme/theme.dart';
import '../../util/format.dart';
import '../../widgets/contributor_bar.dart';
import '../../widgets/press_scale.dart';

const double _minTap = 44;
const double _thinkingPad = Spacing.xxl;
const double _basisPad = 10;

/// One turn of the composer's conversation. The user's turn is a headline
/// line; Pal's reply is body text, followed by what the turn did when it acted.
class ComposerTurn extends StatelessWidget {
  const ComposerTurn({super.key, required this.message, this.onUndo, this.onEdit});

  final PalMessage message;

  /// Reverses one of this turn's auto-applied actions (by index), keeping the row.
  final ValueChanged<int>? onUndo;

  /// Reverses and removes one logged action (by index) and refills the input.
  final ValueChanged<int>? onEdit;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final m = message;
    if (m.role == PalRole.user) {
      return Text(m.text, style: AppType.headline.copyWith(color: c.ink));
    }
    final hasReply = m.text.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Spacing.lg,
      children: [
        if (hasReply)
          Text(m.text, style: AppType.body.copyWith(color: m.offline ? c.ink3 : c.ink)),
        for (var a = 0; a < m.actions.length; a++)
          _actionRow(m.actions[a], m.isUndone(a), _bind(onUndo, a), _bind(onEdit, a)),
      ],
    );
  }
}

VoidCallback? _bind(ValueChanged<int>? f, int a) => f == null ? null : () => f(a);

Widget _actionRow(PalAction action, bool undone, VoidCallback? onUndo, VoidCallback? onEdit) =>
    switch (action) {
      LogEntryAction() =>
        _LogTurn(action: action, undone: undone, onUndo: onUndo, onEdit: onEdit),
      LogMealAction() => _ActedLine(
          text: '${mealName(action.name)} · ${action.cal.lo}–${action.cal.hi} kcal, '
              '${action.confidence.label}',
          undone: undone,
          onUndo: onUndo,
          onEdit: onEdit,
        ),
      SetGoalAction() => _GoalLine(action: action, undone: undone, onUndo: onUndo),
      CreateRoutineAction() => _ActedLine(
          text: 'Saved a routine: ${action.name ?? action.goal}.',
          undone: undone,
          onUndo: onUndo,
        ),
    };

/// Shown while Pal is thinking.
class ComposerThinking extends StatelessWidget {
  const ComposerThinking({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: _thinkingPad),
        child: Text('…',
            textAlign: TextAlign.center,
            style: AppType.body.copyWith(color: context.colors.ink3)),
      );
}

/// A logged entry: the tracker it moved under `Based on`, then the acted line.
/// The tracker reads live totals, which already include the new entry.
class _LogTurn extends ConsumerWidget {
  const _LogTurn({required this.action, required this.undone, this.onUndo, this.onEdit});

  final LogEntryAction action;
  final bool undone;
  final VoidCallback? onUndo;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final currency = ref.watch(appSettingsControllerProvider).currency;
    final today = ref.watch(todayStateProvider).asData?.value;
    final detail = switch (action.type) {
      // a word joiner keeps the minus on the amount's line ("−$6.50", never
      // "−" then "$6.50").
      EntryType.money => formatCurrency(action.amount ?? 0, currency, withSign: true)
          .replaceFirst('−', '−\u2060'),
      EntryType.move =>
        action.durationMinutes != null ? '${action.durationMinutes} min' : null,
      EntryType.rituals => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (today != null) ...[
          Text('Based on', style: AppType.label.copyWith(color: c.ink3)),
          const SizedBox(height: Spacing.xs),
          DecoratedBox(
            decoration: BoxDecoration(border: Border(top: BorderSide(color: c.hair))),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: _basisPad),
              child: _tracker(today, currency),
            ),
          ),
        ],
        _ActedLine(
          text: 'Logged ${action.title}${detail == null ? '' : ' · $detail'}.',
          undone: undone,
          onUndo: onUndo,
          onEdit: onEdit,
        ),
      ],
    );
  }

  ContributorBar _tracker(TodayState today, Currency currency) {
    double share(num now, num goal) => goal > 0 ? now / goal : 0;
    switch (action.type) {
      case EntryType.money:
        final now = today.moneySpent;
        final goal = today.goals.dailyBudget;
        final over = goal > 0 && now > goal;
        return ContributorBar(
          label: 'Spending today',
          value: over
              ? '${formatCurrency(now, currency)} · over by ${formatCurrency(now - goal, currency)}'
              : '${formatCurrency(now, currency)} of ${formatCurrency(goal, currency)}',
          fraction: share(now, goal),
          off: over ? AreaState.care : null,
        );
      case EntryType.move:
        final now = today.moveKcal;
        final goal = today.goals.dailyMoveKcal;
        return ContributorBar(
          label: 'Movement today',
          value: '$now of $goal kcal',
          fraction: share(now, goal),
        );
      case EntryType.rituals:
        final now = today.ritualsDone;
        final goal = today.ritualsTarget;
        return ContributorBar(
          label: 'Rituals today',
          value: goal == 0
              ? noTargetLine(hasRoutines: today.routines.isNotEmpty)
              : '$now of $goal',
          fraction: share(now, goal),
        );
    }
  }
}

/// The acted line for a changed daily goal.
class _GoalLine extends ConsumerWidget {
  const _GoalLine({required this.action, required this.undone, this.onUndo});

  final SetGoalAction action;
  final bool undone;
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(appSettingsControllerProvider).currency;
    final text = switch (action.target) {
      GoalTarget.dailyBudget =>
        'Daily budget set to ${formatCurrency(action.value, currency)}.',
      GoalTarget.dailyMoveKcal => 'Daily move goal set to ${action.value} kcal.',
      GoalTarget.dailyRitualTarget => 'Daily ritual target set to ${action.value}.',
    };
    return _ActedLine(text: text, undone: undone, onUndo: onUndo);
  }
}

/// What a turn did, with Undo (and Edit for logs). Once undone it reads
/// `Undone` and offers nothing.
class _ActedLine extends StatelessWidget {
  const _ActedLine({required this.text, required this.undone, this.onUndo, this.onEdit});

  final String text;
  final bool undone;
  final VoidCallback? onUndo;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _minTap),
      child: Row(
        children: [
          Expanded(
            child: Text(
              undone ? 'Undone' : text,
              style: AppType.subhead.copyWith(color: undone ? c.ink3 : c.ink2),
            ),
          ),
          if (!undone) ...[
            _TextButton(label: 'Undo', onTap: onUndo),
            if (onEdit != null) _TextButton(label: 'Edit', onTap: onEdit),
          ],
        ],
      ),
    );
  }
}

class _TextButton extends StatelessWidget {
  const _TextButton({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => PressScale(
        semanticLabel: label,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: _minTap, minWidth: _minTap),
          padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
          alignment: Alignment.center,
          child: Text(label, style: AppType.headline.copyWith(color: context.colors.ink)),
        ),
      );
}
