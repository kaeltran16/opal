import 'package:drift/drift.dart';

import '../db/database.dart';
import '../db/mappers.dart';
import 'seed_data.dart';

/// Populates the database with first-run content, in two independently-guarded
/// passes: [seedReferenceData] (the exercise catalog — always) and
/// [seedDemoData] (a fake user's history — dev only).
///
/// Each pass is idempotent via its own row in the `seed_markers` table and runs
/// in its own transaction, so a crash mid-pass won't leave it half-seeded but
/// marked done, and the reference catalog never depends on the demo commit.
class Seeder {
  Seeder(this._db);

  final LoopDatabase _db;

  /// Marker keys, written once each section's seed completes.
  ///
  /// Split so reference data (the catalog) seeds on every launch while demo
  /// content stays behind the dev `SEED_DATA` flag. Bump a key to re-run that
  /// section (insertOrReplace) over an already-seeded DB.
  static const String _catalogMarker = 'catalog_seed_v1';
  static const String _demoMarker = 'demo_seed_v1';

  /// Seeds everything — reference catalog + demo history. Convenience for tests
  /// and the dev launch; prod calls [seedReferenceData] alone.
  Future<void> seedIfNeeded() async {
    await seedReferenceData();
    await seedDemoData();
  }

  /// Seeds the exercise catalog — reference data the app needs in every build
  /// (routines/workouts/set_logs FK-reference it). Idempotent via
  /// [_catalogMarker]. Ships PR-less: PRs are demo data, overlaid by
  /// [seedDemoData].
  Future<void> seedReferenceData() async {
    if (await _isSeeded(_catalogMarker)) return;
    await _db.transaction(() async {
      // Double-check inside the transaction to avoid a race on concurrent
      // first-run opens.
      if (await _isSeeded(_catalogMarker)) return;

      for (final e in SeedData.exercises()) {
        await _db
            .into(_db.exercises)
            .insert(e.toCompanion(), mode: InsertMode.insertOrReplace);
      }

      // One-time cleanup of the pre-split combined marker.
      await (_db.delete(_db.seedMarkers)
            ..where((t) => t.key.like('initial_seed_%')))
          .go();
      await _writeMarker(_catalogMarker);
    });
  }

  /// Seeds the demo user's first-run content (a fake history). Dev only.
  /// Ensures the reference catalog exists first (FK targets), then overlays the
  /// demo PRs onto it. Idempotent via [_demoMarker].
  Future<void> seedDemoData() async {
    // Demo routines/workouts FK-reference the catalog; guarantee it exists.
    await seedReferenceData();

    if (await _isSeeded(_demoMarker)) return;
    await _db.transaction(() async {
      if (await _isSeeded(_demoMarker)) return;

      // Seed rows use insertOrReplace so a marker bump re-runs cleanly over an
      // already-seeded DB without tripping primary-key conflicts on stable ids.
      const replace = InsertMode.insertOrReplace;

      // Overlay the demo user's PRs onto the (PR-less) reference catalog rows.
      final byId = {for (final e in SeedData.exercises()) e.id: e};
      for (final pr in SeedData.demoExercisePrs().entries) {
        final base = byId[pr.key];
        if (base == null) continue;
        await _db
            .into(_db.exercises)
            .insert(base.copyWith(pr: pr.value).toCompanion(), mode: replace);
      }

      // Goals (single row).
      await _db
          .into(_db.goalsTable)
          .insert(SeedData.goals.toCompanion(), mode: replace);

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

      // Per-category budget envelopes (no FK; standalone).
      for (final envelope in SeedData.budgetEnvelopes()) {
        await _db
            .into(_db.budgetEnvelopes)
            .insert(envelope.toCompanion(), mode: replace);
      }

      // Nutrition meals (no FK; standalone).
      for (final meal in SeedData.nutritionMeals()) {
        await _db.into(_db.nutritionMeals).insert(meal.toCompanion(), mode: replace);
      }

      await _writeMarker(_demoMarker);
    });
  }

  /// True when [key]'s marker row is present.
  Future<bool> _isSeeded(String key) async {
    final row = await (_db.select(_db.seedMarkers)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row != null;
  }

  Future<void> _writeMarker(String key) => _db.into(_db.seedMarkers).insert(
        SeedMarkersCompanion.insert(key: key),
        mode: InsertMode.insertOrReplace,
      );
}
