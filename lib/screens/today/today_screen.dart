import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/insights_controller.dart';
import '../../controllers/today_controller.dart';
import '../../models/models.dart';
import '../../services/pal/pal_service.dart' show InsightRange;
import '../../router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/activity_rings.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/controls.dart';
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
        child: Text('…',
            style: AppFonts.sf(size: 17, color: c.ink3, letterSpacing: -0.43)),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text("Couldn't load today. Try again in a moment.",
              textAlign: TextAlign.center,
              style: AppFonts.sf(size: 15, color: c.ink3, letterSpacing: -0.24)),
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
    final insightAsync = ref.watch(insightsProvider(InsightRange.day));
    final headline = insightAsync.asData?.value?.headline;
    final hasInsight = headline != null && headline.isNotEmpty;
    final moneySpent = today.moneySpent;
    final ritualsDone = today.ritualsDone;
    final ritualsRemaining = today.ritualsRemaining;
    final closePrompt = ritualsRemaining == 0
        ? 'All routines done · nice close'
        : '$ritualsRemaining routine${ritualsRemaining == 1 ? '' : 's'} to close';

    return LargeTitleScrollView(
      title: 'Today',
      subtitle: _dateSubtitle,
      leading: Text(_monthAbbrev(),
          style: AppFonts.sf(size: 17, color: c.accent)),
      trailing: Row(children: [
        NavIconButton(
          name: 'bell.fill',
          semanticLabel: 'Notifications',
          onTap: () => context.pushNamed(AppRoute.palInbox.name),
        ),
        const SizedBox(width: 8),
        const NavIconButton(
          name: 'magnifyingglass',
          semanticLabel: 'Search',
        ),
      ]),
      padding: const EdgeInsets.only(bottom: 110),
      children: [
        // Activity rings hero.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: BoxDecoration(
                color: c.surface, borderRadius: BorderRadius.circular(18)),
            child: Column(
              children: [
                Row(
                  children: [
                    ActivityRings(values: today.rings),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RingStat(
                              color: c.money,
                              label: 'Spent',
                              value: '\$${moneySpent.toStringAsFixed(0)}',
                              goal: '/ \$${goals.dailyBudget.toStringAsFixed(0)}'),
                          const SizedBox(height: 10),
                          RingStat(
                              color: c.move,
                              label: 'Workout',
                              value: '${today.moveMinutes}',
                              goal: '/ ${goals.dailyMoveMinutes} MIN'),
                          const SizedBox(height: 10),
                          RingStat(
                              color: c.rituals,
                              label: 'Routines',
                              value: '$ritualsDone',
                              goal: '/ ${goals.dailyRitualTarget}'),
                        ],
                      ),
                    ),
                  ],
                ),
                Container(
                  margin: const EdgeInsets.only(top: 14),
                  padding: const EdgeInsets.only(top: 14),
                  decoration: BoxDecoration(
                      border: Border(
                          top: BorderSide(color: c.hair, width: 0.5))),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('DAY · 21:30',
                              style: AppFonts.sf(
                                  size: 12,
                                  weight: FontWeight.w600,
                                  color: c.ink3,
                                  letterSpacing: 0.3)),
                          Text(
                              ritualsRemaining == 0
                                  ? 'On pace · day closed'
                                  : 'On pace · $closePrompt',
                              style: AppFonts.sf(
                                  size: 12,
                                  weight: FontWeight.w500,
                                  color: c.ink2,
                                  letterSpacing: -0.08)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ProgressBar(
                        value: _dayProgress,
                        gradient:
                            LinearGradient(colors: [c.money, c.move, c.rituals]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // 3-up summary tile row (money / move / rituals).
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: SizedBox(
            height: 132,
            child: Row(
            children: [
              Expanded(
                child: SummaryTile(
                  type: 'money',
                  icon: 'dollarsign.circle.fill',
                  label: 'Spent',
                  big: '\$${moneySpent.toStringAsFixed(0)}',
                  sub: 'of \$${goals.dailyBudget.toStringAsFixed(0)} budget',
                  onTap: () =>
                      context.pushNamed(AppRoute.spendingDetail.name),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SummaryTile(
                  type: 'move',
                  icon: 'figure.run',
                  label: 'Workout',
                  big: '${today.moveMinutes}',
                  unit: 'MIN',
                  sub: 'of ${goals.dailyMoveMinutes} min goal',
                  onTap: () => context.pushNamed(AppRoute.moveDetail.name),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SummaryTile(
                  type: 'rituals',
                  icon: 'sparkles',
                  label: 'Routines',
                  big: '$ritualsDone',
                  unit: '/ ${goals.dailyRitualTarget}',
                  sub: closePrompt,
                  onTap: () => context.pushNamed(AppRoute.ritualsDetail.name),
                ),
              ),
            ],
          ),
          ),
        ),

        // Pal insight hero (static copy until U16 wires the real Pal note).
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: PressScale(
            semanticLabel: 'Pal noticed',
            onTap: () => context.pushNamed(AppRoute.palComposer.name),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: c.surface, borderRadius: BorderRadius.circular(18)),
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
                        child: const AppIcon('sparkles',
                            size: 11, color: Color(0xFFFFFFFF)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('PAL NOTICED',
                            style: AppFonts.sf(
                                size: 12,
                                weight: FontWeight.w700,
                                color: c.ink3,
                                letterSpacing: 0.3)),
                      ),
                      AppIcon('chevron.right', size: 13, color: c.ink4),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    insightAsync.isLoading
                        ? 'Pal is reading your week…'
                        : (hasInsight ? headline : _palEmptyCopy),
                    style: AppFonts.sf(
                        size: 17,
                        color: hasInsight ? c.ink : c.ink3,
                        letterSpacing: -0.43,
                        height: 1.38),
                  ),
                  // Reply chips only make sense when there's a real observation
                  // to ask Pal about; hidden in the loading/empty states.
                  if (hasInsight) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
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
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Timeline',
                  style: AppFonts.sf(
                      size: 22,
                      weight: FontWeight.w700,
                      color: c.ink,
                      letterSpacing: 0.35)),
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Center(
              child: Text('Nothing logged yet. Tap + to start your day.',
                  textAlign: TextAlign.center,
                  style:
                      AppFonts.sf(size: 15, color: c.ink3, letterSpacing: -0.24)),
            ),
          ),

        for (final b in today.buckets)
          if (b.entries.isNotEmpty)
            _TimelineBucket(label: b.label, rows: b.entries),

        // Close-out prompt.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: PressScale(
            semanticLabel: 'Close out your day',
            onTap: () => context.pushNamed(AppRoute.eveningCloseOut.name),
            child: _DashedBorderBox(
              color: c.rituals.withValues(alpha: 0.33),
              radius: 14,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: c.ritualsTint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                          color: c.rituals,
                          borderRadius: BorderRadius.circular(9)),
                      alignment: Alignment.center,
                      child: const AppIcon('sparkles',
                          size: 15, color: Color(0xFFFFFFFF)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Close out your day',
                              style: AppFonts.sf(
                                  size: 15,
                                  weight: FontWeight.w600,
                                  color: c.ink,
                                  letterSpacing: -0.24)),
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Text('$closePrompt · 30 min before sleep',
                                style: AppFonts.sf(
                                    size: 12,
                                    color: c.ink3,
                                    letterSpacing: -0.08)),
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

  static const _dayProgress = 0.88;

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

class _TimelineBucket extends StatelessWidget {
  const _TimelineBucket({required this.label, required this.rows});
  final String label;
  final List<Entry> rows;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label.toUpperCase(),
                    style: AppFonts.sf(
                        size: 12,
                        weight: FontWeight.w600,
                        color: c.ink3,
                        letterSpacing: 0.3)),
                Text('${rows.length} ${rows.length == 1 ? 'entry' : 'entries'}',
                    style: AppFonts.sf(
                        size: 12,
                        weight: FontWeight.w500,
                        color: c.ink4,
                        letterSpacing: 0.3)),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
                color: c.surface, borderRadius: BorderRadius.circular(14)),
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

class _TimelineRow extends StatelessWidget {
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

  String? get _valueText {
    switch (entry.type) {
      case EntryType.money:
        final v = entry.amount;
        if (v == null) return null;
        return v < 0
            ? '−\$${v.abs().toStringAsFixed(2)}'
            : '\$${v.toStringAsFixed(2)}';
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
  Widget build(BuildContext context) {
    final c = context.colors;
    final value = _valueText;
    final row = Container(
      decoration: BoxDecoration(
        border:
            last ? null : Border(bottom: BorderSide(color: c.hair, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          SizedBox(
            width: 38,
            child: Text(_time,
                style: AppFonts.sf(
                    size: 12,
                    weight: FontWeight.w500,
                    color: c.ink3,
                    letterSpacing: -0.08,
                    tabular: true)),
          ),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
                color: c.forType(entry.type.wire),
                borderRadius: BorderRadius.circular(9)),
            alignment: Alignment.center,
            child: AppIcon(_icon, size: 15, color: const Color(0xFFFFFFFF)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.sf(
                        size: 15,
                        weight: FontWeight.w500,
                        color: c.ink,
                        letterSpacing: -0.24)),
                if (entry.detail != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(entry.detail!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.sf(
                            size: 12, color: c.ink3, letterSpacing: -0.08)),
                  ),
              ],
            ),
          ),
          if (value != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(value,
                  style: AppFonts.sf(
                      size: 14,
                      weight: FontWeight.w600,
                      color: entry.type == EntryType.money ? c.ink : c.ink3,
                      letterSpacing: -0.15,
                      tabular: true)),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: c.surface2,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: c.hair, width: 0.5),
        ),
        child: Text(label,
            style: AppFonts.sf(
                size: 13,
                weight: FontWeight.w500,
                color: c.ink2,
                letterSpacing: -0.08)),
      ),
    );
  }
}

/// Rounded box with a dashed border, painted via [CustomPaint] (Flutter has no
/// built-in dashed border). Local equivalent of rituals' DottedBorderBox.
class _DashedBorderBox extends StatelessWidget {
  const _DashedBorderBox({
    required this.child,
    required this.color,
    this.radius = 12,
  });

  final Widget child;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(color: color, radius: radius),
      child: child,
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);

    const dash = 5.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dash),
          paint,
        );
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
