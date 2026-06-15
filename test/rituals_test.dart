import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/controllers/providers.dart';
import 'package:opal/controllers/rituals_controller.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/repositories/repositories.dart';
import 'package:opal/models/models.dart';
import 'package:opal/services/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A [HapticsService] that records how many times each method was called, so the
/// toggle path can assert the light haptic fired (no-op on web in production).
class _SpyHaptics implements HapticsService {
  int lightCount = 0;
  @override
  Future<void> light() async => lightCount++;
  @override
  Future<void> medium() async {}
  @override
  Future<void> success() async {}
}

/// A two-step morning routine for the toggle/complete tests.
const _morning = RitualRoutine(
  id: 'morning',
  name: 'Morning',
  time: '7:00 AM',
  tone: RitualTone.morning,
  icon: 'sunrise.fill',
  blurb: 'Ease into the day',
  streak: 4,
  order: 0,
  steps: [
    RitualStep(
      id: 'morning-step-0',
      title: 'Glass of water',
      note: 'Before coffee.',
      icon: 'drop.fill',
    ),
    RitualStep(
      id: 'morning-step-1',
      title: 'Wash my face',
      note: 'Cold rinse.',
      icon: 'drop.fill',
    ),
  ],
);

/// Awaits the next [RitualsState] emission satisfying [test] (a drift write
/// re-runs the underlying `watchToday` query asynchronously, so `.future` —
/// which caches the first emission — can't be re-read after a mutation).
Future<RitualsState> _waitFor(
  ProviderContainer c,
  bool Function(RitualsState) test,
) async {
  final current = c.read(ritualsControllerProvider).value;
  if (current != null && test(current)) return current;
  final completer = Completer<RitualsState>();
  final sub = c.listen(ritualsControllerProvider, (_, next) {
    final v = next.value;
    if (v != null && test(v) && !completer.isCompleted) completer.complete(v);
  });
  try {
    return await completer.future.timeout(const Duration(seconds: 2));
  } finally {
    sub.close();
  }
}

void main() {
  test(
      'toggleStep writes a ritual Entry and progress reflects it; toggling off '
      'removes it', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final rituals = RitualRepository(db);
    final entries = EntryRepository(db);
    await rituals.upsertRoutine(_morning);

    final haptics = _SpyHaptics();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      loopDatabaseProvider.overrideWithValue(db),
      hapticsServiceProvider.overrideWithValue(haptics),
    ]);
    addTearDown(container.dispose);
    // keep the autoDispose streaming controller alive across awaits.
    container.listen(ritualsControllerProvider, (_, _) {});

    final notifier = container.read(ritualsControllerProvider.notifier);

    // initial emission: nothing done.
    var state = await container.read(ritualsControllerProvider.future);
    final routine = state.routines.firstWhere((r) => r.id == 'morning');
    expect(state.doneCount('morning'), 0);
    expect(state.doneSteps, 0);
    expect(state.totalSteps, 2);
    expect(state.upNext?.id, 'morning');
    expect((await entries.getAll()).where((x) => x.type == EntryType.rituals),
        isEmpty);

    // toggle step 0 on → a ritual Entry is written, haptic fires.
    await notifier.toggleStep(routine, 0);
    var all = await entries.getAll();
    final logged = all.where((e) => e.type == EntryType.rituals).toList();
    expect(logged, hasLength(1));
    expect(logged.single.ritualId, 'morning-step-0');
    expect(logged.single.source, EntrySource.manual);
    expect(haptics.lightCount, 1);

    // controller state reflects the completion.
    state = await _waitFor(container, (s) => s.isStepDone('morning', 0));
    expect(state.doneCount('morning'), 1);
    expect(state.firstIncompleteStep(routine), 1);

    // toggle step 0 off → entry removed, progress back to 0.
    await notifier.toggleStep(routine, 0);
    all = await entries.getAll();
    expect(all.where((e) => e.type == EntryType.rituals), isEmpty);
    state = await _waitFor(container, (s) => s.doneCount('morning') == 0);
    expect(state.doneCount('morning'), 0);
  });

  test('completeStep marks done once and is idempotent (never un-checks)',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final rituals = RitualRepository(db);
    final entries = EntryRepository(db);
    await rituals.upsertRoutine(_morning);

    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      loopDatabaseProvider.overrideWithValue(db),
      hapticsServiceProvider.overrideWithValue(_SpyHaptics()),
    ]);
    addTearDown(container.dispose);
    container.listen(ritualsControllerProvider, (_, _) {});

    final notifier = container.read(ritualsControllerProvider.notifier);
    final state = await container.read(ritualsControllerProvider.future);
    final routine = state.routines.firstWhere((r) => r.id == 'morning');

    // complete both steps → routine is complete, upNext clears.
    await notifier.completeStep(routine, 0);
    await notifier.completeStep(routine, 1);
    var s = await _waitFor(container, (s) => s.isComplete(routine));
    expect(s.upNext, isNull);

    // completing an already-done step is a no-op (no duplicate entry).
    await notifier.completeStep(routine, 0);
    final ritualEntries =
        (await entries.getAll()).where((e) => e.type == EntryType.rituals);
    expect(ritualEntries, hasLength(2));
    s = await _waitFor(container, (s) => s.doneCount('morning') == 2);
    expect(s.doneCount('morning'), 2);
  });

  test(
      'completing a routine persists a date-stamped completion that feeds the '
      'computed ritual streak', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final rituals = RitualRepository(db);
    final entries = EntryRepository(db);
    await rituals.upsertRoutine(_morning);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Backfill a persisted completion for yesterday so finishing today's
    // routine extends a real streak to 2 (proving it counts persisted days,
    // not the seeded RitualRoutine.streak of 4).
    await entries.insert(Entry(
      id: '',
      timestamp: today.subtract(const Duration(hours: 3)), // yesterday evening
      type: EntryType.rituals,
      title: 'Glass of water',
      ritualId: 'morning-step-0',
      source: EntrySource.manual,
    ));

    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      loopDatabaseProvider.overrideWithValue(db),
      hapticsServiceProvider.overrideWithValue(_SpyHaptics()),
    ]);
    addTearDown(container.dispose);
    container.listen(ritualsControllerProvider, (_, _) {});

    final notifier = container.read(ritualsControllerProvider.notifier);
    final state = await container.read(ritualsControllerProvider.future);
    final routine = state.routines.firstWhere((r) => r.id == 'morning');

    // finish today's routine.
    await notifier.completeStep(routine, 0);
    await notifier.completeStep(routine, 1);
    await _waitFor(container, (s) => s.isComplete(routine));

    // every completion is a persisted, date-stamped ritual Entry.
    final ritualEntries =
        (await entries.getAll()).where((e) => e.type == EntryType.rituals);
    expect(ritualEntries, hasLength(3)); // yesterday + 2 today

    // the streak computed from those persisted entries is a real 2-day run.
    expect(ritualStreakDays(await entries.getAll(), now: now), 2);
  });
}
