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
    Rituals,
    GoalsTable,
    SeedMarkers,
  ],
)
class LoopDatabase extends _$LoopDatabase {
  LoopDatabase() : super(_open());

  /// Test/override constructor: inject any [QueryExecutor]
  /// (e.g. `NativeDatabase.memory()`).
  LoopDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
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
