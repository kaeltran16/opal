import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../services/pal/pal_service.dart';
import 'providers.dart';

part 'today_brief_controller.g.dart';

/// Pal's lead sentence for Today, from the daily-insights seam. Holds the last
/// good headline so a later failure never blanks the brief; errors resolve to
/// the previous value (or null) rather than an error state, so Today falls
/// back to its local numbers instead of an error view.
@riverpod
class TodayBrief extends _$TodayBrief {
  // an invalidate re-runs build; state still carries the last good headline then.
  @override
  Future<String?> build() async => await _fetch() ?? state.value;

  /// Re-fetches without a loading state. Only a non-empty headline replaces
  /// the current one; a failed or empty refresh leaves the state untouched.
  Future<void> refresh() async {
    final headline = await _fetch();
    if (headline != null && ref.mounted) state = AsyncData(headline);
  }

  /// The trimmed headline, or null when it is empty or the call fails.
  Future<String?> _fetch() async {
    try {
      final insights = await ref.read(palServiceProvider).insights(InsightRange.day);
      final headline = insights.headline?.trim();
      return (headline == null || headline.isEmpty) ? null : headline;
    } catch (e) {
      debugPrint('todayBrief: insights(day) failed, keeping the last brief: $e');
      return null;
    }
  }
}
