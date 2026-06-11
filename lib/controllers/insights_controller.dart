import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../services/pal/pal_service.dart';
import 'providers.dart';

part 'insights_controller.g.dart';

/// Minimum entries in the gate window before we ask Pal for insights. Below
/// this a fresh user has nothing real to reflect on, so we skip the call and
/// the surfaces show their encouraging empty state instead of fabricated copy.
const _minInsightEntries = 3;

/// SF Symbol for an insight row, derived deterministically from its color token
/// so the model never has to (and can't mis-)name an icon.
String insightIcon(String colorToken) => switch (colorToken) {
      'money' => 'dollarsign.circle.fill',
      'move' => 'figure.run',
      _ => 'sparkles',
    };

/// Structured Pal insights for a [range], or null when there isn't enough data
/// (or Pal is unreachable) — in which case the surfaces render an empty state.
///
/// One-shot (not a stream): an LLM call shouldn't fire on every entry edit. The
/// gate window is the data each surface's insight draws on — Today (day) looks
/// back two weeks for streak/patterns; week/month use their own period.
@riverpod
Future<PalInsights?> insights(Ref ref, InsightRange range) async {
  final repo = ref.watch(entryRepositoryProvider);
  final pal = ref.watch(palServiceProvider);

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final (DateTime start, DateTime end) = switch (range) {
    InsightRange.day => (
        today.subtract(const Duration(days: 13)),
        today.add(const Duration(days: 1)),
      ),
    InsightRange.week => (
        today.subtract(Duration(days: now.weekday - 1)),
        today.add(const Duration(days: 1)),
      ),
    InsightRange.month => (
        DateTime(now.year, now.month),
        DateTime(now.year, now.month + 1),
      ),
  };

  final windowEntries = await repo.getEntriesInRange(start, end);
  if (windowEntries.length < _minInsightEntries) return null;

  try {
    final result = await pal.insights(range);
    return result.isEmpty ? null : result;
  } catch (_) {
    // Graceful-degradation boundary: an unreachable backend / timeout / bad
    // payload becomes the empty state rather than an error screen (the chosen
    // UX). Stats on these screens come from separate providers and still show.
    return null;
  }
}
