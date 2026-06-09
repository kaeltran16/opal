import 'package:drift/drift.dart';

/// Drift table definitions mirroring the U01 domain models.
///
/// Conventions (per U02 handoff notes):
/// - Caller-supplied `String` ids are stored as `TEXT PRIMARY KEY`.
/// - Nullable model fields map to `.nullable()` columns.
/// - Enums persist as their stable `.wire` string (NOT index/name).
/// - Owned child collections (`Workout.sets`, `Routine.exercises`) become
///   separate tables with foreign keys.
/// - `RoutineExercise.order` and `Ritual.order` are explicit int columns
///   (`order` is a SQL keyword, so the column is named `position`).
/// - `ExercisePR` is flattened to two nullable columns on `Exercises`.
/// - `Goals` is a single-row table keyed by a fixed id.

/// Unified timeline entries (money / move / rituals).
@DataClassName('EntryRow')
class Entries extends Table {
  TextColumn get id => text()();
  DateTimeColumn get timestamp => dateTime()();

  /// [EntryType.wire].
  TextColumn get type => text()();
  TextColumn get title => text()();
  TextColumn get detail => text().nullable()();
  RealColumn get amount => real().nullable()();
  IntColumn get duration => integer().nullable()();
  IntColumn get calories => integer().nullable()();
  RealColumn get distance => real().nullable()();
  TextColumn get category => text().nullable()();
  TextColumn get ritualId => text().nullable()();
  TextColumn get note => text().nullable()();

  /// [EntrySource.wire].
  TextColumn get source => text()();
  TextColumn get sourceRef => text().nullable()();
  TextColumn get workoutId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Catalog exercises (Exercise Library). `ExercisePR` flattened to two columns.
@DataClassName('ExerciseRow')
class Exercises extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get group => text()();
  TextColumn get muscle => text()();
  TextColumn get icon => text()();
  TextColumn get equipment => text().nullable()();

  /// `ExercisePR.weightKg` — null when the exercise has no PR.
  RealColumn get prWeightKg => real().nullable()();

  /// `ExercisePR.reps` — null when the exercise has no PR.
  IntColumn get prReps => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Reusable workout templates.
@DataClassName('RoutineRow')
class Routines extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// [RoutineTag.wire].
  TextColumn get tag => text()();
  IntColumn get restSeconds => integer().withDefault(const Constant(120))();
  BoolColumn get warmupReminder =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get autoProgress =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Ordered exercise slots inside a [Routines] row (owned child).
@DataClassName('RoutineExerciseRow')
class RoutineExercises extends Table {
  TextColumn get id => text()();
  TextColumn get routineId => text()();
  TextColumn get exerciseId => text()();

  /// `RoutineExercise.order` (renamed; `order` is a SQL keyword).
  IntColumn get position => integer()();
  IntColumn get targetSets => integer().withDefault(const Constant(3))();
  IntColumn get targetReps => integer().nullable()();
  RealColumn get targetWeightKg => real().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        'FOREIGN KEY (routine_id) REFERENCES routines (id) ON DELETE CASCADE',
        'FOREIGN KEY (exercise_id) REFERENCES exercises (id)',
      ];
}

/// Strength/cardio sessions.
@DataClassName('WorkoutRow')
class Workouts extends Table {
  TextColumn get id => text()();
  TextColumn get routineId => text().nullable()();
  TextColumn get name => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Logged sets within a [Workouts] row (owned child).
@DataClassName('SetLogRow')
class SetLogs extends Table {
  TextColumn get id => text()();
  TextColumn get workoutId => text()();
  TextColumn get exerciseId => text()();
  RealColumn get weightKg => real()();
  IntColumn get reps => integer()();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
  BoolColumn get isPR => boolean().withDefault(const Constant(false))();

  /// Preserves insertion order within a workout.
  IntColumn get position => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        'FOREIGN KEY (workout_id) REFERENCES workouts (id) ON DELETE CASCADE',
        'FOREIGN KEY (exercise_id) REFERENCES exercises (id)',
      ];
}

/// Recurring habits.
@DataClassName('RitualRow')
class Rituals extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get icon => text()();

  /// [Cadence.wire].
  TextColumn get cadence => text().withDefault(const Constant('daily'))();
  DateTimeColumn get reminderTime => dateTime().nullable()();

  /// `Ritual.order` (renamed; `order` is a SQL keyword).
  IntColumn get position => integer().withDefault(const Constant(0))();
  IntColumn get streak => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Single-row daily targets table. Always keyed by [singletonId].
@DataClassName('GoalsRow')
class GoalsTable extends Table {
  @override
  String get tableName => 'goals';

  /// Fixed single-row key (literal must match [singletonId]).
  TextColumn get id => text().withDefault(const Constant('goals'))();
  RealColumn get dailyBudget => real().withDefault(const Constant(85.0))();
  IntColumn get dailyMoveMinutes =>
      integer().withDefault(const Constant(60))();
  IntColumn get dailyRitualTarget =>
      integer().withDefault(const Constant(5))();

  @override
  Set<Column> get primaryKey => {id};

  /// The fixed id of the lone Goals row.
  static const String singletonId = 'goals';
}

/// Tracks one-shot seeding so the DB is only populated once.
class SeedMarkers extends Table {
  TextColumn get key => text()();

  @override
  Set<Column> get primaryKey => {key};
}
