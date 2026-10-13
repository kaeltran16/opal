import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/profile_controller.dart';
import '../../controllers/providers.dart';
import '../../models/models.dart';
import '../../services/pal/pal_context_builder.dart';
import '../../theme/theme.dart';
import '../../util/dates.dart';
import '../../widgets/controls.dart';
import '../../widgets/nav_bar.dart' show NavIconButton;
import '../../widgets/stat_row.dart';

// where the prototype's content starts, just under the status bar.
const double _contentTop = 52;
const double _contentBottom = 48;
const double _heroTop = 28;
const String _closeRoute = '/today';

/// Live timeline entries for the move-streak math. The repository already
/// scopes the heavy lifting; the seed/live history is short enough that the
/// whole stream is a fine lookback for [moveStreakDays] (it counts back from
/// today on its own). A manual provider (not codegen) since no controller
/// exposes the raw entry stream and this screen is its only consumer.
final _moveEntriesProvider = StreamProvider.autoDispose<List<Entry>>(
  (ref) => ref.watch(entryRepositoryProvider).watchAll(),
);

/// Screen 15 — Streak Celebration.
///
/// The workout streak ("days moving") as one light number, the since line in
/// the serif, a stat row and one Keep going. The number is the live move
/// streak, computed from the entry stream via [moveStreakDays]; the stats
/// draw from [profileStatsProvider] (kcal totals/best day).
class StreakCelebrationScreen extends ConsumerWidget {
  const StreakCelebrationScreen({super.key});

  /// Stats derived from real profile data; only includes one when its value
  /// can actually be computed (no fabricated stats).
  static List<Stat> _statsFor(ProfileStats? stats, int streak) {
    if (stats == null) return const [];
    final out = <Stat>[];
    if (stats.moveKcal > 0) {
      out.add(Stat(value: '${stats.moveKcal}', unit: 'kcal', label: 'Total'));
    }
    final bestDay = stats.bestMoveDay;
    if (bestDay != null && stats.bestMoveDayKcal > 0) {
      final wd = kWeekdaysShort[bestDay.weekday - 1];
      out.add(Stat(value: '${stats.bestMoveDayKcal}', unit: 'kcal', label: 'Best day · $wd'));
    }
    final next = nextStreakMilestone(streak);
    if (next != null) {
      out.add(Stat(value: '${next - streak}', unit: 'days', label: 'Next milestone'));
    }
    return out;
  }

  void _close(BuildContext context) => Navigator.of(context).canPop()
      ? Navigator.of(context).pop()
      : context.go(_closeRoute);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final safe = MediaQuery.paddingOf(context);
    final stats = ref.watch(profileStatsProvider).asData?.value;
    // the workout streak the rest of the app reports: consecutive move days,
    // counted from the live entry stream (the same helper the Pal context uses).
    // profileStats.longestStreak is the *ritual* streak — wrong source for this
    // "days moving" screen — so we derive the move streak from entries directly.
    final entries = ref.watch(_moveEntriesProvider).asData?.value;
    final streak = entries == null ? 0 : moveStreakDays(entries);
    final shown = _statsFor(stats, streak);
    final String sinceLine;
    if (streak < 1) {
      sinceLine = 'Move on any day to start a streak.';
    } else {
      // a streak of at least 1 always has a start date.
      final start = streakStartDate(streak, clock.now())!;
      sinceLine = "You haven't missed a day since "
          '${kMonthsShort[start.month - 1]} ${start.day}.\n'
          'Your current streak.';
    }

    return Scaffold(
      backgroundColor: c.bg,
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          Spacing.lg,
          math.max(_contentTop, safe.top + Spacing.xs),
          Spacing.lg,
          _contentBottom + safe.bottom,
        ),
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: NavIconButton(
              name: 'xmark',
              semanticLabel: 'Close',
              onTap: () => _close(context),
            ),
          ),
          const SizedBox(height: _heroTop),
          Text('Workout streak', style: AppType.label.copyWith(color: c.ink3)),
          const SizedBox(height: Spacing.xs),
          Text('$streak', style: AppType.display.copyWith(color: c.ink)),
          Text(streak == 1 ? 'day' : 'days', style: AppType.subhead.copyWith(color: c.ink2)),
          const SizedBox(height: Spacing.xl),
          Text(sinceLine, style: AppType.lead.copyWith(color: c.ink)),
          if (shown.isNotEmpty) ...[
            const SizedBox(height: Spacing.xxl),
            StatRow(stats: shown),
          ],
          const SizedBox(height: Spacing.xxxl),
          PillButton(label: 'Keep going', onTap: () => _close(context)),
        ],
      ),
    );
  }
}
