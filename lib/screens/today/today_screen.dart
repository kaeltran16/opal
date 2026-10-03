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
import '../../controllers/providers.dart';
import '../../controllers/rituals_controller.dart';
import '../../controllers/sleep_controller.dart';
import '../../controllers/spending_controller.dart' show DetailTracker;
import '../../controllers/today_brief_controller.dart';
import '../../controllers/today_controller.dart';
import '../../controllers/weekly_plan_controller.dart';
import '../../models/models.dart';
import '../../router.dart';
import '../../services/pal/pal_service.dart' show PalAgenda;
import '../../theme/theme.dart';
import '../../util/format.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/day_scene.dart';
import '../../widgets/pal_label.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/shortcut_ring.dart';
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
const double _cardDisc = 48;
const double _cardIcon = 24;
const double _rowDisc = 28;
const double _rowIcon = 18;
const double _rowGap = 10;
const double _rowInset = Spacing.xs;
// wide enough for "12:30 PM" in caption.
const double _timeWidth = 56;
const double _railWidth = 1;
const double _leadMaxWidth = 300;
const double _leadMinHeight = 100;
const double _leadGap = 6;
const int _leadMaxLines = 3;
const int _receiptTitleLines = 2;
const double _dateTracking = 1.2;
const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

const String _restLead = 'Nothing is left. Rest up.';
const String _doneIcon = 'moon.stars.fill';

/// The timeline's rail, drawn only when there are rows.
const Key todayRailKey = ValueKey('today.rail');

/// Today: the scene, the date line, three rings, Pal's lead, one action card
/// and the day's timeline. Every number comes from local providers; Pal only
/// supplies the lead and its proposals.
class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  late final AppLifecycleListener _lifecycle;
  Timer? _minuteTick;
  PlanSession _session = const PlanSession();

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
        final proposals = ref.read(palAgendaProvider).value?.proposals ?? const [];
        final toCloseOut = proposals.any((p) => p.id == item.ref && p.navigatesToCloseOut);
        if (toCloseOut) {
          context.pushNamed(AppRoute.eveningCloseOut.name);
        } else {
          _settle(item, done: true);
        }
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
      // informational rows never reach the card.
      case PlanKind.sleep:
      case PlanKind.receipt:
        break;
    }
  }

  /// Where a done row leads, or null when it has no screen of its own.
  VoidCallback? _opener(PlanItem item) => switch (item.kind) {
        PlanKind.sleep => () => context.pushNamed(AppRoute.todaySleep.name),
        PlanKind.mood => () => context.pushNamed(AppRoute.todayMood.name),
        PlanKind.meal => () => context.goNamed(AppRoute.nutrition.name),
        PlanKind.routine => () => context.pushNamed(AppRoute.ritualsDetail.name),
        _ => null,
      };

  Future<void> _undoReceipt(String entryId) async {
    final messenger = ScaffoldMessenger.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    try {
      await ref.read(entryRepositoryProvider).deleteById(entryId);
    } catch (err) {
      debugPrint('today: undo of entry $entryId failed: $err');
      messenger.showSnackBar(SnackBar(
        content: const Text("Couldn't undo. Try again."),
        behavior: SnackBarBehavior.floating,
        // just above the tab bar and ask bar, never over the header.
        margin: EdgeInsets.fromLTRB(
            Spacing.lg, 0, Spacing.lg, _shellOverlay + Spacing.sm + bottom),
      ));
    }
  }

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
    final currency = ref.watch(appSettingsControllerProvider).currency;
    final plan = buildDayPlan(
      agenda: ref.watch(palAgendaProvider).value ?? const PalAgenda(),
      rituals: ref.watch(ritualsControllerProvider).value,
      workout: ref.watch(weeklyPlanControllerProvider).value?.today,
      lastNight: ref.watch(sleepControllerProvider).value?.lastNight,
      lastCheckin: ref.watch(moodControllerProvider).value?.lastCheckin,
      meals: ref.watch(nutritionControllerProvider).value?.meals ?? const [],
      entries: today.entries,
      now: now,
    );
    final current = plan.current(_session, now);
    final later = plan.later(_session, now);
    final done = plan.doneRows;
    final glances = areaGlances(
      GlanceNumbers(
        spent: today.moneySpent,
        budget: today.goals.dailyBudget,
        moveKcal: today.moveKcal,
        moveGoal: today.goals.dailyMoveKcal,
        routinesDone: today.ritualsDone,
        routinesTotal: today.ritualsTarget,
      ),
      currency,
      now,
    );
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
              children: [
                _Header(
                  date: dateLine(now),
                  progress: '${plan.doneCount(_session)} of ${plan.total} done',
                  onUndo: _session.canUndo
                      ? () => setState(() => _session = _session.undo())
                      : null,
                ),
                const SizedBox(height: Spacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (i, g) in glances.indexed) ...[
                      if (i > 0) const SizedBox(width: Spacing.sm),
                      Expanded(
                        child: ShortcutRing(
                          icon: _ringIcon(g.tracker),
                          value: g.value,
                          state: g.state,
                          fraction: g.fraction,
                          semanticLabel: g.semantics,
                          onTap: () => context.pushNamed(_ringRoute(g.tracker).name),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: Spacing.md),
                _Lead(text: _leadFor(current)),
                const SizedBox(height: Spacing.md),
                _ActionCard(
                  item: current,
                  when: current == null ? null : plan.whenLabel(current, _session, now),
                  onAct: _act,
                  onSkip: (item) => _settle(item, done: false),
                ),
                const SizedBox(height: Spacing.md),
                if (later.isNotEmpty || done.isNotEmpty)
                  _Timeline(
                    rows: [
                      for (final item in later)
                        _PlanRow(
                          item: item,
                          title: item.title,
                          semanticLabel: '${item.title}, '
                              '${item.minuteOfDay == null ? 'any time' : 'at ${clockLabel(item.minuteOfDay!)}'}'
                              '. Do this next',
                          onTap: () => setState(() => _session = _session.select(item.id)),
                        ),
                      for (final item in done)
                        if (item.kind == PlanKind.receipt)
                          _receiptRow(item, today.entries, currency)
                        else
                          _PlanRow(
                            item: item,
                            title: item.title,
                            quiet: true,
                            onTap: _opener(item),
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

  /// Pal's headline, else the current item's own sentence, else its title.
  String _leadFor(PlanItem? current) {
    if (current == null) return _restLead;
    final headline = ref.watch(todayBriefProvider).value;
    if (headline != null && headline.isNotEmpty) return headline;
    final said = current.said;
    return said != null && said.isNotEmpty ? said : current.title;
  }

  Widget _receiptRow(PlanItem item, List<Entry> entries, Currency currency) {
    final amount = entries.where((e) => e.id == item.ref).firstOrNull?.amount;
    final title = amount == null
        ? 'Logged ${item.title}'
        : 'Logged ${item.title}, ${formatCurrency(amount, currency, withSign: true, trimZeroCents: false)}';
    return _PlanRow(
      item: item,
      title: title,
      // the amount is the end of the line; beside Undo one line would cut it.
      titleLines: _receiptTitleLines,
      quiet: true,
      trailing: PressScale(
        onTap: () => _undoReceipt(item.ref!),
        semanticLabel: 'Undo ${item.title}',
        child: Container(
          constraints: const BoxConstraints(minHeight: _minTap),
          padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
          alignment: Alignment.center,
          child: Text('Undo',
              style: AppType.subhead
                  .copyWith(fontWeight: FontWeight.w600, color: context.colors.ink)),
        ),
      ),
    );
  }
}

String _ringIcon(DetailTracker tracker) => switch (tracker) {
      DetailTracker.money => 'dollarsign.circle.fill',
      DetailTracker.move => 'figure.run',
      DetailTracker.rituals => 'sparkles',
    };

AppRoute _ringRoute(DetailTracker tracker) => switch (tracker) {
      DetailTracker.money => AppRoute.spendingDetail,
      DetailTracker.move => AppRoute.moveDetail,
      DetailTracker.rituals => AppRoute.ritualsDetail,
    };

/// The date line, `Undo` while the session can undo, and the day's progress.
class _Header extends StatelessWidget {
  const _Header({required this.date, required this.progress, required this.onUndo});

  final String date, progress;
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final label = AppType.label.copyWith(color: c.ink2);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _minTap),
      child: Row(
        children: [
          Expanded(
            child: Text(date,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: label.copyWith(letterSpacing: _dateTracking)),
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
          const SizedBox(width: Spacing.sm),
          Text(progress, style: label.copyWith(fontFeatures: _tabular)),
        ],
      ),
    );
  }
}

/// Pal's line for the day, the screen's only serif.
class _Lead extends StatelessWidget {
  const _Lead({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _leadMinHeight),
        child: Padding(
          padding: const EdgeInsets.only(top: Spacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PalLabel(),
              const SizedBox(height: _leadGap),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _leadMaxWidth),
                child: Text(text,
                    maxLines: _leadMaxLines,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.lead.copyWith(color: context.colors.ink)),
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
  const _ActionCard({
    required this.item,
    required this.when,
    required this.onAct,
    required this.onSkip,
  });

  final PlanItem? item;
  final String? when;
  final void Function(PlanItem) onAct;
  final void Function(PlanItem) onSkip;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final item = this.item;
    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: c.hair),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: _cardDisc,
                height: _cardDisc,
                decoration: BoxDecoration(color: c.surface2, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: AppIcon(item?.icon ?? _doneIcon, size: _cardIcon, color: c.ink),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(when ?? 'All done',
                        style: AppType.label
                            .copyWith(color: c.ink3, fontFeatures: _tabular)),
                    const SizedBox(height: Spacing.xxs),
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
          if (item != null) ...[
            const SizedBox(height: Spacing.lg),
            Row(
              children: [
                Expanded(
                  child: _Pill(
                    label: item.actionLabel,
                    primary: true,
                    onTap: () => onAct(item),
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                _Pill(label: item.skipLabel, primary: false, onTap: () => onSkip(item)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.primary, required this.onTap});

  final String label;
  final bool primary;
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
          color: primary ? c.ink : c.surface2,
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        alignment: Alignment.center,
        child: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.headline.copyWith(color: primary ? c.bg : c.ink)),
      ),
    );
  }
}

/// The rows of the day on a hairline rail: what is still to do, then what is
/// done.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final timeWidth = MediaQuery.textScalerOf(context).scale(_timeWidth);
    return Stack(
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
    );
  }
}

/// One timeline row. [quiet] rows are done; a row with no [onTap] is a record.
class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.item,
    required this.title,
    this.titleLines = 1,
    this.quiet = false,
    this.semanticLabel,
    this.onTap,
    this.trailing,
  });

  final PlanItem item;
  final String title;
  final int titleLines;
  final bool quiet;
  final String? semanticLabel;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ink = quiet ? c.ink3 : c.ink;
    final minute = item.minuteOfDay;
    final detail = item.detail;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _minTap),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _rowInset),
        child: Row(
          children: [
            SizedBox(
              width: MediaQuery.textScalerOf(context).scale(_timeWidth),
              child: Text(minute == null ? 'Any' : clockLabel(minute),
                  maxLines: 1,
                  style: AppType.caption.copyWith(color: c.ink3, fontFeatures: _tabular)),
            ),
            const SizedBox(width: _rowGap),
            Container(
              width: _rowDisc,
              height: _rowDisc,
              decoration: BoxDecoration(color: c.surface2, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: AppIcon(item.icon, size: _rowIcon, color: ink),
            ),
            const SizedBox(width: _rowGap),
            Expanded(
              child: Text(title,
                  maxLines: titleLines,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.callout.copyWith(color: ink)),
            ),
            if (detail != null) ...[
              const SizedBox(width: Spacing.sm),
              Text(detail,
                  style: AppType.subhead.copyWith(color: c.ink3, fontFeatures: _tabular)),
            ],
            ?trailing,
          ],
        ),
      ),
    );
    if (onTap == null) return row;
    return PressScale(
      onTap: onTap,
      semanticLabel: semanticLabel,
      pressedScale: 1,
      child: row,
    );
  }
}
