import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/profile_controller.dart';
import '../../router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/inset_section.dart';
import '../../widgets/nav_bar.dart';

/// Screen 15 — You / profile + settings.
///
/// Avatar + name + "Member since …", a this-year 2×2 stat grid (Total spent /
/// Hours moved / Rituals kept / Longest streak, all from repositories via
/// [profileStatsProvider]), and a Settings [InsetSection] list. The Rituals row
/// deep-links to the Rituals tab; Integrations → Email sync targets the U20
/// email stub. Non-email rows are no-op stubs for now (// TODO).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final async = ref.watch(profileStatsProvider);

    return async.when(
      loading: () => Center(
        child: Text('…',
            style: AppFonts.sf(size: 17, color: c.ink3, letterSpacing: -0.43)),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text("Couldn't load your profile.\n$e",
              textAlign: TextAlign.center,
              style:
                  AppFonts.sf(size: 15, color: c.ink3, letterSpacing: -0.24)),
        ),
      ),
      data: (stats) => _ProfileBody(stats: stats),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.stats});
  final ProfileStats stats;

  String _money(double v) {
    // Whole-dollar display with thousands separators (no cents on the grid).
    final n = v.round();
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '\$$buf';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return ListView(
      padding: const EdgeInsets.only(bottom: 110),
      children: [
        const LargeTitleNavBar(title: 'You'),

        // --- Avatar + name + "Member since …" ---
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 22),
          child: Column(
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: c.accentTint,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: AppIcon('person.crop.circle.fill',
                    size: 56, color: c.accent),
              ),
              const SizedBox(height: 12),
              Text('You',
                  style: AppFonts.sf(
                      size: 22,
                      weight: FontWeight.w700,
                      color: c.ink,
                      letterSpacing: -0.35)),
              const SizedBox(height: 2),
              Text('Member since ${stats.memberSinceYear}',
                  style: AppFonts.sf(
                      size: 15, color: c.ink3, letterSpacing: -0.24)),
            ],
          ),
        ),

        // --- This-year 2×2 stat grid ---
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text('THIS YEAR',
              style: AppFonts.sf(size: 13, color: c.ink3, letterSpacing: -0.08)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 22),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: 'dollarsign.circle.fill',
                      color: c.money,
                      label: 'Total spent',
                      value: _money(stats.totalSpent),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: 'figure.walk',
                      color: c.move,
                      label: 'Hours moved',
                      value: '${stats.moveHours}',
                      unit: 'h',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: 'sparkles',
                      color: c.rituals,
                      label: 'Rituals kept',
                      value: '${stats.ritualsKept}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: 'flame.fill',
                      color: c.money,
                      label: 'Longest streak',
                      value: '${stats.longestStreak}',
                      unit: stats.longestStreak == 1 ? 'day' : 'days',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // --- Settings ---
        InsetSection(
          header: 'Settings',
          children: [
            ListRow(
              icon: 'sparkles',
              iconBg: c.rituals,
              title: 'Rituals',
              // Deep-link to the Rituals tab (built in U08).
              onTap: () => context.goNamed(AppRoute.rituals.name),
            ),
            ListRow(
              icon: 'target',
              iconBg: c.money,
              title: 'Budgets & goals',
              // TODO: Budgets & goals editor (later unit).
              onTap: () {},
            ),
            ListRow(
              icon: 'bell.fill',
              iconBg: c.red,
              title: 'Notifications',
              // TODO: Notification preferences (later unit).
              onTap: () {},
            ),
            ListRow(
              icon: 'heart.fill',
              iconBg: c.move,
              title: 'HealthKit',
              value: 'Connected',
              chevron: false,
              // TODO: HealthKit connection management (device-only, U27).
              onTap: () {},
            ),
            ListRow(
              icon: 'envelope.fill',
              iconBg: c.accent,
              title: 'Integrations',
              subtitle: 'Email sync',
              value: 'Off',
              last: true,
              // Targets the U20 email-intro stub; the row shows "Off" until an
              // EmailAccount exists.
              onTap: () => context.pushNamed(AppRoute.emailSync.name),
            ),
          ],
        ),

        InsetSection(
          children: [
            ListRow(
              icon: 'lock.fill',
              iconBg: c.ink3,
              title: 'Privacy',
              // TODO: Privacy settings (later unit).
              onTap: () {},
            ),
            ListRow(
              icon: 'arrow.up.right',
              iconBg: c.move,
              title: 'Export data',
              // TODO: Data export (later unit).
              onTap: () {},
            ),
            ListRow(
              icon: 'gearshape.fill',
              iconBg: c.ink3,
              title: 'About',
              value: 'Loop 1.0',
              chevron: false,
              last: true,
              // TODO: About screen (later unit).
              onTap: () {},
            ),
          ],
        ),
      ],
    );
  }
}

/// One cell of the this-year 2×2 grid: tinted icon + label + big value/unit.
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.unit,
  });

  final String icon;
  final Color color;
  final String label;
  final String value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      constraints: const BoxConstraints(minHeight: 104),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: c.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.sf(
                      size: 14,
                      weight: FontWeight.w600,
                      color: color,
                      letterSpacing: -0.15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: AppFonts.sfr(
                    size: 28,
                    weight: FontWeight.w700,
                    color: c.ink,
                    letterSpacing: -0.3),
              ),
              if (unit != null) ...[
                const SizedBox(width: 4),
                Text(
                  unit!,
                  style: AppFonts.sf(
                      size: 13,
                      weight: FontWeight.w600,
                      color: c.ink3,
                      letterSpacing: 0.3),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
