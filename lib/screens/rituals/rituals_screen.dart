import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/rituals_controller.dart';
import '../../models/models.dart';
import '../../router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/controls.dart';
import '../../widgets/inset_section.dart';
import '../../widgets/nav_bar.dart';

/// Screen 13 — Rituals landing.
///
/// Large-title nav "Rituals" + streak subtitle, a "N / M today" progress card
/// (rituals-purple), today's rituals as an inset-grouped list with a trailing
/// [CheckButton] per row, and a "Manage rituals" outline button. Toggling a
/// row's check writes/removes a ritual-type [Entry] (so the Today rituals ring
/// updates) and fires a light haptic — all via `ritualsControllerProvider`.
class RitualsScreen extends ConsumerWidget {
  const RitualsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final async = ref.watch(ritualsControllerProvider);

    return async.when(
      loading: () => Center(
        child: Text('…',
            style: AppFonts.sf(size: 17, color: c.ink3, letterSpacing: -0.43)),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text("Couldn't load rituals.\n$e",
              textAlign: TextAlign.center,
              style: AppFonts.sf(size: 15, color: c.ink3, letterSpacing: -0.24)),
        ),
      ),
      data: (state) => _RitualsBody(state: state),
    );
  }
}

class _RitualsBody extends ConsumerWidget {
  const _RitualsBody({required this.state});
  final RitualsState state;

  String get _subtitle {
    final streak = state.bestStreak;
    if (streak <= 0) return 'Build your daily streak';
    return '$streak-day streak · keep it going';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final done = state.doneCount;
    final total = state.totalCount;

    return ListView(
      padding: const EdgeInsets.only(bottom: 110),
      children: [
        LargeTitleNavBar(
          title: 'Rituals',
          subtitle: _subtitle,
          trailing: const NavIconButton(name: 'flame.fill', semanticLabel: 'Streak'),
        ),

        // "N / M today" progress card (rituals-purple).
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            decoration: BoxDecoration(
                color: c.surface, borderRadius: BorderRadius.circular(18)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                          color: c.rituals,
                          borderRadius: BorderRadius.circular(9)),
                      alignment: Alignment.center,
                      child: const AppIcon('sparkles',
                          size: 15, color: Color(0xFFFFFFFF)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('TODAY',
                              style: AppFonts.sf(
                                  size: 12,
                                  weight: FontWeight.w700,
                                  color: c.ink3,
                                  letterSpacing: 0.3)),
                          Text(
                            total == 0
                                ? 'No rituals yet'
                                : (done == total
                                    ? 'All done · nice'
                                    : '${total - done} to close'),
                            style: AppFonts.sf(
                                size: 13,
                                weight: FontWeight.w500,
                                color: c.ink2,
                                letterSpacing: -0.08),
                          ),
                        ],
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '$done',
                            style: AppFonts.sf(
                                size: 28,
                                weight: FontWeight.w700,
                                color: c.ink,
                                letterSpacing: 0.36,
                                tabular: true),
                          ),
                          TextSpan(
                            text: ' / $total',
                            style: AppFonts.sf(
                                size: 17,
                                weight: FontWeight.w600,
                                color: c.ink3,
                                letterSpacing: -0.43,
                                tabular: true),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ProgressBar(value: state.progress, color: c.rituals, height: 6),
              ],
            ),
          ),
        ),

        // Today's rituals — inset-grouped list with trailing CheckButton.
        if (total == 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Center(
              child: Text('No rituals yet. Add some to get started.',
                  textAlign: TextAlign.center,
                  style: AppFonts.sf(
                      size: 15, color: c.ink3, letterSpacing: -0.24)),
            ),
          )
        else
          InsetSection(
            header: "Today's rituals",
            children: [
              for (var i = 0; i < state.rituals.length; i++)
                _RitualRow(
                  ritual: state.rituals[i],
                  done: state.isDone(state.rituals[i].id),
                  last: i == state.rituals.length - 1,
                ),
            ],
          ),

        // "Manage rituals" outline button → stubbed builder route (U21b).
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: _OutlineButton(
            label: 'Manage rituals',
            icon: 'slider.horizontal.3',
            onTap: () => context.pushNamed(AppRoute.manageRituals.name),
          ),
        ),
      ],
    );
  }
}

/// A single ritual row: tinted icon + title/streak subtitle + trailing check.
class _RitualRow extends ConsumerWidget {
  const _RitualRow({
    required this.ritual,
    required this.done,
    required this.last,
  });

  final Ritual ritual;
  final bool done;
  final bool last;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final subtitle = ritual.streak > 0 ? '${ritual.streak}-day streak' : null;
    void toggle() => ref.read(ritualsControllerProvider.notifier).toggle(ritual);
    // Compose the shared ListRow (icon + title/subtitle + separator, no chevron)
    // and overlay a trailing CheckButton in the value slot via a Stack.
    return Stack(
      alignment: Alignment.centerRight,
      children: [
        ListRow(
          icon: ritual.icon,
          iconBg: c.rituals,
          title: ritual.title,
          subtitle: subtitle,
          chevron: false,
          last: last,
          onTap: toggle,
        ),
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: CheckButton(
            checked: done,
            typeColor: c.rituals,
            onTap: toggle,
          ),
        ),
      ],
    );
  }
}

/// iOS-style outline (tertiary) button used for "Manage rituals".
class _OutlineButton extends StatelessWidget {
  const _OutlineButton({
    required this.label,
    required this.onTap,
    this.icon,
  });

  final String label;
  final String? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.hair, width: 1),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              AppIcon(icon!, size: 16, color: c.accent),
              const SizedBox(width: 8),
            ],
            Text(label,
                style: AppFonts.sf(
                    size: 17,
                    weight: FontWeight.w600,
                    color: c.accent,
                    letterSpacing: -0.43)),
          ],
        ),
      ),
    );
  }
}
