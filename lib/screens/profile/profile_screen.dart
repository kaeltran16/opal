import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/profile_controller.dart';
import '../../controllers/providers.dart';
import '../../controllers/today_controller.dart';
import '../../models/models.dart';
import '../../router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
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
    final name = ref.watch(settingsRepositoryProvider).displayName;
    final memberSince =
        ref.watch(profileStatsProvider).asData?.value.memberSince;

    return async.when(
      loading: () => Center(
        child: Text('…',
            style: AppFonts.sf(size: 17, color: c.ink3, letterSpacing: -0.43)),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text("Couldn't load your profile.",
              textAlign: TextAlign.center,
              style:
                  AppFonts.sf(size: 15, color: c.ink3, letterSpacing: -0.24)),
        ),
      ),
      data: (goals) =>
          _ProfileBody(goals: goals, name: name, tenure: _tenure(memberSince)),
    );
  }

  /// Builds the `Tracking since <Month Year> · N days` line from the earliest
  /// entry date. Returns an honest placeholder when there's no entry history.
  static String _tenure(DateTime? memberSince, {DateTime? now}) {
    if (memberSince == null) return 'Just getting started';
    final today = now ?? DateTime.now();
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final month = months[memberSince.month - 1];
    final start =
        DateTime(memberSince.year, memberSince.month, memberSince.day);
    final end = DateTime(today.year, today.month, today.day);
    final days = end.difference(start).inDays;
    return 'Tracking since $month ${memberSince.year} · $days days';
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({
    required this.goals,
    required this.name,
    required this.tenure,
  });
  final Goals goals;

  /// User's display name from onboarding; empty falls back to "You".
  final String name;

  /// Pre-computed tenure line (e.g. "Tracking since April 2026 · 70 days").
  final String tenure;

  String _grouped(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

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
    final displayName = name.isEmpty ? 'You' : name;
    final initial = displayName.characters.first.toUpperCase();

    return ListView(
      padding: const EdgeInsets.only(bottom: 110),
      children: [
        const LargeTitleNavBar(
          title: 'You',
          subtitle: 'Reviews, patterns, settings',
          trailing: NavIconButton(name: 'gearshape.fill', semanticLabel: 'Settings'),
        ),

        // --- Profile card ---
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(18),
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
                      style: AppFonts.sf(
                          size: 22,
                          weight: FontWeight.w700,
                          color: const Color(0xFFFFFFFF))),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayName,
                          style: AppFonts.sf(
                              size: 17,
                              weight: FontWeight.w600,
                              color: c.ink,
                              letterSpacing: -0.3)),
                      const SizedBox(height: 2),
                      Text(tenure,
                          style: AppFonts.sf(
                              size: 13, color: c.ink3, letterSpacing: -0.08)),
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
              value: '\$${_grouped(goals.dailyBudget.round())}',
              onTap: () => _openBudgetSheet(context),
            ),
            ListRow(
              icon: 'flame.fill',
              iconBg: c.move,
              title: 'Workout goal',
              value: '${goals.dailyMoveMinutes} min',
              chevron: false,
            ),
            ListRow(
              icon: 'sparkles',
              iconBg: c.rituals,
              title: 'Daily rituals',
              value: '${goals.dailyRitualTarget}',
              chevron: false,
              last: true,
            ),
          ],
        ),

        // --- Reviews ---
        InsetSection(
          header: 'Reviews',
          children: [
            ListRow(
              icon: 'calendar',
              iconBg: c.rituals,
              title: 'Weekly review',
              value: 'Apr 17–23',
              onTap: () => context.pushNamed(AppRoute.weeklyReview.name),
            ),
            ListRow(
              icon: 'chart.bar.fill',
              iconBg: c.accent,
              title: 'Monthly review',
              value: 'April',
              onTap: () => context.pushNamed(AppRoute.monthlyReview.name),
            ),
            ListRow(
              icon: 'sparkles',
              iconBg: c.money,
              title: 'Yearly rewind',
              value: 'Preview',
              chevron: false,
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
              value: 'Gmail · On',
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
              onTap: () => context.pushNamed(AppRoute.weeklyReview.name),
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
              onTap: () => context.pushNamed(AppRoute.budgetsGoals.name),
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
