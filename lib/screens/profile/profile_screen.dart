import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/email_sync_controller.dart';
import '../../controllers/pal_agenda_controller.dart';
import '../../controllers/pal_memory_controller.dart';
import '../../controllers/profile_controller.dart';
import '../../controllers/providers.dart';
import '../../controllers/today_controller.dart';
import '../../models/models.dart';
import '../../router.dart';
import '../../services/pal/pal_context_builder.dart' show moveStreakDays;
import '../../services/pal/pal_service.dart';
import '../../theme/theme.dart';
import '../../util/dates.dart';
import '../../util/format.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/budget_sheet.dart';
import '../../widgets/inset_section.dart';
import '../../widgets/nav_bar.dart';
import '../pal/pal_agenda_widgets.dart';
import '../pal/pal_noticed_section.dart';

// kept literal: the shell overlay under the content, tab bar gap 8 + bar 62 +
// gap 10 + ask bar 52 (the same stack Today clears).
const double _shellOverlay = 132;
const double _avatar = 56;
const double _pillHeight = 26;

/// The You tab: a profile card with the workout streak, then Pal (what it
/// remembers, what it runs on autopilot, what it noticed), then Goals and the
/// settings sections. Daily budget taps open the [BudgetSheet]; the live
/// [Goals] record feeds the Goals values.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();

  /// Builds the `Tracking since <Month Year> · N days` line from the earliest
  /// entry date. Returns an honest placeholder when there's no entry history.
  static String _tenure(DateTime? memberSince, {DateTime? now}) {
    if (memberSince == null) return 'Just getting started';
    final today = now ?? clock.now();
    final month = kMonths[memberSince.month - 1];
    final start = startOfDay(memberSince);
    final end = startOfDay(today);
    final days = end.difference(start).inDays;
    return 'Tracking since $month ${memberSince.year} · $days days';
  }
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  // held here rather than in the list rows so a toggle survives the rows
  // scrolling out of the lazy list.
  final Map<String, bool> _autopilotById = {};
  // patterns have no id; dismiss is local and session-only.
  final Set<String> _dismissedPatterns = {};

  bool _autopilotOn(PalAutopilotItem a) => _autopilotById[a.id] ?? a.enabled;

  /// Shown just above the tab bar and ask bar, never over the header.
  void _showError(String message) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.fromLTRB(
          Spacing.lg, 0, Spacing.lg, _shellOverlay + Spacing.sm + bottom),
    ));
  }

  Future<void> _deleteFact(PalFact fact) async {
    try {
      await ref.read(palServiceProvider).deleteFact(fact.id);
    } catch (e) {
      debugPrint('you: forgetting fact ${fact.id} failed: $e');
      if (mounted) _showError("Couldn't forget that. Try again.");
      return;
    }
    ref.invalidate(palMemoryProvider);
  }

  Future<void> _wipeMemory() async {
    final danger = context.colors.dangerInk;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all memory?'),
        content: const Text(
            "Pal will forget every fact and pattern. This can't be undone."),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(foregroundColor: danger),
              child: const Text('Clear')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(palServiceProvider).clearMemory();
    } catch (e) {
      debugPrint('you: clearing Pal memory failed: $e');
      if (mounted) _showError("Couldn't clear what Pal remembers. Try again.");
      return;
    }
    ref.invalidate(palMemoryProvider);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final async = ref.watch(goalsStreamProvider);
    final name = ref.watch(settingsRepositoryProvider).displayNameOrDefault;
    final stats = ref.watch(profileStatsProvider).asData?.value;
    final routineCount = stats?.routineCount ?? 0;
    final currency = ref.watch(appSettingsControllerProvider).currency;
    // the live workout streak from real entries, as the Move week strip and
    // the streak celebration count it; the agenda's streakDays can drift.
    final entries = ref.watch(allEntriesStreamProvider).asData?.value;
    final streakDays = entries == null ? 0 : moveStreakDays(entries);
    final agenda = ref.watch(palAgendaProvider).asData?.value ?? const PalAgenda();
    final memory =
        ref.watch(palMemoryProvider).asData?.value ?? const PalMemoryDigest();
    // Same connection-state source the email dashboard uses, so the You-tab
    // Integrations row can't claim "On" while the dashboard says "not connected".
    final emailConnected =
        ref.watch(emailDashboardControllerProvider).isConnected;

    final pal = <Widget>[
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Label('Pal'),
            MemoryCard(
              memory: PalMemoryDigest(
                facts: memory.facts,
                patterns: memory.patterns
                    .where((p) => !_dismissedPatterns.contains(p.title))
                    .toList(),
              ),
              onDeleteFact: _deleteFact,
              onDismissPattern: (p) =>
                  setState(() => _dismissedPatterns.add(p.title)),
              onWipe: _wipeMemory,
            ),
            if (agenda.autopilot.isNotEmpty) ...[
              const SizedBox(height: Spacing.md),
              AutopilotCard(
                items: agenda.autopilot,
                isOn: _autopilotOn,
                onToggle: (a) =>
                    setState(() => _autopilotById[a.id] = !_autopilotOn(a)),
              ),
            ],
          ],
        ),
      ),
      const PalNoticedSection(),
      const SizedBox(height: Spacing.xxl),
    ];

    return async.when(
      loading: () => Center(
        child: Text('…', style: AppType.body.copyWith(color: c.ink3)),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.xxl),
          child: Text("Couldn't load your profile.",
              textAlign: TextAlign.center,
              style: AppType.subhead
                  .copyWith(color: c.ink3, letterSpacing: -0.24)),
        ),
      ),
      data: (goals) => _ProfileBody(
        goals: goals,
        name: name,
        streakDays: streakDays,
        tenure: ProfileScreen._tenure(stats?.memberSince),
        routineCount: routineCount,
        currency: currency,
        emailConnected: emailConnected,
        pal: pal,
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({
    required this.goals,
    required this.name,
    required this.streakDays,
    required this.tenure,
    required this.routineCount,
    required this.currency,
    required this.emailConnected,
    required this.pal,
  });
  final Goals goals;

  /// Display currency for money values (daily budget).
  final Currency currency;

  /// User's display name from onboarding; empty falls back to "You".
  final String name;

  /// Current workout streak; the card shows [tenure] instead when it is 0.
  final int streakDays;

  /// Pre-computed tenure line (e.g. "Tracking since April 2026 · 70 days").
  final String tenure;

  /// Number of routines — the "Daily routines" goal value, matching the Today
  /// ring and Budgets & Goals (derived from the routine count, not the stored
  /// [Goals.dailyRitualTarget]).
  final int routineCount;

  /// Whether an email account is connected — drives the Integrations row value
  /// from the same source as the email dashboard.
  final bool emailConnected;

  /// The Pal section, built by the screen state that owns its overrides.
  final List<Widget> pal;

  void _openBudgetSheet(BuildContext context) {
    // present over the whole shell so the sheet's backdrop covers the tab bar
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, animation, secondary) =>
            BudgetSheet(dailyBudget: goals.dailyBudget),
        transitionsBuilder: (context, animation, secondary, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: const Cubic(0.2, 0.8, 0.2, 1),
            reverseCurve: Curves.easeInCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                .animate(curved),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final initial = name.characters.first.toUpperCase();

    return LargeTitleScrollView(
      title: 'You',
      padding: EdgeInsets.only(
          bottom: _shellOverlay + Spacing.xxl + MediaQuery.paddingOf(context).bottom),
      children: [
        // --- Profile card ---
        Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.xxl),
          child: Container(
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: _cardDecoration(c),
            child: Row(
              children: [
                Container(
                  width: _avatar,
                  height: _avatar,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: c.accent),
                  alignment: Alignment.center,
                  child: Text(initial,
                      style: AppFonts.sfr(
                          size: 24, weight: FontWeight.w800, color: c.onAccent)),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: AppType.title3.copyWith(
                              color: c.ink,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3)),
                      const SizedBox(height: Spacing.xs),
                      if (streakDays > 0)
                        _StreakPill(days: streakDays)
                      else
                        Text(tenure,
                            style: AppType.footnote.copyWith(color: c.ink3)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        ...pal,

        // --- Goals ---
        _Group(
          label: 'Goals',
          children: [
            ListRow(
              icon: 'dollarsign.circle.fill',
              iconBg: c.moneyTint,
              iconColor: c.moneyInk,
              title: 'Daily budget',
              value: formatCurrency(goals.dailyBudget, currency),
              onTap: () => _openBudgetSheet(context),
            ),
            ListRow(
              icon: 'flame.fill',
              iconBg: c.moveTint,
              iconColor: c.moveInk,
              title: 'Workout goal',
              value: '${goals.dailyMoveKcal} kcal',
              onTap: () => context.pushNamed(AppRoute.budgetsGoals.name),
            ),
            ListRow(
              icon: 'sparkles',
              iconBg: c.ritualsTint,
              iconColor: c.ritualsInk,
              title: 'Daily routines',
              value: '$routineCount',
              chevron: false,
              last: true,
            ),
          ],
        ),

        // --- Money ---
        _Group(
          label: 'Money',
          children: [
            ListRow(
              icon: 'square.grid.2x2.fill',
              iconBg: c.moneyTint,
              iconColor: c.moneyInk,
              title: 'Budgets',
              onTap: () => context.pushNamed(AppRoute.youBudgets.name),
            ),
            ListRow(
              icon: 'chart.bar.fill',
              iconBg: c.accentTint,
              iconColor: c.accentInk,
              title: 'Insights',
              onTap: () => context.pushNamed(AppRoute.youInsights.name),
              last: true,
            ),
          ],
        ),

        // --- Reviews ---
        _Group(
          label: 'Reviews',
          children: [
            ListRow(
              icon: 'calendar',
              iconBg: c.ritualsTint,
              iconColor: c.ritualsInk,
              title: "Today's recap",
              onTap: () => context.pushNamed(AppRoute.recap.name,
                  queryParameters: const {'range': 'day'}),
              last: true,
            ),
          ],
        ),

        // --- Integrations ---
        _Group(
          label: 'Integrations',
          children: [
            ListRow(
              icon: 'tray.fill',
              iconBg: c.accentTint,
              iconColor: c.accentInk,
              title: 'Email sync',
              value: emailConnected ? 'Gmail · On' : 'Not connected',
              last: true,
              onTap: () => context.pushNamed(AppRoute.emailSync.name),
            ),
          ],
        ),

        // --- Data ---
        _Group(
          label: 'Data',
          children: [
            ListRow(
              icon: 'chart.bar.fill',
              iconBg: c.moveTint,
              iconColor: c.moveInk,
              title: 'All stats',
              onTap: () => context.pushNamed(AppRoute.recap.name,
                  queryParameters: const {'range': 'week'}),
            ),
            ListRow(
              icon: 'tray.fill',
              iconBg: c.ink3,
              title: 'Export data',
              onTap: () => context.pushNamed(AppRoute.exportData.name),
            ),
            ListRow(
              icon: 'lock.fill',
              iconBg: c.ink3,
              title: 'Privacy',
              onTap: () => context.pushNamed(AppRoute.privacy.name),
            ),
            ListRow(
              icon: 'bell.fill',
              iconBg: c.moneyTint,
              iconColor: c.moneyInk,
              title: 'Notifications',
              value: '3 new',
              last: true,
              onTap: () => context.pushNamed(AppRoute.notificationSettings.name),
            ),
          ],
        ),

        // --- Account ---
        _Group(
          label: 'Account',
          children: [
            ListRow(
              icon: 'slider.horizontal.3',
              iconBg: c.ink3,
              title: 'Appearance',
              onTap: () => context.pushNamed(AppRoute.appearance.name),
            ),
            ListRow(
              icon: 'book.closed.fill',
              iconBg: c.ink3,
              title: 'About Opal',
              onTap: () => context.pushNamed(AppRoute.about.name),
            ),
            ListRow(
              icon: 'heart.fill',
              iconBg: c.red,
              title: 'Help & feedback',
              last: true,
            ),
          ],
        ),
      ],
    );
  }
}

BoxDecoration _cardDecoration(AppColors c) => BoxDecoration(
      color: c.surface,
      borderRadius: BorderRadius.circular(Radii.xxl),
      boxShadow: [BoxShadow(color: c.hair, blurRadius: 0, spreadRadius: 0.5)],
    );

/// The 13 pt bold uppercase label above a group.
class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.xs, 0, Spacing.xs, Spacing.sm),
      child: Text(text.toUpperCase(),
          style: AppType.footnote.copyWith(
              fontWeight: FontWeight.w700,
              color: context.colors.ink3,
              letterSpacing: 0.2)),
    );
  }
}

/// A labelled list group on a top-level surface card.
class _Group extends StatelessWidget {
  const _Group({required this.label, required this.children});
  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Label(label),
          Container(
            decoration: _cardDecoration(context.colors),
            clipBehavior: Clip.antiAlias,
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

/// The "N-day workout streak" pill, in the move tint and ink.
class _StreakPill extends StatelessWidget {
  const _StreakPill({required this.days});
  final int days;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      // grows rather than clips at large text sizes.
      constraints: const BoxConstraints(minHeight: _pillHeight),
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md, vertical: Spacing.xxs),
      decoration: BoxDecoration(
          color: c.moveTint, borderRadius: BorderRadius.circular(Radii.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon('bolt.fill', size: 12, color: c.moveInk),
          const SizedBox(width: Spacing.xs),
          Flexible(
            child: Text('$days-day workout streak',
                style: AppType.footnote
                    .copyWith(fontWeight: FontWeight.w600, color: c.moveInk)),
          ),
        ],
      ),
    );
  }
}
