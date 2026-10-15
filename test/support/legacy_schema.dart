/// routine_exercises as it stood from v1 to v10, before target_duration_min.
/// A migration test that stamps an old user_version needs it: v11 alters it,
/// and every real pre-v11 database has it.
const v10RoutineExercises = 'CREATE TABLE routine_exercises ('
    'id TEXT NOT NULL PRIMARY KEY, routine_id TEXT NOT NULL, exercise_id TEXT NOT NULL, '
    'position INTEGER NOT NULL, target_sets INTEGER NOT NULL DEFAULT 3, '
    'target_reps INTEGER NULL, target_weight_kg REAL NULL)';
