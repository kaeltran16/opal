import 'package:riverpod_annotation/riverpod_annotation.dart';

// prefixed so the provider function `spendHabits` does not collide with the
// pure `habitPicksForNow` it calls, and to keep the analysis origin visible.
import '../analysis/spend_habits.dart' as sh;
import '../analysis/spend_patterns.dart' show kSpendWindowDays;
import 'providers.dart';

part 'spend_habits_controller.g.dart';

/// The user's recurring expenses for the current daypart — the local source for
/// New Entry's quick picks.
///
/// Reactive: re-emits whenever in-window entries change, so logging something
/// feeds straight back into the picks. [now] is captured per subscription, so
/// the daypart is the one in force when the surface opened.
@riverpod
Stream<List<sh.HabitPick>> spendHabits(Ref ref) async* {
  final entriesRepo = ref.watch(entryRepositoryProvider);

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final start = today.subtract(const Duration(days: kSpendWindowDays - 1));
  final end = today.add(const Duration(days: 1));

  await for (final entries in entriesRepo.watchEntriesInRange(start, end)) {
    yield sh.habitPicksForNow(entries, now: now);
  }
}
