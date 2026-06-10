import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/providers.dart';
import '../../models/models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/app_icon.dart';
import '../email/email_nav.dart';

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
    final all = await ref.read(entryRepositoryProvider).getAll();
    final json = const JsonEncoder.withIndent('  ')
        .convert(all.map(_entryToMap).toList());
    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) return;
    setState(() {
      _busy = false;
      _count = all.length;
      _result = 'Copied ${all.length} '
          '${all.length == 1 ? 'entry' : 'entries'} to the clipboard.';
    });
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

    return ColoredBox(
      color: c.bg,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          EmailNavBar(
            title: 'Export data',
            leadingLabel: 'You',
            onLeading: () => context.pop(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: c.accentTint,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: AppIcon('square.and.arrow.up', size: 32, color: c.accent),
                ),
                const SizedBox(height: 18),
                Text(
                  'Export your timeline',
                  style: AppFonts.sf(
                      size: 22,
                      weight: FontWeight.w700,
                      color: c.ink,
                      letterSpacing: -0.35),
                ),
                const SizedBox(height: 8),
                Text(
                  'Copies every logged entry as a JSON array to your '
                  'clipboard. Paste it into a note, a spreadsheet, or a backup.',
                  textAlign: TextAlign.center,
                  style: AppFonts.sf(
                      size: 15, color: c.ink3, letterSpacing: -0.24, height: 1.3),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GestureDetector(
              onTap: _export,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: c.accent,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  _busy ? 'Copying…' : label,
                  style: AppFonts.sf(
                      size: 17,
                      weight: FontWeight.w600,
                      color: const Color(0xFFFFFFFF),
                      letterSpacing: -0.43),
                ),
              ),
            ),
          ),
          if (_result != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppIcon('checkmark', size: 15, color: c.move),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _result!,
                      style: AppFonts.sf(
                          size: 14, color: c.ink3, letterSpacing: -0.15),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
