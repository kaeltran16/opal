import 'package:clock/clock.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

// prefixed so the provider function `spendHabits` does not collide with the
// pure `habitPicksForNow` it calls, and to keep the analysis origin visible.
import '../analysis/spend_habits.dart' as sh;
import '../analysis/spend_patterns.dart' show kSpendWindowDays;
import '../models/models.dart';
import 'providers.dart';

part 'spend_habits_controller.g.dart';

/// The user's recurring expenses for the current daypart — the local source for
/// New Entry's quick picks.
///
/// Reactive: re-emits whenever in-window entries change, so logging something
/// feeds straight back into the picks. `now` is captured per subscription, so
/// the daypart is the one in force when the surface opened.
@riverpod
Stream<List<sh.HabitPick>> spendHabits(Ref ref) =>
    _spendWindow(ref).map((w) => sh.habitPicksForNow(w.entries, now: w.now));

/// The composer's predicted logs: [spendHabits]' picks minus those already
/// logged this daypart, plus the [logged] titles themselves so the composer can
/// drop a Pal chip for them too (Pal's chips may be a cached reply from before
/// the log).
@riverpod
Stream<({List<sh.HabitPick> picks, Set<String> logged})> composerHabits(Ref ref) =>
    _spendWindow(ref).map((w) {
      final logged = sh.titlesLoggedThisDaypart(w.entries, now: w.now);
      final picks = sh
          .habitPicksForNow(w.entries, now: w.now)
          .where((p) => !logged.contains(p.title.toLowerCase()))
          .toList();
      return (picks: picks, logged: logged);
    });

/// The habit window's entries as they change, with the `now` they are read at.
Stream<({DateTime now, List<Entry> entries})> _spendWindow(Ref ref) async* {
  final entriesRepo = ref.watch(entryRepositoryProvider);

  final now = clock.now();
  final today = DateTime(now.year, now.month, now.day);
  final start = today.subtract(const Duration(days: kSpendWindowDays - 1));
  final end = today.add(const Duration(days: 1));

  await for (final entries in entriesRepo.watchEntriesInRange(start, end)) {
    yield (now: now, entries: entries);
  }
}
