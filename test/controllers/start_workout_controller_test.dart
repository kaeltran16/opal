import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/controllers/providers.dart';
import 'package:opal/controllers/start_workout_controller.dart';
import 'package:opal/data/db/database.dart' show LoopDatabase;
import 'package:opal/data/seed/seeder.dart';
import 'package:opal/models/models.dart';

const _saved = 'Fresh Day';
const _wait = Duration(seconds: 5);

void main() {
  test('saving a routine re-emits the picker with it', () async {
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    await Seeder(db).seedIfNeeded();
    addTearDown(db.close);
    final container = ProviderContainer(overrides: [loopDatabaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);

    final shown = Completer<void>();
    container.listen(startWorkoutProvider, (_, next) {
      final state = next.value;
      if (state == null || shown.isCompleted) return;
      if ([...state.strength, ...state.cardio].any((r) => r.name == _saved)) shown.complete();
    });
    final first = await container.read(startWorkoutProvider.future);
    expect(first.strength.map((r) => r.name), isNot(contains(_saved)));

    // no workout is logged, so only the routines table changes.
    await container
        .read(routineRepositoryProvider)
        .insert(const Routine(id: '', name: _saved, tag: RoutineTag.full));

    await shown.future.timeout(_wait);
  });
}
