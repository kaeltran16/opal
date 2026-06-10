import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/providers.dart';
import '../../services/services.dart';
import '../../theme/app_colors.dart';
import '../../widgets/inset_section.dart';
import '../email/email_nav.dart';

/// Settings → HealthKit.
///
/// Shows the read-only connection (a permission request via [HealthService])
/// and today's movement summary. On iOS this is HealthKit; elsewhere the mock
/// service feeds canned samples so the screen still renders.
class HealthSettingsScreen extends ConsumerStatefulWidget {
  const HealthSettingsScreen({super.key});

  @override
  ConsumerState<HealthSettingsScreen> createState() =>
      _HealthSettingsScreenState();
}

class _HealthSettingsScreenState extends ConsumerState<HealthSettingsScreen> {
  bool _loading = true;
  bool _connecting = false;
  HealthSample? _sample;
  String? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await ref.read(healthServiceProvider).todaySample();
      if (!mounted) return;
      setState(() {
        _sample = s;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _connect() async {
    if (_connecting) return;
    setState(() => _connecting = true);
    final ok = await ref.read(healthServiceProvider).requestPermissions();
    if (!mounted) return;
    setState(() {
      _connecting = false;
      _status = ok ? 'Connected' : 'Not available';
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = _sample;
    return ColoredBox(
      color: c.bg,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          EmailNavBar(
            title: 'Health',
            leadingLabel: 'You',
            onLeading: () => context.pop(),
          ),
          const SizedBox(height: 8),
          InsetSection(
            header: 'Connection',
            footer: 'Opal reads move minutes, active energy, steps and heart '
                'rate. Access is read-only.',
            children: [
              ListRow(
                icon: 'heart.fill',
                iconBg: c.move,
                title: 'Apple Health',
                subtitle: 'Read-only access',
                value: _connecting ? '…' : (_status ?? 'Connected'),
                valueColor: c.move,
                chevron: false,
                last: true,
                onTap: _connect,
              ),
            ],
          ),
          InsetSection(
            header: 'Today',
            children: _loading
                ? [
                    ListRow(
                      title: 'Loading…',
                      chevron: false,
                      last: true,
                    ),
                  ]
                : [
                    ListRow(
                      icon: 'figure.run',
                      iconBg: c.move,
                      title: 'Move minutes',
                      value: s == null ? '—' : '${s.moveMinutes} min',
                      chevron: false,
                    ),
                    ListRow(
                      icon: 'flame.fill',
                      iconBg: c.money,
                      title: 'Active energy',
                      value: s == null ? '—' : '${s.activeEnergyKcal} kcal',
                      chevron: false,
                    ),
                    ListRow(
                      icon: 'figure.walk',
                      iconBg: c.accent,
                      title: 'Steps',
                      value: (s?.steps == null) ? '—' : '${s!.steps}',
                      chevron: false,
                    ),
                    ListRow(
                      icon: 'heart.fill',
                      iconBg: c.red,
                      title: 'Heart rate',
                      value: (s?.avgHeartRate == null)
                          ? '—'
                          : '${s!.avgHeartRate} bpm',
                      chevron: false,
                      last: true,
                    ),
                  ],
          ),
        ],
      ),
    );
  }
}
