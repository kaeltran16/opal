import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../analysis/pal_findings.dart';
import '../../controllers/pal_findings_controller.dart';
import '../../controllers/pal_memory_controller.dart';
import '../../controllers/providers.dart';
import '../../services/pal/pal_service.dart';
import '../../theme/theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/press_scale.dart';
import 'sub_screen.dart';

const double _minTap = 44;
const double _factMinHeight = 48;
const double _patternMinHeight = 56;
const double _hairline = 1;
const double _closeIcon = 13;
// the x's tap target hangs into the gutter so its glyph lines up with the edge.
const double _closeHang = 10;

/// What Pal remembers, pushed from You: the facts you told Pal, the patterns
/// it uses (the same findings You lists, so a dismissal leaves both), and an
/// inline confirm to clear it all.
class PalMemoryScreen extends ConsumerStatefulWidget {
  const PalMemoryScreen({super.key});

  @override
  ConsumerState<PalMemoryScreen> createState() => _PalMemoryScreenState();
}

class _PalMemoryScreenState extends ConsumerState<PalMemoryScreen> {
  bool _asking = false;

  /// Shown just above the tab bar and ask bar, as You shows its errors.
  void _showError(String message) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg,
          kSubScreenShellOverlay + Spacing.sm + bottom),
    ));
  }

  // the container, not ref, finishes the work after the server call: the
  // screen may be popped while it is in flight, and the change still lands.
  Future<void> _forget(PalFact fact) async {
    final container = ProviderScope.containerOf(context, listen: false);
    try {
      await container.read(palServiceProvider).deleteFact(fact.id);
    } catch (e) {
      debugPrint('pal memory: forgetting fact ${fact.id} failed: $e');
      if (mounted) _showError("Couldn't forget that. Try again.");
      return;
    }
    container.invalidate(palMemoryProvider);
  }

  Future<void> _clear() async {
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() => _asking = false);
    try {
      await container.read(palServiceProvider).clearMemory();
    } catch (e) {
      debugPrint('pal memory: clearing what Pal remembers failed: $e');
      if (mounted) _showError("Couldn't clear what Pal remembers. Try again.");
      return;
    }
    // dismiss before reloading memory, so the reload reads the new dismissals.
    await container.read(palFindingsControllerProvider.notifier).dismissAll();
    container.invalidate(palMemoryProvider);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final memory = ref.watch(palMemoryProvider);
    final findingsAsync = ref.watch(palFindingsControllerProvider);
    // nothing but the header until both lists are in, so the empty copy never
    // flashes on open.
    final loaded = memory.hasValue && (findingsAsync.hasValue || findingsAsync.hasError);
    final facts = memory.value?.facts ?? const <PalFact>[];
    final findings = findingsAsync.value ?? const <PalFinding>[];
    final findingsCtl = ref.read(palFindingsControllerProvider.notifier);

    return SubScreen(
      eyebrow: 'Facts and preferences Pal uses',
      title: 'What Pal remembers',
      children: [
        if (loaded && facts.isEmpty && findings.isEmpty) ...[
          const SizedBox(height: Spacing.md),
          Text(
            "As we talk, I'll note facts you mention and patterns I learn here. "
            'You can delete anything.',
            style: AppType.subhead.copyWith(color: c.ink3, height: 20 / 15),
          ),
        ],
        if (facts.isNotEmpty) ...[
          const SizedBox(height: Spacing.xxl),
          const _Heading('Facts you told Pal'),
          for (final f in facts)
            _Row(
              minHeight: _factMinHeight,
              closeLabel: 'Forget: ${f.text}',
              onClose: () => _forget(f),
              child: Text(f.text, style: AppType.callout.copyWith(color: c.ink, height: 22 / 16)),
            ),
        ],
        if (findings.isNotEmpty) ...[
          const SizedBox(height: Spacing.xxl),
          const _Heading('Patterns Pal uses'),
          Padding(
            padding: const EdgeInsets.only(top: Spacing.xxs, bottom: Spacing.xs),
            child: Text(
              'The same patterns as Pal noticed on You. Dismiss one and it leaves both.',
              style: AppType.caption.copyWith(color: c.ink3, height: 16 / 12, letterSpacing: 0.3),
            ),
          ),
          for (final f in findings)
            _Row(
              minHeight: _patternMinHeight,
              closeLabel: 'Dismiss: ${f.line}',
              onClose: () => findingsCtl.dismiss(f.id),
              child: _PatternText(finding: f),
            ),
        ],
        if (facts.isNotEmpty || findings.isNotEmpty) ...[
          const SizedBox(height: Spacing.xxl),
          _ClearRow(
            asking: _asking,
            onAsk: () => setState(() => _asking = true),
            onCancel: () => setState(() => _asking = false),
            onClear: _clear,
          ),
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
        child: Text(text,
            style: AppType.headline.copyWith(color: context.colors.ink, height: 22 / 17)),
      );
}

/// A pattern's line with its areas under it.
class _PatternText extends StatelessWidget {
  const _PatternText({required this.finding});

  final PalFinding finding;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final meta = finding.areasLabel;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(finding.line, style: AppType.callout.copyWith(color: c.ink, height: 22 / 16)),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: Spacing.xxs),
            Text(meta,
                style: AppType.caption.copyWith(color: c.ink3, height: 16 / 12, letterSpacing: 0.3)),
          ],
        ],
      ),
    );
  }
}

/// One item under a hairline, with an x at the right.
class _Row extends StatelessWidget {
  const _Row({
    required this.minHeight,
    required this.closeLabel,
    required this.onClose,
    required this.child,
  });

  final double minHeight;
  final String closeLabel;
  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.hair, width: _hairline)),
      ),
      child: Row(
        children: [
          Expanded(child: child),
          const SizedBox(width: Spacing.sm),
          Transform.translate(
            offset: const Offset(_closeHang, 0),
            // its own node, so the row's text does not merge into its label.
            child: Semantics(
              container: true,
              child: PressScale(
                onTap: onClose,
                semanticLabel: closeLabel,
                child: SizedBox.square(
                  dimension: _minTap,
                  child: Center(child: AppIcon('xmark', size: _closeIcon, color: c.ink3)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Clear what Pal remembers, asking inline before it clears.
class _ClearRow extends StatelessWidget {
  const _ClearRow({
    required this.asking,
    required this.onAsk,
    required this.onCancel,
    required this.onClear,
  });

  final bool asking;
  final VoidCallback onAsk;
  final VoidCallback onCancel;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      constraints: const BoxConstraints(minHeight: _factMinHeight),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.hair, width: _hairline)),
      ),
      child: Row(
        children: asking
            ? [
                Expanded(
                  child: Text('Clear everything Pal remembers?',
                      style: AppType.subhead.copyWith(color: c.ink2, height: 20 / 15)),
                ),
                const SizedBox(width: Spacing.sm),
                _TextButton('Cancel',
                    color: c.ink,
                    padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
                    onTap: onCancel),
                _TextButton('Clear',
                    color: c.dangerInk,
                    padding: const EdgeInsets.only(left: Spacing.sm),
                    onTap: onClear),
              ]
            : [
                Flexible(
                  child: _TextButton('Clear what Pal remembers',
                      color: c.dangerInk, onTap: onAsk),
                ),
              ],
      ),
    );
  }
}

class _TextButton extends StatelessWidget {
  const _TextButton(
    this.text, {
    required this.color,
    this.padding = EdgeInsets.zero,
    required this.onTap,
  });

  final String text;
  final Color color;
  final EdgeInsets padding;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        child: PressScale(
          onTap: onTap,
          semanticLabel: text,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _minTap, minWidth: _minTap),
            child: Padding(
              padding: padding,
              // widthFactor keeps the button as wide as its label when a Flexible bounds it.
              child: Align(
                widthFactor: 1,
                child: Text(text, style: AppType.headline.copyWith(color: color)),
              ),
            ),
          ),
        ),
      );
}
