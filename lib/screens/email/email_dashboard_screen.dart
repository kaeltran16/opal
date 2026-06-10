import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/email_sync_controller.dart';
import '../../models/models.dart';
import '../../services/email/email_sync_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/controls.dart';
import '../../widgets/inset_section.dart';
import '../../widgets/nav_bar.dart';

/// Screen 18 — Synced dashboard (mock).
///
/// A sync-job hero (connection chip with a pulse while syncing, a STAGED status
/// line + animated progress bar, a Sync-now button, a schedule chip), a recent-
/// imports list with a NEW badge that fades after the items settle, and a
/// Disconnect action. The staged status/progress are driven entirely by
/// [syncStatusProvider]; Sync-now/disconnect go through
/// [EmailDashboardController].
class EmailDashboardScreen extends ConsumerWidget {
  const EmailDashboardScreen({super.key});

  /// Human status line + progress fraction (0..1) for each [SyncStatus].
  static (String, double) _stage(SyncStatus s, DateTime? lastSync) =>
      switch (s) {
        SyncStatus.idle => (_lastSyncLabel(lastSync), 0),
        SyncStatus.scanning => ('Scanning INBOX…', 0.28),
        SyncStatus.filtering => ('Filtering by sender…', 0.55),
        SyncStatus.categorizing => ('Pal is categorizing…', 0.80),
        SyncStatus.upToDate => ('Up to date · just now', 1),
        SyncStatus.error => ('Sync failed — try again', 0),
      };

  static String _lastSyncLabel(DateTime? at) {
    if (at == null) return 'Never synced';
    final mins = DateTime.now().difference(at).inMinutes;
    if (mins < 1) return 'Last sync just now';
    return 'Last sync $mins min ago';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final dash = ref.watch(emailDashboardControllerProvider);
    final statusAsync = ref.watch(syncStatusProvider);
    final status = statusAsync.asData?.value ?? SyncStatus.idle;

    final syncing = status == SyncStatus.scanning ||
        status == SyncStatus.filtering ||
        status == SyncStatus.categorizing;
    final (line, progress) = _stage(status, dash.lastSyncAt);
    final address = dash.account?.address ?? 'alex@gmail.com';

    return ColoredBox(
      color: c.bg,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 48),
        children: [
          LargeTitleNavBar(
            title: 'Email sync',
            leading: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => context.pop(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIcon('chevron.left', size: 20, color: c.accent),
                  Text('Settings',
                      style: AppFonts.sf(
                          size: 17, color: c.accent, letterSpacing: -0.43)),
                ],
              ),
            ),
            trailing: const NavIconButton(name: 'ellipsis'),
          ),

          // --- Sync-job hero -------------------------------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: c.hair, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: c.accentTint,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: AppIcon('envelope.fill',
                            size: 16, color: c.accent),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(address,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppFonts.sf(
                                          size: 15,
                                          weight: FontWeight.w600,
                                          color: c.ink,
                                          letterSpacing: -0.24)),
                                ),
                                const SizedBox(width: 8),
                                _ConnectionChip(syncing: syncing),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(line,
                                style: AppFonts.sf(
                                    size: 12,
                                    color: c.ink3,
                                    letterSpacing: -0.08,
                                    tabular: true)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ProgressBar(
                    value: progress,
                    color: status == SyncStatus.upToDate ? c.move : c.accent,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _SyncNowButton(
                          syncing: syncing,
                          done: status == SyncStatus.upToDate,
                          onTap: () => ref
                              .read(emailDashboardControllerProvider.notifier)
                              .syncNow(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _ScheduleChip(),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // --- Recently synced ----------------------------------------------
          if (dash.imports.isNotEmpty)
            InsetSection(
              header: 'Recently synced',
              footer:
                  'Tap any entry to edit or correct the category. Pal learns from your edits.',
              children: [
                for (var i = 0; i < dash.imports.length; i++)
                  _ImportRow(
                    item: dash.imports[i],
                    last: i == dash.imports.length - 1,
                  ),
              ],
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 28),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.hair, width: 0.5),
                ),
                alignment: Alignment.center,
                child: Text('No imports yet — tap Sync now.',
                    style: AppFonts.sf(
                        size: 15, color: c.ink3, letterSpacing: -0.24)),
              ),
            ),

          // --- Disconnect ----------------------------------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () async {
                await ref
                    .read(emailDashboardControllerProvider.notifier)
                    .disconnect();
                if (context.mounted) context.pop();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                alignment: Alignment.center,
                child: Text('Disconnect Gmail',
                    style: AppFonts.sf(
                        size: 15,
                        weight: FontWeight.w500,
                        color: c.red,
                        letterSpacing: -0.24)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Connected/Syncing pill; the dot pulses while syncing.
class _ConnectionChip extends StatelessWidget {
  const _ConnectionChip({required this.syncing});
  final bool syncing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: c.move.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulseDot(active: syncing, color: c.move),
          const SizedBox(width: 4),
          Text(syncing ? 'Syncing' : 'Connected',
              style: AppFonts.sf(
                  size: 11,
                  weight: FontWeight.w600,
                  color: c.move,
                  letterSpacing: -0.05)),
        ],
      ),
    );
  }
}

/// A 6×6 dot that pulses (opacity) while [active].
class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.active, required this.color});
  final bool active;
  final Color color;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_PulseDot old) {
    super.didUpdateWidget(old);
    if (widget.active && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.active && _ctrl.isAnimating) {
      _ctrl.stop();
      _ctrl.value = 1;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: widget.active
          ? Tween<double>(begin: 0.3, end: 1).animate(_ctrl)
          : const AlwaysStoppedAnimation(1),
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

/// Primary Sync-now button reflecting syncing/done state.
class _SyncNowButton extends StatelessWidget {
  const _SyncNowButton({
    required this.syncing,
    required this.done,
    required this.onTap,
  });
  final bool syncing;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (String icon, String label) = syncing
        ? ('arrow.up.right', 'Syncing…')
        : done
            ? ('checkmark', 'Done')
            : ('paperplane.fill', 'Sync now');
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: syncing ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
        decoration: BoxDecoration(
          color: syncing ? c.fill : c.ink,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(icon, size: 13, color: syncing ? c.ink2 : c.bg),
            const SizedBox(width: 7),
            Text(label,
                style: AppFonts.sf(
                    size: 14,
                    weight: FontWeight.w600,
                    color: syncing ? c.ink2 : c.bg,
                    letterSpacing: -0.1)),
          ],
        ),
      ),
    );
  }
}

/// The "Every 15m" schedule chip (static; cadence selection is out of scope).
class _ScheduleChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
      decoration:
          BoxDecoration(color: c.fill, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon('clock.fill', size: 13, color: c.ink2),
          const SizedBox(width: 6),
          Text('Every 15m',
              style: AppFonts.sf(
                  size: 14,
                  weight: FontWeight.w500,
                  color: c.ink,
                  letterSpacing: -0.1)),
        ],
      ),
    );
  }
}

/// One imported receipt row: tinted category tile + merchant/meta + amount,
/// with a NEW badge that fades out a few seconds after the item appears.
class _ImportRow extends StatefulWidget {
  const _ImportRow({required this.item, required this.last});
  final EmailImportItem item;
  final bool last;

  @override
  State<_ImportRow> createState() => _ImportRowState();
}

class _ImportRowState extends State<_ImportRow> {
  static const _fadeAfter = Duration(seconds: 6);
  bool _badgeVisible = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.item.isNew) {
      _timer = Timer(_fadeAfter, () {
        if (mounted) setState(() => _badgeVisible = false);
      });
    } else {
      _badgeVisible = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final item = widget.item;
    final amount = item.amount.abs().toStringAsFixed(2);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        color: _badgeVisible
            ? c.accent.withValues(alpha: 0.05)
            : const Color(0x00000000),
        border: widget.last
            ? null
            : Border(bottom: BorderSide(color: c.hair, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: c.money.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: AppIcon('basket.fill', size: 16, color: c.money),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(item.merchant,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.sf(
                              size: 15,
                              weight: FontWeight.w500,
                              color: c.ink,
                              letterSpacing: -0.24)),
                    ),
                    if (item.isNew) ...[
                      const SizedBox(width: 6),
                      AnimatedOpacity(
                        opacity: _badgeVisible ? 1 : 0,
                        duration: const Duration(milliseconds: 600),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                              color: c.accent,
                              borderRadius: BorderRadius.circular(100)),
                          child: Text('NEW',
                              style: AppFonts.sf(
                                  size: 9,
                                  weight: FontWeight.w700,
                                  color: const Color(0xFFFFFFFF),
                                  letterSpacing: 0.3)),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 1),
                Text(item.category ?? 'Uncategorized',
                    style: AppFonts.sf(
                        size: 12, color: c.ink3, letterSpacing: -0.08)),
              ],
            ),
          ),
          Text('−\$$amount',
              style: AppFonts.sfr(
                  size: 16,
                  weight: FontWeight.w600,
                  color: c.ink,
                  letterSpacing: -0.2)),
        ],
      ),
    );
  }
}
