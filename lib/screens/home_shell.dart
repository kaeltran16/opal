import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/app_icon.dart';
import '../widgets/controls.dart';
import '../widgets/loop_tab_bar.dart';
import 'today_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.brightness,
    required this.accent,
    required this.onBrightness,
    required this.onAccent,
  });

  final Brightness brightness;
  final AppAccent accent;
  final ValueChanged<Brightness> onBrightness;
  final ValueChanged<AppAccent> onAccent;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  String _active = 'today';

  Widget _body() => switch (_active) {
        'today' => const TodayScreen(),
        _ => _Placeholder(label: _active),
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: [
          Positioned.fill(child: _body()),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: LoopTabBar(
              active: _active,
              onTab: (id) => setState(() => _active = id),
              onFab: () => _showQuickActions(context),
            ),
          ),
          // Preview-only tweaks affordance (not part of the shipping design).
          Positioned(
            left: 12,
            bottom: 92,
            child: _TweaksButton(onTap: _openTweaks),
          ),
        ],
      ),
    );
  }

  void _showQuickActions(BuildContext context) {
    final c = context.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: c.bg,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Quick Actions — coming soon',
              style: AppFonts.sf(size: 17, color: c.ink, letterSpacing: -0.43)),
        ),
      ),
    );
  }

  void _openTweaks() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.bg,
      builder: (sheetContext) {
        final c = context.colors;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tweaks',
                    style: AppFonts.sf(size: 22, weight: FontWeight.w700, color: c.ink, letterSpacing: -0.35)),
                const SizedBox(height: 16),
                Segmented<Brightness>(
                  options: const [(Brightness.light, 'Light'), (Brightness.dark, 'Dark')],
                  value: widget.brightness,
                  onChanged: (b) {
                    widget.onBrightness(b);
                    Navigator.pop(sheetContext);
                  },
                ),
                const SizedBox(height: 20),
                Text('ACCENT',
                    style: AppFonts.sf(size: 13, color: c.ink3, letterSpacing: 0.3)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    for (final a in AppAccent.values)
                      GestureDetector(
                        onTap: () {
                          widget.onAccent(a);
                          Navigator.pop(sheetContext);
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: widget.brightness == Brightness.dark ? a.dark() : a.light(),
                            shape: BoxShape.circle,
                            border: a == widget.accent
                                ? Border.all(color: c.ink, width: 2)
                                : Border.all(color: c.hair, width: 0.5),
                          ),
                          child: a == widget.accent
                              ? const AppIcon('checkmark', size: 16, color: Color(0xFFFFFFFF))
                              : null,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TweaksButton extends StatelessWidget {
  const _TweaksButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: c.surface.withValues(alpha: 0.9),
          shape: BoxShape.circle,
          border: Border.all(color: c.hair, width: 0.5),
          boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 10, offset: Offset(0, 2))],
        ),
        alignment: Alignment.center,
        child: AppIcon('gearshape.fill', size: 16, color: c.ink2),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ColoredBox(
      color: c.bg,
      child: Center(
        child: Text('${label[0].toUpperCase()}${label.substring(1)} — coming soon',
            style: AppFonts.sf(size: 17, color: c.ink3, letterSpacing: -0.43)),
      ),
    );
  }
}
