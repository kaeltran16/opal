import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/providers.dart';
import '../../models/models.dart';
import '../../theme/theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/press_scale.dart';
import '../you/sub_screen.dart';

const double _pillHeight = 48;
const double _resultIcon = 15;

/// Settings → Export data.
///
/// Serializes every [Entry] to a JSON array and copies it to the clipboard —
/// a dependency-free export the user can paste anywhere. No network, nothing
/// leaves the device unless the user chooses to paste it.
class ExportDataScreen extends ConsumerStatefulWidget {
  const ExportDataScreen({super.key});

  @override
  ConsumerState<ExportDataScreen> createState() => _ExportDataScreenState();
}

class _ExportDataScreenState extends ConsumerState<ExportDataScreen> {
  int? _count;
  bool _busy = false;
  String? _result;
  bool _ok = true;

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  Future<void> _loadCount() async {
    final all = await ref.read(entryRepositoryProvider).getAll();
    if (!mounted) return;
    setState(() => _count = all.length);
  }

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final all = await ref.read(entryRepositoryProvider).getAll();
      final json = const JsonEncoder.withIndent('  ')
          .convert(all.map(_entryToMap).toList());
      await Clipboard.setData(ClipboardData(text: json));
      if (!mounted) return;
      setState(() {
        _count = all.length;
        _ok = true;
        _result = 'Copied ${all.length} '
            '${all.length == 1 ? 'entry' : 'entries'} to the clipboard.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _ok = false;
        _result = "Couldn't copy. Try again.";
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static Map<String, dynamic> _entryToMap(Entry e) => {
        'id': e.id,
        'timestamp': e.timestamp.toIso8601String(),
        'type': e.type.wire,
        'title': e.title,
        'detail': e.detail,
        'amount': e.amount,
        'duration': e.duration,
        'calories': e.calories,
        'distance': e.distance,
        'category': e.category,
        'ritualId': e.ritualId,
        'note': e.note,
        'source': e.source.wire,
        'sourceRef': e.sourceRef,
        'workoutId': e.workoutId,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final count = _count;
    final label = count == null
        ? 'Copy entries as JSON'
        : 'Copy $count ${count == 1 ? 'entry' : 'entries'} as JSON';
    final result = _result;
    // the error reads in care ink beside its words, never colour alone.
    final resultInk = _ok ? c.ink2 : c.careInk;

    return SubScreen(
      eyebrow: 'Settings',
      title: 'Export data',
      children: [
        const SizedBox(height: Spacing.xxl),
        Semantics(
          header: true,
          child: Text('Export your timeline',
              style: AppType.headline.copyWith(color: c.ink)),
        ),
        const SizedBox(height: Spacing.sm),
        Text(
          'Copies every logged entry as a JSON array to your '
          'clipboard. Paste it into a note, a spreadsheet, or a backup.',
          style: AppType.subhead.copyWith(color: c.ink2),
        ),
        const SizedBox(height: Spacing.xxl),
        _PrimaryPill(label: _busy ? 'Copying…' : label, onTap: _export),
        if (result != null) ...[
          const SizedBox(height: Spacing.lg),
          Row(
            children: [
              AppIcon(_ok ? 'checkmark' : 'xmark', size: _resultIcon, color: resultInk),
              const SizedBox(width: Spacing.sm),
              Flexible(
                child: Text(result, style: AppType.subhead.copyWith(color: resultInk)),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// The screen's one primary action.
class _PrimaryPill extends StatelessWidget {
  const _PrimaryPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PressScale(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        constraints: const BoxConstraints(minHeight: _pillHeight),
        padding: const EdgeInsets.symmetric(horizontal: Spacing.xl, vertical: Spacing.sm),
        decoration: BoxDecoration(
          color: c.ink,
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        alignment: Alignment.center,
        child: Text(label,
            textAlign: TextAlign.center,
            style: AppType.headline.copyWith(color: c.bg)),
      ),
    );
  }
}
