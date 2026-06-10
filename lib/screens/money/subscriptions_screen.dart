import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/money_recurring_controller.dart';
import '../../models/models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/nav_bar.dart';
import '../../widgets/press_scale.dart';

/// Parses a "#RRGGBB" brand hex string to a [Color]. Falls back to the accent
/// when the string is malformed so a bad seed never crashes the row.
Color _hex(String s, Color fallback) {
  var h = s.replaceFirst('#', '').trim();
  if (h.length == 6) h = 'FF$h';
  final v = int.tryParse(h, radix: 16);
  return v == null ? fallback : Color(v);
}

String _money(double v, {int? decimals}) {
  final d = decimals ?? (v == v.roundToDouble() ? 0 : 2);
  return '\$${v.toStringAsFixed(d)}';
}

/// Screen 18 — Subscriptions. Auto-detected recurring services with a monthly
/// total + stacked category bar and an upcoming list sorted by next charge.
class SubscriptionsScreen extends ConsumerWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final async = ref.watch(subscriptionsProvider);

    return async.when(
      loading: () => Center(
        child: Text('…',
            style: AppFonts.sf(size: 17, color: c.ink3, letterSpacing: -0.43)),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text("Couldn't load subscriptions.",
              textAlign: TextAlign.center,
              style: AppFonts.sf(size: 15, color: c.ink3, letterSpacing: -0.24)),
        ),
      ),
      data: (state) => _Body(state: state),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state});
  final SubscriptionsState state;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final nextUp = state.nextUp;

    return ListView(
      padding: const EdgeInsets.only(bottom: 110),
      children: [
        LargeTitleNavBar(
          title: 'Subscriptions',
          subtitle: 'Auto-detected from your email',
          leading: PressScale(
            onTap: () => context.pop(),
            semanticLabel: 'You',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon('chevron.left', size: 20, color: c.accent),
                Text('You',
                    style:
                        AppFonts.sf(size: 17, color: c.accent, letterSpacing: -0.43)),
              ],
            ),
          ),
          trailing: const NavIconButton(name: 'plus', semanticLabel: 'Add subscription'),
        ),

        // Monthly total card.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
                color: c.surface, borderRadius: BorderRadius.circular(18)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MONTHLY',
                    style: AppFonts.sf(
                        size: 12,
                        weight: FontWeight.w700,
                        color: c.money,
                        letterSpacing: 0.3)),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(_money(state.monthlyTotal, decimals: 2),
                        style: AppFonts.sfr(
                            size: 40, weight: FontWeight.w700, color: c.ink)),
                    const SizedBox(width: 8),
                    Text('· ${_money(state.yearlyTotal, decimals: 0)}/yr',
                        style: AppFonts.sf(
                            size: 14, color: c.ink3, letterSpacing: -0.15)),
                  ],
                ),
                const SizedBox(height: 14),
                _StackedBar(subs: state.subs, total: state.monthlyTotal),
                if (nextUp != null) ...[
                  const SizedBox(height: 10),
                  _NextUpLine(sub: nextUp),
                ],
              ],
            ),
          ),
        ),

        // Upcoming list.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Text('Upcoming',
              style: AppFonts.sf(
                  size: 22,
                  weight: FontWeight.w700,
                  color: c.ink,
                  letterSpacing: 0.35)),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
              color: c.surface, borderRadius: BorderRadius.circular(14)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < state.subs.length; i++)
                _SubRow(sub: state.subs[i], last: i == state.subs.length - 1),
            ],
          ),
        ),

        // Footer button.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Center(
            child: PressScale(
              onTap: () {},
              child: Text('Scan email again',
                  style: AppFonts.sf(
                      size: 14, color: c.accent, letterSpacing: -0.15)),
            ),
          ),
        ),
      ],
    );
  }
}

/// Stacked horizontal bar (8px): one segment per sub, width ∝ amount, each its
/// brand color, with thin separators between segments.
class _StackedBar extends StatelessWidget {
  const _StackedBar({required this.subs, required this.total});
  final List<Subscription> subs;
  final double total;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 8,
        child: total <= 0
            ? ColoredBox(color: c.fill)
            : Row(
                children: [
                  for (var i = 0; i < subs.length; i++)
                    Expanded(
                      flex: (subs[i].amount * 1000).round().clamp(1, 1 << 30),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _hex(subs[i].color, c.accent),
                          border: i < subs.length - 1
                              ? const Border(
                                  right: BorderSide(
                                      color: Color(0xFFFFFFFF), width: 1))
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _NextUpLine extends StatelessWidget {
  const _NextUpLine({required this.sub});
  final Subscription sub;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final n = daysUntil(sub.nextChargeDate);
    return Row(
      children: [
        AppIcon('sparkles', size: 13, color: c.accent),
        const SizedBox(width: 6),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: AppFonts.sf(size: 13, color: c.ink2, letterSpacing: -0.15),
              children: [
                const TextSpan(text: 'Next up: '),
                TextSpan(
                    text: sub.name,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                TextSpan(
                    text:
                        ' in $n ${n == 1 ? 'day' : 'days'} · ${_money(sub.amount, decimals: 2)}'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SubRow extends StatelessWidget {
  const _SubRow({required this.sub, required this.last});
  final Subscription sub;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final n = daysUntil(sub.nextChargeDate);
    return Container(
      decoration: BoxDecoration(
        border:
            last ? null : Border(bottom: BorderSide(color: c.hair, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: _hex(sub.color, c.accent),
                borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            child: AppIcon(sub.icon, size: 16, color: const Color(0xFFFFFFFF)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sub.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.sf(
                        size: 15,
                        weight: FontWeight.w600,
                        color: c.ink,
                        letterSpacing: -0.24)),
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text('${sub.category} · in $n ${n == 1 ? 'day' : 'days'}',
                      style: AppFonts.sf(
                          size: 12, color: c.ink3, letterSpacing: -0.08)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_money(sub.amount, decimals: 2),
                  style: AppFonts.sf(
                      size: 15,
                      weight: FontWeight.w600,
                      color: c.ink,
                      letterSpacing: -0.15,
                      tabular: true)),
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text('/MO',
                    style: AppFonts.sf(
                        size: 11, color: c.ink4, letterSpacing: 0.3)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
