import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/mood_controller.dart';
import '../../theme/theme.dart';
import '../../util/mood_scale.dart';
import '../../widgets/press_scale.dart';
import 'widgets/mood_widgets.dart';

/// Opens the mood logger as a modal bottom sheet.
Future<void> showMoodLogger(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    // present over the shell so the sheet covers the bottom nav; without this it
    // opens on the tab's nested navigator and the shell's nav bar paints over the
    // sticky Log button (matches the nutrition sheets).
    useRootNavigator: true,
    backgroundColor: context.colors.bg,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
    ),
    builder: (_) => const _MoodLoggerSheet(),
  );
}

// ─── Sheet content ────────────────────────────────────────────────────────────

class _MoodLoggerSheet extends ConsumerStatefulWidget {
  const _MoodLoggerSheet();

  @override
  ConsumerState<_MoodLoggerSheet> createState() => _MoodLoggerSheetState();
}

class _MoodLoggerSheetState extends ConsumerState<_MoodLoggerSheet> {
  double _t = 0.5;
  String? _tag;

  Future<void> _log() async {
    await ref
        .read(moodControllerProvider.notifier)
        .logCheckin(_t, _tag);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = c.brightness == Brightness.dark;
    final tColor = moodColor(_t, dark);

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      maxChildSize: 0.94,
      minChildSize: 0.5,
      expand: false,
      builder: (ctx, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: c.bg,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(Radii.lg),
            ),
          ),
          child: Column(
            children: [
              // sticky header
              _SheetHeader(
                tColor: tColor,
                onCancel: () => Navigator.of(context).pop(),
              ),
              // scrollable body
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(
                    Spacing.lg,
                    Spacing.xl,
                    Spacing.lg,
                    Spacing.xxxl,
                  ),
                  children: [
                    // eyebrow
                    Text(
                      'HOW YOU FEEL RIGHT NOW',
                      style: AppFonts.sf(
                        size: 11.5,
                        weight: FontWeight.w700,
                        color: c.ink3,
                        letterSpacing: 1.1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: Spacing.md),
                    // word readout
                    Text(
                      moodWord(_t),
                      style: AppFonts.sf(
                        size: 26,
                        weight: FontWeight.w700,
                        color: tColor,
                        letterSpacing: -0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: Spacing.xl),
                    // orb — centered
                    Center(
                      child: MoodOrb(t: _t, dark: dark),
                    ),
                    const SizedBox(height: Spacing.xl),
                    // scale track
                    MoodScaleTrack(
                      t: _t,
                      dark: dark,
                      onChanged: (v) => setState(() => _t = v),
                    ),
                    const SizedBox(height: Spacing.xl),
                    // tag section header
                    Text(
                      'ADD A WORD — OPTIONAL',
                      style: AppFonts.sf(
                        size: 11.5,
                        weight: FontWeight.w700,
                        color: c.ink3,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: Spacing.md),
                    // tag chips
                    Wrap(
                      spacing: Spacing.sm,
                      runSpacing: Spacing.sm,
                      children: moodTags.map((tag) {
                        final active = _tag == tag;
                        return PressScale(
                          onTap: () => setState(
                            () => _tag = active ? null : tag,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Spacing.md,
                              vertical: Spacing.sm - 1,
                            ),
                            decoration: BoxDecoration(
                              color: active
                                  ? tColor
                                  : c.fill,
                              borderRadius: BorderRadius.circular(Radii.pill),
                            ),
                            child: Text(
                              tag,
                              style: AppFonts.sf(
                                size: 14,
                                weight: active
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: active ? Colors.white : c.ink2,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: Spacing.xl),
                    // helper line
                    Text(
                      'Takes a few seconds. Just notice where you are — there\'s nothing to get right.',
                      style: AppType.subhead.copyWith(
                        color: c.ink3,
                        letterSpacing: -0.1,
                        height: 1.45,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              // sticky footer
              _LogButton(tColor: tColor, onLog: _log),
            ],
          ),
        );
      },
    );
  }
}

// ─── Sheet header ─────────────────────────────────────────────────────────────

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.tColor, required this.onCancel});
  final Color tColor;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(Spacing.sm, Spacing.md, Spacing.lg, 0),
      child: Row(
        children: [
          // Cancel button (tinted with mood color)
          TextButton(
            onPressed: onCancel,
            style: TextButton.styleFrom(
              foregroundColor: tColor,
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.sm,
                vertical: Spacing.xs,
              ),
            ),
            child: Text(
              'Cancel',
              style: AppType.body.copyWith(color: tColor),
            ),
          ),
          Expanded(
            child: Text(
              'Check in',
              style: AppType.headline.copyWith(color: c.ink),
              textAlign: TextAlign.center,
            ),
          ),
          // spacer to balance Cancel width
          const SizedBox(width: 70),
        ],
      ),
    );
  }
}

// ─── Log button ───────────────────────────────────────────────────────────────

class _LogButton extends StatelessWidget {
  const _LogButton({required this.tColor, required this.onLog});
  final Color tColor;
  final VoidCallback onLog;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.md, Spacing.lg, Spacing.lg),
        child: PressScale(
          pressedScale: 0.97,
          onTap: onLog,
          semanticLabel: 'Log mood',
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: Spacing.lg - 1),
            decoration: BoxDecoration(
              color: tColor,
              borderRadius: BorderRadius.circular(Radii.card),
              boxShadow: [
                BoxShadow(
                  color: tColor.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Text(
              'Log mood',
              style: AppFonts.sf(
                size: 17,
                weight: FontWeight.w600,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
