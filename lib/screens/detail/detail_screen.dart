import '../shell/loop_shell.dart' show shellBottomInset;
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/cupertino.dart'
    show showCupertinoDialog, CupertinoAlertDialog, CupertinoDialogAction;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../analysis/area.dart';
import '../../controllers/area_detail_controller.dart';
import '../../controllers/providers.dart';
import '../../controllers/spending_controller.dart';
import '../../models/models.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../util/dates.dart';
import '../../util/format.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/contributor_bar.dart';
import '../../widgets/day_scene.dart';
import '../../widgets/failure_note.dart' show deleteFailedCopy;
import '../../widgets/pal_label.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/state_colors.dart';
import '../../widgets/week_bars.dart';
import '../nutrition/nutrition_add_sheet.dart';
import '../today/today_logic.dart' show dateLine;

// kept literal: where the prototype's content starts, just under the status bar.
const double _contentTop = 52;
const double _minTap = 44;
const double _backIcon = 24;
// the chevron hangs into the gutter so its stroke lines up with the text edge.
const double _backHang = Spacing.sm;
const double _areaIcon = 16;
const double _labelGap = 6;
const double _dateTracking = 1.2;
const double _heroTop = Spacing.xl;
const double _palTop = 28;
const double _palMaxWidth = 320;
const double _contributorTop = 10;
const double _trailingMaxWidth = 160;
const double _hairline = 1;
const double _listRowHeight = 48;
const double _mealTimeWidth = 56; // fits "12:00 PM" in caption
const double _mealGap = 10;
const double _mealDisc = 28;
const double _mealIcon = 18;
// Add a meal lines up with the meal names: time, gap, disc, gap.
const double _addMealInset = _mealTimeWidth + _mealGap + _mealDisc + _mealGap;
const double _chevron = 16;
const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

const String _backLabel = 'Areas';

/// An area page under the Areas tab: the area's number and state, Pal's line,
/// what is shaping it, today's meals or routines, the week, and recent
/// entries. Sleep shows only its empty state: it has no data source yet.
///
/// Everything shown is computed in `area_detail_controller.dart`; this widget
/// only lays out.
class DetailScreen extends ConsumerWidget {
  const DetailScreen({super.key, required this.area});

  final Area area;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final safe = MediaQuery.paddingOf(context);
    final padding = EdgeInsets.fromLTRB(
      Spacing.lg,
      math.max(_contentTop, safe.top + Spacing.xs),
      Spacing.lg,
      shellBottomInset(context),
    );
    final header = _Header(date: dateLine(clock.now()));
    Widget message(String text, TextStyle style) => Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SceneTop(padding: padding, child: header),
              Expanded(
                child: Center(
                  child: Text(text,
                      textAlign: TextAlign.center, style: style.copyWith(color: c.ink3)),
                ),
              ),
            ],
          ),
        );

    return Scaffold(
      backgroundColor: c.bg,
      body: area == Area.sleep
          ? ref.watch(sleepDetailProvider).when(
                loading: () => message('…', AppType.body),
                error: (e, _) {
                  debugPrint('detail load failed (${area.title}): $e');
                  return message("Couldn't load ${area.title}.", AppType.subhead);
                },
                data: (detail) => detail == null
                    ? _SleepBody(padding: padding, header: header)
                    : _AreaBody(detail: detail, padding: padding, header: header),
              )
          : ref.watch(areaDetailProvider(area)).when(
                // the routines page rebuilds on every step toggle; keep the last
                // value on screen instead of flashing the loading state.
                skipLoadingOnReload: true,
                loading: () => message('…', AppType.body),
                error: (e, _) {
                  debugPrint('detail load failed (${area.title}): $e');
                  return message("Couldn't load ${area.title}.", AppType.subhead);
                },
                data: (detail) =>
                    _AreaBody(detail: detail, padding: padding, header: header),
              ),
    );
  }
}

/// The time-of-day scene behind [child], drawn up into the top padding and out
/// to the screen edges, so it scrolls with the page as it does on Today.
class _SceneTop extends StatelessWidget {
  const _SceneTop({required this.padding, required this.child});

  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: -padding.top,
          left: -padding.left,
          right: -padding.right,
          child: DayScene(phase: phaseFor(clock.now())),
        ),
        child,
      ],
    );
  }
}

/// Back to Areas at the left, the date line at the right.
class _Header extends StatelessWidget {
  const _Header({required this.date});

  final String date;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _minTap),
      child: Row(
        children: [
          Transform.translate(
            offset: const Offset(-_backHang, 0),
            // its own node, or the button merges with the date line beside it.
            child: Semantics(
              container: true,
              child: PressScale(
                onTap: () => context.pop(),
                semanticLabel: 'Back to $_backLabel',
                child: Container(
                  constraints: const BoxConstraints(minHeight: _minTap),
                  padding: const EdgeInsets.only(right: Spacing.sm),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppIcon('chevron.left', size: _backIcon, color: c.ink),
                      const SizedBox(width: Spacing.xxs),
                      Text(_backLabel, style: AppType.headline.copyWith(color: c.ink)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(date,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: AppType.label.copyWith(color: c.ink2, letterSpacing: _dateTracking)),
          ),
        ],
      ),
    );
  }
}

/// The area's glyph and title, the page's heading.
class _AreaTitle extends StatelessWidget {
  const _AreaTitle(this.area);

  final Area area;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      header: true,
      child: Row(
        children: [
          AppIcon(area.glyph, size: _areaIcon, color: c.ink2),
          const SizedBox(width: _labelGap),
          Text(area.title, style: AppType.label.copyWith(color: c.ink2)),
        ],
      ),
    );
  }
}

/// Sleep has no data source yet, so its page is the header and the empty state.
class _SleepBody extends StatelessWidget {
  const _SleepBody({required this.padding, required this.header});

  final EdgeInsets padding;
  final Widget header;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListView(
      padding: padding,
      children: [
        _SceneTop(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              const SizedBox(height: _heroTop),
              const _AreaTitle(Area.sleep),
              const SizedBox(height: Spacing.sm),
              Text('No sleep data yet', style: AppType.title.copyWith(color: c.ink)),
              const SizedBox(height: _labelGap),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _palMaxWidth),
                  child: Text('Sleep needs a data source, and none is connected yet.',
                      style: AppType.body.copyWith(color: c.ink2)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AreaBody extends ConsumerWidget {
  const _AreaBody({required this.detail, required this.padding, required this.header});

  final AreaDetail detail;
  final EdgeInsets padding;
  final Widget header;

  /// What a recent entry shows at the right: its amount, or its detail where
  /// an entry has no amount of its own.
  String? _trailing(DetailTracker tracker, Entry e, Currency currency) => switch (tracker) {
        DetailTracker.money => formatCurrency(tracker.magnitudeOf(e), currency),
        DetailTracker.move => '${tracker.magnitudeOf(e).round()} kcal',
        DetailTracker.rituals => e.detail,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final currency = ref.watch(appSettingsControllerProvider).currency;
    final area = detail.area;
    final tracker = area.tracker;
    final state = detail.state;
    final hasGoal = detail.goal > 0;
    final caption = AppType.caption.copyWith(color: c.ink3);

    return ListView(
      padding: padding,
      children: [
        _SceneTop(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              const SizedBox(height: _heroTop),
              _AreaTitle(area),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(detail.hero,
                    maxLines: 1, style: AppType.display.copyWith(color: c.ink)),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: Text(detail.unit,
                        style: AppType.subhead.copyWith(color: c.ink2, fontFeatures: _tabular)),
                  ),
                  if (state != null) ...[
                    const SizedBox(width: Spacing.md),
                    Text(state.word,
                        style: AppType.label.copyWith(color: c.wordInkFor(state))),
                  ],
                ],
              ),
              const SizedBox(height: _palTop),
              const Align(alignment: AlignmentDirectional.centerStart, child: PalLabel()),
              const SizedBox(height: _labelGap),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _palMaxWidth),
                  child: Text(detail.palLine,
                      style: AppType.body.copyWith(color: c.ink)),
                ),
              ),
            ],
          ),
        ),
        if (detail.contributors.isNotEmpty) ...[
          const SizedBox(height: Spacing.xxxl),
          const _Heading('What is shaping it'),
          const SizedBox(height: Spacing.xs),
          for (final part in detail.contributors)
            Padding(
              padding: const EdgeInsets.only(top: _contributorTop, bottom: Spacing.md),
              child: ContributorBar(
                label: part.label,
                value: part.value,
                fraction: part.fraction,
                off: part.off,
              ),
            ),
        ],
        if (area == Area.nutrition) _MealsSection(meals: detail.meals),
        if (area == Area.routines) _RoutinesSection(routines: detail.routines),
        const SizedBox(height: Spacing.xl),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            const Expanded(child: _Heading('This week')),
            const SizedBox(width: Spacing.md),
            Text(detail.weekNote, style: caption),
          ],
        ),
        const SizedBox(height: Spacing.md),
        WeekBars(
          values: [for (final bar in detail.week) bar.value],
          off: [for (final bar in detail.week) bar.off],
          todayIndex: detail.week.indexWhere((bar) => bar.today),
          goal: detail.goal,
          semanticLabel: hasGoal
              ? '${area.title} this week: ${detail.weekNote}. ${detail.goalLabel}'
              : '${area.title} this week: ${detail.weekNote}',
        ),
        if (hasGoal) ...[
          const SizedBox(height: Spacing.md),
          Text('Dashed line: ${detail.goalLabel}', style: caption),
        ],
        if (tracker != null) ...[
          const SizedBox(height: Spacing.xxxl),
          if (detail.days.isEmpty)
            Text('Nothing logged yet.', style: AppType.subhead.copyWith(color: c.ink3))
          else
            for (final group in detail.days) ...[
              Padding(
                padding: const EdgeInsets.only(top: Spacing.md, bottom: Spacing.xs),
                child: Text(_dayLabel(group.day), style: AppType.label.copyWith(color: c.ink3)),
              ),
              for (final (i, entry) in group.entries.indexed)
                _EntryRow(
                  entry: entry,
                  trailing: _trailing(tracker, entry, currency),
                  divided: i > 0,
                  onDelete: () => ref.read(entryRepositoryProvider).deleteById(entry.id),
                ),
            ],
        ],
      ],
    );
  }
}

/// Today's meals, each opening its detail, then Add a meal.
class _MealsSection extends StatelessWidget {
  const _MealsSection({required this.meals});

  final List<NutritionMeal> meals;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Spacing.xs,
      children: [
        const SizedBox(height: Spacing.xl - Spacing.xs),
        const _Heading("Today's meals"),
        for (final meal in meals) _MealRow(meal: meal),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: PressScale(
            onTap: () => showNutritionAddSheet(context),
            semanticLabel: 'Add a meal',
            child: Container(
              constraints: const BoxConstraints(minHeight: _minTap),
              padding: const EdgeInsetsDirectional.only(start: _addMealInset),
              alignment: AlignmentDirectional.centerStart,
              child: Text('Add a meal',
                  style: AppType.subhead.copyWith(color: c.ink, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ],
    );
  }
}

class _MealRow extends StatelessWidget {
  const _MealRow({required this.meal});

  final NutritionMeal meal;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final kcal = '${groupThousands('${meal.cal.mid}', ',')} kcal';
    return PressScale(
      onTap: () => context.pushNamed(
        AppRoute.nutritionMeal.name,
        pathParameters: {'id': meal.id},
      ),
      semanticLabel: '${meal.slot} at ${meal.time}, ${meal.name}, $kcal',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _listRowHeight),
        child: Row(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: _mealTimeWidth),
              child: Text(meal.time,
                  style: AppType.caption.copyWith(color: c.ink3, fontFeatures: _tabular)),
            ),
            const SizedBox(width: _mealGap),
            Container(
              width: _mealDisc,
              height: _mealDisc,
              decoration: BoxDecoration(color: c.surface2, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: AppIcon(meal.icon, size: _mealIcon, color: c.ink),
            ),
            const SizedBox(width: _mealGap),
            Expanded(
              child: Text(meal.name, style: AppType.callout.copyWith(color: c.ink)),
            ),
            const SizedBox(width: _mealGap),
            Text(kcal, style: AppType.subhead.copyWith(color: c.ink3, fontFeatures: _tabular)),
          ],
        ),
      ),
    );
  }
}

/// Today's routines, an open one starting its player, then Manage routines.
class _RoutinesSection extends StatelessWidget {
  const _RoutinesSection({required this.routines});

  final List<RoutineRow> routines;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: Spacing.xl),
        const _Heading("Today's routines"),
        const SizedBox(height: Spacing.xs),
        for (final row in routines) _RoutineItem(row: row),
        PressScale(
          onTap: () => context.goNamed(AppRoute.areaManageRoutines.name),
          semanticLabel: 'Manage routines',
          child: _ListRowFrame(
            child: Row(
              children: [
                Expanded(
                  child: Text('Manage routines',
                      style: AppType.callout.copyWith(color: c.ink)),
                ),
                const SizedBox(width: Spacing.md),
                AppIcon('chevron.right', size: _chevron, color: c.ink3),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RoutineItem extends StatelessWidget {
  const _RoutineItem({required this.row});

  final RoutineRow row;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final content = _ListRowFrame(
      child: Row(
        children: [
          Expanded(
            child: Text(row.name,
                style: AppType.callout
                    .copyWith(color: row.done ? c.ink3 : c.ink)),
          ),
          const SizedBox(width: Spacing.md),
          Text(row.detail,
              style: AppType.subhead.copyWith(color: c.ink3, fontFeatures: _tabular)),
        ],
      ),
    );
    // a done routine has nothing left to start.
    if (row.done) {
      return Semantics(
        container: true,
        label: row.semanticLabel,
        excludeSemantics: true,
        child: content,
      );
    }
    return PressScale(
      onTap: () => context.pushNamed(
        AppRoute.routinePlayer.name,
        pathParameters: {'routineId': row.id},
      ),
      semanticLabel: row.semanticLabel,
      child: content,
    );
  }
}

/// A list row with the hairline above it.
class _ListRowFrame extends StatelessWidget {
  const _ListRowFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: _listRowHeight),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.colors.hair, width: _hairline)),
      ),
      alignment: AlignmentDirectional.centerStart,
      child: child,
    );
  }
}

String _dayLabel(DateTime day) {
  final diff = startOfDay(clock.now()).difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return '${kMonthsShort[day.month - 1]} ${day.day}';
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(text, style: AppType.headline.copyWith(color: context.colors.ink)),
    );
  }
}

/// One recent entry. Swiping it away deletes it, after a confirm; a failed
/// delete slides it back and says so.
class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.trailing,
    required this.divided,
    required this.onDelete,
  });

  final Entry entry;
  final String? trailing;

  /// Draws the hairline above the row, between it and the one before.
  final bool divided;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final trailing = this.trailing;
    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmAndDelete(context),
      background: Container(
        color: c.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: Spacing.lg),
        child: AppIcon('trash.fill', size: 20, color: c.bg),
      ),
      child: Container(
        constraints: const BoxConstraints(minHeight: _minTap),
        decoration: BoxDecoration(
          color: c.bg,
          border: divided
              ? Border(top: BorderSide(color: c.hair, width: _hairline))
              : null,
        ),
        padding: const EdgeInsets.symmetric(vertical: Spacing.md),
        child: Row(
          children: [
            Expanded(
              child: Text(entry.title, style: AppType.callout.copyWith(color: c.ink)),
            ),
            if (trailing != null) ...[
              const SizedBox(width: Spacing.md),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _trailingMaxWidth),
                child: Text(trailing,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.subhead.copyWith(color: c.ink2, fontFeatures: _tabular)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Deletes the entry once the user confirms. Returns true only when the
  /// delete landed, so a failed one leaves the row in place.
  Future<bool> _confirmAndDelete(BuildContext context) async {
    if (!await _confirmDelete(context)) return false;
    try {
      await onDelete();
      return true;
    } catch (e, st) {
      debugPrint('area page: deleting entry ${entry.id} failed: $e\n$st');
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text(deleteFailedCopy)));
      }
      return false;
    }
  }

  /// iOS confirm dialog before a swipe actually deletes the entry. Returns true
  /// only when the user taps Delete.
  Future<bool> _confirmDelete(BuildContext context) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Delete entry?'),
        content: Text('"${entry.title}" will be removed. This can’t be undone.'),
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
    return confirmed ?? false;
  }
}
