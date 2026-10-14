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
import '../../controllers/rituals_controller.dart';
import '../../controllers/today_brief_controller.dart';
import '../../controllers/today_controller.dart';
import '../../controllers/weekly_plan_controller.dart';
import '../../router.dart';
import '../../services/pal/pal_service.dart' show PalAgenda;
import '../../theme/theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/day_scene.dart';
import '../../widgets/pal_label.dart';
import '../../widgets/press_scale.dart';
import '../mood/mood_logger_sheet.dart';
import 'day_plan.dart';
import 'today_logic.dart';

// kept literal: the shell overlay under the content, tab bar gap 8 + bar 62 +
// gap 10 + ask bar 52.
const double _shellOverlay = 132;
// kept literal: where the prototype's content starts, just under the status bar.
const double _contentTop = 52;
const double _minTap = 44;
const double _pillHeight = 48;
const double _cardGap = 14;
const double _rowDisc = 28;
const double _rowIcon = 18;
const double _rowGap = 10;
const double _rowInset = Spacing.xs;
// wide enough for "12:30 PM" in caption.
const double _timeWidth = 56;
const double _railWidth = 1;
const double _labelHeight = 18;
// the Why button's tap target overhangs the label row this much on each side.
const double _labelOverhang = (_minTap - _labelHeight) / 2;
const double _whyIcon = 14;
const double _leadMaxWidth = 300;
const double _leadMinHeight = 100;
const int _leadMaxLines = 3;
const double _dateTracking = 1.2;
// the timeline stays short so the lead is the only thing that reads first.
const int _laterShown = 2;
// the most of its row a secondary text button takes, so large text ellipsises
// it instead of crowding out the label or the primary pill.
const double _sideShare = 0.5;
const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

const String _restLead = 'Nothing is left. Rest up.';
const String _palOnline = 'Pal';
const String _palOffline = 'Pal is offline · next on the clock';
const String _why = 'Why this first';

/// The timeline's rail, drawn only when there are rows.
const Key todayRailKey = ValueKey('today.rail');

/// The action card, always shown once the day has loaded.
const Key todayCardKey = ValueKey('today.card');

/// Today: the scene, the date line, Pal's lead, one action card and a short
/// timeline of what is still open. Every number comes from local providers;
/// Pal only supplies the headline and its proposals.
class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  late final AppLifecycleListener _lifecycle;
  Timer? _minuteTick;
  PlanSession _session = const PlanSession();
  // once opened, the rest of the day stays listed while the screen lives.
  bool _allLater = false;

  @override
  void initState() {
    super.initState();
    // today stays mounted in the shell's indexed stack, so a resume on any tab
    // refetches and the brief is fresh when the user comes back.
    _lifecycle = AppLifecycleListener(onResume: _refresh);
    _scheduleTick();
  }

  @override
  void dispose() {
    _minuteTick?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  // the date line, the scene's phase and what is overdue all follow the clock.
  void _scheduleTick() {
    final toNextMinute = Duration.secondsPerMinute - clock.now().second;
    _minuteTick = Timer(Duration(seconds: toNextMinute), () {
      setState(() {});
      _scheduleTick();
    });
  }

  Future<void> _refresh() async {
    ref.invalidate(palAgendaProvider);
    await ref.read(todayBriefProvider.notifier).refresh();
  }

  void _settle(PlanItem item, {required bool done}) =>
      setState(() => _session = _session.settle(item.id, done: done));

  void _act(PlanItem item) {
    switch (item.kind) {
      case PlanKind.proposal:
        _settle(item, done: true);
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

  void _askWhy(PlanItem item) => context.pushNamed(AppRoute.palComposer.name,
      queryParameters: {'seed': 'Why ${item.title} first?', 'from': '/today'});

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
      data: (today) => RefreshIndicator(onRefresh: _refresh, child: _content(today)),
    );
  }

  Widget _content(TodayState today) {
    final now = clock.now();
    final agenda = ref.watch(palAgendaProvider);
    final headline = ref.watch(todayBriefProvider).value;
    final plan = buildDayPlan(
      agenda: agenda.value ?? const PalAgenda(),
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
    final current = plan.current(_session, now, rules);
    final palsLead = online && plan.isPalPick(_session, now, rules);
    final later = plan.later(_session, now, rules);
    final hidden = _allLater ? 0 : math.max(0, later.length - _laterShown);
    final shown = hidden > 0 ? later.take(_laterShown) : later;
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
              _shellOverlay + Spacing.xxl + safe.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: Spacing.md,
              children: [
                _Header(
                  date: dateLine(now),
                  onUndo: _session.canUndo
                      ? () => setState(() => _session = _session.undo())
                      : null,
                ),
                _Lead(
                  label: online ? _palOnline : _palOffline,
                  text: _leadFor(current, palsLead ? headline : null),
                  onWhy: palsLead ? () => _askWhy(current!) : null,
                ),
                _ActionCard(
                  item: current,
                  onAct: _act,
                  onSkip: (item) => _settle(item, done: false),
                ),
                if (later.isNotEmpty)
                  _Timeline(
                    rows: [
                      for (final item in shown)
                        _PlanRow(
                          item: item,
                          onTap: () => setState(() => _session = _session.select(item.id)),
                        ),
                      if (hidden > 0)
                        _MoreRow(
                          label: '$hidden more later today',
                          onTap: () => setState(() => _allLater = true),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Pal's [headline] when it leads, else the item's own sentence, else its
  /// title.
  String _leadFor(PlanItem? current, String? headline) {
    if (current == null) return _restLead;
    if (headline != null && headline.isNotEmpty) return headline;
    final said = current.said;
    return said != null && said.isNotEmpty ? said : current.title;
  }
}

/// The date line, and `Undo` while the session can undo.
class _Header extends StatelessWidget {
  const _Header({required this.date, required this.onUndo});

  final String date;
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _minTap),
      child: Row(
        children: [
          Expanded(
            child: Text(date,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.label.copyWith(color: c.ink2, letterSpacing: _dateTracking)),
          ),
          if (onUndo != null)
            PressScale(
              onTap: onUndo,
              child: Container(
                constraints: const BoxConstraints(minHeight: _minTap),
                padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                alignment: Alignment.center,
                child: Text('Undo', style: AppType.headline.copyWith(color: c.ink)),
              ),
            ),
        ],
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
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _leadMaxWidth),
                child: Text(text,
                    maxLines: _leadMaxLines,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.lead.copyWith(color: c.ink)),
              ),
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
          Column(
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

/// The open rows on a hairline rail.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final timeWidth = MediaQuery.textScalerOf(context).scale(_timeWidth);
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.sm),
      child: Stack(
        children: [
          Positioned(
            key: todayRailKey,
            left: _rowInset + timeWidth + _rowGap + (_rowDisc - _railWidth) / 2,
            top: _minTap / 2,
            bottom: _minTap / 2,
            width: _railWidth,
            child: ColoredBox(color: context.colors.hair),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
        ],
      ),
    );
  }
}

/// One open item; a tap makes it the lead.
class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.item, required this.onTap});

  final PlanItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final minute = item.minuteOfDay;
    final time = minute == null ? null : clockLabel(minute);
    return PressScale(
      onTap: onTap,
      semanticLabel:
          '${item.title}, ${time == null ? 'any time' : 'at $time'}. Do this next',
      pressedScale: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _minTap),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: _rowInset),
          child: Row(
            spacing: _rowGap,
            children: [
              SizedBox(
                width: MediaQuery.textScalerOf(context).scale(_timeWidth),
                child: Text(time ?? 'Any',
                    maxLines: 1,
                    style: AppType.caption.copyWith(color: c.ink3, fontFeatures: _tabular)),
              ),
              Container(
                width: _rowDisc,
                height: _rowDisc,
                decoration: BoxDecoration(color: c.surface2, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: AppIcon(item.icon, size: _rowIcon, color: c.ink),
              ),
              Expanded(
                child: Text(item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.callout.copyWith(color: c.ink)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `N more later today`, lined up with the row titles.
class _MoreRow extends StatelessWidget {
  const _MoreRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final timeWidth = MediaQuery.textScalerOf(context).scale(_timeWidth);
    return PressScale(
      onTap: onTap,
      pressedScale: 1,
      child: Container(
        constraints: const BoxConstraints(minHeight: _minTap),
        padding: EdgeInsets.only(
            left: _rowInset + timeWidth + _rowGap + _rowDisc + _rowGap, right: _rowInset),
        alignment: AlignmentDirectional.centerStart,
        child: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.subhead.copyWith(color: context.colors.ink3)),
      ),
    );
  }
}
