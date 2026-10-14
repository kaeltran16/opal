import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/mood_controller.dart';
import '../../theme/theme.dart';
import '../../util/mood_scale.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/controls.dart';
import 'widgets/mood_widgets.dart';

/// Opens the mood logger as the app's bottom sheet.
Future<void> showMoodLogger(BuildContext context) {
  // scrollable: the orb, track and tags outgrow the default sheet height.
  return showAppSheet<void>(
    context,
    scrollable: true,
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Spacing.lg,
      children: [
        Semantics(
          header: true,
          child: Text('Check in', style: AppType.title.copyWith(color: c.ink)),
        ),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'How you feel right now',
                  style: AppType.label.copyWith(color: c.ink3),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  moodWord(_t),
                  style: AppType.title.copyWith(color: moodColor(_t, dark)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Spacing.xl),
                Center(child: MoodOrb(t: _t, dark: dark)),
                const SizedBox(height: Spacing.xl),
                MoodScaleTrack(
                  t: _t,
                  dark: dark,
                  onChanged: (v) => setState(() => _t = v),
                ),
                const SizedBox(height: Spacing.xl),
                Text(
                  'Add a word, optional',
                  style: AppType.label.copyWith(color: c.ink3),
                ),
                const SizedBox(height: Spacing.xs),
                Wrap(
                  spacing: Spacing.sm,
                  children: [
                    for (final tag in moodTags)
                      AppChip(
                        label: tag,
                        selected: _tag == tag,
                        onTap: () => setState(
                          () => _tag = _tag == tag ? null : tag,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: Spacing.lg),
                Text(
                  'Takes a few seconds. Just notice where you are — there\'s nothing to get right.',
                  style: AppType.subhead.copyWith(color: c.ink3),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        PillButton(label: 'Log mood', semanticLabel: 'Log mood', onTap: _log),
        PillButton(
          label: 'Cancel',
          primary: false,
          onTap: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
