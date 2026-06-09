import 'package:flutter/widgets.dart';
import '../data/mock_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/activity_rings.dart';
import '../widgets/app_icon.dart';
import '../widgets/controls.dart';
import '../widgets/nav_bar.dart';
import '../widgets/summary_tile.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  static const _moneyBudget = 85.0;
  static const _moveMinutes = 66;
  static const _moveGoal = 60;
  static const _ritualsGoal = 5;
  static const _dayProgress = 0.88;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final moneySpent = todayEntries
        .where((e) => e.type == 'money')
        .fold<double>(0, (s, e) => s + (e.value as num).abs());
    final ritualsDone = todayEntries.where((e) => e.type == 'rituals').length;

    final buckets = <(String, List<Entry>)>[
      ('Morning', todayEntries.where((e) => e.hour < 12).toList()),
      ('Afternoon', todayEntries.where((e) => e.hour >= 12 && e.hour < 18).toList()),
      ('Evening', todayEntries.where((e) => e.hour >= 18).toList()),
    ];

    return ListView(
      padding: const EdgeInsets.only(bottom: 110),
      children: [
        LargeTitleNavBar(
          title: 'Today',
          subtitle: 'Thursday, April 23',
          leading: Text('Apr', style: AppFonts.sf(size: 17, color: c.accent)),
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
            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(18)),
            child: Column(
              children: [
                Row(
                  children: [
                    ActivityRings(values: [
                      moneySpent / _moneyBudget,
                      _moveMinutes / _moveGoal,
                      ritualsDone / _ritualsGoal,
                    ]),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RingStat(color: c.money, label: 'Spent', value: '\$${moneySpent.toStringAsFixed(0)}', goal: '/ \$85'),
                          const SizedBox(height: 10),
                          RingStat(color: c.move, label: 'Move', value: '$_moveMinutes', goal: '/ $_moveGoal MIN'),
                          const SizedBox(height: 10),
                          RingStat(color: c.rituals, label: 'Rituals', value: '$ritualsDone', goal: '/ $_ritualsGoal'),
                        ],
                      ),
                    ),
                  ],
                ),
                Container(
                  margin: const EdgeInsets.only(top: 14),
                  padding: const EdgeInsets.only(top: 14),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: c.hair, width: 0.5))),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('DAY · 21:30',
                              style: AppFonts.sf(size: 12, weight: FontWeight.w600, color: c.ink3, letterSpacing: 0.3)),
                          Text('On pace · 1 ritual to close',
                              style: AppFonts.sf(size: 12, weight: FontWeight.w500, color: c.ink2, letterSpacing: -0.08)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ProgressBar(
                        value: _dayProgress,
                        gradient: LinearGradient(colors: [c.money, c.move, c.rituals]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Pal insight hero.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(18)),
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
                      child: const AppIcon('sparkles', size: 11, color: Color(0xFFFFFFFF)),
                    ),
                    const SizedBox(width: 8),
                    Text('PAL NOTICED',
                        style: AppFonts.sf(size: 12, weight: FontWeight.w700, color: c.ink3, letterSpacing: 0.3)),
                    const Spacer(),
                    AppIcon('chevron.right', size: 13, color: c.ink4),
                  ],
                ),
                const SizedBox(height: 10),
                Text.rich(
                  TextSpan(
                    style: AppFonts.sf(size: 17, color: c.ink, letterSpacing: -0.43, height: 1.38),
                    children: [
                      const TextSpan(text: "You've moved "),
                      TextSpan(text: '11 days in a row', style: const TextStyle(fontWeight: FontWeight.w700)),
                      const TextSpan(text: '. On days you finish morning rituals, you spend '),
                      TextSpan(text: '32% less', style: TextStyle(color: c.money, fontWeight: FontWeight.w600)),
                      const TextSpan(text: ' on food.'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final q in const ['Why?', 'Show me the days', 'How to keep it up'])
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: c.fill, borderRadius: BorderRadius.circular(100)),
                        child: Text(q,
                            style: AppFonts.sf(size: 12, weight: FontWeight.w500, color: c.ink2, letterSpacing: -0.08)),
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
              Text('Timeline', style: AppFonts.sf(size: 22, weight: FontWeight.w700, color: c.ink, letterSpacing: 0.35)),
              Text('Week', style: AppFonts.sf(size: 15, color: c.accent, letterSpacing: -0.24)),
            ],
          ),
        ),

        for (final (label, rows) in buckets)
          if (rows.isNotEmpty) _TimelineBucket(label: label, rows: rows),

        // Close-out prompt.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: c.ritualsTint,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.rituals.withValues(alpha: 0.33), width: 0.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(color: c.rituals, borderRadius: BorderRadius.circular(9)),
                  alignment: Alignment.center,
                  child: const AppIcon('sparkles', size: 15, color: Color(0xFFFFFFFF)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Close out your day',
                          style: AppFonts.sf(size: 15, weight: FontWeight.w600, color: c.ink, letterSpacing: -0.24)),
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text('1 ritual left · 30 min before sleep',
                            style: AppFonts.sf(size: 12, color: c.ink3, letterSpacing: -0.08)),
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
                    style: AppFonts.sf(size: 12, weight: FontWeight.w600, color: c.ink3, letterSpacing: 0.3)),
                Text('${rows.length} ${rows.length == 1 ? 'entry' : 'entries'}',
                    style: AppFonts.sf(size: 12, weight: FontWeight.w500, color: c.ink4, letterSpacing: 0.3)),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14)),
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

  String? get _valueText {
    final v = entry.value;
    if (v == null) return null;
    if (v is num) {
      return v < 0 ? '−\$${v.abs().toStringAsFixed(2)}' : '\$${v.toStringAsFixed(2)}';
    }
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final value = _valueText;
    return Container(
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: c.hair, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          SizedBox(
            width: 38,
            child: Text(entry.time,
                style: AppFonts.sf(size: 12, weight: FontWeight.w500, color: c.ink3, letterSpacing: -0.08, tabular: true)),
          ),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: c.forType(entry.type), borderRadius: BorderRadius.circular(9)),
            alignment: Alignment.center,
            child: AppIcon(entry.sf, size: 15, color: const Color(0xFFFFFFFF)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.sf(size: 15, weight: FontWeight.w500, color: c.ink, letterSpacing: -0.24)),
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(entry.detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.sf(size: 12, color: c.ink3, letterSpacing: -0.08)),
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
                      color: entry.type == 'money' ? c.ink : c.ink3,
                      letterSpacing: -0.15,
                      tabular: true)),
            ),
        ],
      ),
    );
  }
}
