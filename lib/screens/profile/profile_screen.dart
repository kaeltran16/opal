import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/email_sync_controller.dart';
import '../../controllers/pal_agenda_controller.dart';
import '../../controllers/profile_controller.dart';
import '../../controllers/providers.dart';
import '../../controllers/today_controller.dart';
import '../../models/models.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../util/dates.dart';
import '../../util/format.dart';
import '../../widgets/budget_sheet.dart';
import '../../widgets/inset_section.dart';
import '../../widgets/nav_bar.dart';

/// Screen 15 — You / profile + settings (redesigned `YouTabScreen`).
///
/// A profile card followed by inset-grouped sections: Goals (daily budget
/// taps open the [BudgetSheet]), Reviews, Integrations, Data, and Account.
/// The live [Goals] record (watched via
/// [goalsStreamProvider]) feeds the Goals row values so they reflect the user's
/// real targets.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final async = ref.watch(goalsStreamProvider);
    final name = ref.watch(settingsRepositoryProvider).displayNameOrDefault;
    final stats = ref.watch(profileStatsProvider).asData?.value;
    final memberSince = stats?.memberSince;
    final routineCount = stats?.routineCount ?? 0;
    final currency = ref.watch(appSettingsControllerProvider).currency;
    // Pal's "needs you" count for the Reviews row badge (from the agenda seam).
    final palCount =
        ref.watch(palAgendaProvider).asData?.value.proposals.length;
    // Same connection-state source the email dashboard uses, so the You-tab
    // Integrations row can't claim "On" while the dashboard says "not connected".
    final emailConnected =
        ref.watch(emailDashboardControllerProvider).isConnected;

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
        tenure: _tenure(memberSince),
        routineCount: routineCount,
        currency: currency,
        palCount: palCount,
        emailConnected: emailConnected,
      ),
    );
  }

  /// Builds the `Tracking since <Month Year> · N days` line from the earliest
  /// entry date. Returns an honest placeholder when there's no entry history.
  static String _tenure(DateTime? memberSince, {DateTime? now}) {
    if (memberSince == null) return 'Just getting started';
    final today = now ?? DateTime.now();
    final month = kMonths[memberSince.month - 1];
    final start = startOfDay(memberSince);
    final end = startOfDay(today);
    final days = end.difference(start).inDays;
    return 'Tracking since $month ${memberSince.year} · $days days';
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({
    required this.goals,
    required this.name,
    required this.tenure,
    required this.routineCount,
    required this.currency,
    required this.palCount,
    required this.emailConnected,
  });
  final Goals goals;

  /// Display currency for money values (daily budget).
  final Currency currency;

  /// User's display name from onboarding; empty falls back to "You".
  final String name;

  /// Pre-computed tenure line (e.g. "Tracking since April 2026 · 70 days").
  final String tenure;

  /// Number of routines — the "Daily routines" goal value, matching the Today
  /// ring and Budgets & Goals (derived from the routine count, not the stored
  /// [Goals.dailyRitualTarget]).
  final int routineCount;

  /// Number of Pal proposals awaiting the user, shown as the Reviews row badge.
  /// Null while the agenda is still loading (badge hidden until it resolves).
  final int? palCount;

  /// Whether an email account is connected — drives the Integrations row value
  /// from the same source as the email dashboard.
  final bool emailConnected;

  void _openBudgetSheet(BuildContext context) {
    // present over the whole shell so the sheet's backdrop covers the tab bar
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: const Color(0x00000000),
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
    final displayName = name;
    final initial = displayName.characters.first.toUpperCase();

    return LargeTitleScrollView(
      title: 'You',
      subtitle: 'Reviews, patterns, settings',
      // You is now pushed from the Today header (not a tab root), so it needs
      // its own back affordance.
      leading: NavAction(
        icon: 'chevron.left',
        label: 'Today',
        onTap: () => context.pop(),
        semanticLabel: 'Back to Today',
      ),
      padding: const EdgeInsets.only(bottom: 110),
      children: [
        // --- Profile card ---
        Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.lg),
          child: Container(
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(Radii.lg),
              boxShadow: [
                BoxShadow(color: c.hair, blurRadius: 0, spreadRadius: 0.5),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [c.accent, c.move],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(initial,
                      style: AppType.title2.copyWith(color: c.onAccent)),
                ),
                const SizedBox(width: Spacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayName,
                          style: AppType.headline
                              .copyWith(color: c.ink, letterSpacing: -0.3)),
                      const SizedBox(height: Spacing.xxs),
                      Text(tenure,
                          style: AppType.footnote
                              .copyWith(color: c.ink3, letterSpacing: -0.08)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // --- Goals ---
        InsetSection(
          header: 'Goals',
          children: [
            ListRow(
              icon: 'dollarsign.circle.fill',
              iconBg: c.money,
              title: 'Daily budget',
              value: formatCurrency(goals.dailyBudget, currency),
              onTap: () => _openBudgetSheet(context),
            ),
            ListRow(
              icon: 'flame.fill',
              iconBg: c.move,
              title: 'Workout goal',
              value: '${goals.dailyMoveKcal} kcal',
              onTap: () => context.pushNamed(AppRoute.budgetsGoals.name),
            ),
            ListRow(
              icon: 'sparkles',
              iconBg: c.rituals,
              title: 'Daily routines',
              value: '$routineCount',
              chevron: false,
              last: true,
            ),
          ],
        ),

        // --- Money ---
        InsetSection(
          header: 'Money',
          children: [
            ListRow(
              icon: 'square.grid.2x2.fill',
              iconBg: c.money,
              title: 'Budgets',
              onTap: () => context.pushNamed(AppRoute.youBudgets.name),
              last: false,
            ),
            ListRow(
              icon: 'chart.bar.fill',
              iconBg: c.accent,
              title: 'Insights',
              onTap: () => context.pushNamed(AppRoute.youInsights.name),
              last: true,
            ),
          ],
        ),

        // --- Reviews ---
        InsetSection(
          header: 'Reviews',
          children: [
            ListRow(
              icon: 'sparkles',
              iconBg: c.accent,
              title: 'Pal',
              subtitle: "Your daily brief & what Pal's handling",
              value: palCount != null && palCount! > 0 ? '$palCount for you' : null,
              valueColor: c.accent,
              onTap: () => context.pushNamed(AppRoute.palHome.name),
            ),
            ListRow(
              icon: 'calendar',
              iconBg: c.rituals,
              title: "Today's recap",
              onTap: () => context.pushNamed(AppRoute.recap.name,
                  queryParameters: const {'range': 'day'}),
              last: true,
            ),
          ],
        ),

        // --- Integrations ---
        InsetSection(
          header: 'Integrations',
          children: [
            ListRow(
              icon: 'tray.fill',
              iconBg: c.accent,
              title: 'Email sync',
              value: emailConnected ? 'Gmail · On' : 'Not connected',
              last: true,
              onTap: () => context.pushNamed(AppRoute.emailSync.name),
            ),
          ],
        ),

        // --- Data ---
        InsetSection(
          header: 'Data',
          children: [
            ListRow(
              icon: 'chart.bar.fill',
              iconBg: c.move,
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
              icon: 'bell.fill',
              iconBg: c.money,
              title: 'Notifications',
              value: '3 new',
              last: true,
              onTap: () => context.pushNamed(AppRoute.notificationSettings.name),
            ),
          ],
        ),

        // --- Account ---
        InsetSection(
          header: 'Account',
          children: [
            ListRow(
              icon: 'gearshape.fill',
              iconBg: c.ink3,
              title: 'Settings',
              onTap: () => context.pushNamed(AppRoute.settings.name),
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
