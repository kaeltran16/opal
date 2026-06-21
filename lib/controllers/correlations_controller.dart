import 'package:riverpod_annotation/riverpod_annotation.dart';

// prefixed so the provider function `surfacedCorrelations` does not collide
// with the pure `surfacedCorrelations` it calls (same name, same scope).
import '../analysis/correlations.dart' as corr;
import 'providers.dart';

part 'correlations_controller.g.dart';

/// Surfaced cross-dimension correlations over the rolling window, strongest
/// first. Computed on-device from entries + meals; empty when nothing clears
/// the confidence bar (the honest empty state). Single source of truth shared
/// by the Insights and Nutrition surfaces.
@riverpod
Future<List<corr.Correlation>> surfacedCorrelations(Ref ref) async {
  final entryRepo = ref.watch(entryRepositoryProvider);
  final nutritionRepo = ref.watch(nutritionRepositoryProvider);

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final start =
      today.subtract(const Duration(days: corr.kCorrelationWindowDays - 1));
  final end = today.add(const Duration(days: 1));

  final entries = await entryRepo.getEntriesInRange(start, end);
  final meals = await nutritionRepo.getMealsInRange(start, end);

  final vectors = corr.buildDailyVectors(entries, meals, now: now);
  return corr.surfacedCorrelations(vectors);
}
