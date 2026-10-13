import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator, CupertinoSwitch;
import 'package:flutter/material.dart' show ScaffoldMessenger, SnackBar;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/email_sync_controller.dart';
import '../../controllers/providers.dart';
import '../../data/repositories/settings_repository.dart' show SyncCadence;
import '../../models/models.dart';
import '../../services/email/email_sync_service.dart';
import '../../theme/theme.dart';
import '../../util/format.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/controls.dart';
import '../../widgets/press_scale.dart';
import '../you/sub_screen.dart';
import 'sender_filter_section.dart';

const double _pillHeight = 48;
const double _minTap = 44;
const double _rowHeight = 56;
const double _hairline = 1;
const double _rowIcon = 20;
const double _spinnerRadius = 7;
const Duration _newFade = Duration(milliseconds: 600);
const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

/// Email sync, connected: the account and its sync status as words, Sync now,
/// import counts, recent imports, sync settings, the sender allowlist and
/// Disconnect. The staged status and progress come from [syncStatusProvider];
/// Sync now and Disconnect go through [EmailDashboardController].
class EmailDashboardScreen extends ConsumerWidget {
  const EmailDashboardScreen({super.key, this.popOnDisconnect = true});

  /// Whether Disconnect pops this route. False where the intro hosts the
  /// dashboard, since the intro itself turns back into the pitch.
  final bool popOnDisconnect;

  /// Status words and progress fraction (0..1) for each [SyncStatus].
  static (String, double) _stage(SyncStatus s, DateTime? lastSync) => switch (s) {
        SyncStatus.idle => (_lastSyncLabel(lastSync), 0),
        SyncStatus.scanning => ('Scanning INBOX…', 0.28),
        SyncStatus.filtering => ('Filtering by sender…', 0.55),
        SyncStatus.categorizing => ('Pal is categorizing…', 0.80),
        SyncStatus.upToDate => ('Up to date · just now', 1),
        SyncStatus.error => ('Sync failed — try again', 0),
      };

  /// Next cadence in the cycle (wraps), for tap-to-cycle on the settings row.
  static SyncCadence _nextCadence(SyncCadence current) {
    final values = SyncCadence.values;
    return values[(current.index + 1) % values.length];
  }

  static String _lastSyncLabel(DateTime? at) {
    if (at == null) return 'Never synced';
    final mins = clock.now().difference(at).inMinutes;
    if (mins < 1) return 'Last sync just now';
    return 'Last sync $mins min ago';
  }

  Future<void> _disconnect(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(emailDashboardControllerProvider.notifier).disconnect();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn\'t disconnect — try again')),
        );
      }
      return;
    }
    if (popOnDisconnect && context.mounted) context.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final dash = ref.watch(emailDashboardControllerProvider);
    final controller = ref.read(emailDashboardControllerProvider.notifier);
    final status = ref.watch(syncStatusProvider).asData?.value ?? SyncStatus.idle;
    final quiet = AppType.subhead.copyWith(color: c.ink3);

    // single source of truth for every connection-dependent affordance, so the
    // screen can't contradict itself.
    final connected = dash.isConnected;
    final syncing = status == SyncStatus.scanning ||
        status == SyncStatus.filtering ||
        status == SyncStatus.categorizing;
    final failed = status == SyncStatus.error;
    final (line, progress) = _stage(status, dash.lastSyncAt);
    final statusText = !connected
        ? 'Not connected'
        : failed
            ? line
            : '${syncing ? 'Syncing' : 'Connected'} · $line';

    return SubScreen(
      eyebrow: 'Settings',
      title: 'Email sync',
      children: [
        const SizedBox(height: Spacing.xxl),
        Text(dash.account?.address ?? 'Gmail',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.headline.copyWith(color: c.ink)),
        const SizedBox(height: Spacing.xxs),
        Text(statusText,
            style: AppType.subhead.copyWith(
                color: failed ? c.careInk : c.ink2, fontFeatures: _tabular)),
        if (syncing) ...[
          const SizedBox(height: Spacing.md),
          ProgressBar(value: progress, color: c.ink),
        ],
        const SizedBox(height: Spacing.lg),
        // sync now is a no-op without an account, so the disconnected screen
        // offers Connect instead, the action that state actually needs.
        if (connected)
          _SyncNowPill(
            syncing: syncing,
            done: status == SyncStatus.upToDate,
            onTap: () => unawaited(controller.syncNow()),
          )
        else
          _ConnectPill(onTap: () => context.pushNamed('emailSetup')),
        const SizedBox(height: Spacing.xxxl),

        // real counts of email-sourced entries. no recurring count: that data
        // model was removed and is not reconstructed here.
        const _Heading('Imports'),
        const SizedBox(height: Spacing.sm),
        _ValueRow(title: 'This month', value: '${connected ? dash.importsThisMonth : 0}'),
        _ValueRow(title: 'All time', value: '${connected ? dash.importsAllTime : 0}'),
        const SizedBox(height: Spacing.xxxl),

        // the list shows this session's freshly synced items; the empty line
        // keys off the persisted all-time count so it can't contradict it.
        const _Heading('Recently synced'),
        const SizedBox(height: Spacing.sm),
        if (dash.imports.isNotEmpty) ...[
          for (final item in dash.imports) _ImportRow(item: item),
          const SizedBox(height: Spacing.sm),
          Text('Tap any entry to edit or correct the category. Pal learns from your edits.',
              style: quiet),
        ] else
          Text(
            !connected
                ? 'Connect Gmail to start importing receipts.'
                : dash.importsAllTime > 0
                    ? 'Synced earlier — tap Sync now to refresh.'
                    : 'No imports yet — tap Sync now.',
            style: quiet,
          ),
        const SizedBox(height: Spacing.xxxl),

        // persisted prefs: tapping cadence cycles its options; the switches flip.
        const _Heading('Sync settings'),
        const SizedBox(height: Spacing.sm),
        _ValueRow(
          title: 'Background sync',
          value: dash.syncCadence.label,
          onTap: () => controller.setSyncCadence(_nextCadence(dash.syncCadence)),
        ),
        _SwitchRow(
          title: 'Notify on new detection',
          value: dash.importNotifications,
          onChanged: controller.setImportNotifications,
        ),
        _SwitchRow(
          title: 'Pal auto-categorize',
          value: dash.autoCategorize,
          onChanged: controller.setAutoCategorize,
        ),

        // editable live: writes onto the connected account and rides along on
        // the next sync, with no reconnect.
        if (connected) ...[
          const SizedBox(height: Spacing.xxxl),
          SenderFilterSection(
            senders: dash.account?.senderFilters ?? const [],
            onChanged: controller.setSenderFilters,
          ),
          const SizedBox(height: Spacing.xxl),
          _DisconnectButton(onTap: () => _disconnect(context, ref)),
        ],
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
        header: true,
        child: Text(text, style: AppType.headline.copyWith(color: context.colors.ink)),
      );
}

/// A pill: ink when [primary], surface2 otherwise.
class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.onTap,
    this.primary = false,
    this.leading,
  });
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      child: PressScale(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: _pillHeight),
          padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
          decoration: BoxDecoration(
            color: primary ? c.ink : c.surface2,
            borderRadius: BorderRadius.circular(Radii.pill),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: Spacing.sm)],
              Text(label,
                  style: AppType.headline.copyWith(color: primary ? c.bg : c.ink)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sync now as the secondary pill, worded for syncing and done.
class _SyncNowPill extends StatelessWidget {
  const _SyncNowPill({required this.syncing, required this.done, required this.onTap});
  final bool syncing;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _Pill(
        label: syncing
            ? 'Syncing…'
            : done
                ? 'Done'
                : 'Sync now',
        onTap: syncing ? null : onTap,
        leading: syncing
            ? CupertinoActivityIndicator(radius: _spinnerRadius, color: context.colors.ink2)
            : null,
      );
}

/// The primary pill shown in place of Sync now when no account is linked.
class _ConnectPill extends StatelessWidget {
  const _ConnectPill({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) =>
      _Pill(label: 'Connect', onTap: onTap, primary: true);
}

/// Disconnect as a care text button.
class _DisconnectButton extends StatelessWidget {
  const _DisconnectButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => PressScale(
        onTap: onTap,
        semanticLabel: 'Disconnect',
        child: Container(
          constraints: const BoxConstraints(minHeight: _minTap),
          alignment: Alignment.center,
          child: Text('Disconnect',
              style: AppType.headline.copyWith(color: context.colors.careInk)),
        ),
      );
}

/// A row under a hairline, at least [_rowHeight] tall.
class _HairlineRow extends StatelessWidget {
  const _HairlineRow({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: _rowHeight),
        padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: context.colors.hair, width: _hairline)),
        ),
        child: child,
      );
}

/// A title with its value at the right; tappable when [onTap] is set.
class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.title, required this.value, this.onTap});
  final String title;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final row = _HairlineRow(
      child: Row(
        children: [
          Expanded(child: Text(title, style: AppType.callout.copyWith(color: c.ink))),
          const SizedBox(width: Spacing.md),
          Text(value, style: AppType.callout.copyWith(color: c.ink2, fontFeatures: _tabular)),
        ],
      ),
    );
    if (onTap == null) return row;
    return Semantics(
      button: true,
      label: '$title, $value',
      excludeSemantics: true,
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: row),
    );
  }
}

/// A title with its switch. The whole row takes the tap so the target is more
/// than the track.
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.title, required this.value, required this.onChanged});
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      // the switch below carries the row's semantics.
      excludeFromSemantics: true,
      child: _HairlineRow(
        child: Row(
          children: [
            Expanded(child: Text(title, style: AppType.callout.copyWith(color: c.ink))),
            const SizedBox(width: Spacing.md),
            MergeSemantics(
              child: Semantics(
                label: title,
                child: CupertinoSwitch(
                  value: value,
                  onChanged: onChanged,
                  activeTrackColor: c.ink,
                  inactiveTrackColor: c.track,
                  thumbColor: c.bg,
                  inactiveThumbColor: c.ink3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One imported receipt: merchant and category, then the amount. A new item
/// carries a "New" word that fades a few seconds after it appears.
class _ImportRow extends ConsumerStatefulWidget {
  const _ImportRow({required this.item});
  final EmailImportItem item;

  @override
  ConsumerState<_ImportRow> createState() => _ImportRowState();
}

class _ImportRowState extends ConsumerState<_ImportRow> {
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
    final currency = ref.watch(appSettingsControllerProvider).currency;
    return _HairlineRow(
      child: Row(
        children: [
          AppIcon('basket.fill', size: _rowIcon, color: c.ink2),
          const SizedBox(width: Spacing.md),
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
                          style: AppType.callout.copyWith(color: c.ink)),
                    ),
                    if (item.isNew) ...[
                      const SizedBox(width: Spacing.sm),
                      AnimatedOpacity(
                        opacity: _badgeVisible ? 1 : 0,
                        duration: _newFade,
                        child: Text('New', style: AppType.label.copyWith(color: c.ink2)),
                      ),
                    ],
                  ],
                ),
                Text(item.category ?? 'Uncategorized',
                    style: AppType.subhead.copyWith(color: c.ink3)),
              ],
            ),
          ),
          const SizedBox(width: Spacing.md),
          Text('−${formatCurrency(item.amount.abs(), currency, trimZeroCents: false)}',
              style: AppType.callout.copyWith(color: c.ink, fontFeatures: _tabular)),
        ],
      ),
    );
  }
}
