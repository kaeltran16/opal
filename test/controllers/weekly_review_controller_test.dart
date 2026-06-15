import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/controllers/providers.dart';
import 'package:opal/controllers/weekly_review_controller.dart';
import 'package:opal/services/services.dart';

/// A PalService whose `review` returns a different canned string per call (so a
/// regenerate is guaranteed to swap text) and records the range it was asked
/// for. Other seams are unused no-ops.
class _SequencedPal implements PalService {
  int _i = 0;
  final List<ReviewRange> reviewRanges = [];
  static const _reviews = ['FIRST week review.', 'SECOND week review.'];

  @override
  Future<String> review(DateTime anchor, ReviewRange range) async {
    reviewRanges.add(range);
    return _reviews[_i++ % _reviews.length];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('build resolves the week narrative from PalService.review', () async {
    final pal = _SequencedPal();
    final container = ProviderContainer(overrides: [
      palServiceProvider.overrideWithValue(pal),
    ]);
    addTearDown(container.dispose);

    final text = await container.read(weeklyReviewControllerProvider.future);

    expect(text, 'FIRST week review.');
    // the controller asks for the week range, not the month.
    expect(pal.reviewRanges, [ReviewRange.week]);
  });

  test('regenerate swaps to the next narrative', () async {
    final pal = _SequencedPal();
    final container = ProviderContainer(overrides: [
      palServiceProvider.overrideWithValue(pal),
    ]);
    addTearDown(container.dispose);

    await container.read(weeklyReviewControllerProvider.future);
    await container.read(weeklyReviewControllerProvider.notifier).regenerate();

    final state = container.read(weeklyReviewControllerProvider);
    expect(state.value, 'SECOND week review.');
    expect(pal.reviewRanges, [ReviewRange.week, ReviewRange.week]);
  });
}
