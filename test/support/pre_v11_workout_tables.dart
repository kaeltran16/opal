/// The pre-v11 exercises, workouts, set_logs and routine_exercises tables,
/// for a hand-built database stamped with an older user_version: schema v11
/// alters them, so every upgrade from before v11 needs them to exist.
void createPreV11WorkoutTables(dynamic raw) {
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
  raw.execute('CREATE TABLE routine_exercises (id TEXT NOT NULL PRIMARY KEY, '
      'routine_id TEXT NOT NULL, exercise_id TEXT NOT NULL, '
      'position INTEGER NOT NULL, target_sets INTEGER NOT NULL DEFAULT 3, '
      'target_reps INTEGER NULL, target_weight_kg REAL NULL)');
}
