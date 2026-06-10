import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/pal_inbox_controller.dart';
import '../../models/models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/press_scale.dart';

/// Screen 25 — Pal Inbox. "A quiet inbox, not an anxious one": a timeline of the
/// passive observations Pal has made, filterable by tracker, with a "Mark all
/// read" affordance. Reads [PalInboxState] from [palInboxControllerProvider];
/// this widget only lays out.
class PalInboxScreen extends ConsumerWidget {
  const PalInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final async = ref.watch(palInboxControllerProvider);

    return async.when(
      loading: () => Container(
        color: c.bg,
        alignment: Alignment.center,
        child: Text('…',
            style: AppFonts.sf(size: 17, color: c.ink3, letterSpacing: -0.43)),
      ),
      error: (e, _) => Container(
        color: c.bg,
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text("Couldn't load your inbox. Try again in a moment.",
              textAlign: TextAlign.center,
              style: AppFonts.sf(size: 15, color: c.ink3, letterSpacing: -0.24)),
        ),
      ),
      data: (state) => _InboxBody(state: state),
    );
  }
}

class _InboxBody extends ConsumerWidget {
  const _InboxBody({required this.state});
  final PalInboxState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final controller = ref.read(palInboxControllerProvider.notifier);
    final unread = state.unreadCount;
    final visible = state.visible;

    return Container(
      color: c.bg,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 110),
        children: [
          // --- Nav: back to Today + Mark all read -----------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 56, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 4, 4, 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppIcon('chevron.left', size: 20, color: c.accent),
                        const SizedBox(width: 2),
                        Text('Today',
                            style: AppFonts.sf(
                                size: 17,
                                color: c.accent,
                                letterSpacing: -0.43)),
                      ],
                    ),
                  ),
                ),
                PressScale(
                  onTap: controller.markAllRead,
                  semanticLabel: 'Mark all read',
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text('Mark all read',
                        style: AppFonts.sf(
                            size: 15, color: c.accent, letterSpacing: -0.15)),
                  ),
                ),
              ],
            ),
          ),

          // --- Title: gradient sparkle avatar + "Pal noticed" + sub -----------
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [c.accent, c.rituals],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: c.accent.withValues(alpha: 0.33),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const AppIcon('sparkles',
                          size: 16, color: Color(0xFFFFFFFF)),
                    ),
                    const SizedBox(width: 10),
                    Text('Pal noticed',
                        style: AppFonts.sf(
                            size: 28,
                            weight: FontWeight.w700,
                            color: c.ink,
                            letterSpacing: -0.3,
                            height: 1)),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: unread > 0
                      ? Text.rich(
                          TextSpan(
                            style: AppFonts.sf(
                                size: 15, color: c.ink3, letterSpacing: -0.24),
                            children: [
                              TextSpan(
                                  text: '$unread new',
                                  style: TextStyle(
                                      color: c.ink,
                                      fontWeight: FontWeight.w700)),
                              const TextSpan(
                                  text:
                                      ' · a quiet inbox, not an anxious one'),
                            ],
                          ),
                        )
                      : Text('All caught up · a quiet inbox, not an anxious one',
                          style: AppFonts.sf(
                              size: 15, color: c.ink3, letterSpacing: -0.24)),
                ),
              ],
            ),
          ),

          // --- Filter chips ---------------------------------------------------
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _FilterChip(
                  label: 'All',
                  count: state.notes.length,
                  active: state.filter == InboxFilter.all,
                  onTap: () => controller.setFilter(InboxFilter.all),
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: 'Unread',
                  count: unread,
                  active: state.filter == InboxFilter.unread,
                  onTap: () => controller.setFilter(InboxFilter.unread),
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: 'Money',
                  dotColor: c.money,
                  active: state.filter == InboxFilter.money,
                  onTap: () => controller.setFilter(InboxFilter.money),
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: 'Move',
                  dotColor: c.move,
                  active: state.filter == InboxFilter.move,
                  onTap: () => controller.setFilter(InboxFilter.move),
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: 'Rituals',
                  dotColor: c.rituals,
                  active: state.filter == InboxFilter.rituals,
                  onTap: () => controller.setFilter(InboxFilter.rituals),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // --- Timeline -------------------------------------------------------
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 40, 20, 40),
              child: Text('Nothing here. A quiet Pal is a happy Pal.',
                  textAlign: TextAlign.center,
                  style:
                      AppFonts.sf(size: 14, color: c.ink3, letterSpacing: -0.15)),
            )
          else
            for (var i = 0; i < visible.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _NoteCard(note: visible[i]),
              ),
            ],

          // --- Footer: tune what Pal notices ----------------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Center(
              child: PressScale(
                semanticLabel: 'Tune what Pal notices',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIcon('gearshape.fill', size: 12, color: c.ink3),
                    const SizedBox(width: 6),
                    Text('Tune what Pal notices',
                        style: AppFonts.sf(
                            size: 13, color: c.ink3, letterSpacing: -0.08)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single filter pill. Active inverts to ink bg / bg text; inactive is a
/// surface chip with ink2 text. Category chips show a colored dot (when
/// inactive); count chips show a trailing count badge.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
    this.count,
    this.dotColor,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final int? count;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = active ? c.bg : c.ink2;
    return PressScale(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: active ? c.ink : c.surface,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
              color: active ? c.ink : c.hair, width: 0.5),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null && !active) ...[
              Container(
                width: 6,
                height: 6,
                decoration:
                    BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
            ],
            Text(label,
                style: AppFonts.sf(
                    size: 13,
                    weight: FontWeight.w500,
                    color: fg,
                    letterSpacing: -0.08)),
            if (count != null) ...[
              const SizedBox(width: 4),
              Text('$count',
                  style: AppFonts.sf(
                      size: 11,
                      weight: FontWeight.w600,
                      color: active
                          ? c.bg.withValues(alpha: 0.6)
                          : c.ink4)),
            ],
          ],
        ),
      ),
    );
  }
}

/// A note card: category-colored icon tile + meta row ("{KIND} · {when}") +
/// title + body + optional action pill. Unread notes get an accent left dot and
/// full opacity; read notes are slightly dimmed.
class _NoteCard extends ConsumerWidget {
  const _NoteCard({required this.note});
  final PalNote note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final catColor = c.forType(note.category.wire);
    final kindColor = c.forType(note.kind.dotColorKey);

    final card = Container(
      decoration: BoxDecoration(
          color: c.surface, borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // unread indicator
          if (note.unread)
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 16),
              child: Container(
                width: 6,
                height: 6,
                decoration:
                    BoxDecoration(color: c.accent, shape: BoxShape.circle),
              ),
            ),
          // category icon tile
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: catColor, borderRadius: BorderRadius.circular(11)),
            alignment: Alignment.center,
            child: AppIcon(note.icon, size: 16, color: const Color(0xFFFFFFFF)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // meta row
                Row(
                  children: [
                    Text(note.kind.label.toUpperCase(),
                        style: AppFonts.sf(
                            size: 11,
                            weight: FontWeight.w700,
                            color: kindColor,
                            letterSpacing: 0.3)),
                    const SizedBox(width: 8),
                    Container(
                      width: 3,
                      height: 3,
                      decoration:
                          BoxDecoration(color: c.ink4, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(_relativeTime(note.createdAt),
                        style: AppFonts.sf(
                            size: 11, color: c.ink3, letterSpacing: -0.08)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(note.title,
                    style: AppFonts.sf(
                        size: 15,
                        weight: FontWeight.w600,
                        color: c.ink,
                        letterSpacing: -0.24,
                        height: 1.3)),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(note.body,
                      style: AppFonts.sf(
                          size: 13,
                          color: c.ink2,
                          letterSpacing: -0.08,
                          height: 1.45)),
                ),
                if (note.actionLabel != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: PressScale(
                      onTap: () {
                        ref
                            .read(palInboxControllerProvider.notifier)
                            .markRead(note.id);
                        context.go(
                            '/pal-composer?seed=${Uri.encodeComponent(note.title)}');
                      },
                      semanticLabel: note.actionLabel,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                            color: c.fill,
                            borderRadius: BorderRadius.circular(100)),
                        child: Text(note.actionLabel!,
                            style: AppFonts.sf(
                                size: 12,
                                weight: FontWeight.w600,
                                color: c.ink,
                                letterSpacing: -0.08)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    return Opacity(opacity: note.unread ? 1 : 0.95, child: card);
  }
}

const _weekdayAbbrev = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _monthAbbrev = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Compact relative time: "2m ago" / "2h ago" / "Yesterday" / weekday within a
/// week / "Apr 18" beyond that.
String _relativeTime(DateTime when) {
  final now = DateTime.now();
  final diff = now.difference(when);

  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';

  // day-bucketed comparisons ignore the time-of-day.
  final today = DateTime(now.year, now.month, now.day);
  final thatDay = DateTime(when.year, when.month, when.day);
  final days = today.difference(thatDay).inDays;

  if (days == 1) return 'Yesterday';
  if (days < 7) return _weekdayAbbrev[when.weekday - 1];
  return '${_monthAbbrev[when.month - 1]} ${when.day}';
}
