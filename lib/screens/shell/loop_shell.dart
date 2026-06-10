import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/controls.dart';
import '../../widgets/loop_tab_bar.dart';
import '../../router.dart';

/// The persistent app shell: the indexed-stack tab bodies (from go_router's
/// [StatefulNavigationShell]) plus the visual [LoopTabBar], center FAB, and the
/// preview-only Tweaks gear. Replaces the old string-switch `HomeShell`.
class LoopShell extends StatelessWidget {
  const LoopShell({super.key, required this.navigationShell});

  /// The branch navigator stack provided by `StatefulShellRoute.indexedStack`.
  final StatefulNavigationShell navigationShell;

  /// Maps a branch index to the [LoopTabBar] string id and back.
  static const _tabIds = ['today', 'move', 'rituals', 'profile'];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final activeId = _tabIds[navigationShell.currentIndex];
    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: [
          Positioned.fill(child: navigationShell),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: LoopTabBar(
              active: activeId,
              onTab: (id) => _goBranch(_tabIds.indexOf(id)),
              // Handoff #2: the FAB now opens the unified Pal composer (the
              // single input surface) instead of the old Quick-Actions menu.
              onFab: () => context.pushNamed(AppRoute.palComposer.name),
            ),
          ),
          // Preview-only tweaks affordance (not part of the shipping design).
          Positioned(
            left: 12,
            bottom: 92,
            child: _TweaksButton(onTap: () => _openTweaks(context)),
          ),
        ],
      ),
    );
  }

  void _goBranch(int index) {
    // initialLocation:true returns to the branch root if it's the active tab
    // (matches iOS tab double-tap-to-root behaviour).
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  void _openTweaks(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.colors.bg,
      builder: (sheetContext) => const _TweaksSheet(),
    );
  }
}

/// The Tweaks sheet — now reads/writes the Riverpod `AppSettingsController`
/// (persisted), instead of the old setState callbacks.
class _TweaksSheet extends ConsumerWidget {
  const _TweaksSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final settings = ref.watch(appSettingsControllerProvider);
    final controller = ref.read(appSettingsControllerProvider.notifier);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tweaks',
                style: AppFonts.sf(
                    size: 22,
                    weight: FontWeight.w700,
                    color: c.ink,
                    letterSpacing: -0.35)),
            const SizedBox(height: 16),
            Segmented<Brightness>(
              options: const [
                (Brightness.light, 'Light'),
                (Brightness.dark, 'Dark')
              ],
              value: settings.brightness,
              onChanged: (b) {
                controller.setBrightness(b);
                Navigator.pop(context);
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
                      controller.setAccent(a);
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: settings.brightness == Brightness.dark
                            ? a.dark()
                            : a.light(),
                        shape: BoxShape.circle,
                        border: a == settings.accent
                            ? Border.all(color: c.ink, width: 2)
                            : Border.all(color: c.hair, width: 0.5),
                      ),
                      child: a == settings.accent
                          ? const AppIcon('checkmark',
                              size: 16, color: Color(0xFFFFFFFF))
                          : null,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
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
          boxShadow: const [
            BoxShadow(
                color: Color(0x22000000), blurRadius: 10, offset: Offset(0, 2))
          ],
        ),
        alignment: Alignment.center,
        child: AppIcon('gearshape.fill', size: 16, color: c.ink2),
      ),
    );
  }
}

/// Simple centred placeholder body for tabs/screens not yet built.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ColoredBox(
      color: c.bg,
      child: Center(
        child: Text('$label — coming soon',
            style: AppFonts.sf(size: 17, color: c.ink3, letterSpacing: -0.43)),
      ),
    );
  }
}
