/// routine_exercises as it stood from v1 to v10, before target_duration_min.
const _v10RoutineExercises = 'CREATE TABLE routine_exercises ('
    'id TEXT NOT NULL PRIMARY KEY, routine_id TEXT NOT NULL, exercise_id TEXT NOT NULL, '
    'position INTEGER NOT NULL, target_sets INTEGER NOT NULL DEFAULT 3, '
    'target_reps INTEGER NULL, target_weight_kg REAL NULL)';

/// The exercises, workouts, set_logs and routine_exercises tables as they stood
/// up to v10. A migration test that stamps an old user_version needs them: v11
/// and v12 alter them, and every real pre-v11 database has them.
void createV10WorkoutTables(dynamic raw) {
  raw.execute('CREATE TABLE exercises (id TEXT NOT NULL PRIMARY KEY, '
      'name TEXT NOT NULL, "group" TEXT NOT NULL, muscle TEXT NOT NULL, '
      'icon TEXT NOT NULL, equipment TEXT NULL, pr_weight_kg REAL NULL, '
      'pr_reps INTEGER NULL)');
  raw.execute('CREATE TABLE workouts (id TEXT NOT NULL PRIMARY KEY, '
      'routine_id TEXT NULL, name TEXT NOT NULL, started_at INTEGER NOT NULL, '
      'ended_at INTEGER NULL)');
  raw.execute('CREATE TABLE set_logs (id TEXT NOT NULL PRIMARY KEY, '
      'workout_id TEXT NOT NULL, exercise_id TEXT NOT NULL, '
      'weight_kg REAL NOT NULL, reps INTEGER NOT NULL, '
      'done INTEGER NOT NULL DEFAULT 0, is_p_r INTEGER NOT NULL DEFAULT 0, '
      'position INTEGER NOT NULL DEFAULT 0)');
  raw.execute(_v10RoutineExercises);
}
