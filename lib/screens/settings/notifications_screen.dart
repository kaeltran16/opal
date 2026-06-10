import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
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
  String? _permStatus;
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    final repo = ref.read(settingsRepositoryProvider);
    _ritualReminders = repo.ritualReminders;
    _budgetAlerts = repo.budgetAlerts;
  }

  Future<void> _requestPerms() async {
    if (_requesting) return;
    setState(() => _requesting = true);
    final ok = await ref.read(notificationServiceProvider).requestPermissions();
    if (!mounted) return;
    setState(() {
      _requesting = false;
      _permStatus = ok ? 'Allowed' : 'Denied';
    });
  }

  void _setRitualReminders(bool v) {
    setState(() => _ritualReminders = v);
    ref.read(settingsRepositoryProvider).setRitualReminders(v);
  }

  void _setBudgetAlerts(bool v) {
    setState(() => _budgetAlerts = v);
    ref.read(settingsRepositoryProvider).setBudgetAlerts(v);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
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
          const SizedBox(height: 8),
          InsetSection(
            header: 'Permission',
            footer: 'Opal asks iOS for permission before it can deliver any '
                'reminders.',
            children: [
              ListRow(
                icon: 'bell.fill',
                iconBg: c.red,
                title: 'Allow notifications',
                value: _requesting ? '…' : _permStatus,
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
              _SwitchRow(
                icon: 'sparkles',
                color: c.rituals,
                title: 'Ritual reminders',
                value: _ritualReminders,
                onChanged: _setRitualReminders,
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              children: [
                Container(
                  width: 29,
                  height: 29,
                  decoration: BoxDecoration(
                      color: color, borderRadius: BorderRadius.circular(7)),
                  alignment: Alignment.center,
                  child: AppIcon(icon, size: 17, color: const Color(0xFFFFFFFF)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title,
                      style: AppFonts.sf(
                          size: 17, color: c.ink, letterSpacing: -0.43)),
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
