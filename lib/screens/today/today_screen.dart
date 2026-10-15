import '../shell/loop_shell.dart' show shellBottomInset;
import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../analysis/area_state.dart';
import '../../controllers/mood_controller.dart';
import '../../controllers/nutrition_controller.dart';
import '../../controllers/pal_agenda_controller.dart';
import '../../controllers/plan_session_controller.dart';
import '../../controllers/rituals_controller.dart';
import '../../controllers/today_controller.dart';
import '../../controllers/weekly_plan_controller.dart';
import '../../router.dart';
import '../../services/pal/pal_service.dart' show PalAgenda;
import '../../theme/theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/day_scene.dart';
import '../../widgets/pal_label.dart';
import '../../widgets/pal_lead.dart' show PalLeadText;
import '../../widgets/press_scale.dart';
import '../mood/mood_logger_sheet.dart';
import 'day_plan.dart';
import 'today_logic.dart';

// kept literal: where the prototype's content starts, just under the status bar.
const double _contentTop = 52;
const double _minTap = 44;
const double _pillHeight = 48;
const double _cardGap = 14;
const double _cardDisc = 40;
const double _cardIcon = 20;
const double _rowDisc = 28;
const double _rowIcon = 18;
const double _rowGap = 10;
const double _rowInset = Spacing.xs;
// a title and its detail, with room around them.
const double _rowHeight = _minTap + Spacing.md;
const double _chevron = 14;
// wide enough for "12:30 PM" and "Any time" in caption.
const double _timeWidth = 56;
const double _railWidth = 1;
const double _labelHeight = 18;
// the Why button's tap target overhangs the label row this much on each side.
const double _labelOverhang = (_minTap - _labelHeight) / 2;
const double _whyIcon = 14;
const double _leadMaxWidth = 300;
const double _leadMinHeight = 100;
const double _dateTracking = 1.2;
// the most of its row a secondary text button takes, so large text ellipsises
// it instead of crowding out the label or the primary pill.
const double _sideShare = 0.5;
const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

const String _palOnline = 'Pal';
const String _palOffline = 'Pal is offline · next on the clock';
const String _why = 'Why this first';
const String _yourDay = 'Your day';
const String _anyTime = 'Any time';

/// Your day's rail, drawn only when there are rows.
const Key todayRailKey = ValueKey('today.rail');

/// The action card, always shown once the day has loaded.
const Key todayCardKey = ValueKey('today.card');

/// Acts on [item] as Today's card does: a proposal is approved, anything
/// else opens where it is done. You's Pal suggests approves through this too.
void actOnPlanItem(BuildContext context, WidgetRef ref, PlanItem item) {
  switch (item.kind) {
    case PlanKind.proposal:
      ref.read(planSessionControllerProvider.notifier).approve(item);
    case PlanKind.routine:
      context.pushNamed(AppRoute.routinePlayer.name,
          pathParameters: {'routineId': item.ref!});
    case PlanKind.workout:
      context.goNamed(AppRoute.startWorkout.name);
    case PlanKind.mood:
      showMoodLogger(context);
    case PlanKind.meal:
      context.pushNamed(AppRoute.palComposer.name);
    case PlanKind.closeOut:
      context.pushNamed(AppRoute.eveningCloseOut.name);
  }
}

/// Today: the scene, the date line, Pal's line about the lead, one action
/// card and the whole day as a quiet list. The code picks the lead and every
/// number comes from local providers; Pal only words the line and proposes.
class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  late final AppLifecycleListener _lifecycle;
  Timer? _minuteTick;

  @override
  void initState() {
    super.initState();
    // today stays mounted in the shell's indexed stack, so a resume on any tab
    // refetches and the day is current when the user comes back.
    _lifecycle = AppLifecycleListener(onResume: _resume);
    _scheduleTick();
  }

  @override
  void dispose() {
    _minuteTick?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  // the date line, the scene's phase, what is overdue and the day's put-offs
  // all follow the clock.
  void _scheduleTick() {
    final toNextMinute = Duration.secondsPerMinute - clock.now().second;
    _minuteTick = Timer(Duration(seconds: toNextMinute), () {
      _plan.syncDay(clock.now());
      setState(() {});
      _scheduleTick();
    });
  }

  void _resume() {
    _plan.syncDay(clock.now());
    ref.invalidate(palAgendaProvider);
  }

  Future<void> _pull() async {
    try {
      ref.invalidate(palAgendaProvider);
      await ref.read(palAgendaProvider.future);
    } catch (e) {
      // the provider holds the error, which Today reads as Pal offline.
      debugPrint('today: agenda refresh failed: $e');
    }
  }

  PlanSessionController get _plan => ref.read(planSessionControllerProvider.notifier);

  void _askWhy(PlanItem item, String note) => context.pushNamed(
        AppRoute.palComposer.name,
        queryParameters: {'seed': 'Why ${item.title} first?', 'about': note, 'from': '/today'},
      );

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final async = ref.watch(todayStateProvider);

    return async.when(
      loading: () => Center(
        child: Text('…', style: AppType.body.copyWith(color: c.ink3)),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.xxl),
          child: Text("Couldn't load today. Try again in a moment.",
              textAlign: TextAlign.center,
              style: AppType.subhead.copyWith(color: c.ink3)),
        ),
      ),
      data: (today) => RefreshIndicator(onRefresh: _pull, child: _content(today)),
    );
  }

  Widget _content(TodayState today) {
    final now = clock.now();
    final agenda = ref.watch(palAgendaProvider);
    final palAgenda = agenda.value ?? const PalAgenda();
    final session = ref.watch(planSessionControllerProvider);
    final plan = buildDayPlan(
      agenda: palAgenda,
      rituals: ref.watch(ritualsControllerProvider).value,
      workout: ref.watch(weeklyPlanControllerProvider).value?.today,
      lastCheckin: ref.watch(moodControllerProvider).value?.lastCheckin,
      meals: ref.watch(nutritionControllerProvider).value?.meals ?? const [],
      now: now,
    );
    // loading counts as online, so the label does not flicker on a cold start;
    // a failed refresh still holds the old proposals but reads offline.
    final online = !agenda.hasError;
    final rules = LeadRules(
      palOnline: online,
      care: careAreas(today.glance, now),
    );
    final current = plan.current(session, now, rules);
    final line = leadLine(
      lead: current,
      agenda: palAgenda,
      online: online,
      leadKey: current == null ? null : plan.factFor(current, session, now, rules).key,
    );
    final rows = plan.rows(session, now);
    final progress = plan.progress(session);
    final safe = MediaQuery.paddingOf(context);

    return SingleChildScrollView(
      // a short day still has to pull down to refresh.
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      child: Stack(
        children: [
          Positioned(top: 0, left: 0, right: 0, child: DayScene(phase: phaseFor(now))),
          // the screen's heading, for assistive tech only.
          Positioned(
            top: _contentTop,
            left: Spacing.lg,
            child: Semantics(
              header: true,
              label: 'Today',
              child: const SizedBox.square(dimension: 1),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              Spacing.lg,
              math.max(_contentTop, safe.top + Spacing.xs),
              Spacing.lg,
              shellBottomInset(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: Spacing.md,
              children: [
                _Header(date: dateLine(now)),
                _Lead(
                  label: online ? _palOnline : _palOffline,
                  text: line,
                  onWhy: online && current != null
                      ? () => _askWhy(current, plan.whyNote(current, session, now, rules))
                      : null,
                ),
                _ActionCard(
                  item: current,
                  onAct: (item) => actOnPlanItem(context, ref, item),
                  onSkip: _plan.putOff,
                ),
                if (rows.isNotEmpty)
                  _YourDay(
                    done: progress.done,
                    total: progress.total,
                    rows: [
                      for (final row in rows) _PlanRow(row: row, onTap: _rowTap(row)),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// An open row opens as the card's pill does; a put-off comes back; a done
  /// mood check-in opens the logger again; any other done row is inert.
  VoidCallback? _rowTap(PlanRow row) => switch (row.state) {
        PlanRowState.open || PlanRowState.missed => () => actOnPlanItem(context, ref, row.item),
        PlanRowState.putOff => () => _plan.bringBack(row.item),
        PlanRowState.done when row.tappable => () => showMoodLogger(context),
        PlanRowState.done => null,
      };
}

/// The date line.
class _Header extends StatelessWidget {
  const _Header({required this.date});

  final String date;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _minTap),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(date,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.label.copyWith(color: context.colors.ink2, letterSpacing: _dateTracking)),
      ),
    );
  }
}

/// Pal's label, `Why this first` when [onWhy] is set, and the day's line, the
/// screen's only serif.
class _Lead extends StatelessWidget {
  const _Lead({required this.label, required this.text, required this.onWhy});

  final String label, text;
  final VoidCallback? onWhy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final onWhy = this.onWhy;
    return Semantics(
      container: true,
      liveRegion: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _leadMinHeight),
        child: Padding(
          padding: const EdgeInsets.only(top: Spacing.xl - _labelOverhang),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // always the tap target's height, so Why coming and going does
              // not move the lead.
              SizedBox(
                height: _minTap,
                child: LayoutBuilder(
                  builder: (context, box) => Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: PalLabel(text: label),
                        ),
                      ),
                      if (onWhy != null)
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: box.maxWidth * _sideShare),
                          child: PressScale(
                            onTap: onWhy,
                            child: Padding(
                              padding: const EdgeInsets.only(left: Spacing.sm),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                spacing: Spacing.xxs,
                                children: [
                                  Flexible(
                                    child: Text(_why,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppType.label.copyWith(color: c.ink3)),
                                  ),
                                  AppIcon('chevron.right', size: _whyIcon, color: c.ink3),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              PalLeadText(text, color: c.ink, maxWidth: _leadMaxWidth),
            ],
          ),
        ),
      ),
    );
  }
}

/// The one thing to do now, or the all-done card when [item] is null.
class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.item, required this.onAct, required this.onSkip});

  final PlanItem? item;
  final void Function(PlanItem) onAct;
  final void Function(PlanItem) onSkip;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final item = this.item;
    return Container(
      key: todayCardKey,
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: _cardGap,
        children: [
          Row(
            spacing: Spacing.md,
            children: [
              _Disc(
                size: _cardDisc,
                child: AppIcon(item?.icon ?? 'checkmark', size: _cardIcon, color: c.ink),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: Spacing.xxs,
                  children: [
                    Text(item?.whenLabel ?? 'All done',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.label.copyWith(color: c.ink3, fontFeatures: _tabular)),
                    Semantics(
                      header: true,
                      child: Text(item?.title ?? "That's the day",
                          style: AppType.title.copyWith(color: c.ink)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (item != null)
            LayoutBuilder(
              builder: (context, box) => Row(
                spacing: Spacing.sm,
                children: [
                  Expanded(child: _Pill(label: item.actionLabel, onTap: () => onAct(item))),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: box.maxWidth * _sideShare),
                    child: PressScale(
                      onTap: () => onSkip(item),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: _pillHeight),
                        padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
                        // widthFactor keeps the button its label's width
                        // under the cap.
                        child: Align(
                          widthFactor: 1,
                          child: Text(item.skipLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.headline.copyWith(color: c.ink2)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The card's primary action.
class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PressScale(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: _pillHeight),
        padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
        decoration: BoxDecoration(
          color: c.ink,
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        alignment: Alignment.center,
        child: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.headline.copyWith(color: c.bg)),
      ),
    );
  }
}

/// A round `surface2` disc holding an icon.
class _Disc extends StatelessWidget {
  const _Disc({required this.size, required this.child});

  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: context.colors.surface2, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: child,
      );
}

/// `Your day · N of M done`, then every row of the day on a hairline rail.
class _YourDay extends StatelessWidget {
  const _YourDay({required this.done, required this.total, required this.rows});

  final int done, total;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final timeWidth = MediaQuery.textScalerOf(context).scale(_timeWidth);
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: Spacing.xxxl),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: _rowInset),
              child: Row(
                spacing: Spacing.xs,
                children: [
                  Semantics(
                    header: true,
                    child: Text(_yourDay, style: AppType.label.copyWith(color: c.ink2)),
                  ),
                  Flexible(
                    child: Text('· $done of $total done',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.label.copyWith(color: c.ink3, fontFeatures: _tabular)),
                  ),
                ],
              ),
            ),
          ),
          Stack(
            children: [
              Positioned(
                key: todayRailKey,
                left: _rowInset + timeWidth + _rowGap + (_rowDisc - _railWidth) / 2,
                top: _rowHeight / 2,
                bottom: _rowHeight / 2,
                width: _railWidth,
                child: ColoredBox(color: c.hair),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
            ],
          ),
        ],
      ),
    );
  }
}

/// One item of the day: its time, a disc, the title and its detail. A done
/// or put-off row goes quiet; a row with [onTap] carries a chevron.
class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.row, required this.onTap});

  final PlanRow row;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final item = row.item;
    final done = row.state == PlanRowState.done;
    final ink = done || row.state == PlanRowState.putOff ? c.ink3 : c.ink;
    final minute = item.minuteOfDay;
    final detail = row.detail;
    final body = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _rowHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _rowInset),
        child: Row(
          spacing: _rowGap,
          children: [
            SizedBox(
              width: MediaQuery.textScalerOf(context).scale(_timeWidth),
              child: Text(minute == null ? _anyTime : clockLabel(minute),
                  maxLines: 1,
                  style: AppType.caption.copyWith(color: c.ink3, fontFeatures: _tabular)),
            ),
            _Disc(
              size: _rowDisc,
              child: AppIcon(done ? 'checkmark' : item.icon, size: _rowIcon, color: ink),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.callout.copyWith(color: ink)),
                  if (detail != null)
                    Text(detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.caption.copyWith(color: c.ink3, fontFeatures: _tabular)),
                ],
              ),
            ),
            if (onTap != null) AppIcon('chevron.right', size: _chevron, color: c.ink3),
          ],
        ),
      ),
    );
    final tap = onTap;
    if (tap == null) {
      // read as one line, but not a button.
      return Semantics(
        container: true,
        label: row.semanticLabel,
        excludeSemantics: true,
        child: body,
      );
    }
    return PressScale(onTap: tap, semanticLabel: row.semanticLabel, pressedScale: 1, child: body);
  }
}
