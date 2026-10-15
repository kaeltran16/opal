import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/move_controller.dart';
import '../../controllers/providers.dart';
import '../../models/models.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../util/dates.dart';
import '../../widgets/day_strip.dart';
import '../../widgets/inset_section.dart';
import '../../widgets/nav_bar.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/session_row.dart';
import '../../widgets/stat_row.dart';
import '../shell/loop_shell.dart' show shellBottomInset;
import '../shell/tab_header.dart';
import '../workout/pal_pick_lead.dart';

const double _leadTop = Spacing.xl;
const double _sectionGap = Spacing.xxxl;
const double _stripGap = Spacing.lg;
const double _statGap = Spacing.xl;
const double _recentHeadGap = Spacing.xs;
const double _minTap = 44;
// a heading's trailing value takes at most this share, so the heading keeps the rest.
const double _trailingShare = 0.5;
const double _kgPerTonne = 1000;
const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

/// The Workout tab: Pal's lead, this week, recent sessions, the tools and any
/// other activity. All derivation lives in `moveStateProvider`; this widget
/// only lays out.
class MoveScreen extends ConsumerWidget {
  const MoveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final async = ref.watch(moveStateProvider);
    final exerciseCount = ref.watch(exercisesProvider).asData?.value.length;

    return async.when(
      loading: () => Center(
        child: Text('…', style: AppType.body.copyWith(color: c.ink3)),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.xxl),
          child: Text(
            "Couldn't load Workout.\n$e",
            textAlign: TextAlign.center,
            style: AppType.subhead.copyWith(color: c.ink3),
          ),
        ),
      ),
      data: (state) => _MoveBody(state: state, exerciseCount: exerciseCount),
    );
  }
}

class _MoveBody extends StatelessWidget {
  const _MoveBody({required this.state, required this.exerciseCount});
  final MoveState state;
  final int? exerciseCount;

  @override
  Widget build(BuildContext context) {
    return TabHeaderScrollView(
      title: 'Workout',
      contextualAction: NavIconButton(
        name: 'plus',
        semanticLabel: 'Start a workout',
        onTap: () => context.pushNamed(AppRoute.startWorkout.name),
      ),
      padding: EdgeInsets.only(bottom: shellBottomInset(context)),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(Spacing.lg, _leadTop, Spacing.lg, 0),
          child: PalPickLead(),
        ),
        _Gutter(child: _ThisWeek(state: state)),
        if (state.recentSessions.isNotEmpty)
          _Gutter(child: _Recent(sessions: state.recentSessions)),
        Padding(
          padding: const EdgeInsets.only(top: _sectionGap),
          child: _Tools(routineCount: state.routineCount, exerciseCount: exerciseCount),
        ),
        if (state.otherActivity.isNotEmpty) _OtherActivity(entries: state.otherActivity),
      ],
    );
  }
}

/// A section on the screen gutter, a section gap below what precedes it.
class _Gutter extends StatelessWidget {
  const _Gutter({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(Spacing.lg, _sectionGap, Spacing.lg, 0),
    child: child,
  );
}

/// A section heading with an optional trailing widget on its baseline.
class _Heading extends StatelessWidget {
  const _Heading({required this.text, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final trailing = this.trailing;
    return LayoutBuilder(
      builder: (context, box) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: Spacing.sm,
        children: [
          Expanded(
            // its own node, so the header flag stays on the heading alone.
            child: Semantics(
              container: true,
              header: true,
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.headline.copyWith(color: c.ink),
              ),
            ),
          ),
          if (trailing != null)
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: box.maxWidth * _trailingShare),
              child: trailing,
            ),
        ],
      ),
    );
  }
}

/// This week: workouts against the plan, the day strip and the week's numbers.
class _ThisWeek extends StatelessWidget {
  const _ThisWeek({required this.state});
  final MoveState state;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final count = state.weekGoal == 0
        ? 'No weekly plan yet'
        : '${state.weekWorkouts} of ${state.weekGoal} workouts';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Heading(
          text: 'This week',
          trailing: Text(
            count,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: AppType.subhead.copyWith(color: c.ink3, fontFeatures: _tabular),
          ),
        ),
        const SizedBox(height: _stripGap),
        Semantics(
          container: true,
          child: DayStrip(
            days: [
              for (final (i, d) in state.weekDays.indexed)
                DayMark(letter: d.letter, done: d.done, today: d.today, name: kWeekdays[i]),
            ],
            semanticLabel: 'This week: trained ${_trained(state.weekDays)}. $count',
          ),
        ),
        const SizedBox(height: _statGap),
        StatRow(
          stats: [
            Stat(
              value: (state.weekVolumeKg / _kgPerTonne).toStringAsFixed(1),
              unit: 't',
              label: 'Volume',
            ),
            Stat(value: '${state.weekMinutes}', unit: 'min', label: 'Time'),
            Stat(value: '${state.weekPrCount}', label: 'Records'),
          ],
        ),
      ],
    );
  }

  /// The trained days spoken as a list: "Monday, Tuesday and today".
  static String _trained(List<WeekDay> days) {
    final names = [
      for (final (i, d) in days.indexed)
        if (d.done) d.today ? 'today' : kWeekdays[i],
    ];
    if (names.isEmpty) return 'no days yet';
    if (names.length == 1) return names.single;
    return '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
  }
}

/// The newest sessions on hairlines, and See all for the full history.
class _Recent extends StatelessWidget {
  const _Recent({required this.sessions});
  final List<RecentSession> sessions;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Heading(
          text: 'Recent',
          // its own stop, apart from the session row below
          trailing: Semantics(
            container: true,
            child: PressScale(
              onTap: () => context.pushNamed(AppRoute.workoutHistory.name),
              semanticLabel: 'See all',
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: _minTap, minWidth: _minTap),
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  widthFactor: 1,
                  child: Text(
                    'See all',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.headline.copyWith(color: c.ink2),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: _recentHeadGap),
        for (final (i, s) in sessions.indexed)
          SessionRow(
            first: i == 0,
            when: s.relativeDate,
            title: s.workout.name,
            detail: s.timedDetail ??
                [
                  '${s.durationMinutes} min',
                  // cardio logs no volume, so it shows time alone.
                  if (s.volumeTonnes > 0) '${s.volumeTonnes.toStringAsFixed(1)} t',
                ].join(' · '),
            newBest: s.workout.prCount > 0,
            onTap: () => context.pushNamed(
              AppRoute.workoutDetail.name,
              pathParameters: {'id': s.workout.id},
            ),
          ),
      ],
    );
  }
}

/// The tab's tools: the plan, routines, Pal's generator, the library, history.
class _Tools extends StatelessWidget {
  const _Tools({required this.routineCount, required this.exerciseCount});
  final int routineCount;
  final int? exerciseCount;

  @override
  Widget build(BuildContext context) {
    return InsetSection(
      children: [
        ListRow(
          icon: 'calendar',
          title: 'Weekly plan',
          onTap: () => context.pushNamed(AppRoute.weeklyPlan.name),
        ),
        ListRow(
          icon: 'list.bullet',
          title: 'My routines',
          value: '$routineCount',
          onTap: () => context.pushNamed(AppRoute.startWorkout.name),
        ),
        ListRow(
          icon: 'wand.and.stars',
          title: 'Generate with Pal',
          onTap: () => context.pushNamed(AppRoute.routineGenerator.name),
        ),
        ListRow(
          icon: 'plus',
          title: 'New routine',
          onTap: () => context.pushNamed(AppRoute.routineEditor.name),
        ),
        ListRow(
          icon: 'book',
          title: 'Exercise library',
          value: exerciseCount == null ? null : '$exerciseCount',
          onTap: () => context.pushNamed(AppRoute.exerciseLibrary.name),
        ),
        ListRow(
          icon: 'chart.line.uptrend.xyaxis',
          title: 'History and trends',
          last: true,
          onTap: () => context.pushNamed(AppRoute.workoutHistory.name),
        ),
      ],
    );
  }
}

/// Non-workout movement entries, such as a logged run.
class _OtherActivity extends StatelessWidget {
  const _OtherActivity({required this.entries});
  final List<Entry> entries;

  @override
  Widget build(BuildContext context) {
    return InsetSection(
      header: 'Other activity',
      children: [
        for (final (i, e) in entries.indexed)
          ListRow(
            icon: 'figure.run',
            title: e.title,
            subtitle: e.detail,
            chevron: false,
            last: i == entries.length - 1,
          ),
      ],
    );
  }
}
