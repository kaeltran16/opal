import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/cupertino.dart'
    show showCupertinoDialog, CupertinoAlertDialog, CupertinoDialogAction;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/area_detail_controller.dart';
import '../../controllers/providers.dart';
import '../../controllers/spending_controller.dart';
import '../../models/models.dart';
import '../../theme/theme.dart';
import '../../util/dates.dart';
import '../../util/format.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/contributor_bar.dart';
import '../../widgets/pal_label.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/state_colors.dart';
import '../../widgets/week_bars.dart';
import '../today/today_logic.dart' show dateLine;

// kept literal: the shell overlay under the content, tab bar gap 8 + bar 62 +
// gap 10 + ask bar 52.
const double _shellOverlay = 132;
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
const double _palLineHeight = 24 / 17;
const double _contributorTop = 10;
const double _trailingMaxWidth = 160;
const double _hairline = 1;
const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

String _areaTitle(DetailTracker tracker) => switch (tracker) {
      DetailTracker.money => 'Money',
      DetailTracker.move => 'Move',
      DetailTracker.rituals => 'Routines',
    };

String _areaGlyph(DetailTracker tracker) => switch (tracker) {
      DetailTracker.money => 'dollarsign.circle.fill',
      DetailTracker.move => 'figure.run',
      DetailTracker.rituals => 'sparkles',
    };

/// The area page behind a ring on Today: the area's number and state, Pal's
/// line, what is shaping it, the week against the goal, and recent entries.
///
/// Everything shown is computed by [buildAreaDetail]; this widget only lays out.
class DetailScreen extends ConsumerWidget {
  const DetailScreen({super.key, this.tracker = DetailTracker.money});

  final DetailTracker tracker;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final safe = MediaQuery.paddingOf(context);
    final padding = EdgeInsets.fromLTRB(
      Spacing.lg,
      math.max(_contentTop, safe.top + Spacing.xs),
      Spacing.lg,
      _shellOverlay + Spacing.xxl + safe.bottom,
    );
    final header = _Header(date: dateLine(clock.now()));
    Widget message(String text, TextStyle style) => Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
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
      body: ref.watch(areaDetailProvider(tracker)).when(
            // the routines page rebuilds on every step toggle; keep the last
            // value on screen instead of flashing the loading state.
            skipLoadingOnReload: true,
            loading: () => message('…', AppType.body),
            error: (e, _) {
              debugPrint('detail load failed (${tracker.title}): $e');
              return message("Couldn't load ${tracker.title}.", AppType.subhead);
            },
            data: (detail) => _AreaBody(detail: detail, padding: padding, header: header),
          ),
    );
  }
}

/// Back to Today at the left, the date line at the right.
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
                semanticLabel: 'Back to Today',
                child: Container(
                  constraints: const BoxConstraints(minHeight: _minTap),
                  padding: const EdgeInsets.only(right: Spacing.sm),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppIcon('chevron.left', size: _backIcon, color: c.ink),
                      const SizedBox(width: Spacing.xxs),
                      Text('Today', style: AppType.headline.copyWith(color: c.ink)),
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

class _AreaBody extends ConsumerWidget {
  const _AreaBody({required this.detail, required this.padding, required this.header});

  final AreaDetail detail;
  final EdgeInsets padding;
  final Widget header;

  /// What a recent entry shows at the right: its amount, or its detail where
  /// an entry has no amount of its own.
  String? _trailing(Entry e, Currency currency) => switch (detail.tracker) {
        DetailTracker.money => formatCurrency(detail.tracker.magnitudeOf(e), currency),
        DetailTracker.move => '${detail.tracker.magnitudeOf(e).round()} kcal',
        DetailTracker.rituals => e.detail,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final currency = ref.watch(appSettingsControllerProvider).currency;
    final title = _areaTitle(detail.tracker);
    final hasGoal = detail.goal > 0;
    final caption = AppType.caption.copyWith(color: c.ink3);

    return ListView(
      padding: padding,
      children: [
        header,
        const SizedBox(height: _heroTop),
        Semantics(
          header: true,
          child: Row(
            children: [
              AppIcon(_areaGlyph(detail.tracker), size: _areaIcon, color: c.ink2),
              const SizedBox(width: _labelGap),
              Text(title, style: AppType.label.copyWith(color: c.ink2)),
            ],
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(detail.hero, maxLines: 1, style: AppType.display.copyWith(color: c.ink)),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(detail.unit,
                  style: AppType.subhead.copyWith(color: c.ink2, fontFeatures: _tabular)),
            ),
            const SizedBox(width: Spacing.md),
            Text(detail.state.word,
                style: AppType.label.copyWith(color: c.wordInkFor(detail.state))),
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
                style: AppType.body.copyWith(color: c.ink, height: _palLineHeight)),
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
              ? '$title this week: ${detail.weekNote}. ${detail.goalLabel}'
              : '$title this week: ${detail.weekNote}',
        ),
        if (hasGoal) ...[
          const SizedBox(height: Spacing.md),
          Text('Dashed line: ${detail.goalLabel}', style: caption),
        ],
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
                trailing: _trailing(entry, currency),
                divided: i > 0,
                onDelete: () => ref.read(entryRepositoryProvider).deleteById(entry.id),
              ),
          ],
      ],
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

/// One recent entry. Swiping it away deletes it, after a confirm.
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
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) => onDelete(),
      background: Container(
        color: c.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: Spacing.lg),
        child: AppIcon('trash.fill', size: 20, color: c.onAccent),
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
              child: Text(entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.callout.copyWith(color: c.ink)),
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
