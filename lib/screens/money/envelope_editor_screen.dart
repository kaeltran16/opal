import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/budget_envelopes_controller.dart';
import '../../controllers/budget_recommendations_controller.dart';
import '../../controllers/budgets_controller.dart';
import '../../controllers/providers.dart';
import '../../models/models.dart';
import '../../theme/theme.dart';
import '../../util/format.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/failure_note.dart';
import '../../widgets/press_scale.dart';
import '../you/sub_screen.dart';
import 'envelope_sheets.dart';

const double _tapTarget = 44;
const double _rowHeight = 56;
const double _rowGlyph = 22;
const double _handleGlyph = 20;
const double _rowGlyphGap = 14;
const double _hairWidth = 1;
const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

/// Budgets' envelope editor: each envelope's cap (tap to edit, drag to
/// reorder), New envelope, and the suggested caps to apply. Every write goes
/// through [budgetEnvelopesControllerProvider]; a failed list write shows a
/// [FailureNote] under the summary until the next write lands.
class EnvelopeEditorScreen extends ConsumerStatefulWidget {
  const EnvelopeEditorScreen({super.key});

  @override
  ConsumerState<EnvelopeEditorScreen> createState() => _EnvelopeEditorScreenState();
}

class _EnvelopeEditorScreenState extends ConsumerState<EnvelopeEditorScreen> {
  bool _listFailed = false;

  /// The dragged order, held until the stream catches up so the row doesn't
  /// snap back; null shows the stream's order.
  List<BudgetEnvelope>? _dragged;

  /// Runs a list write; a throw shows the note and drops the dragged order.
  Future<void> _write(Future<void> Function() write, String action) async {
    try {
      await write();
    } catch (e, st) {
      debugPrint('envelopes: $action failed: $e\n$st');
      if (mounted) {
        setState(() {
          _listFailed = true;
          _dragged = null;
        });
      }
    }
  }

  void _reorder(List<BudgetEnvelope> envelopes, int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    final moved = List.of(envelopes);
    moved.insert(newIndex, moved.removeAt(oldIndex));
    setState(() => _dragged = moved);
    _write(
      () => ref.read(budgetEnvelopesControllerProvider.notifier).reorder(oldIndex, newIndex),
      'reordering',
    );
  }

  void _apply(BudgetRecommendation rec) => _write(
        () => ref
            .read(budgetEnvelopesControllerProvider.notifier)
            .applyCap(rec.category, rec.suggestedCap),
        'applying the ${rec.category} cap',
      );

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // any emission is a write that landed: it clears the note and the drag.
    ref.listen(budgetEnvelopesControllerProvider, (_, next) {
      if (next.hasValue) {
        setState(() {
          _listFailed = false;
          _dragged = null;
        });
      }
    });
    final async = ref.watch(budgetEnvelopesControllerProvider);
    // kept loaded so a cap sheet opens with its spend note already there.
    ref.watch(budgetsDataProvider);

    return SubScreen(
      eyebrow: 'Budgets',
      title: 'Envelopes',
      backLabel: 'Budgets',
      children: [
        async.when(
          loading: () => _notice(Text('…', style: AppType.body.copyWith(color: c.ink3))),
          error: (e, st) {
            debugPrint("envelopes: couldn't load: $e\n$st");
            return _notice(Text("Couldn't load your envelopes.",
                style: AppType.subhead.copyWith(color: c.ink3)));
          },
          data: (envelopes) => _body(_dragged ?? envelopes),
        ),
      ],
    );
  }

  static Widget _notice(Widget child) => Padding(
        padding: const EdgeInsets.only(top: Spacing.xxl),
        child: child,
      );

  Widget _body(List<BudgetEnvelope> envelopes) {
    final c = context.colors;
    final currency = ref.watch(appSettingsControllerProvider).currency;
    final quiet = AppType.subhead.copyWith(color: c.ink3, fontFeatures: _tabular);
    final total = envelopes.fold<double>(0, (sum, e) => sum + e.cap);
    final count = envelopes.length;
    final summary = count == 0
        ? 'Caps you set here pace this month’s spending.'
        : '$count ${count == 1 ? 'envelope' : 'envelopes'} · '
            '${formatCurrency(total, currency)} a month';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: Spacing.sm),
        Text(summary, style: quiet),
        if (_listFailed) ...[
          const SizedBox(height: Spacing.lg),
          const FailureNote(),
        ],
        const SizedBox(height: Spacing.xxl),
        if (envelopes.isEmpty)
          _HairTop(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.md),
              child: Text('No envelopes yet. Add one, or use a suggested cap below.',
                  style: quiet),
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: envelopes.length,
            onReorderItem: (oldIndex, newIndex) => _reorder(envelopes, oldIndex, newIndex),
            proxyDecorator: (child, _, _) => ColoredBox(color: c.surface2, child: child),
            itemBuilder: (context, i) {
              final envelope = envelopes[i];
              return _EnvelopeRow(
                key: ValueKey(envelope.id),
                index: i,
                envelope: envelope,
                cap: formatCurrency(envelope.cap, currency),
                onTap: () => showEnvelopeCapSheet(context, ref, envelope),
              );
            },
          ),
        _HairTop(
          child: PressScale(
            onTap: () => showNewEnvelopeSheet(context, ref),
            semanticLabel: 'New envelope',
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: _rowHeight),
              child: Row(
                children: [
                  AppIcon('plus', size: _rowGlyph, color: c.ink2),
                  const SizedBox(width: _rowGlyphGap),
                  Text('New envelope', style: AppType.body.copyWith(color: c.ink)),
                ],
              ),
            ),
          ),
        ),
        if (envelopes.isNotEmpty) ...[
          const SizedBox(height: Spacing.sm),
          Text('Tap an envelope to change its cap. Drag to reorder.', style: quiet),
        ],
        _Suggestions(currency: currency, onUse: _apply),
      ],
    );
  }
}

/// A 1px hairline above [child], at least a row tall.
class _HairTop extends StatelessWidget {
  const _HairTop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: _rowHeight),
      alignment: AlignmentDirectional.centerStart,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.colors.hair, width: _hairWidth)),
      ),
      child: child,
    );
  }
}

/// An envelope: its line glyph, name and cap (tap to edit), then the handle.
class _EnvelopeRow extends StatelessWidget {
  const _EnvelopeRow({
    super.key,
    required this.index,
    required this.envelope,
    required this.cap,
    required this.onTap,
  });

  final int index;
  final BudgetEnvelope envelope;
  final String cap;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final name = envelope.category;
    return _HairTop(
      child: Row(
        children: [
          Expanded(
            child: PressScale(
              onTap: onTap,
              semanticLabel: '$name, $cap a month. Edit cap',
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: _rowHeight),
                child: Row(
                  children: [
                    AppIcon.line(envelope.icon, size: _rowGlyph, color: c.ink2),
                    const SizedBox(width: _rowGlyphGap),
                    Expanded(
                      child: Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.body.copyWith(color: c.ink)),
                    ),
                    const SizedBox(width: Spacing.md),
                    Text(cap,
                        style: AppType.subhead.copyWith(color: c.ink2, fontFeatures: _tabular)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: Spacing.xs),
          Semantics(
            button: true,
            label: 'Reorder $name',
            excludeSemantics: true,
            child: ReorderableDragStartListener(
              index: index,
              child: SizedBox(
                width: _tapTarget,
                height: _tapTarget,
                child: Center(
                  child: AppIcon('line.3.horizontal', size: _handleGlyph, color: c.ink3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Suggested caps that differ from the current one, each with Use. Left out
/// while loading, on error, or when no row remains.
class _Suggestions extends ConsumerWidget {
  const _Suggestions({required this.currency, required this.onUse});

  final Currency currency;
  final ValueChanged<BudgetRecommendation> onUse;

  static String _trendWord(SpendTrend trend) => switch (trend) {
        SpendTrend.increasing => 'trending up',
        SpendTrend.decreasing => 'trending down',
        SpendTrend.stable => 'steady',
      };

  String _why(BudgetRecommendation rec) {
    final average = '${formatCurrency(rec.monthlyAverage, currency)}/mo';
    final current = rec.currentCap;
    if (current == null) return 'No envelope yet · $average';
    return '$average · ${_trendWord(rec.trend)} · now ${formatCurrency(current, currency)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final recs = [
      for (final rec in ref.watch(budgetRecommendationsProvider).asData?.value ??
          const <BudgetRecommendation>[])
        if (rec.currentCap != rec.suggestedCap) rec,
    ];
    if (recs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: Spacing.xxxl),
        Semantics(
          header: true,
          child: Text('Suggested caps', style: AppType.headline.copyWith(color: c.ink)),
        ),
        const SizedBox(height: Spacing.xs),
        for (final rec in recs) _suggestion(context, rec),
        const SizedBox(height: Spacing.sm),
        Text('From your spending over the last 3 months.',
            style: AppType.subhead.copyWith(color: c.ink3)),
      ],
    );
  }

  Widget _suggestion(BuildContext context, BudgetRecommendation rec) {
    final c = context.colors;
    final cap = formatCurrency(rec.suggestedCap, currency);
    return _HairTop(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
        child: Row(
          children: [
            Expanded(
              child: MergeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rec.category, style: AppType.callout.copyWith(color: c.ink)),
                    Text(_why(rec),
                        style: AppType.subhead.copyWith(color: c.ink3, fontFeatures: _tabular)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: Spacing.md),
            Text(cap, style: AppType.subhead.copyWith(color: c.ink2, fontFeatures: _tabular)),
            PressScale(
              onTap: () => onUse(rec),
              semanticLabel: 'Use $cap for ${rec.category}',
              child: SizedBox(
                height: _tapTarget,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
                  child: Center(
                    widthFactor: 1,
                    child: Text('Use', style: AppType.headline.copyWith(color: c.ink)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
