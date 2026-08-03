import 'package:riverpod_annotation/riverpod_annotation.dart';

// prefixed so the provider function `spendPatterns` does not collide with the
// pure `detectSpendPatterns` it calls, and to keep the analysis origin visible.
import '../analysis/spend_patterns.dart' as sp;
import 'providers.dart';

part 'spend_patterns_controller.g.dart';

/// Spend patterns over the rolling window — biggest weekday, weekend split,
/// daypart peak, no-spend streak, standout expenses.
///
/// Reactive: re-emits whenever in-window entries change. Every finding is
/// independently gated, so an [sp.SpendPatterns.isEmpty] result is the honest
/// answer for a thin history rather than a failure.
@riverpod
Stream<sp.SpendPatterns> spendPatterns(Ref ref) async* {
  final entriesRepo = ref.watch(entryRepositoryProvider);

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final start = today.subtract(const Duration(days: sp.kSpendWindowDays - 1));
  final end = today.add(const Duration(days: 1));

  await for (final entries in entriesRepo.watchEntriesInRange(start, end)) {
    yield sp.detectSpendPatterns(sp.aggregateSpend(entries, now: now));
  }
}
