import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/spending_controller.dart';
import '../../models/models.dart';
import '../../router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/controls.dart';

/// Screen 06 — the reusable tracker detail template.
///
/// Parametrized by [DetailTracker] (money now; Move/Rituals reuse it later via
/// the same widget + `detailDataProvider`). Renders: a hero card with the big
/// total + progress-vs-budget bar; a category breakdown (amount + bar each); a
/// recent-entries list grouped by day; and a bottom "Ask Pal about …" pill that
/// routes to the Ask Pal stub.
///
/// All math is in [DetailData]/[buildDetailData]; this widget only lays out.
class DetailScreen extends ConsumerWidget {
  const DetailScreen({super.key, this.tracker = DetailTracker.money});

  final DetailTracker tracker;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final async = ref.watch(detailDataProvider(tracker));

    return Scaffold(
      backgroundColor: c.bg,
      body: async.when(
        loading: () => const _Loading(),
        error: (e, _) => _Error(message: "Couldn't load ${tracker.title}.\n$e"),
        data: (data) => _DetailBody(data: data),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Text('…',
          style: AppFonts.sf(size: 17, color: c.ink3, letterSpacing: -0.43)),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message,
            textAlign: TextAlign.center,
            style: AppFonts.sf(size: 15, color: c.ink3, letterSpacing: -0.24)),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.data});
  final DetailData data;

  /// Formats a magnitude for display per tracker (money -> $, else integer +
  /// unit). Kept here since it is purely presentational.
  String _fmt(double v, {bool withSign = false}) {
    switch (data.tracker) {
      case DetailTracker.money:
        final s = '\$${v.abs().toStringAsFixed(v == v.roundToDouble() ? 0 : 2)}';
        return withSign && v > 0 ? '−$s' : s;
      case DetailTracker.move:
        return '${v.round()} min';
      case DetailTracker.rituals:
        return '${v.round()}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = c.forType(data.tracker.colorToken);

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            _NavBar(title: data.tracker.title, color: color),
            _HeroCard(data: data, color: color, fmt: _fmt),
            if (data.categories.isNotEmpty) ...[
              const _SectionHeader('By category'),
              _CategoryCard(data: data, color: color, fmt: _fmt),
            ],
            if (data.days.isNotEmpty) ...[
              const _SectionHeader('Recent'),
              for (final group in data.days)
                _DayGroupCard(group: group, data: data, fmt: _fmt),
            ],
            if (data.categories.isEmpty && data.days.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 40, 16, 0),
                child: Center(
                  child: Text('Nothing logged yet.',
                      style: AppFonts.sf(
                          size: 15, color: c.ink3, letterSpacing: -0.24)),
                ),
              ),
          ],
        ),
        // Bottom "Ask Pal about …" pill.
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: _AskPalPill(label: data.tracker.askPalPrompt),
        ),
      ],
    );
  }
}

/// Back nav + centered title + `+` trailing (matches handoff screen 06 chrome).
class _NavBar extends StatelessWidget {
  const _NavBar({required this.title, required this.color});
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      color: c.bg,
      padding: const EdgeInsets.fromLTRB(8, 52, 8, 8),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.pop(),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: AppIcon('chevron.left', size: 20, color: c.accent),
            ),
          ),
          Expanded(
            child: Text(title,
                textAlign: TextAlign.center,
                style: AppFonts.sf(
                    size: 17,
                    weight: FontWeight.w600,
                    color: c.ink,
                    letterSpacing: -0.43)),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.pushNamed(AppRoute.newEntry.name),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: AppIcon('plus', size: 20, color: c.accent),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hero card: big total numeral + budget caption + progress bar.
class _HeroCard extends StatelessWidget {
  const _HeroCard(
      {required this.data, required this.color, required this.fmt});
  final DetailData data;
  final Color color;
  final String Function(double, {bool withSign}) fmt;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final over = data.target > 0 && data.total > data.target;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        decoration: BoxDecoration(
            color: c.surface, borderRadius: BorderRadius.circular(18)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('TOTAL',
                style: AppFonts.sf(
                    size: 12,
                    weight: FontWeight.w700,
                    color: c.ink3,
                    letterSpacing: 0.3)),
            const SizedBox(height: 6),
            Text(fmt(data.total),
                style: AppFonts.sfr(
                    size: 40, weight: FontWeight.w700, color: c.ink)),
            const SizedBox(height: 14),
            ProgressBar(value: data.progress, color: over ? c.red : color),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('of ${fmt(data.target)} budget',
                    style: AppFonts.sf(
                        size: 13, color: c.ink3, letterSpacing: -0.08)),
                Text(
                    over
                        ? '${fmt(data.total - data.target)} over'
                        : '${fmt(data.remaining)} left',
                    style: AppFonts.sf(
                        size: 13,
                        weight: FontWeight.w600,
                        color: over ? c.red : color,
                        letterSpacing: -0.08)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Text(label.toUpperCase(),
          style: AppFonts.sf(
              size: 12,
              weight: FontWeight.w600,
              color: c.ink3,
              letterSpacing: 0.3)),
    );
  }
}

/// Category breakdown rows: label + amount + share bar each.
class _CategoryCard extends StatelessWidget {
  const _CategoryCard(
      {required this.data, required this.color, required this.fmt});
  final DetailData data;
  final Color color;
  final String Function(double, {bool withSign}) fmt;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      decoration: BoxDecoration(
          color: c.surface, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          for (var i = 0; i < data.categories.length; i++)
            Padding(
              padding: EdgeInsets.only(
                  top: i == 0 ? 12 : 10,
                  bottom: i == data.categories.length - 1 ? 12 : 10),
              child: _CategoryRow(
                  row: data.categories[i], color: color, fmt: fmt),
            ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow(
      {required this.row, required this.color, required this.fmt});
  final CategoryBreakdown row;
  final Color color;
  final String Function(double, {bool withSign}) fmt;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(row.label,
                style: AppFonts.sf(
                    size: 15,
                    weight: FontWeight.w500,
                    color: c.ink,
                    letterSpacing: -0.24)),
            Text(fmt(row.amount),
                style: AppFonts.sf(
                    size: 15,
                    weight: FontWeight.w600,
                    color: c.ink,
                    letterSpacing: -0.24,
                    tabular: true)),
          ],
        ),
        const SizedBox(height: 6),
        ProgressBar(value: row.fraction, color: color),
      ],
    );
  }
}

/// One day's group of entries (day header + rows).
class _DayGroupCard extends StatelessWidget {
  const _DayGroupCard(
      {required this.group, required this.data, required this.fmt});
  final DayGroup group;
  final DetailData data;
  final String Function(double, {bool withSign}) fmt;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec' //
  ];

  String get _dayLabel {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(group.day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${_months[group.day.month - 1]} ${group.day.day}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
            child: Text(_dayLabel.toUpperCase(),
                style: AppFonts.sf(
                    size: 12,
                    weight: FontWeight.w600,
                    color: c.ink3,
                    letterSpacing: 0.3)),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
                color: c.surface, borderRadius: BorderRadius.circular(14)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < group.entries.length; i++)
                  _EntryRow(
                    entry: group.entries[i],
                    data: data,
                    fmt: fmt,
                    last: i == group.entries.length - 1,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.data,
    required this.fmt,
    required this.last,
  });
  final Entry entry;
  final DetailData data;
  final String Function(double, {bool withSign}) fmt;
  final bool last;

  String get _time {
    final t = entry.timestamp;
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = c.forType(data.tracker.colorToken);
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
                color: color, borderRadius: BorderRadius.circular(9)),
            alignment: Alignment.center,
            child: const AppIcon('creditcard.fill',
                size: 15, color: Color(0xFFFFFFFF)),
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
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(fmt(data.tracker.magnitudeOf(entry), withSign: true),
                style: AppFonts.sf(
                    size: 14,
                    weight: FontWeight.w600,
                    color: c.ink,
                    letterSpacing: -0.15,
                    tabular: true)),
          ),
        ],
      ),
    );
  }
}

/// Bottom pill → Ask Pal stub (U16).
class _AskPalPill extends StatelessWidget {
  const _AskPalPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.pushNamed(AppRoute.askPal.name),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [c.accent, c.rituals],
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [
            BoxShadow(
                color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 6)),
          ],
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AppIcon('sparkles', size: 16, color: Color(0xFFFFFFFF)),
            const SizedBox(width: 8),
            Text(label,
                style: AppFonts.sf(
                    size: 16,
                    weight: FontWeight.w600,
                    color: const Color(0xFFFFFFFF),
                    letterSpacing: -0.31)),
          ],
        ),
      ),
    );
  }
}
