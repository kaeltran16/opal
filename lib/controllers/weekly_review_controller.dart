import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'providers.dart';

part 'weekly_review_controller.g.dart';

/// One tinted stat tile in the Weekly Review three-ring summary (handoff screen
/// 17). Mirrors the mock's canned week numbers — this is a mock-data review.
@immutable
class WeekStat {
  const WeekStat({
    required this.label,
    required this.value,
    required this.sub,
    required this.colorToken,
  });

  /// Tile title, e.g. "Spent".
  final String label;

  /// Big formatted value, e.g. "\$435" or "296".
  final String value;

  /// Sub line under the value, e.g. "of \$595".
  final String sub;

  /// `context.colors.forType(colorToken)` accent ('money'|'move'|'rituals').
  final String colorToken;
}

/// The mock's canned three-ring week summary for the review week (Apr 17–23).
/// Fixed values matching the prototype; kept here so the screen stays dumb.
const List<WeekStat> kWeeklyReviewStats = [
  WeekStat(label: 'Spent', value: '\$435', sub: 'of \$595', colorToken: 'money'),
  WeekStat(label: 'Workout', value: '296', sub: 'of 420 min', colorToken: 'move'),
  WeekStat(label: 'Routines', value: '26', sub: 'of 35', colorToken: 'rituals'),
];

/// Drives the Pal-written weekly narrative: holds the review text with a loading
/// state, and re-requests it on [regenerate]. Mirrors [MonthlyReviewController]
/// — reuses the [PalService.review] seam, passing the review week's start date
/// (Apr 17) so the mock returns canned text.
@riverpod
class WeeklyReviewController extends _$WeeklyReviewController {
  /// The review week's start date — Apr 17 of the current year, matching the
  /// mock's "Weekly Review · Apr 17–23" eyebrow.
  DateTime get _weekStart => DateTime(DateTime.now().year, 4, 17);

  @override
  Future<String> build() {
    final pal = ref.watch(palServiceProvider);
    return pal.review(_weekStart);
  }

  /// Re-requests the narrative from [PalService.review], showing the loading
  /// state while the new text is fetched.
  Future<void> regenerate() async {
    final pal = ref.read(palServiceProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => pal.review(_weekStart));
  }
}
