import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/pal_inbox_controller.dart';
import '../../models/models.dart';
import '../../theme/theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/nav_bar.dart';
import '../../widgets/pal_avatar.dart';
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
            style: AppType.body.copyWith(color: c.ink3)),
      ),
      error: (e, _) => Container(
        color: c.bg,
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.xxl),
          child: Text("Couldn't load your inbox. Try again in a moment.",
              textAlign: TextAlign.center,
              style: AppType.subhead.copyWith(color: c.ink3, letterSpacing: -0.24)),
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
        padding: const EdgeInsets.only(bottom: 110), // bottom-nav clearance
        children: [
          // --- Nav: back to Today + Mark all read -----------------------------
          Padding(
            // top 56 = status-bar/safe-area offset, kept literal
            padding: const EdgeInsets.fromLTRB(Spacing.lg, 56, Spacing.lg, Spacing.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                NavAction(
                  icon: 'chevron.left',
                  label: 'Today',
                  onTap: () => context.pop(),
                  semanticLabel: 'Back',
                ),
                NavAction(
                  label: 'Mark all read',
                  onTap: controller.markAllRead,
                  semanticLabel: 'Mark all read',
                ),
              ],
            ),
          ),

          // --- Title: gradient sparkle avatar + "Pal noticed" + sub -----------
          Padding(
            padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.xs, Spacing.xl, Spacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const PalAvatar(size: 36, glyphSize: 16, glow: true),
                    const SizedBox(width: Spacing.md),
                    Text('Pal noticed',
                        style: AppType.title1.copyWith(
                            color: c.ink,
                            letterSpacing: -0.3,
                            height: 1)),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: Spacing.sm),
                  child: unread > 0
                      ? Text.rich(
                          TextSpan(
                            style: AppType.subhead.copyWith(
                                color: c.ink3, letterSpacing: -0.24),
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
                          style: AppType.subhead.copyWith(
                              color: c.ink3, letterSpacing: -0.24)),
                ),
              ],
            ),
          ),

          // --- Filter chips ---------------------------------------------------
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
              children: [
                _FilterChip(
                  label: 'All',
                  count: state.notes.length,
                  active: state.filter == InboxFilter.all,
                  onTap: () => controller.setFilter(InboxFilter.all),
                ),
                const SizedBox(width: Spacing.sm),
                _FilterChip(
                  label: 'Unread',
                  count: unread,
                  active: state.filter == InboxFilter.unread,
                  onTap: () => controller.setFilter(InboxFilter.unread),
                ),
                const SizedBox(width: Spacing.sm),
                _FilterChip(
                  label: 'Money',
                  dotColor: c.money,
                  active: state.filter == InboxFilter.money,
                  onTap: () => controller.setFilter(InboxFilter.money),
                ),
                const SizedBox(width: Spacing.sm),
                _FilterChip(
                  label: 'Workout',
                  dotColor: c.move,
                  active: state.filter == InboxFilter.move,
                  onTap: () => controller.setFilter(InboxFilter.move),
                ),
                const SizedBox(width: Spacing.sm),
                _FilterChip(
                  label: 'Routines',
                  dotColor: c.rituals,
                  active: state.filter == InboxFilter.rituals,
                  onTap: () => controller.setFilter(InboxFilter.rituals),
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.lg),

          // --- Timeline -------------------------------------------------------
          if (visible.isEmpty)
            Padding(
              // 40 vertical = deliberate empty-state breathing room, kept literal
              padding: const EdgeInsets.fromLTRB(Spacing.xl, 40, Spacing.xl, 40),
              child: Text('Nothing here. A quiet Pal is a happy Pal.',
                  textAlign: TextAlign.center,
                  style:
                      AppType.footnote.copyWith(color: c.ink3, letterSpacing: -0.15)),
            )
          else
            for (var i = 0; i < visible.length; i++) ...[
              if (i > 0) const SizedBox(height: Spacing.sm),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
                child: _NoteCard(note: visible[i]),
              ),
            ],

          // --- Footer: tune what Pal notices ----------------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.xl, Spacing.xl, Spacing.sm),
            child: Center(
              // no onTap yet — render as a plain label so screen readers don't
              // announce a dead button.
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIcon('gearshape.fill', size: 12, color: c.ink3),
                  const SizedBox(width: Spacing.sm),
                  Text('Tune what Pal notices',
                      style: AppType.footnote.copyWith(
                          color: c.ink3, letterSpacing: -0.08)),
                ],
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
        padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
        decoration: BoxDecoration(
          color: active ? c.ink : c.surface,
          borderRadius: BorderRadius.circular(Radii.pill),
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
              const SizedBox(width: Spacing.sm),
            ],
            Text(label,
                style: AppType.footnote.copyWith(
                    fontWeight: FontWeight.w500,
                    color: fg,
                    letterSpacing: -0.08)),
            if (count != null) ...[
              const SizedBox(width: Spacing.xs),
              Text('$count',
                  style: AppType.caption2.copyWith(
                      fontWeight: FontWeight.w600,
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
          color: c.surface, borderRadius: BorderRadius.circular(Radii.lg)),
      padding: const EdgeInsets.all(Spacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // unread indicator
          if (note.unread)
            Padding(
              padding: const EdgeInsets.only(right: Spacing.sm, top: Spacing.lg),
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
                color: catColor, borderRadius: BorderRadius.circular(Radii.md)),
            alignment: Alignment.center,
            child: AppIcon(note.icon, size: 16, color: c.onAccent),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // meta row
                Row(
                  children: [
                    Text(note.kind.label.toUpperCase(),
                        style: AppType.caption2.copyWith(
                            fontWeight: FontWeight.w700,
                            color: kindColor,
                            letterSpacing: 0.3)),
                    const SizedBox(width: Spacing.sm),
                    Container(
                      width: 3,
                      height: 3,
                      decoration:
                          BoxDecoration(color: c.ink4, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: Spacing.sm),
                    Text(_relativeTime(note.createdAt),
                        style: AppType.caption2.copyWith(
                            color: c.ink3, letterSpacing: -0.08)),
                  ],
                ),
                const SizedBox(height: Spacing.xs),
                Text(note.title,
                    style: AppType.subhead.copyWith(
                        fontWeight: FontWeight.w600,
                        color: c.ink,
                        letterSpacing: -0.24,
                        height: 1.3)),
                Padding(
                  padding: const EdgeInsets.only(top: Spacing.xs),
                  child: Text(note.body,
                      style: AppType.footnote.copyWith(
                          color: c.ink2,
                          letterSpacing: -0.08,
                          height: 1.45)),
                ),
                if (note.actionLabel != null)
                  Padding(
                    padding: const EdgeInsets.only(top: Spacing.md),
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
                            horizontal: Spacing.md, vertical: Spacing.sm),
                        decoration: BoxDecoration(
                            color: c.fill,
                            borderRadius: BorderRadius.circular(Radii.pill)),
                        child: Text(note.actionLabel!,
                            style: AppType.caption.copyWith(
                                fontWeight: FontWeight.w600,
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
