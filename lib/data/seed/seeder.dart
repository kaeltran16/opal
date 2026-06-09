import 'package:drift/drift.dart';

import '../db/database.dart';
import '../db/mappers.dart';
import 'seed_data.dart';

/// Populates the database with first-run content exactly once.
///
/// Idempotency is guarded by a row in the `seed_markers` table: if the marker
/// is present, [seedIfNeeded] is a no-op. The whole seed runs in a single
/// transaction, so a crash mid-seed won't leave a half-seeded DB marked done.
class Seeder {
  Seeder(this._db);

  final LoopDatabase _db;

  /// Marker key written once the initial seed completes.
  ///
  /// Bumped to `v2` for U11's expanded exercise catalog (~21 exercises across
  /// Push/Pull/Legs/Core/Cardio) + sample routines, so existing DBs seeded
  /// under `initial_seed_v1` re-run the seed and pick up the richer content.
  static const String _markerKey = 'initial_seed_v2';

  /// Seeds the DB if it hasn't been seeded yet. Safe to call on every launch.
  Future<void> seedIfNeeded() async {
    final already = await (_db.select(_db.seedMarkers)
          ..where((t) => t.key.equals(_markerKey)))
        .getSingleOrNull();
    if (already != null) return;

    await _db.transaction(() async {
      // Double-check inside the transaction to avoid a race on concurrent
      // first-run opens.
      final check = await (_db.select(_db.seedMarkers)
            ..where((t) => t.key.equals(_markerKey)))
          .getSingleOrNull();
      if (check != null) return;

      // Goals (single row).
      await _db
          .into(_db.goalsTable)
          .insert(SeedData.goals.toCompanion(), mode: InsertMode.insertOrReplace);

      // Seed rows use insertOrReplace so a marker bump (e.g. v1 -> v2 for the
      // expanded catalog) re-runs cleanly over an already-seeded DB without
      // tripping primary-key conflicts on the stable seed ids.
      const replace = InsertMode.insertOrReplace;

      // Rituals.
      for (final r in SeedData.rituals()) {
        await _db.into(_db.rituals).insert(r.toCompanion(), mode: replace);
      }

      // Exercises (catalog) — must precede routines/workouts (FK targets).
      for (final e in SeedData.exercises()) {
        await _db.into(_db.exercises).insert(e.toCompanion(), mode: replace);
      }

      // Routines + their ordered exercise slots.
      for (final routine in SeedData.routines()) {
        await _db
            .into(_db.routines)
            .insert(routine.toCompanion(), mode: replace);
        for (final ex in routine.exercises) {
          await _db
              .into(_db.routineExercises)
              .insert(ex.toCompanion(routine.id), mode: replace);
        }
      }

      // Workouts + their sets.
      for (final w in SeedData.workouts()) {
        await _db.into(_db.workouts).insert(w.toCompanion(), mode: replace);
        for (var i = 0; i < w.sets.length; i++) {
          await _db
              .into(_db.setLogs)
              .insert(w.sets[i].toCompanion(w.id, i), mode: replace);
        }
      }

      // Timeline entries.
      for (final entry in SeedData.entries()) {
        await _db.into(_db.entries).insert(entry.toCompanion(), mode: replace);
      }

      // Mark done.
      await _db
          .into(_db.seedMarkers)
          .insert(SeedMarkersCompanion.insert(key: _markerKey));
    });
  }
}
