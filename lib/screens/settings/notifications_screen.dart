import 'package:flutter/cupertino.dart' show CupertinoSwitch;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/providers.dart';
import '../../services/notifications/notification_service.dart';
import '../../theme/theme.dart';
import '../../widgets/press_scale.dart';
import '../you/sub_screen.dart';

const double _rowMinHeight = 56;
const double _hairline = 1;

/// Settings → Notifications.
///
/// Toggles ritual-reminder and budget-alert preferences (persisted via
/// [SettingsRepository]) and lets the user request OS permission through
/// [NotificationService]. Actual delivery is only verifiable on a real iOS
/// build; elsewhere the no-op service simply reports success.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  late bool _ritualReminders;
  late bool _budgetAlerts;
  late TimeOfDay _reminderTime;
  String? _permStatus;
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    final repo = ref.read(settingsRepositoryProvider);
    _ritualReminders = repo.ritualReminders;
    _budgetAlerts = repo.budgetAlerts;
    _reminderTime = repo.reminderTime;
    _loadPermStatus();
  }

  /// Reads the real OS permission state (without prompting) so the row reflects
  /// what the system actually allows, not the toggles' persisted preference.
  Future<void> _loadPermStatus() async {
    final granted = await ref.read(notificationServiceProvider).hasPermission();
    if (!mounted) return;
    setState(() => _permStatus = granted ? 'Allowed' : 'Not set');
  }

  /// True once permission is confirmed granted; until then a toggled-on reminder
  /// can't actually be delivered.
  bool get _permissionGranted => _permStatus == 'Allowed';

  Future<void> _requestPerms() async {
    if (_requesting) return;
    setState(() => _requesting = true);
    final notifications = ref.read(notificationServiceProvider);
    final ok = await notifications.requestPermissions();
    if (!mounted) return;
    setState(() {
      _requesting = false;
      _permStatus = ok ? 'Allowed' : 'Denied';
    });
    // granting here also fixes an already-on-but-unpermitted reminder, so wire
    // up the daily schedule now rather than waiting for the next launch reconcile.
    if (ok && _ritualReminders) {
      await notifications.scheduleDaily(
        id: NotificationIds.ritualReminder,
        title: kRitualReminderTitle,
        body: kRitualReminderBody,
        time: _reminderTime,
      );
    }
  }

  /// (Re)schedules the daily reminder at the configured time. Requests
  /// permission first; if denied, surfaces it via the permission row rather than
  /// silently scheduling against a denied permission.
  Future<void> _scheduleReminder() async {
    final notifications = ref.read(notificationServiceProvider);
    final granted = await notifications.requestPermissions();
    if (!mounted) return;
    if (!granted) {
      setState(() => _permStatus = 'Denied');
      return;
    }
    await notifications.scheduleDaily(
      id: NotificationIds.ritualReminder,
      title: kRitualReminderTitle,
      body: kRitualReminderBody,
      time: _reminderTime,
    );
  }

  Future<void> _setRitualReminders(bool v) async {
    setState(() => _ritualReminders = v);
    await ref.read(settingsRepositoryProvider).setRitualReminders(v);
    if (v) {
      await _scheduleReminder();
    } else {
      await ref
          .read(notificationServiceProvider)
          .cancel(NotificationIds.ritualReminder);
    }
  }

  Future<void> _pickReminderTime() async {
    final picked =
        await showTimePicker(context: context, initialTime: _reminderTime);
    if (picked == null || !mounted) return;
    setState(() => _reminderTime = picked);
    await ref.read(settingsRepositoryProvider).setReminderTime(picked);
    if (_ritualReminders) await _scheduleReminder();
  }

  /// '9:00 AM'-style label for the reminder-time row.
  String _formatTime(TimeOfDay t) {
    final period = t.hour < 12 ? 'AM' : 'PM';
    final hour12 = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    return '$hour12:$minute $period';
  }

  void _setBudgetAlerts(bool v) {
    setState(() => _budgetAlerts = v);
    ref.read(settingsRepositoryProvider).setBudgetAlerts(v);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // a toggle promising delivery while the OS hasn't granted permission is the
    // gap to surface (defaults are on, so this is the fresh-install state).
    final permissionGap =
        (_ritualReminders || _budgetAlerts) && !_permissionGranted;
    return SubScreen(
      eyebrow: 'Settings',
      title: 'Notifications',
      children: [
        const SizedBox(height: Spacing.xxl),
        const _Heading('Permission'),
        const SizedBox(height: Spacing.sm),
        _Row(
          title: 'Allow notifications',
          value: _requesting ? '…' : (_permStatus ?? 'Not set'),
          // the value is the state word, so care ink sits beside its word.
          valueColor: permissionGap ? c.careInk : null,
          onTap: _requestPerms,
        ),
        const _Footer('Opal asks iOS for permission before it can deliver any '
            'reminders.'),
        const SizedBox(height: Spacing.xxl),
        const _Heading('Reminders'),
        const SizedBox(height: Spacing.sm),
        if (permissionGap)
          _Row(
            title: 'Not allowed yet',
            subtitle: 'Tap to let iOS deliver these reminders.',
            onTap: _requestPerms,
          ),
        _SwitchRow(
          title: 'Routine reminders',
          value: _ritualReminders,
          onChanged: _setRitualReminders,
        ),
        if (_ritualReminders)
          _Row(
            title: 'Reminder time',
            value: _formatTime(_reminderTime),
            onTap: _pickReminderTime,
          ),
        _SwitchRow(
          title: 'Budget alerts',
          value: _budgetAlerts,
          onChanged: _setBudgetAlerts,
        ),
        const _Footer('Reminders are scheduled and delivered on your device only.'),
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

/// A section's closing note, under a hairline.
class _Footer extends StatelessWidget {
  const _Footer(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.only(top: Spacing.sm),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.hair, width: _hairline)),
      ),
      child: Text(text, style: AppType.subhead.copyWith(color: c.ink3)),
    );
  }
}

/// A tappable hairline row: [title] with an optional [subtitle], and an
/// optional trailing [value].
class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    this.subtitle,
    this.value,
    this.valueColor,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final String? value;
  final Color? valueColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final value = this.value;
    final subtitle = this.subtitle;
    return Semantics(
      container: true,
      child: PressScale(
        onTap: onTap,
        semanticLabel: value == null ? title : '$title, $value',
        child: Container(
          constraints: const BoxConstraints(minHeight: _rowMinHeight),
          padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: c.hair, width: _hairline)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppType.callout.copyWith(color: c.ink)),
                    if (subtitle != null) ...[
                      const SizedBox(height: Spacing.xxs),
                      Text(subtitle, style: AppType.subhead.copyWith(color: c.ink3)),
                    ],
                  ],
                ),
              ),
              if (value != null) ...[
                const SizedBox(width: Spacing.md),
                Text(value,
                    style: AppType.subhead.copyWith(
                        color: valueColor ?? c.ink3,
                        fontFeatures: const [FontFeature.tabularFigures()])),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A hairline row with a trailing switch. The whole row takes the tap so the
/// target is more than the track.
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      // the switch below carries the row's semantics.
      excludeFromSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: _rowMinHeight),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: c.hair, width: _hairline)),
        ),
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
