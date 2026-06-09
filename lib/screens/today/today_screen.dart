import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/today_controller.dart';
import '../../models/models.dart';
import '../../router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/activity_rings.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/controls.dart';
import '../../widgets/nav_bar.dart';
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
          child: Text("Couldn't load today.\n$e",
              textAlign: TextAlign.center,
              style: AppFonts.sf(size: 15, color: c.ink3, letterSpacing: -0.24)),
        ),
      ),
      data: (today) => _TodayBody(today: today),
    );
  }
}

class _TodayBody extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final goals = today.goals;
    final moneySpent = today.moneySpent;
    final ritualsDone = today.ritualsDone;
    final ritualsRemaining = today.ritualsRemaining;
    final closePrompt = ritualsRemaining == 0
        ? 'All rituals done · nice close'
        : '$ritualsRemaining ritual${ritualsRemaining == 1 ? '' : 's'} to close';

    return ListView(
      padding: const EdgeInsets.only(bottom: 110),
      children: [
        LargeTitleNavBar(
          title: 'Today',
          subtitle: _dateSubtitle,
          leading: Text(_monthAbbrev(),
              style: AppFonts.sf(size: 17, color: c.accent)),
          trailing: Row(children: const [
            NavIconButton(name: 'bell.fill'),
            SizedBox(width: 8),
            NavIconButton(name: 'magnifyingglass'),
          ]),
        ),

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
                              label: 'Move',
                              value: '${today.moveMinutes}',
                              goal: '/ ${goals.dailyMoveMinutes} MIN'),
                          const SizedBox(height: 10),
                          RingStat(
                              color: c.rituals,
                              label: 'Rituals',
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
                          Text('DAY',
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
                      context.goNamed(AppRoute.spendingDetail.name),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SummaryTile(
                  type: 'move',
                  icon: 'figure.run',
                  label: 'Move',
                  big: '${today.moveMinutes}',
                  unit: 'MIN',
                  sub: 'of ${goals.dailyMoveMinutes} min goal',
                  onTap: () => context.goNamed(AppRoute.moveDetail.name),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SummaryTile(
                  type: 'rituals',
                  icon: 'sparkles',
                  label: 'Rituals',
                  big: '$ritualsDone',
                  unit: '/ ${goals.dailyRitualTarget}',
                  sub: closePrompt,
                  onTap: () => context.goNamed(AppRoute.ritualsDetail.name),
                ),
              ),
            ],
          ),
          ),
        ),

        // Pal insight hero (static copy until U16 wires the real Pal note).
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
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
                    Text('PAL NOTICED',
                        style: AppFonts.sf(
                            size: 12,
                            weight: FontWeight.w700,
                            color: c.ink3,
                            letterSpacing: 0.3)),
                    const Spacer(),
                    AppIcon('chevron.right', size: 13, color: c.ink4),
                  ],
                ),
                const SizedBox(height: 10),
                Text.rich(
                  TextSpan(
                    style: AppFonts.sf(
                        size: 17,
                        color: c.ink,
                        letterSpacing: -0.43,
                        height: 1.38),
                    children: [
                      const TextSpan(text: "You've moved "),
                      TextSpan(
                          text: '11 days in a row',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const TextSpan(
                          text:
                              '. On days you finish morning rituals, you spend '),
                      TextSpan(
                          text: '32% less',
                          style: TextStyle(
                              color: c.money, fontWeight: FontWeight.w600)),
                      const TextSpan(text: ' on food.'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final q in const [
                      'Why?',
                      'Show me the days',
                      'How to keep it up'
                    ])
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                            color: c.fill,
                            borderRadius: BorderRadius.circular(100)),
                        child: Text(q,
                            style: AppFonts.sf(
                                size: 12,
                                weight: FontWeight.w500,
                                color: c.ink2,
                                letterSpacing: -0.08)),
                      ),
                  ],
                ),
              ],
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
              Text('Week',
                  style:
                      AppFonts.sf(size: 15, color: c.accent, letterSpacing: -0.24)),
            ],
          ),
        ),

        for (final b in today.buckets)
          if (b.entries.isNotEmpty)
            _TimelineBucket(label: b.label, rows: b.entries),

        // Close-out prompt.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: c.ritualsTint,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: c.rituals.withValues(alpha: 0.33), width: 0.5),
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
                                size: 12, color: c.ink3, letterSpacing: -0.08)),
                      ),
                    ],
                  ),
                ),
                AppIcon('chevron.right', size: 13, color: c.ink4),
              ],
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
        if (entry.calories != null) return '${entry.calories} kcal';
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
    return Container(
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
  }
}
