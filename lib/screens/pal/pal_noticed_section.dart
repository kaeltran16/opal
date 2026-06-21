import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/pal_inbox_controller.dart';
import '../../models/models.dart';
import '../../theme/theme.dart';
import '../../util/dates.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/nav_bar.dart';
import '../../widgets/press_scale.dart';

/// "What Pal noticed" — the passive observation feed, embedded as a section of
/// the Pal hub. Reads [palInboxControllerProvider]; renders as a Column so it
/// nests inside the hub's scroll view. Handles its own loading/empty/error
/// independent of the agenda regions (compose, not fuse).
class PalNoticedSection extends ConsumerWidget {
  const PalNoticedSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final async = ref.watch(palInboxControllerProvider);

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => Padding(
        padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.lg, Spacing.xl, Spacing.lg),
        child: Text("Couldn't load what Pal noticed.",
            style: AppType.footnote.copyWith(color: c.ink3, letterSpacing: -0.15)),
      ),
      data: (state) => _Body(state: state),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.state});
  final PalInboxState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final controller = ref.read(palInboxControllerProvider.notifier);
    final unread = state.unreadCount;
    final visible = state.visible;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Header: "What Pal noticed" + Mark all read --------------------
        Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.lg, Spacing.lg, Spacing.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('What Pal noticed',
                  style: AppType.title3.copyWith(color: c.ink, letterSpacing: -0.3)),
              NavAction(
                label: 'Mark all read',
                onTap: controller.markAllRead,
                semanticLabel: 'Mark all read',
              ),
            ],
          ),
        ),

        // --- Filter chips -------------------------------------------------
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

        // --- Notes --------------------------------------------------------
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(Spacing.xl, 24, Spacing.xl, 24),
            child: Text('Nothing here. A quiet Pal is a happy Pal.',
                textAlign: TextAlign.center,
                style: AppType.footnote.copyWith(color: c.ink3, letterSpacing: -0.15)),
          )
        else
          for (var i = 0; i < visible.length; i++) ...[
            if (i > 0) const SizedBox(height: Spacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
              child: _NoteCard(note: visible[i]),
            ),
          ],
      ],
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

/// Compact relative time: "2m ago" / "2h ago" / "Yesterday" / weekday within a
/// week / "Apr 18" beyond that.
String _relativeTime(DateTime when) {
  final now = DateTime.now();
  final diff = now.difference(when);

  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';

  // day-bucketed comparisons ignore the time-of-day.
  final days = startOfDay(now).difference(startOfDay(when)).inDays;

  if (days == 1) return 'Yesterday';
  if (days < 7) return kWeekdaysShort[when.weekday - 1];
  return '${kMonthsShort[when.month - 1]} ${when.day}';
}
