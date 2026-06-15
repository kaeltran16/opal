import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/data/repositories/repositories.dart';
import 'package:opal/models/models.dart';

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
}
