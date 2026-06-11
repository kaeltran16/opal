import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'database.g.dart';

/// The application's drift database.
///
/// On native it uses `drift_flutter`'s `driftDatabase` (path_provider-backed
/// sqlite3). On web it boots from the vendored `sqlite3.wasm` +
/// `drift_worker.dart.js` in `web/` (OPFS-backed, degrades gracefully).
@DriftDatabase(
  tables: [
    Entries,
    Exercises,
    Routines,
    RoutineExercises,
    Workouts,
    SetLogs,
    RitualRoutines,
    RitualSteps,
    PalNotes,
    GoalsTable,
    SeedMarkers,
    WeeklyPlanDays,
  ],
)
class LoopDatabase extends _$LoopDatabase {
  LoopDatabase() : super(_open());

  /// Test/override constructor: inject any [QueryExecutor]
  /// (e.g. `NativeDatabase.memory()`).
  LoopDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        // v1 -> v2 (Handoff #2): the flat `rituals` table is replaced by
        // `ritual_routines` + `ritual_steps`, and PalNotes arrive. Ritual
        // definitions were seed-only (no user-authored rows yet), so dropping
        // the old table is non-destructive to real data; the seeder (marker
        // bump) repopulates the new routines on next launch.
        //
        // v2 -> v3: the Bills and Subscriptions features were removed, so their
        // backing tables are dropped. They held seed-only data, so this is
        // non-destructive to real user data.
        //
        // v3 -> v4: routines gain authored per-routine fields (estMin, plus
        // cardio distanceKm/pace) for richer Start-workout cards. All nullable,
        // so existing rows survive; the seeder (marker bump) backfills seed
        // routines on next launch.
        //
        // v4 -> v5: a new weekly_plan_days table (weekday -> routineId) backs
        // the Weekly Plan screen. It's a brand-new table, so creating it leaves
        // every existing table and row untouched; the seeder (marker bump)
        // populates a default schedule on next launch.
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await customStatement('DROP TABLE IF EXISTS rituals');
            await m.createTable(ritualRoutines);
            await m.createTable(ritualSteps);
            await m.createTable(palNotes);
          }
          if (from < 3) {
            await customStatement('DROP TABLE IF EXISTS bills');
            await customStatement('DROP TABLE IF EXISTS subscriptions');
          }
          if (from < 4) {
            await m.addColumn(routines, routines.estMin);
            await m.addColumn(routines, routines.distanceKm);
            await m.addColumn(routines, routines.pace);
          }
          if (from < 5) {
            await m.createTable(weeklyPlanDays);
          }
        },
        beforeOpen: (details) async {
          // Enforce FK constraints (off by default in sqlite).
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  static QueryExecutor _open() {
    return driftDatabase(
      name: 'loop_db',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.dart.js'),
      ),
    );
  }
}
