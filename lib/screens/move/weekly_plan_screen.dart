import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/providers.dart';
import '../../controllers/weekly_plan_controller.dart';
import '../../models/models.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../util/dates.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/controls.dart';
import '../../widgets/day_strip.dart';
import '../../widgets/inset_section.dart';
import '../../widgets/nav_bar.dart';
import '../../widgets/pal_lead.dart';
import '../../widgets/session_row.dart';
import '../shell/loop_shell.dart' show shellBottomInset;
import '../workout/session_launcher.dart';

const double _sectionGap = Spacing.xl;
const String _restTitle = 'Rest';
const String _restDay = 'Rest day';
const String _current = 'Current';

/// Screen 24 — Weekly Plan, the derived 7-day workout schedule.
///
/// Reads the [WeeklyPlan] from `weeklyPlanControllerProvider` (a stream joining
/// the persisted schedule to routines + this week's workouts) and renders the
/// title block, the week strip, today's card, the full schedule list, and a
/// computed weekly-progress note. All derivation lives in the controller; this
/// widget only lays out.
class WeeklyPlanScreen extends ConsumerWidget {
  const WeeklyPlanScreen({super.key});

  /// Monday of the current week, formatted "WEEK OF MON DD". The plan's day
  /// model only carries day-of-month, so the month comes from the current
  /// week's Monday (the same anchor the controller uses).
  static String _weekOfLabel() {
    final monday = startOfWeek(clock.now());
    return 'WEEK OF ${kMonthsShort[monday.month - 1].toUpperCase()} ${monday.day}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final plan = ref.watch(weeklyPlanControllerProvider).asData?.value ??
        const WeeklyPlan(days: []);
    final today = plan.today;
    final todayIndex = plan.days.indexWhere((d) => d.today);

    return LargeTitleScrollView(
      eyebrow: _weekOfLabel(),
      title: 'Your plan',
      subtitle:
          '${plan.doneCount} of ${plan.totalCount} done · ${plan.totalMinutes} min planned',
      leading: NavAction(
        icon: 'chevron.left',
        label: 'Workout',
        onTap: () => context.pop(),
        semanticLabel: 'Back',
      ),
      trailing: NavIconButton(
        name: 'ellipsis',
        semanticLabel: 'More options',
        onTap: () => _showPlanMenu(context),
      ),
      padding: EdgeInsets.only(bottom: shellBottomInset(context)),
      children: [
        if (plan.days.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Spacing.lg, Spacing.sm, Spacing.lg, _sectionGap),
            child: DayStrip(
              semanticLabel: 'This week',
              days: [
                for (final (i, d) in plan.days.indexed)
                  DayMark(
                      letter: d.day[0],
                      done: d.done,
                      today: d.today,
                      name: kWeekdays[i]),
              ],
              selected: todayIndex < 0 ? null : todayIndex,
              // weekday = strip index + 1 (Mon..Sun, 1..7).
              onTap: (i) => _showAssignSheet(context, ref, i + 1),
            ),
          ),

        if (today != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Spacing.lg, 0, Spacing.lg, _sectionGap),
            child: today.isRest
                ? Text(_restDay,
                    style: AppType.title.copyWith(color: c.ink))
                : ActionCard(
                    meta: 'Today',
                    title: today.routine ?? today.type,
                    primary: PillButton(
                      label: 'Start workout',
                      onTap: () => _startToday(context, ref),
                    ),
                  ),
          ),

        InsetSection(
          header: 'Schedule',
          footer: 'Tap a day to set or change its routine.',
          children: [
            for (final (i, d) in plan.days.indexed)
              SessionRow(
                first: i == 0,
                when: d.day,
                title: d.isRest ? _restTitle : (d.routine ?? d.type),
                detail: _detail(d),
                onTap: () => _showAssignSheet(context, ref, i + 1),
              ),
          ],
        ),

        // computed from the plan, not invented coaching: coaching is Pal's
        // and has no real source here.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
          child: Text(_progressSummary(plan),
              style: AppType.subhead.copyWith(color: c.ink2)),
        ),
      ],
    );
  }
}

/// The schedule row's detail: the estimate, and the word for a done day.
String _detail(WeekPlanDay day) {
  if (day.isRest) return '';
  final est = day.est == null ? null : '${day.est} min';
  if (!day.done) return est ?? '';
  return est == null ? 'Done' : 'Done · $est';
}

/// Factual progress line from the plan's own counts.
String _progressSummary(WeeklyPlan plan) {
  final done = plan.doneCount;
  final total = plan.totalCount;
  final remaining = total - done;
  if (total == 0) return 'No workouts scheduled this week yet.';
  if (done >= total) {
    return 'All $total workouts done this week — ${plan.totalMinutes} min planned.';
  }
  final left = remaining == 1 ? '1 workout' : '$remaining workouts';
  return '$done of $total done · $left left this week.';
}

/// The routine assigned to [weekday] (1=Mon..7=Sun), or null for a rest day.
/// Read from the repo so the id is exact even when two routines share a name.
Future<String?> _assignedRoutineId(WidgetRef ref, int weekday) async {
  final schedule = await ref.read(weeklyPlanRepositoryProvider).getSchedule();
  for (final a in schedule) {
    if (a.weekday == weekday) return a.routineId;
  }
  return null;
}

/// Opens today's routine through the launcher, which resumes a running
/// session instead of starting a second one.
Future<void> _startToday(BuildContext context, WidgetRef ref) async {
  final id = await _assignedRoutineId(ref, clock.now().weekday);
  if (id == null || !context.mounted) return;
  openWorkoutSession(context, ref, id);
}

/// Overflow ("…") menu for the Weekly Plan: shortcuts to start a workout or
/// add a routine.
Future<void> _showPlanMenu(BuildContext context) {
  return showAppSheet<void>(
    context,
    builder: (sheetContext) => InsetSection(
      margin: EdgeInsets.zero,
      children: [
        ListRow(
          icon: 'figure.run',
          title: 'Start workout',
          onTap: () {
            Navigator.of(sheetContext).pop();
            context.go('/move/start');
          },
        ),
        ListRow(
          icon: 'plus',
          title: 'New routine',
          last: true,
          onTap: () {
            Navigator.of(sheetContext).pop();
            context.pushNamed(AppRoute.routineEditor.name);
          },
        ),
      ],
    ),
  );
}

/// Routine picker for one weekday: lists every routine (+ a Rest option) and
/// upserts the chosen assignment, which the plan stream re-derives.
Future<void> _showAssignSheet(
    BuildContext context, WidgetRef ref, int weekday) async {
  final routines =
      ref.read(workoutRoutinesStreamProvider).asData?.value ?? const <Routine>[];
  final currentId = await _assignedRoutineId(ref, weekday);
  if (!context.mounted) return;

  final repo = ref.read(weeklyPlanRepositoryProvider);
  await showAppSheet<void>(
    context,
    scrollable: true,
    builder: (sheetContext) => SingleChildScrollView(
      child: InsetSection(
        header: 'Assign routine',
        margin: EdgeInsets.zero,
        children: [
          ListRow(
            icon: 'calendar',
            title: _restDay,
            value: currentId == null ? _current : null,
            chevron: false,
            onTap: () {
              Navigator.of(sheetContext).pop();
              repo.upsert(weekday, null);
            },
          ),
          for (final (i, r) in routines.indexed)
            ListRow(
              icon: r.tag == RoutineTag.cardio ? 'figure.run' : 'dumbbell',
              title: r.name,
              subtitle: r.estMin == null ? null : '${r.estMin} min',
              value: currentId == r.id ? _current : null,
              chevron: false,
              last: i == routines.length - 1,
              onTap: () {
                Navigator.of(sheetContext).pop();
                repo.upsert(weekday, r.id);
              },
            ),
          if (routines.isEmpty)
            ListRow(
              icon: 'plus',
              title: 'Create a routine',
              subtitle: 'Build one to add it to your plan',
              last: true,
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.pushNamed(AppRoute.routineEditor.name);
              },
            ),
        ],
      ),
    ),
  );
}
