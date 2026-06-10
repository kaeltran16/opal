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

/// Parses a "#RRGGBB" brand hex string to a [Color]; [fallback] on a bad seed.
Color _hex(String s, Color fallback) {
  var h = s.replaceFirst('#', '').trim();
  if (h.length == 6) h = 'FF$h';
  final v = int.tryParse(h, radix: 16);
  return v == null ? fallback : Color(v);
}

const _weekdaysShort = [
  'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun' //
];
const _monthsShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec' //
];

/// "Mon, Apr 28" — local formatter (intl is not a project dependency).
String _dueLabel(DateTime d) =>
    '${_weekdaysShort[d.weekday - 1]}, ${_monthsShort[d.month - 1]} ${d.day}';

String _weekdayAbbrev(DateTime d) => _weekdaysShort[d.weekday - 1];

/// Money with grouped thousands and two decimals (e.g. "$2,400.00"), or no
/// decimals for whole-dollar list amounts when [decimals] is 0.
String _money(double v, {int decimals = 2}) {
  final neg = v < 0;
  final abs = v.abs();
  final whole = abs.truncate();
  final groups = whole.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'),
        (m) => '${m[1]},',
      );
  final frac =
      decimals == 0 ? '' : '.${(abs - whole).toStringAsFixed(decimals).substring(2)}';
  return '${neg ? '−' : ''}\$$groups$frac';
}

/// Screen 23 — Bills / Recurring. Next-bill hero, due-this-month timeline card,
/// and an upcoming list sorted by due date.
class BillsScreen extends ConsumerWidget {
  const BillsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final async = ref.watch(billsProvider);

    return async.when(
      loading: () => Center(
        child: Text('…',
            style: AppFonts.sf(size: 17, color: c.ink3, letterSpacing: -0.43)),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text("Couldn't load bills.",
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
  final BillsState state;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final next = state.next;

    return ListView(
      padding: const EdgeInsets.only(bottom: 110),
      children: [
        LargeTitleNavBar(
          title: 'Bills',
          subtitle:
              '${state.count} recurring · ${state.autoPayCount} on auto-pay',
          leading: PressScale(
            onTap: () => context.pop(),
            semanticLabel: 'Today',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon('chevron.left', size: 20, color: c.accent),
                Text('Today',
                    style: AppFonts.sf(
                        size: 17, color: c.accent, letterSpacing: -0.43)),
              ],
            ),
          ),
          trailing: const NavIconButton(name: 'plus', semanticLabel: 'Add bill'),
        ),

        if (next != null) _Hero(bill: next),

        // Due-this-month card with the tiny bar timeline.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
                color: c.surface, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('DUE THIS MONTH',
                          style: AppFonts.sf(
                              size: 11,
                              weight: FontWeight.w700,
                              color: c.ink3,
                              letterSpacing: 0.3)),
                      const SizedBox(height: 2),
                      Text(_money(state.monthTotal),
                          style: AppFonts.sfr(
                              size: 22, weight: FontWeight.w700, color: c.ink)),
                    ],
                  ),
                ),
                _MiniTimeline(bills: state.bills),
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
              for (var i = 0; i < state.bills.length; i++)
                _BillRow(bill: state.bills[i], last: i == state.bills.length - 1),
            ],
          ),
        ),

        // Footer.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Center(
            child: PressScale(
              onTap: () {},
              child: Text('+ Add a bill',
                  style: AppFonts.sf(
                      size: 14, color: c.accent, letterSpacing: -0.15)),
            ),
          ),
        ),
      ],
    );
  }
}

/// Next-bill hero: pulsing money dot, eyebrow, big amount, name/payee, a
/// countdown strip, and Pay now / Remind CTAs.
class _Hero extends StatelessWidget {
  const _Hero({required this.bill});
  final Bill bill;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = _hex(bill.color, c.accent);
    final n = daysUntil(bill.dueDate);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            // Surface fill, then the radial money wash from the top-right.
            Positioned.fill(child: ColoredBox(color: c.surface)),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(1, -1),
                    radius: 1.1,
                    colors: [
                      c.money.withValues(alpha: 0.13),
                      const Color(0x00000000),
                    ],
                    stops: const [0, 0.6],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _PulsingDot(color: c.money),
                      const SizedBox(width: 10),
                      Text('NEXT BILL · DUE IN $n ${n == 1 ? 'DAY' : 'DAYS'}',
                          style: AppFonts.sf(
                              size: 12,
                              weight: FontWeight.w700,
                              color: c.money,
                              letterSpacing: 0.4)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                                color: color.withValues(alpha: 0.33),
                                blurRadius: 18,
                                offset: const Offset(0, 6)),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: AppIcon(bill.icon,
                            size: 26, color: const Color(0xFFFFFFFF)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_money(bill.amount),
                                style: AppFonts.sfr(
                                    size: 34,
                                    weight: FontWeight.w700,
                                    color: c.ink,
                                    height: 1)),
                            const SizedBox(height: 6),
                            Text(bill.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppFonts.sf(
                                    size: 15,
                                    weight: FontWeight.w600,
                                    color: c.ink,
                                    letterSpacing: -0.24)),
                            Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child: Text(bill.payee,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppFonts.sf(
                                      size: 13,
                                      color: c.ink3,
                                      letterSpacing: -0.08)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _CountdownStrip(bill: bill),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: PressScale(
                          onTap: () {},
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            decoration: BoxDecoration(
                                color: c.ink,
                                borderRadius: BorderRadius.circular(12)),
                            alignment: Alignment.center,
                            child: Text('Pay now',
                                style: AppFonts.sf(
                                    size: 14,
                                    weight: FontWeight.w600,
                                    color: c.bg,
                                    letterSpacing: -0.15)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      PressScale(
                        onTap: () {},
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 11),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: c.hair, width: 0.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppIcon('bell.fill', size: 13, color: c.ink2),
                              const SizedBox(width: 6),
                              Text('Remind',
                                  style: AppFonts.sf(
                                      size: 14,
                                      weight: FontWeight.w600,
                                      color: c.ink,
                                      letterSpacing: -0.15)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountdownStrip extends StatelessWidget {
  const _CountdownStrip({required this.bill});
  final Bill bill;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
          color: c.fill, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          AppIcon('calendar', size: 16, color: c.ink2),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_dueLabel(bill.dueDate),
                    style: AppFonts.sf(
                        size: 13,
                        weight: FontWeight.w600,
                        color: c.ink,
                        letterSpacing: -0.15)),
                if (bill.autoPay)
                  Text('Auto-pays from Chase ··0427',
                      style: AppFonts.sf(
                          size: 11, color: c.ink3, letterSpacing: -0.08)),
              ],
            ),
          ),
          if (bill.autoPay)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                  color: c.move, borderRadius: BorderRadius.circular(100)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppIcon('checkmark',
                      size: 10, color: Color(0xFFFFFFFF)),
                  const SizedBox(width: 4),
                  Text('On',
                      style: AppFonts.sf(
                          size: 11,
                          weight: FontWeight.w700,
                          color: const Color(0xFFFFFFFF),
                          letterSpacing: 0.2)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 8px money dot with a soft halo that pulses (1.8s loop), matching the
/// prototype's `pulse` keyframes.
class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});
  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 16,
      child: Center(
        child: AnimatedBuilder(
          animation: _ctl,
          builder: (context, _) {
            final t = _ctl.value;
            return Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color,
                boxShadow: [
                  BoxShadow(
                    color: widget.color
                        .withValues(alpha: 0.2 * (1 - t) + 0.05),
                    blurRadius: 0,
                    spreadRadius: 4 * t,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Tiny vertical bar timeline: one bar per bill, height ∝ amount, each its
/// brand color. Heights are scaled against the largest amount.
class _MiniTimeline extends StatelessWidget {
  const _MiniTimeline({required this.bills});
  final List<Bill> bills;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final maxAmount =
        bills.fold<double>(0, (m, b) => b.amount > m ? b.amount : m);
    return SizedBox(
      height: 36,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final b in bills) ...[
            Container(
              width: 6,
              height: maxAmount <= 0
                  ? 8
                  : (b.amount / maxAmount * 36).clamp(8, 36).toDouble(),
              decoration: BoxDecoration(
                color: _hex(b.color, c.accent),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 3),
          ],
        ],
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow({required this.bill, required this.last});
  final Bill bill;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final n = daysUntil(bill.dueDate);
    final urgent = n <= 3;
    final wholeDollar = bill.amount == bill.amount.roundToDouble();

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
                color: _hex(bill.color, c.accent),
                borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            child: AppIcon(bill.icon, size: 16, color: const Color(0xFFFFFFFF)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(bill.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.sf(
                              size: 15,
                              weight: FontWeight.w600,
                              color: c.ink,
                              letterSpacing: -0.24)),
                    ),
                    if (bill.autoPay) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                            color: c.fill,
                            borderRadius: BorderRadius.circular(4)),
                        child: Text('AUTO',
                            style: AppFonts.sf(
                                size: 10,
                                weight: FontWeight.w700,
                                color: c.ink3,
                                letterSpacing: 0.3)),
                      ),
                    ],
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text.rich(
                    TextSpan(
                      style: AppFonts.sf(
                          size: 12, color: c.ink3, letterSpacing: -0.08),
                      children: [
                        TextSpan(text: '${bill.category} · '),
                        TextSpan(
                          text: 'in $n ${n == 1 ? 'day' : 'days'}',
                          style: TextStyle(
                            color: urgent ? c.money : c.ink3,
                            fontWeight:
                                urgent ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_money(bill.amount, decimals: wholeDollar ? 0 : 2),
                  style: AppFonts.sf(
                      size: 15,
                      weight: FontWeight.w600,
                      color: c.ink,
                      letterSpacing: -0.15,
                      tabular: true)),
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(_weekdayAbbrev(bill.dueDate),
                    style: AppFonts.sf(
                        size: 11, color: c.ink4, letterSpacing: -0.08)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
