import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/repositories/repositories.dart';
import 'package:opal/data/seed/seeder.dart';
import 'package:opal/models/models.dart';

import 'support/legacy_schema.dart';

/// Guards the v5->v6 re-base of the daily move goal from minutes to kcal.
///
/// The first test exercises the real Drift `onUpgrade(5->6)` SQL: it stands up a
/// v5-schema `goals` table (with `daily_move_minutes`, user_version = 5),
/// opens [LoopDatabase] so Drift runs the migration, and asserts it added
/// `daily_move_kcal` defaulting to 500. The second test pins the fresh-DB
/// default and round-trips an explicit kcal goal.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('v5->v6 migration adds daily_move_kcal with a 500 default', () async {
    // Build the pre-rename v5 goals table by hand and stamp user_version = 5
    // (in `setup`, before Drift opens) so Drift treats the connection as a v5
    // DB and runs onUpgrade(5->6). The setup callback hands us the raw sqlite3
    // handle, so we avoid a direct dependency on package:sqlite3.
    final db = LoopDatabase.forTesting(NativeDatabase.memory(setup: (raw) {
      raw.execute('CREATE TABLE goals ('
          "id TEXT NOT NULL PRIMARY KEY DEFAULT 'goals', "
          'daily_budget REAL NOT NULL DEFAULT 85.0, '
          'daily_move_minutes INTEGER NOT NULL DEFAULT 60, '
          'daily_ritual_target INTEGER NOT NULL DEFAULT 5)');
      raw.execute("INSERT INTO goals (id) VALUES ('goals')");
      // later steps (v11, v12) alter these, as they exist in any real v5 DB
      createV10WorkoutTables(raw);
      raw.execute('PRAGMA user_version = 5');
    }));
    addTearDown(db.close);

    // The typed read forces beforeOpen + onUpgrade to run; it would throw if
    // the new column were missing, since the goals mapper selects it.
    final goals = await GoalsRepository(db).get();
    expect(goals.dailyMoveKcal, 500);

    // Direct read confirms the migration created the column with the 500 default
    // (not just the model falling back to its own default).
    final row =
        await db.customSelect('SELECT daily_move_kcal FROM goals').getSingle();
    expect(row.read<int>('daily_move_kcal'), 500);
  });

  test('v10->v11 migration adds a nullable target_duration_min to routine slots', () async {
    final db = LoopDatabase.forTesting(NativeDatabase.memory(setup: (raw) {
      createV10WorkoutTables(raw);
      raw.execute("INSERT INTO routine_exercises (id, routine_id, exercise_id, position) "
          "VALUES ('s1', 'r1', 'plank', 0)");
      raw.execute('PRAGMA user_version = 10');
    }));
    addTearDown(db.close);

    final row = await db
        .customSelect('SELECT target_duration_min FROM routine_exercises')
        .getSingle();
    expect(row.read<int?>('target_duration_min'), isNull);
  });

  test('fresh DB exposes the kcal move goal with a 500 default', () async {
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = GoalsRepository(db);

    // No row yet -> model defaults; the move goal is now kcal-based.
    expect((await repo.get()).dailyMoveKcal, 500);

    // The renamed column persists and reads back through the mapper.
    await repo.upsert(const Goals(dailyMoveKcal: 750));
    expect((await repo.get()).dailyMoveKcal, 750);
  });

  group('v10->v12 timed sets', _timedSetsMigration);
}

/// Stands up the v10 shape of the tables schemas v11 and v12 alter, with a bench
/// and plank PR, a treadmill row and two old logged sets, stamped
/// user_version 10.
void _v10Schema(dynamic raw) {
  createV10WorkoutTables(raw);
  raw.execute('INSERT INTO exercises VALUES '
      "('bench', 'Bench', 'Push', 'Chest', 'x', NULL, 92.5, 5), "
      "('plank', 'Plank', 'Core', 'Core', 'x', NULL, 0, 90), "
      "('treadmill', 'Treadmill Run', 'Cardio', 'Cardio', 'x', NULL, NULL, NULL)");
  raw.execute("INSERT INTO workouts VALUES ('w1', NULL, 'Push', 1780000000, NULL)");
  raw.execute('INSERT INTO set_logs VALUES '
      "('s1', 'w1', 'bench', 80, 5, 1, 0, 0), "
      "('s2', 'w1', 'plank', 0, 60, 1, 0, 1)");
  raw.execute('PRAGMA user_version = 10');
}

void _timedSetsMigration() {
  test('flags cardio and plank as timed and clears their PRs',
      () async {
    final db = LoopDatabase.forTesting(NativeDatabase.memory(setup: _v10Schema));
    addTearDown(db.close);
    final repo = RoutineRepository(db);

    final treadmill = await repo.getExerciseById('treadmill');
    final plank = await repo.getExerciseById('plank');
    final bench = await repo.getExerciseById('bench');
    expect(treadmill!.timed, isTrue);
    expect(plank!.timed, isTrue);
    expect(bench!.timed, isFalse);

    // a timed exercise keeps no stored PR, so nothing reads "0 kg × 90"
    expect(plank.pr, isNull);
    expect(bench.pr, const ExercisePR(weightKg: 92.5, reps: 5));
  });

  test('keeps old logged sets as weight × reps', () async {
    final db = LoopDatabase.forTesting(NativeDatabase.memory(setup: _v10Schema));
    addTearDown(db.close);

    final w = await WorkoutRepository(db).getById('w1');
    expect(w!.sets.every((s) => s.minutes == null && s.distanceKm == null),
        isTrue);
    final plank = w.sets.firstWhere((s) => s.exerciseId == 'plank');
    expect(plank.reps, 60);
    expect(plank.isTimed, isFalse);
  });

  test('a freshly seeded demo database has no plank PR', () async {
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await Seeder(db).seedIfNeeded();

    final plank = await RoutineRepository(db).getExerciseById('plank');
    expect(plank!.timed, isTrue);
    expect(plank.pr, isNull);
    final treadmill = await RoutineRepository(db).getExerciseById('treadmill');
    expect(treadmill!.timed, isTrue);
    final bench = await RoutineRepository(db).getExerciseById('bench');
    expect(bench!.timed, isFalse);
    expect(bench.pr, isNotNull);
  });
}
