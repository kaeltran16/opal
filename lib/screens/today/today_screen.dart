import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/insights_controller.dart';
import '../../controllers/providers.dart';
import '../../controllers/today_controller.dart';
import '../../models/models.dart';
import '../../services/pal/pal_service.dart' show InsightRange;
import '../../router.dart';
import '../../theme/theme.dart';
import '../../util/format.dart';
import '../../widgets/activity_rings.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/controls.dart';
import '../../widgets/dashed_border.dart';
import '../../widgets/nav_bar.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/summary_tile.dart';

/// Screen 02 — Today, on live data.
///
/// Reads the computed [TodayState] from `todayStateProvider` (entries + goals +
/// health) and renders the rings hero, the 3-up summary-tile row, the Pal
/// insight card, and the timeline. All math lives in the controller; this
/// widget only lays out. Tapping a summary tile routes to its detail screen
/// (stubbed; Spending detail is U09).
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final async = ref.watch(todayStateProvider);

    return async.when(
      loading: () => Center(
        child: Text('…', style: AppType.body.copyWith(color: c.ink3)),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.xxl),
          child: Text("Couldn't load today. Try again in a moment.",
              textAlign: TextAlign.center,
              style: AppType.subhead
                  .copyWith(color: c.ink3, letterSpacing: -0.24)),
        ),
      ),
      data: (today) => _TodayBody(today: today),
    );
  }
}

class _TodayBody extends ConsumerWidget {
  const _TodayBody({required this.today});
  final TodayState today;

  String get _dateSubtitle {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    final now = DateTime.now();
    return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }

  /// Shown in the "Pal noticed" card when there isn't enough data (or Pal is
  /// unreachable) — never fabricated numbers.
  static const _palEmptyCopy =
      "Keep logging and Pal will surface what's working.";

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final goals = today.goals;
    final currency = ref.watch(appSettingsControllerProvider).currency;
    final insightAsync = ref.watch(insightsProvider(InsightRange.day));
    final headline = insightAsync.asData?.value?.headline;
    final hasInsight = headline != null && headline.isNotEmpty;
    final moneySpent = today.moneySpent;
    final ritualsDone = today.ritualsDone;
    final ritualsTarget = today.ritualsTarget;
    final ritualsRemaining = today.ritualsRemaining;
    final closePrompt = ritualsRemaining == 0
        ? 'All routines done · nice close'
        : '$ritualsRemaining routine${ritualsRemaining == 1 ? '' : 's'} to close';

    return LargeTitleScrollView(
      title: 'Today',
      subtitle: _dateSubtitle,
      leading: Text(_monthAbbrev(),
          style: AppType.body.copyWith(color: c.accent, letterSpacing: 0)),
      trailing: Row(children: [
        NavIconButton(
          name: 'bell.fill',
          semanticLabel: 'Notifications',
          onTap: () => context.pushNamed(AppRoute.palInbox.name),
        ),
        const SizedBox(width: Spacing.sm),
        NavIconButton(
          name: 'magnifyingglass',
          semanticLabel: 'Search',
          onTap: () => _openSearch(context, today.timelineEntries),
        ),
      ]),
      // kept literal: fixed bottom inset clearing the floating tab bar / FAB.
      padding: const EdgeInsets.only(bottom: 110),
      children: [
        // Activity rings hero.
        Padding(
          padding: const EdgeInsets.fromLTRB(
              Spacing.lg, Spacing.xs, Spacing.lg, Spacing.lg),
          child: Container(
            padding: const EdgeInsets.fromLTRB(
                Spacing.xl, Spacing.xl, Spacing.xl, Spacing.lg),
            decoration: BoxDecoration(
                color: c.surface, borderRadius: BorderRadius.circular(Radii.lg)),
            child: Column(
              children: [
                Row(
                  children: [
                    ActivityRings(values: today.rings),
                    const SizedBox(width: Spacing.xl),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RingStat(
                              color: c.money,
                              label: 'Spent',
                              // rings show a compact whole-number figure
                              value: formatCurrency(
                                  moneySpent.roundToDouble(), currency),
                              goal:
                                  '/ ${formatCurrency(goals.dailyBudget.roundToDouble(), currency)}',
                              onTap: () => context
                                  .pushNamed(AppRoute.spendingDetail.name)),
                          const SizedBox(height: 10),
                          RingStat(
                              color: c.move,
                              label: 'Workout',
                              value: '${today.moveKcal}',
                              goal: '/ ${goals.dailyMoveKcal} kcal',
                              onTap: () =>
                                  context.pushNamed(AppRoute.moveDetail.name)),
                          const SizedBox(height: 10),
                          RingStat(
                              color: c.rituals,
                              label: 'Routines',
                              value: '$ritualsDone',
                              goal: '/ $ritualsTarget',
                              onTap: () => context
                                  .pushNamed(AppRoute.ritualsDetail.name)),
                        ],
                      ),
                    ),
                  ],
                ),
                Container(
                  // height-sensitive hero rhythm (first 600px viewport) — keep literals.
                  margin: const EdgeInsets.only(top: 14),
                  padding: const EdgeInsets.only(top: 14),
                  decoration: BoxDecoration(
                      border: Border(
                          top: BorderSide(color: c.hair, width: 0.5))),
                  child: Text(
                      ritualsRemaining == 0
                          ? 'On pace · day closed'
                          : 'On pace · $closePrompt',
                      style: AppType.caption.copyWith(
                          fontWeight: FontWeight.w500,
                          color: c.ink2,
                          letterSpacing: -0.08)),
                ),
              ],
            ),
          ),
        ),

        // Pal insight hero (static copy until U16 wires the real Pal note).
        Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.xl),
          child: PressScale(
            semanticLabel: 'Pal noticed',
            onTap: () => context.pushNamed(AppRoute.palComposer.name),
            child: Container(
              padding: const EdgeInsets.all(Spacing.lg),
              decoration: BoxDecoration(
                  color: c.surface, borderRadius: BorderRadius.circular(Radii.lg)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [c.accent, c.rituals],
                          ),
                        ),
                        alignment: Alignment.center,
                        child: AppIcon('sparkles',
                            size: 11, color: c.onAccent),
                      ),
                      const SizedBox(width: Spacing.sm),
                      Expanded(
                        child: Text('PAL NOTICED',
                            style: AppType.caption.copyWith(
                                fontWeight: FontWeight.w700,
                                color: c.ink3,
                                letterSpacing: 0.3)),
                      ),
                      AppIcon('chevron.right', size: 13, color: c.ink4),
                    ],
                  ),
                  const SizedBox(height: Spacing.md),
                  Text(
                    insightAsync.isLoading
                        ? 'Pal is reading your week…'
                        : (hasInsight ? headline : _palEmptyCopy),
                    style: AppType.body.copyWith(
                        color: hasInsight ? c.ink : c.ink3,
                        height: 1.38),
                  ),
                  // Reply chips only make sense when there's a real observation
                  // to ask Pal about; hidden in the loading/empty states.
                  if (hasInsight) ...[
                    const SizedBox(height: Spacing.md),
                    Wrap(
                      spacing: Spacing.sm,
                      runSpacing: Spacing.sm,
                      children: [
                        for (final label in const [
                          'Why?',
                          'Show me the days',
                          'How to keep it up'
                        ])
                          _PalReplyChip(label: label),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),

        // Timeline header.
        Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.xl, 0, Spacing.xl, Spacing.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Timeline',
                  style: AppType.title2
                      .copyWith(color: c.ink, letterSpacing: 0.35)),
              SizedBox(
                width: 124,
                child: Segmented<TimelineMode>(
                  options: const [
                    (TimelineMode.day, 'Day'),
                    (TimelineMode.week, 'Week'),
                  ],
                  value: today.mode,
                  onChanged: (m) =>
                      ref.read(timelineModeControllerProvider.notifier).set(m),
                ),
              ),
            ],
          ),
        ),

        if (!today.buckets.any((b) => b.entries.isNotEmpty))
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Spacing.lg, Spacing.sm, Spacing.lg, Spacing.sm),
            child: Center(
              child: Text('Nothing logged yet. Tap + to start your day.',
                  textAlign: TextAlign.center,
                  style: AppType.subhead
                      .copyWith(color: c.ink3, letterSpacing: -0.24)),
            ),
          ),

        for (final b in today.buckets)
          if (b.entries.isNotEmpty)
            _TimelineBucket(label: b.label, rows: b.entries),

        // Close-out prompt.
        Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, 0),
          child: PressScale(
            semanticLabel: 'Close out your day',
            onTap: () => context.pushNamed(AppRoute.eveningCloseOut.name),
            child: DottedBorderBox(
              color: c.rituals.withValues(alpha: 0.33),
              strokeWidth: 0.5,
              radius: Radii.card,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.lg, vertical: Spacing.lg),
                decoration: BoxDecoration(
                  color: c.ritualsTint,
                  borderRadius: BorderRadius.circular(Radii.card),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                          color: c.rituals,
                          borderRadius: BorderRadius.circular(Radii.sm)),
                      alignment: Alignment.center,
                      child: AppIcon('sparkles', size: 15, color: c.onAccent),
                    ),
                    const SizedBox(width: Spacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Close out your day',
                              style: AppType.subhead.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: c.ink,
                                  letterSpacing: -0.24)),
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Text('$closePrompt · 30 min before sleep',
                                style: AppType.caption.copyWith(
                                    color: c.ink3, letterSpacing: -0.08)),
                          ),
                        ],
                      ),
                    ),
                    AppIcon('chevron.right', size: 13, color: c.ink4),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _monthAbbrev() {
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return m[DateTime.now().month - 1];
  }
}

/// Opens the timeline search sheet over [entries] — the entries the Today
/// screen already has in hand (today's, or the whole week in week mode). A
/// client-side filter over titles / details / categories; no new backend.
void _openSearch(BuildContext context, List<Entry> entries) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0x00000000),
    builder: (context) => _SearchSheet(entries: entries),
  );
}

/// A modal search surface over the supplied [entries]. Lives here (not a route)
/// so the search is self-contained and matches the screen's existing data —
/// it filters the same entries the timeline shows, in week mode the full week.
class _SearchSheet extends StatefulWidget {
  const _SearchSheet({required this.entries});
  final List<Entry> entries;

  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Entry> get _results {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.entries;
    return widget.entries.where((e) {
      return e.title.toLowerCase().contains(q) ||
          (e.detail?.toLowerCase().contains(q) ?? false) ||
          (e.category?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final results = _results;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: c.bg,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                    color: c.hair, borderRadius: BorderRadius.circular(3)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: c.fill,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            AppIcon('magnifyingglass', size: 16, color: c.ink3),
                            const SizedBox(width: 6),
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                autofocus: true,
                                onChanged: (v) => setState(() => _query = v),
                                cursorColor: c.accent,
                                style: AppFonts.sf(
                                    size: 17, color: c.ink, letterSpacing: -0.43),
                                decoration: InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                  hintText: 'Search your timeline',
                                  hintStyle: AppFonts.sf(
                                      size: 17,
                                      color: c.ink3,
                                      letterSpacing: -0.43),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    NavAction(
                      label: 'Done',
                      onTap: () => Navigator.of(context).pop(),
                      semanticLabel: 'Close search',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: results.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                              _query.trim().isEmpty
                                  ? 'Nothing logged yet.'
                                  : 'No matches.',
                              textAlign: TextAlign.center,
                              style: AppFonts.sf(
                                  size: 15,
                                  color: c.ink3,
                                  letterSpacing: -0.24)),
                        ),
                      )
                    : ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        children: [
                          Container(
                            decoration: BoxDecoration(
                                color: c.surface,
                                borderRadius: BorderRadius.circular(14)),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              children: [
                                for (var i = 0; i < results.length; i++)
                                  _TimelineRow(
                                      entry: results[i],
                                      last: i == results.length - 1),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineBucket extends StatelessWidget {
  const _TimelineBucket({required this.label, required this.rows});
  final String label;
  final List<Entry> rows;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Spacing.xl, Spacing.sm, Spacing.xl, Spacing.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label.toUpperCase(),
                    style: AppType.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: c.ink3,
                        letterSpacing: 0.3)),
                Text('${rows.length} ${rows.length == 1 ? 'entry' : 'entries'}',
                    style: AppType.caption.copyWith(
                        fontWeight: FontWeight.w500,
                        color: c.ink4,
                        letterSpacing: 0.3)),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: Spacing.lg),
            decoration: BoxDecoration(
                color: c.surface, borderRadius: BorderRadius.circular(Radii.card)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++)
                  _TimelineRow(entry: rows[i], last: i == rows.length - 1),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineRow extends ConsumerWidget {
  const _TimelineRow({required this.entry, required this.last});
  final Entry entry;
  final bool last;

  /// Wires a row to an existing detail route, or null for types/entries with no
  /// destination yet. money → spending detail; move w/ workoutId → workout
  /// detail; rituals (and move without a workout) have no detail route today.
  void _open(BuildContext context) {
    switch (entry.type) {
      case EntryType.money:
        context.pushNamed(AppRoute.spendingDetail.name);
      case EntryType.move:
        final id = entry.workoutId;
        if (id != null) {
          context.pushNamed(AppRoute.workoutDetail.name,
              pathParameters: {'id': id});
        }
      case EntryType.rituals:
        break;
    }
  }

  bool get _tappable =>
      entry.type == EntryType.money ||
      (entry.type == EntryType.move && entry.workoutId != null);

  /// SF Symbol for the row icon, derived from entry type/category.
  String get _icon {
    switch (entry.type) {
      case EntryType.money:
        final cat = entry.category?.toLowerCase() ?? '';
        if (cat.contains('coffee')) return 'cup.and.saucer.fill';
        if (cat.contains('dining')) return 'fork.knife';
        if (cat.contains('grocer')) return 'basket.fill';
        return 'creditcard.fill';
      case EntryType.move:
        if (entry.workoutId != null) return 'dumbbell.fill';
        return 'figure.run';
      case EntryType.rituals:
        return 'sparkles';
    }
  }

  String? _valueText(Currency currency) {
    switch (entry.type) {
      case EntryType.money:
        final v = entry.amount;
        if (v == null) return null;
        // keep cents for USD-style currencies; VND drops them via decimals: 0
        return formatCurrency(v, currency, withSign: true, trimZeroCents: false);
      case EntryType.move:
        // design shows duration in minutes, not calories (no healthkit content)
        if (entry.duration != null) return '${entry.duration} min';
        return null;
      case EntryType.rituals:
        return null;
    }
  }

  String get _time {
    final t = entry.timestamp;
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final currency = ref.watch(appSettingsControllerProvider).currency;
    final value = _valueText(currency);
    final row = Container(
      decoration: BoxDecoration(
        border:
            last ? null : Border(bottom: BorderSide(color: c.hair, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg, vertical: Spacing.md),
      child: Row(
        children: [
          SizedBox(
            width: 38,
            child: Text(_time,
                style: AppType.caption.copyWith(
                    fontWeight: FontWeight.w500,
                    color: c.ink3,
                    letterSpacing: -0.08,
                    fontFeatures: const [FontFeature.tabularFigures()])),
          ),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
                color: c.forType(entry.type.wire),
                borderRadius: BorderRadius.circular(Radii.sm)),
            alignment: Alignment.center,
            child: AppIcon(_icon, size: 15, color: c.onAccent),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.subhead.copyWith(
                        fontWeight: FontWeight.w500,
                        color: c.ink,
                        letterSpacing: -0.24)),
                if (entry.detail != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(entry.detail!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.caption
                            .copyWith(color: c.ink3, letterSpacing: -0.08)),
                  ),
              ],
            ),
          ),
          if (value != null)
            Padding(
              padding: const EdgeInsets.only(left: Spacing.sm),
              child: Text(value,
                  style: AppType.footnote.copyWith(
                      fontWeight: FontWeight.w600,
                      color: entry.type == EntryType.money ? c.ink : c.ink3,
                      letterSpacing: -0.15,
                      fontFeatures: const [FontFeature.tabularFigures()])),
            ),
        ],
      ),
    );
    if (!_tappable) return row;
    return PressScale(
      semanticLabel: entry.title,
      onTap: () => _open(context),
      child: row,
    );
  }
}

/// Quick-reply chip under the Pal-insight card; tapping seeds the Pal composer.
class _PalReplyChip extends StatelessWidget {
  const _PalReplyChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PressScale(
      semanticLabel: label,
      onTap: () => context.pushNamed(AppRoute.palComposer.name,
          queryParameters: {'seed': label}),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md, vertical: Spacing.sm),
        decoration: BoxDecoration(
          color: c.surface2,
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(color: c.hair, width: 0.5),
        ),
        child: Text(label,
            style: AppType.footnote.copyWith(
                fontWeight: FontWeight.w500,
                color: c.ink2,
                letterSpacing: -0.08)),
      ),
    );
  }
}

