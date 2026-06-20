import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show TimeOfDay, showTimePicker;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/providers.dart';
import '../../services/notifications/notification_service.dart';
import '../../theme/theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/inset_section.dart';
import '../email/email_nav.dart';

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
    return ColoredBox(
      color: c.bg,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          EmailNavBar(
            title: 'Notifications',
            leadingLabel: 'You',
            onLeading: () => context.pop(),
          ),
          const SizedBox(height: Spacing.sm),
          InsetSection(
            header: 'Permission',
            footer: 'Opal asks iOS for permission before it can deliver any '
                'reminders.',
            children: [
              ListRow(
                icon: 'bell.fill',
                iconBg: c.red,
                title: 'Allow notifications',
                value: _requesting ? '…' : (_permStatus ?? 'Not set'),
                valueColor: permissionGap ? c.red : null,
                chevron: false,
                last: true,
                onTap: _requestPerms,
              ),
            ],
          ),
          InsetSection(
            header: 'Reminders',
            footer: 'Reminders are scheduled and delivered on your device only.',
            children: [
              if (permissionGap)
                ListRow(
                  icon: 'lock.fill',
                  iconBg: c.red,
                  title: 'Not allowed yet',
                  subtitle: 'Tap to let iOS deliver these reminders.',
                  onTap: _requestPerms,
                ),
              _SwitchRow(
                icon: 'sparkles',
                color: c.rituals,
                title: 'Routine reminders',
                value: _ritualReminders,
                onChanged: _setRitualReminders,
              ),
              if (_ritualReminders)
                ListRow(
                  icon: 'clock.fill',
                  iconBg: c.rituals,
                  title: 'Reminder time',
                  value: _formatTime(_reminderTime),
                  chevron: false,
                  onTap: _pickReminderTime,
                ),
              _SwitchRow(
                icon: 'flame.fill',
                color: c.money,
                title: 'Budget alerts',
                value: _budgetAlerts,
                last: true,
                onChanged: _setBudgetAlerts,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Inset-grouped row with a trailing iOS switch.
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.onChanged,
    this.last = false,
  });

  final String icon;
  final Color color;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.sm),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              children: [
                Container(
                  width: 29,
                  height: 29,
                  decoration: BoxDecoration(
                      color: color, borderRadius: BorderRadius.circular(Radii.sm)),
                  alignment: Alignment.center,
                  child: AppIcon(icon, size: 17, color: c.onAccent),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Text(title,
                      style: AppType.body.copyWith(color: c.ink)),
                ),
                CupertinoSwitch(
                  value: value,
                  activeTrackColor: c.accent,
                  onChanged: onChanged,
                ),
              ],
            ),
          ),
        ),
        if (!last)
          Positioned(
            left: 57,
            right: 0,
            bottom: 0,
            child: Container(height: 0.5, color: c.hair),
          ),
      ],
    );
  }
}
