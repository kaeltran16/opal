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
  /// Bumped to `v5`: a default weekly schedule (`weekly_plan_days`) is seeded,
  /// so DBs seeded under `initial_seed_v4` re-run (insertOrReplace) and backfill
  /// the schedule referencing the seed routines.
  static const String _markerKey = 'initial_seed_v5';

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

      // Ritual routines + their ordered steps.
      for (final routine in SeedData.ritualRoutines()) {
        await _db
            .into(_db.ritualRoutines)
            .insert(routine.toCompanion(), mode: replace);
        for (var i = 0; i < routine.steps.length; i++) {
          await _db.into(_db.ritualSteps).insert(
                routine.steps[i].toCompanion(routine.id, i),
                mode: replace,
              );
        }
      }

      // Pal notes.
      for (final n in SeedData.palNotes()) {
        await _db.into(_db.palNotes).insert(n.toCompanion(), mode: replace);
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

      // Weekly schedule (weekday -> routineId) — must follow routines (FK).
      for (final assignment in SeedData.weeklyPlan()) {
        await _db
            .into(_db.weeklyPlanDays)
            .insert(assignment.toCompanion(), mode: replace);
      }

      // Mark done. Drop stale older `initial_seed_*` markers so version bumps
      // don't accumulate dead rows, then write the current marker idempotently.
      await (_db.delete(_db.seedMarkers)
            ..where((t) => t.key.like('initial_seed_%') & t.key.equals(_markerKey).not()))
          .go();
      await _db.into(_db.seedMarkers).insert(
            SeedMarkersCompanion.insert(key: _markerKey),
            mode: InsertMode.insertOrReplace,
          );
    });
  }
}
