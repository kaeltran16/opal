import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/mood_controller.dart';
import '../../controllers/nutrition_controller.dart';
import '../../controllers/pal_agenda_controller.dart';
import '../../controllers/providers.dart';
import '../../controllers/rituals_controller.dart';
import '../../controllers/sleep_controller.dart';
import '../../controllers/today_brief_controller.dart';
import '../../controllers/today_controller.dart';
import '../../models/models.dart';
import '../../router.dart';
import '../../services/pal/pal_service.dart' show PalAgenda, PalProposal;
import '../../theme/theme.dart';
import '../../util/dates.dart';
import '../../util/format.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/brief_text.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/whats_left_row.dart';
import '../pal/pal_agenda_widgets.dart';
import '../shell/tab_header.dart';
import 'today_area_cards.dart';
import 'today_logic.dart';

// kept literal: the shell overlay under the content, tab bar gap 8 + bar 62 +
// gap 10 + ask bar 52.
const double _shellOverlay = 132;
const double _minTap = 44;
const double _badgeSize = 22;
const double _doneTile = 32;

// when each area is naturally due, for the "Your day" order.
const int _sleepMinute = 0;
const int _moodMinute = 8 * 60;
const int _moneyMinute = 12 * 60;
const int _nutritionMinute = 12 * 60 + 30;
const int _moveMinute = 17 * 60;

/// Today, Pal first: the brief (or what's left when it's missing), what
/// needs the user, what Pal already did, then the areas in Pal's order.
/// Every number comes from local providers; Pal only supplies the lead.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              style: AppType.subhead
                  .copyWith(color: c.ink3, letterSpacing: -0.24)),
        ),
      ),
      data: (today) => _TodayBody(today: today),
    );
  }
}

/// Opens [area]'s detail from a brief chip or a what's-left column.
void _openArea(BuildContext context, TodayArea area) {
  final route = switch (area) {
    TodayArea.money => AppRoute.spendingDetail,
    TodayArea.move => AppRoute.moveDetail,
    _ => AppRoute.ritualsDetail,
  };
  context.pushNamed(route.name);
}

Widget _sectionTitle(AppColors c, String text) => Text(text,
    style: AppType.title3.copyWith(
        color: c.ink, fontWeight: FontWeight.w700, letterSpacing: -0.3));

class _TodayBody extends ConsumerWidget {
  const _TodayBody({required this.today});
  final TodayState today;

  /// Where each area stands, from the same providers its detail screen reads.
  List<AreaStatus> _statuses(WidgetRef ref, DateTime now) {
    final night = ref.watch(sleepControllerProvider).value?.lastNight;
    final checkin = ref.watch(moodControllerProvider).value?.lastCheckin;
    final meals = ref.watch(nutritionControllerProvider).value?.meals ?? const [];
    final next = ref.watch(ritualsControllerProvider).value?.upNext;
    return [
      AreaStatus(
        area: TodayArea.routines,
        complete: today.ritualsRemaining == 0,
        minuteOfDay: (next == null ? null : routineMinute(next.time)) ?? eveningMinute,
      ),
      AreaStatus(
        area: TodayArea.sleep,
        // a night is dated by the morning the user woke on.
        complete: night != null && startOfDay(night.night) == startOfDay(now),
        minuteOfDay: _sleepMinute,
      ),
      AreaStatus(area: TodayArea.mood, complete: checkin != null, minuteOfDay: _moodMinute),
      // the budget runs all day, so money is never done.
      const AreaStatus(area: TodayArea.money, complete: false, minuteOfDay: _moneyMinute),
      AreaStatus(
        area: TodayArea.move,
        complete: today.moveKcal >= today.goals.dailyMoveKcal,
        minuteOfDay: _moveMinute,
      ),
      AreaStatus(
          area: TodayArea.nutrition, complete: meals.isNotEmpty, minuteOfDay: _nutritionMinute),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final now = clock.now();
    final name = ref.watch(settingsRepositoryProvider).displayNameOrDefault;
    final currency = ref.watch(appSettingsControllerProvider).currency;
    final numbers = GlanceNumbers(
      spent: today.moneySpent,
      budget: today.goals.dailyBudget,
      moveKcal: today.moveKcal,
      moveGoal: today.goals.dailyMoveKcal,
      routinesDone: today.ritualsDone,
      routinesTotal: today.ritualsTarget,
    );
    final doneByPal = today.entries.where((e) => isDoneByPal(e, now)).toList();
    final order = orderAreas(_statuses(ref, now));

    return TabHeaderScrollView(
      title: 'Today',
      eyebrow: '${kWeekdays[now.weekday - 1]}, ${kMonths[now.month - 1]} ${now.day}'
          .toUpperCase(),
      largeTitle: '${greetingFor(now)}, $name',
      padding: EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg,
          _shellOverlay + Spacing.xxl + MediaQuery.paddingOf(context).bottom),
      children: [
        _Brief(numbers: numbers, currency: currency),
        const _NeedsYou(),
        if (doneByPal.isNotEmpty) _DoneByPal(entries: doneByPal, currency: currency),
        Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.xs, Spacing.xxl, Spacing.xs, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(child: _sectionTitle(c, 'Your day')),
              Text('Ordered by Pal', style: AppType.footnote.copyWith(color: c.ink3)),
            ],
          ),
        ),
        for (final area in order) ...[
          const SizedBox(height: Spacing.md),
          TodayAreaCard(area: area, today: today),
        ],
      ],
    );
  }
}

/// Pal's lead plus the number chips, or the what's-left row while there is no
/// headline. The chips sit on a surface card: area tints on the grey page
/// fall short of 4.5:1.
class _Brief extends ConsumerWidget {
  const _Brief({required this.numbers, required this.currency});

  final GlanceNumbers numbers;
  final Currency currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final brief = ref.watch(todayBriefProvider);
    void open(TodayArea area) => _openArea(context, area);

    if (briefMode(brief) == BriefMode.fallback) {
      return Padding(
        padding: const EdgeInsets.only(top: Spacing.sm),
        child: WhatsLeftRow(numbers: numbers, currency: currency, onTap: open),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.md, Spacing.lg, Spacing.md),
      decoration: todayCard(c),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon('sparkles', size: 14, color: c.accentInk),
              const SizedBox(width: Spacing.xs + Spacing.xxs),
              Text('Pal',
                  style: AppType.footnote
                      .copyWith(fontWeight: FontWeight.w600, color: c.accentInk)),
            ],
          ),
          BriefText(lead: brief.value!, numbers: numbers, currency: currency, onChip: open),
        ],
      ),
    );
  }
}

/// Pending proposals with approve / Not now, hidden when there are none. The
/// card states are local overrides on top of the agenda.
class _NeedsYou extends ConsumerStatefulWidget {
  const _NeedsYou();

  @override
  ConsumerState<_NeedsYou> createState() => _NeedsYouState();
}

class _NeedsYouState extends ConsumerState<_NeedsYou> {
  final Map<String, CardStatus> _statusById = {};

  CardStatus _statusOf(String id) => _statusById[id] ?? CardStatus.open;

  void _onApprove(PalProposal p) {
    if (p.navigatesToCloseOut) {
      context.pushNamed(AppRoute.eveningCloseOut.name);
      return;
    }
    setState(() => _statusById[p.id] = CardStatus.done);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final agenda = ref.watch(palAgendaProvider).value ?? const PalAgenda();
    final visible =
        agenda.proposals.where((p) => _statusOf(p.id) != CardStatus.dismissed).toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    final open = visible.where((p) => _statusOf(p.id) == CardStatus.open).length;

    return Padding(
      padding: const EdgeInsets.only(top: Spacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
            child: Row(
              children: [
                _sectionTitle(c, 'Needs you'),
                if (open > 0) ...[
                  const SizedBox(width: Spacing.sm),
                  Semantics(
                    container: true,
                    label: '$open need you',
                    excludeSemantics: true,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: _badgeSize),
                      height: _badgeSize,
                      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
                      decoration: BoxDecoration(
                        color: c.accentInk,
                        borderRadius: BorderRadius.circular(Radii.pill),
                      ),
                      alignment: Alignment.center,
                      child: Text('$open',
                          style: AppFonts.sfr(
                              size: 13, weight: FontWeight.w800, color: c.surface)),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: Spacing.md),
          NeedsYouSection(
            loading: false,
            proposals: visible,
            done: (p) => _statusOf(p.id) == CardStatus.done,
            onApprove: _onApprove,
            onDismiss: (p) => setState(() => _statusById[p.id] = CardStatus.dismissed),
            onUndo: (p) => setState(() => _statusById[p.id] = CardStatus.open),
          ),
        ],
      ),
    );
  }
}

/// Today's Gmail-receipt entries, each undoable. A row whose entry is deleted
/// elsewhere drops out on the next stream emit.
class _DoneByPal extends ConsumerWidget {
  const _DoneByPal({required this.entries, required this.currency});

  final List<Entry> entries;
  final Currency currency;

  Future<void> _undo(BuildContext context, WidgetRef ref, Entry e) async {
    final messenger = ScaffoldMessenger.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    try {
      await ref.read(entryRepositoryProvider).deleteById(e.id);
    } catch (err) {
      debugPrint('today: undo of entry ${e.id} failed: $err');
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
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(top: Spacing.xxl),
      decoration: todayCard(c),
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++)
            Container(
              padding: const EdgeInsets.fromLTRB(
                  Spacing.lg, Spacing.sm, Spacing.sm, Spacing.sm),
              decoration: BoxDecoration(
                border: i == 0
                    ? null
                    : Border(top: BorderSide(color: c.hair, width: 0.5)),
              ),
              child: _row(context, ref, c, entries[i]),
            ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, WidgetRef ref, AppColors c, Entry e) {
    final amount = e.amount;
    final title = amount == null
        ? e.title
        : '${e.title}, ${formatCurrency(amount, currency, withSign: true, trimZeroCents: false)}';
    return Row(
      children: [
        Container(
          width: _doneTile,
          height: _doneTile,
          decoration: BoxDecoration(color: c.accentTint, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: AppIcon('sparkles', size: 15, color: c.accentInk),
        ),
        const SizedBox(width: Spacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: AppType.subhead.copyWith(fontWeight: FontWeight.w600, color: c.ink)),
              Text('Done by Pal · from your Gmail receipt',
                  style: AppType.footnote.copyWith(color: c.ink3)),
            ],
          ),
        ),
        const SizedBox(width: Spacing.sm),
        PressScale(
          onTap: () => _undo(context, ref, e),
          semanticLabel: 'Undo ${e.title}',
          child: Container(
            height: _minTap,
            padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
            decoration: BoxDecoration(
              color: c.accentTint,
              borderRadius: BorderRadius.circular(Radii.pill),
            ),
            alignment: Alignment.center,
            child: Text('Undo',
                style: AppType.subhead.copyWith(fontWeight: FontWeight.w600, color: c.accentInk)),
          ),
        ),
      ],
    );
  }
}
