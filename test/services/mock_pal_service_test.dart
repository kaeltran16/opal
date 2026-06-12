import 'package:flutter_test/flutter_test.dart';
import 'package:opal/services/pal/mock_pal_service.dart';

void main() {
  final fast = const Duration(milliseconds: 1);

  test('suggestWorkout advances past the excluded routine', () async {
    final pal = MockPalService(latency: fast);

    // first canned pick is Push Day A (routineId seed-routine-push-a).
    final first = await pal.suggestWorkout();
    expect(first.routineId, 'seed-routine-push-a');

    // excluding it skips to the next pick instead of repeating.
    final next = await pal.suggestWorkout(excludeRoutineId: 'seed-routine-push-a');
    expect(next.routineId, isNot('seed-routine-push-a'));
  });
}
