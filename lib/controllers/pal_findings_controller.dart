import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../analysis/pal_findings.dart';
import 'correlations_controller.dart';
import 'nutrition_controller.dart';
import 'pal_memory_controller.dart';
import 'providers.dart';
import 'spend_patterns_controller.dart';

part 'pal_findings_controller.g.dart';

/// Every Pal finding, in source order (correlations, spend patterns,
/// Nutrition's patterns, Pal's memory patterns), with the dismissed ones
/// removed. You and What Pal remembers both read this, so a dismissal leaves
/// both lists at once.
@riverpod
class PalFindingsController extends _$PalFindingsController {
  @override
  Future<List<PalFinding>> build() async {
    // every ref use happens before the first await: a source that errors and
    // retries rebuilds this provider, and the stale build must not touch ref.
    final currency = ref.watch(appSettingsControllerProvider).currency;
    final dismissed = ref.watch(settingsRepositoryProvider).dismissedFindings;
    final sources = await Future.wait([
      _source(
        'correlations',
        () async => findingsFromCorrelations(
          await ref.watch(surfacedCorrelationsProvider.future),
          currency,
        ),
      ),
      _source(
        'spend patterns',
        () async => findingsFromSpendPatterns(
          await ref.watch(spendPatternsProvider.future),
          currency,
        ),
      ),
      _source(
        'nutrition patterns',
        () async => findingsFromNutritionPatterns(
          (await ref.watch(nutritionControllerProvider.future)).patterns,
        ),
      ),
      _source(
        'pal memory',
        () async => findingsFromPalPatterns(
          (await ref.watch(palMemoryProvider.future)).patterns,
        ),
      ),
    ]);
    return [
      for (final f in sources.expand((s) => s))
        if (!dismissed.contains(f.id)) f,
    ];
  }

  // one failing source must not hide the others' findings.
  Future<List<PalFinding>> _source(
    String name,
    Future<List<PalFinding>> Function() load,
  ) async {
    try {
      return await load();
    } catch (e, st) {
      debugPrint('pal findings: $name source failed: $e\n$st');
      return const [];
    }
  }

  Future<void> dismiss(String id) => _dismiss({id});

  /// Dismisses every finding currently shown.
  Future<void> dismissAll() =>
      _dismiss({for (final f in state.value ?? const <PalFinding>[]) f.id});

  Future<void> _dismiss(Set<String> ids) async {
    if (ids.isEmpty) return;
    await ref.read(settingsRepositoryProvider).addDismissedFindings(ids);
    final current = state.value;
    if (current == null) return;
    state = AsyncData([
      for (final f in current)
        if (!ids.contains(f.id)) f,
    ]);
  }
}
