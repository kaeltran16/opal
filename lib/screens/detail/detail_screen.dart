import 'package:flutter/cupertino.dart' show showCupertinoDialog, CupertinoAlertDialog, CupertinoDialogAction;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/providers.dart';
import '../../controllers/spending_controller.dart';
import '../../models/models.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../util/format.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/controls.dart';
import '../../widgets/nav_bar.dart';

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
        error: (e, _) {
          debugPrint('detail load failed (${tracker.title}): $e');
          return _Error(message: "Couldn't load ${tracker.title}.");
        },
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
      child: Text('…', style: AppType.body.copyWith(color: c.ink3)),
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
        padding: const EdgeInsets.all(Spacing.xxl),
        child: Text(message,
            textAlign: TextAlign.center,
            style: AppType.subhead
                .copyWith(color: c.ink3, letterSpacing: -0.24)),
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.data});
  final DetailData data;

  /// Formats a magnitude for display per tracker (money via the user's
  /// [currency], else integer + unit). Purely presentational.
  String _fmt(double v, Currency currency, {bool withSign = false}) {
    switch (data.tracker) {
      case DetailTracker.money:
        return formatCurrency(v, currency, withSign: withSign && v > 0);
      case DetailTracker.move:
        return '${v.round()} kcal';
      case DetailTracker.rituals:
        return '${v.round()}';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final color = c.forType(data.tracker.colorToken);
    final currency = ref.watch(appSettingsControllerProvider).currency;
    String fmt(double v, {bool withSign = false}) =>
        _fmt(v, currency, withSign: withSign);
    Future<void> deleteEntry(Entry e) =>
        ref.read(entryRepositoryProvider).deleteById(e.id);

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.only(bottom: 96), // bottom-pill clearance; keep literal
          children: [
            _NavBar(title: data.tracker.title, color: color),
            _HeroCard(data: data, color: color, fmt: fmt),
            if (data.categories.isNotEmpty) ...[
              const _SectionHeader('Breakdown'),
              _CategoryCard(data: data, color: color, fmt: fmt),
            ],
            if (data.days.isNotEmpty) ...[
              _SectionHeader(data.tracker.recentHeader),
              for (final group in data.days)
                _DayGroupCard(
                    group: group, data: data, fmt: fmt, onDelete: deleteEntry),
            ],
            if (data.categories.isEmpty && data.days.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(Spacing.lg, 40, Spacing.lg, 0),
                child: Center(
                  child: Text('Nothing logged yet.',
                      style: AppType.subhead
                          .copyWith(color: c.ink3, letterSpacing: -0.24)),
                ),
              ),
          ],
        ),
        // Bottom "Ask Pal about …" pill.
        Positioned(
          left: Spacing.lg,
          right: Spacing.lg,
          bottom: Spacing.lg,
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
      padding: const EdgeInsets.fromLTRB(Spacing.sm, 52, Spacing.sm, Spacing.sm),
      child: Row(
        children: [
          NavAction(
            icon: 'chevron.left',
            onTap: () => context.pop(),
            semanticLabel: 'Back',
          ),
          Expanded(
            child: Text(title,
                textAlign: TextAlign.center,
                style: AppType.headline.copyWith(color: c.ink)),
          ),
          NavAction(
            icon: 'plus',
            onTap: () => context.pushNamed(AppRoute.newEntry.name),
            semanticLabel: 'Add entry',
          ),
        ],
      ),
    );
  }
}

/// Hero card: 56×56 icon tile + big total + colored sub-line + goal line, with
/// a conic-gradient percent ring on the right (handoff screen 06 hero).
class _HeroCard extends StatelessWidget {
  const _HeroCard(
      {required this.data, required this.color, required this.fmt});
  final DetailData data;
  final Color color;
  final String Function(double, {bool withSign}) fmt;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pct = data.progress.clamp(0.0, 1.0);
    final goalLine = data.tracker == DetailTracker.money
        ? 'of ${fmt(data.target)} daily budget'
        : 'of ${fmt(data.target)} daily goal';
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Spacing.lg, Spacing.sm, Spacing.lg, Spacing.xl),
      child: Container(
        padding: const EdgeInsets.all(Spacing.xl),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: color.withValues(alpha: 0.13), width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(Radii.card),
                // accent-tinted glow on the colored tile; keep inline
                boxShadow: [
                  BoxShadow(
                      color: color.withValues(alpha: 0.33),
                      blurRadius: 14,
                      offset: const Offset(0, 6)),
                ],
              ),
              alignment: Alignment.center,
              child: AppIcon(data.tracker.heroIcon, size: 28, color: c.onAccent),
            ),
            const SizedBox(width: Spacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fmt(data.total),
                      style: AppFonts.sfr(
                          size: 40, // no sfr token for 40; keep inline
                          weight: FontWeight.w700,
                          color: c.ink,
                          letterSpacing: -1,
                          height: 1)),
                  const SizedBox(height: Spacing.xs),
                  Text(data.tracker.heroSub,
                      style: AppType.subhead.copyWith(
                          fontWeight: FontWeight.w600,
                          color: color,
                          letterSpacing: -0.24)),
                  const SizedBox(height: Spacing.xxs),
                  Text(goalLine,
                      style: AppType.footnote
                          .copyWith(color: c.ink2, letterSpacing: -0.08)),
                ],
              ),
            ),
            const SizedBox(width: Spacing.md),
            _PercentRing(pct: pct, color: color),
          ],
        ),
      ),
    );
  }
}

/// 52×52 conic-gradient progress donut with a centered rounded-percent label.
class _PercentRing extends StatelessWidget {
  const _PercentRing({required this.pct, required this.color});
  final double pct; // 0..1
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: CustomPaint(
        painter: _RingPainter(pct: pct, color: color),
        child: Center(
          child: Text('${(pct * 100).round()}%',
              style: AppType.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: -0.08)),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.pct, required this.color});
  final double pct;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 6.0;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.width - stroke) / 2;
    final track = Paint()
      ..color = color.withValues(alpha: 0.13)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);
    // start at 12 o'clock, sweep clockwise
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -1.5708,
        6.2832 * pct, false, fill);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.pct != pct || old.color != color;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Spacing.xl, Spacing.md, Spacing.xl, Spacing.sm),
      child: Text(label.toUpperCase(),
          style: AppType.caption.copyWith(
              fontWeight: FontWeight.w600, color: c.ink3, letterSpacing: 0.3)),
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
      margin: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      padding: const EdgeInsets.fromLTRB(
          Spacing.lg, Spacing.xs, Spacing.lg, Spacing.xs),
      decoration: BoxDecoration(
          color: c.surface, borderRadius: BorderRadius.circular(Radii.card)),
      child: Column(
        children: [
          for (var i = 0; i < data.categories.length; i++)
            Padding(
              // first/last rows were 12, inner 10 — both snap to Spacing.md
              padding: const EdgeInsets.symmetric(vertical: Spacing.md),
              child: _CategoryRow(
                  row: data.categories[i],
                  color: color,
                  fmt: fmt,
                  fallbackIcon: data.tracker.heroIcon),
            ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow(
      {required this.row,
      required this.color,
      required this.fmt,
      required this.fallbackIcon});
  final CategoryBreakdown row;
  final Color color;
  final String Function(double, {bool withSign}) fmt;
  final String fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 29,
              height: 29,
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(Radii.sm)),
              alignment: Alignment.center,
              child: AppIcon(_categoryIcon(row.label, fallbackIcon),
                  size: 16, color: c.onAccent),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Text(row.label,
                  style: AppType.subhead.copyWith(
                      fontWeight: FontWeight.w500,
                      color: c.ink,
                      letterSpacing: -0.24)),
            ),
            Text(fmt(row.amount),
                style: AppType.subhead.copyWith(
                    fontWeight: FontWeight.w500,
                    color: c.ink,
                    letterSpacing: -0.24,
                    fontFeatures: const [FontFeature.tabularFigures()])),
          ],
        ),
        const SizedBox(height: Spacing.sm),
        Padding(
          // align bar under the label, past the icon tile (29 + 12)
          padding: const EdgeInsets.only(left: 41), // alignment offset; keep literal
          child: ProgressBar(value: row.fraction, color: color),
        ),
      ],
    );
  }
}

/// One day's group of entries (day header + rows).
class _DayGroupCard extends StatelessWidget {
  const _DayGroupCard(
      {required this.group,
      required this.data,
      required this.fmt,
      required this.onDelete});
  final DayGroup group;
  final DetailData data;
  final String Function(double, {bool withSign}) fmt;
  final Future<void> Function(Entry) onDelete;

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
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Spacing.xl, Spacing.xs, Spacing.xl, Spacing.sm),
            child: Text(_dayLabel.toUpperCase(),
                style: AppType.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: c.ink3,
                    letterSpacing: 0.3)),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: Spacing.lg),
            decoration: BoxDecoration(
                color: c.surface, borderRadius: BorderRadius.circular(Radii.card)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < group.entries.length; i++)
                  _EntryRow(
                    entry: group.entries[i],
                    data: data,
                    fmt: fmt,
                    onDelete: onDelete,
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

/// Best-effort SF symbol for a category label. The [Entry] model carries no
/// per-row symbol (design `e.sf`), so we map common category words to glyphs and
/// fall back to the tracker's hero icon for anything unmatched.
String _categoryIcon(String label, String fallback) {
  final l = label.toLowerCase();
  if (l.contains('coffee')) return 'cup.and.saucer.fill';
  if (l.contains('lunch') ||
      l.contains('dinner') ||
      l.contains('dining') ||
      l.contains('food') ||
      l.contains('meal')) {
    return 'fork.knife';
  }
  if (l.contains('grocer') || l.contains('snack')) return 'basket.fill';
  if (l.contains('transit') ||
      l.contains('transport') ||
      l.contains('car')) {
    return 'paperplane.fill';
  }
  if (l.contains('run')) return 'figure.run';
  if (l.contains('walk')) return 'figure.walk';
  if (l.contains('gym') || l.contains('lift') || l.contains('strength')) {
    return 'dumbbell.fill';
  }
  if (l.contains('journal') || l.contains('pages') || l.contains('write')) {
    return 'book.closed.fill';
  }
  if (l.contains('read')) return 'books.vertical.fill';
  if (l.contains('language')) return 'character.book.closed.fill';
  if (l.contains('meditate') || l.contains('focus')) return 'heart.fill';
  return fallback;
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.data,
    required this.fmt,
    required this.onDelete,
    required this.last,
  });
  final Entry entry;
  final DetailData data;
  final String Function(double, {bool withSign}) fmt;
  final Future<void> Function(Entry) onDelete;
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
    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context, c),
      onDismissed: (_) => onDelete(entry),
      background: Container(
        color: c.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: Spacing.lg),
        child: AppIcon('trash.fill', size: 20, color: c.onAccent),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          border: last
              ? null
              : Border(bottom: BorderSide(color: c.hair, width: 0.5)),
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
                color: color, borderRadius: BorderRadius.circular(Radii.sm)),
            alignment: Alignment.center,
            child: AppIcon(
                _categoryIcon(
                    entry.category ?? entry.title, data.tracker.heroIcon),
                size: 15,
                color: c.onAccent),
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
          Padding(
            padding: const EdgeInsets.only(left: Spacing.sm),
            child: Text(fmt(data.tracker.magnitudeOf(entry), withSign: true),
                style: AppType.subhead.copyWith(
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                    letterSpacing: -0.15,
                    fontFeatures: const [FontFeature.tabularFigures()])),
          ),
        ],
        ),
      ),
    );
  }

  /// iOS confirm dialog before a swipe actually deletes the entry. Returns true
  /// only when the user taps Delete.
  Future<bool> _confirmDelete(BuildContext context, AppColors c) async {
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

/// Bottom pill → Ask Pal stub (U16).
class _AskPalPill extends StatelessWidget {
  const _AskPalPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.pushNamed(AppRoute.palComposer.name),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [c.accent, c.rituals],
          ),
          borderRadius: BorderRadius.circular(Radii.xxl),
          boxShadow: Elevation.card(c.shadow),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIcon('sparkles', size: 16, color: c.onAccent),
            const SizedBox(width: Spacing.sm),
            Text(label,
                style: AppType.callout.copyWith(
                    fontWeight: FontWeight.w600,
                    color: c.onAccent,
                    letterSpacing: -0.31)),
          ],
        ),
      ),
    );
  }
}
