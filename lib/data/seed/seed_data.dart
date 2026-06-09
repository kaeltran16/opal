import '../../models/models.dart';

/// First-run seed content, migrated from the legacy display-only
/// `lib/data/mock_data.dart` into the rich U01 domain models.
///
/// Ids here are stable, human-readable seed ids (not UUIDs) so seeding is
/// idempotent and seed rows are recognisable. Repository inserts of *new*
/// user data assign UUIDs instead.
///
/// All entry timestamps are anchored to "today" via [seedEntries] so U05's
/// Today screen always has same-day content to render regardless of run date.
class SeedData {
  const SeedData._();

  /// Helper: today at the given wall-clock [hour]:[minute].
  static DateTime _todayAt(int hour, int minute) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  /// Helper: [daysAgo] days back at [hour]:[minute].
  static DateTime _daysAgoAt(int daysAgo, int hour, int minute) {
    final now = DateTime.now();
    final d = DateTime(now.year, now.month, now.day, hour, minute);
    return d.subtract(Duration(days: daysAgo));
  }

  /// The default daily targets (matches handoff / `Goals` defaults).
  static const Goals goals = Goals(
    dailyBudget: 85.0,
    dailyMoveMinutes: 60,
    dailyRitualTarget: 5,
  );

  /// The five tracked rituals (the "pick 5" set).
  static List<Ritual> rituals() => const [
        Ritual(
          id: 'seed-ritual-morning-pages',
          title: 'Morning pages',
          icon: 'book.closed.fill',
          cadence: Cadence.daily,
          order: 0,
          streak: 12,
        ),
        Ritual(
          id: 'seed-ritual-inbox-zero',
          title: 'Inbox zero',
          icon: 'tray.fill',
          cadence: Cadence.weekdays,
          order: 1,
          streak: 4,
        ),
        Ritual(
          id: 'seed-ritual-spanish',
          title: 'Spanish practice',
          icon: 'character.book.closed.fill',
          cadence: Cadence.daily,
          order: 2,
          streak: 31,
        ),
        Ritual(
          id: 'seed-ritual-read',
          title: 'Read',
          icon: 'books.vertical.fill',
          cadence: Cadence.daily,
          order: 3,
          streak: 8,
        ),
        Ritual(
          id: 'seed-ritual-stretch',
          title: 'Stretch',
          icon: 'figure.cooldown',
          cadence: Cadence.daily,
          order: 4,
          streak: 2,
        ),
      ];

  /// The full exercise catalog, mirroring the handoff `workout-data.jsx`
  /// `EXERCISES` table (~21 across Push / Pull / Legs / Core / Cardio).
  /// Cardio entries have no PR (the prototype omits `pr` for them).
  static List<Exercise> exercises() => const [
        // --- Push ---
        Exercise(
          id: 'bench',
          name: 'Barbell Bench Press',
          group: 'Push',
          muscle: 'Chest',
          icon: 'figure.strengthtraining.traditional',
          equipment: 'Barbell',
          pr: ExercisePR(weightKg: 92.5, reps: 5),
        ),
        Exercise(
          id: 'ohp',
          name: 'Overhead Press',
          group: 'Push',
          muscle: 'Shoulders',
          icon: 'figure.strengthtraining.traditional',
          equipment: 'Barbell',
          pr: ExercisePR(weightKg: 57.5, reps: 5),
        ),
        Exercise(
          id: 'incline-db',
          name: 'Incline DB Press',
          group: 'Push',
          muscle: 'Chest',
          icon: 'dumbbell.fill',
          equipment: 'Dumbbell',
          pr: ExercisePR(weightKg: 32.5, reps: 8),
        ),
        Exercise(
          id: 'tricep-rope',
          name: 'Tricep Pushdown',
          group: 'Push',
          muscle: 'Triceps',
          icon: 'figure.strengthtraining.functional',
          equipment: 'Cable',
          pr: ExercisePR(weightKg: 35, reps: 12),
        ),
        Exercise(
          id: 'lateral-raise',
          name: 'Lateral Raise',
          group: 'Push',
          muscle: 'Shoulders',
          icon: 'dumbbell.fill',
          equipment: 'Dumbbell',
          pr: ExercisePR(weightKg: 12.5, reps: 12),
        ),

        // --- Pull ---
        Exercise(
          id: 'deadlift',
          name: 'Deadlift',
          group: 'Pull',
          muscle: 'Back',
          icon: 'figure.strengthtraining.traditional',
          equipment: 'Barbell',
          pr: ExercisePR(weightKg: 142.5, reps: 3),
        ),
        Exercise(
          id: 'pullup',
          name: 'Pull-up',
          group: 'Pull',
          muscle: 'Back',
          icon: 'figure.pullup',
          equipment: 'Bodyweight',
          pr: ExercisePR(weightKg: 0, reps: 11),
        ),
        Exercise(
          id: 'barbell-row',
          name: 'Barbell Row',
          group: 'Pull',
          muscle: 'Back',
          icon: 'figure.strengthtraining.traditional',
          equipment: 'Barbell',
          pr: ExercisePR(weightKg: 77.5, reps: 6),
        ),
        Exercise(
          id: 'face-pull',
          name: 'Face Pull',
          group: 'Pull',
          muscle: 'Rear Delts',
          icon: 'figure.strengthtraining.functional',
          equipment: 'Cable',
          pr: ExercisePR(weightKg: 30, reps: 15),
        ),
        Exercise(
          id: 'bicep-curl',
          name: 'Bicep Curl',
          group: 'Pull',
          muscle: 'Biceps',
          icon: 'dumbbell.fill',
          equipment: 'Dumbbell',
          pr: ExercisePR(weightKg: 17.5, reps: 10),
        ),

        // --- Legs ---
        Exercise(
          id: 'squat',
          name: 'Back Squat',
          group: 'Legs',
          muscle: 'Quads',
          icon: 'figure.strengthtraining.traditional',
          equipment: 'Barbell',
          pr: ExercisePR(weightKg: 115, reps: 5),
        ),
        Exercise(
          id: 'rdl',
          name: 'Romanian Deadlift',
          group: 'Legs',
          muscle: 'Hamstrings',
          icon: 'figure.strengthtraining.traditional',
          equipment: 'Barbell',
          pr: ExercisePR(weightKg: 95, reps: 8),
        ),
        Exercise(
          id: 'leg-press',
          name: 'Leg Press',
          group: 'Legs',
          muscle: 'Quads',
          icon: 'figure.strengthtraining.functional',
          equipment: 'Machine',
          pr: ExercisePR(weightKg: 180, reps: 10),
        ),
        Exercise(
          id: 'calf-raise',
          name: 'Standing Calf Raise',
          group: 'Legs',
          muscle: 'Calves',
          icon: 'figure.strengthtraining.functional',
          equipment: 'Machine',
          pr: ExercisePR(weightKg: 80, reps: 15),
        ),
        Exercise(
          id: 'walking-lunge',
          name: 'Walking Lunge',
          group: 'Legs',
          muscle: 'Quads',
          icon: 'figure.walk',
          equipment: 'Dumbbell',
          pr: ExercisePR(weightKg: 20, reps: 12),
        ),

        // --- Core ---
        Exercise(
          id: 'plank',
          name: 'Plank',
          group: 'Core',
          muscle: 'Core',
          icon: 'figure.core.training',
          equipment: 'Bodyweight',
          pr: ExercisePR(weightKg: 0, reps: 90),
        ),
        Exercise(
          id: 'hanging-leg',
          name: 'Hanging Leg Raise',
          group: 'Core',
          muscle: 'Abs',
          icon: 'figure.core.training',
          equipment: 'Bodyweight',
          pr: ExercisePR(weightKg: 0, reps: 12),
        ),

        // --- Cardio (no PR) ---
        Exercise(
          id: 'treadmill',
          name: 'Treadmill Run',
          group: 'Cardio',
          muscle: 'Cardio',
          icon: 'figure.run',
          equipment: 'Treadmill',
        ),
        Exercise(
          id: 'rower',
          name: 'Row Erg',
          group: 'Cardio',
          muscle: 'Cardio',
          icon: 'figure.rower',
          equipment: 'Rower',
        ),
        Exercise(
          id: 'bike',
          name: 'Assault Bike',
          group: 'Cardio',
          muscle: 'Cardio',
          icon: 'figure.indoor.cycle',
          equipment: 'Bike',
        ),
        Exercise(
          id: 'stairmaster',
          name: 'StairMaster',
          group: 'Cardio',
          muscle: 'Cardio',
          icon: 'figure.stair.stepper',
          equipment: 'Machine',
        ),
      ];

  /// Sample routines from the handoff `ROUTINES` table (Push / Pull / Legs +
  /// an upper-power custom + a cardio interval). Targets derive from the
  /// prototype's top set per exercise.
  static List<Routine> routines() => const [
        Routine(
          id: 'seed-routine-push-a',
          name: 'Push Day A',
          tag: RoutineTag.upper,
          restSeconds: 120,
          exercises: [
            RoutineExercise(
              id: 'seed-rex-push-bench',
              exerciseId: 'bench',
              order: 0,
              targetSets: 4,
              targetReps: 5,
              targetWeightKg: 90,
            ),
            RoutineExercise(
              id: 'seed-rex-push-ohp',
              exerciseId: 'ohp',
              order: 1,
              targetSets: 3,
              targetReps: 6,
              targetWeightKg: 55,
            ),
            RoutineExercise(
              id: 'seed-rex-push-incline',
              exerciseId: 'incline-db',
              order: 2,
              targetSets: 3,
              targetReps: 10,
              targetWeightKg: 30,
            ),
            RoutineExercise(
              id: 'seed-rex-push-lateral',
              exerciseId: 'lateral-raise',
              order: 3,
              targetSets: 3,
              targetReps: 12,
              targetWeightKg: 12,
            ),
            RoutineExercise(
              id: 'seed-rex-push-tricep',
              exerciseId: 'tricep-rope',
              order: 4,
              targetSets: 3,
              targetReps: 12,
              targetWeightKg: 35,
            ),
          ],
        ),
        Routine(
          id: 'seed-routine-pull-a',
          name: 'Pull Day A',
          tag: RoutineTag.upper,
          restSeconds: 120,
          exercises: [
            RoutineExercise(
              id: 'seed-rex-pull-deadlift',
              exerciseId: 'deadlift',
              order: 0,
              targetSets: 3,
              targetReps: 3,
              targetWeightKg: 140,
            ),
            RoutineExercise(
              id: 'seed-rex-pull-pullup',
              exerciseId: 'pullup',
              order: 1,
              targetSets: 3,
              targetReps: 8,
            ),
            RoutineExercise(
              id: 'seed-rex-pull-row',
              exerciseId: 'barbell-row',
              order: 2,
              targetSets: 3,
              targetReps: 8,
              targetWeightKg: 77.5,
            ),
            RoutineExercise(
              id: 'seed-rex-pull-facepull',
              exerciseId: 'face-pull',
              order: 3,
              targetSets: 3,
              targetReps: 15,
              targetWeightKg: 30,
            ),
            RoutineExercise(
              id: 'seed-rex-pull-curl',
              exerciseId: 'bicep-curl',
              order: 4,
              targetSets: 3,
              targetReps: 10,
              targetWeightKg: 17.5,
            ),
          ],
        ),
        Routine(
          id: 'seed-routine-legs',
          name: 'Leg Day',
          tag: RoutineTag.lower,
          restSeconds: 150,
          exercises: [
            RoutineExercise(
              id: 'seed-rex-legs-squat',
              exerciseId: 'squat',
              order: 0,
              targetSets: 4,
              targetReps: 5,
              targetWeightKg: 110,
            ),
            RoutineExercise(
              id: 'seed-rex-legs-rdl',
              exerciseId: 'rdl',
              order: 1,
              targetSets: 3,
              targetReps: 8,
              targetWeightKg: 90,
            ),
            RoutineExercise(
              id: 'seed-rex-legs-legpress',
              exerciseId: 'leg-press',
              order: 2,
              targetSets: 3,
              targetReps: 10,
              targetWeightKg: 180,
            ),
            RoutineExercise(
              id: 'seed-rex-legs-lunge',
              exerciseId: 'walking-lunge',
              order: 3,
              targetSets: 3,
              targetReps: 12,
              targetWeightKg: 20,
            ),
            RoutineExercise(
              id: 'seed-rex-legs-calf',
              exerciseId: 'calf-raise',
              order: 4,
              targetSets: 3,
              targetReps: 15,
              targetWeightKg: 80,
            ),
          ],
        ),
        Routine(
          id: 'seed-routine-upper-power',
          name: 'Upper Power',
          tag: RoutineTag.custom,
          restSeconds: 180,
          exercises: [
            RoutineExercise(
              id: 'seed-rex-up-bench',
              exerciseId: 'bench',
              order: 0,
              targetSets: 3,
              targetReps: 3,
              targetWeightKg: 92.5,
            ),
            RoutineExercise(
              id: 'seed-rex-up-row',
              exerciseId: 'barbell-row',
              order: 1,
              targetSets: 3,
              targetReps: 5,
              targetWeightKg: 77.5,
            ),
            RoutineExercise(
              id: 'seed-rex-up-ohp',
              exerciseId: 'ohp',
              order: 2,
              targetSets: 3,
              targetReps: 5,
              targetWeightKg: 55,
            ),
            RoutineExercise(
              id: 'seed-rex-up-pullup',
              exerciseId: 'pullup',
              order: 3,
              targetSets: 3,
              targetReps: 6,
            ),
          ],
        ),
        Routine(
          id: 'seed-routine-treadmill-int',
          name: 'Treadmill Intervals',
          tag: RoutineTag.cardio,
          restSeconds: 60,
          exercises: [
            RoutineExercise(
              id: 'seed-rex-cardio-treadmill',
              exerciseId: 'treadmill',
              order: 0,
              targetSets: 1,
            ),
          ],
        ),
      ];

  /// Two past workouts: one completed earlier today (push), one yesterday
  /// (legs). The today one is linked from a move [Entry] (see [entries]).
  static List<Workout> workouts() => [
        Workout(
          id: 'seed-workout-today-push',
          routineId: 'seed-routine-push-a',
          name: 'Push Day A',
          startedAt: _todayAt(17, 45),
          endedAt: _todayAt(18, 37),
          sets: const [
            SetLog(
              id: 'seed-set-1',
              exerciseId: 'bench',
              weightKg: 80,
              reps: 5,
              done: true,
            ),
            SetLog(
              id: 'seed-set-2',
              exerciseId: 'bench',
              weightKg: 85,
              reps: 5,
              done: true,
            ),
            SetLog(
              id: 'seed-set-3',
              exerciseId: 'bench',
              weightKg: 92.5,
              reps: 5,
              done: true,
              isPR: true,
            ),
            SetLog(
              id: 'seed-set-4',
              exerciseId: 'ohp',
              weightKg: 52.5,
              reps: 6,
              done: true,
            ),
            SetLog(
              id: 'seed-set-5',
              exerciseId: 'ohp',
              weightKg: 55,
              reps: 6,
              done: true,
            ),
          ],
        ),
        Workout(
          id: 'seed-workout-yday-legs',
          routineId: null,
          name: 'Leg Day',
          startedAt: _daysAgoAt(1, 18, 0),
          endedAt: _daysAgoAt(1, 19, 2),
          sets: const [
            SetLog(
              id: 'seed-set-6',
              exerciseId: 'squat',
              weightKg: 100,
              reps: 5,
              done: true,
            ),
            SetLog(
              id: 'seed-set-7',
              exerciseId: 'squat',
              weightKg: 110,
              reps: 5,
              done: true,
            ),
            SetLog(
              id: 'seed-set-8',
              exerciseId: 'deadlift',
              weightKg: 130,
              reps: 3,
              done: true,
            ),
          ],
        ),
      ];

  /// Today's timeline entries across all three trackers, mirroring the legacy
  /// `todayEntries` but as rich [Entry]s. The strength entry is linked to the
  /// seeded push workout via [Entry.workoutId].
  static List<Entry> entries() => [
        Entry(
          id: 'seed-entry-morning-pages',
          timestamp: _todayAt(6, 42),
          type: EntryType.rituals,
          title: 'Morning pages',
          detail: '15 min · journal',
          duration: 15,
          ritualId: 'seed-ritual-morning-pages',
          source: EntrySource.manual,
        ),
        Entry(
          id: 'seed-entry-run',
          timestamp: _todayAt(7, 15),
          type: EntryType.move,
          title: 'Run · Mission loop',
          detail: '4.8 km · 24:10',
          duration: 24,
          calories: 287,
          distance: 4.8,
          source: EntrySource.health,
        ),
        Entry(
          id: 'seed-entry-coffee',
          timestamp: _todayAt(8, 30),
          type: EntryType.money,
          title: 'Verve Coffee',
          detail: 'Coffee · cortado',
          amount: -5.75,
          category: 'Coffee',
          source: EntrySource.manual,
        ),
        Entry(
          id: 'seed-entry-inbox',
          timestamp: _todayAt(9, 10),
          type: EntryType.rituals,
          title: 'Inbox zero',
          detail: '22 min · focus',
          duration: 22,
          ritualId: 'seed-ritual-inbox-zero',
          source: EntrySource.manual,
        ),
        Entry(
          id: 'seed-entry-lunch',
          timestamp: _todayAt(12, 40),
          type: EntryType.money,
          title: 'Tartine',
          detail: 'Lunch · sandwich',
          amount: -16.20,
          category: 'Dining',
          source: EntrySource.email,
        ),
        Entry(
          id: 'seed-entry-spanish',
          timestamp: _todayAt(14, 20),
          type: EntryType.rituals,
          title: 'Spanish practice',
          detail: '18 min · Duolingo',
          duration: 18,
          ritualId: 'seed-ritual-spanish',
          source: EntrySource.manual,
        ),
        Entry(
          id: 'seed-entry-strength',
          timestamp: _todayAt(17, 45),
          type: EntryType.move,
          title: 'Strength · push',
          detail: '52 min · gym',
          duration: 52,
          calories: 312,
          source: EntrySource.manual,
          workoutId: 'seed-workout-today-push',
        ),
        Entry(
          id: 'seed-entry-groceries',
          timestamp: _todayAt(19, 10),
          type: EntryType.money,
          title: 'Whole Foods',
          detail: 'Groceries · dinner',
          amount: -38.40,
          category: 'Groceries',
          source: EntrySource.email,
        ),
        Entry(
          id: 'seed-entry-read',
          timestamp: _todayAt(21, 30),
          type: EntryType.rituals,
          title: 'Read · Pachinko',
          detail: '28 min · 19 pgs',
          duration: 28,
          ritualId: 'seed-ritual-read',
          source: EntrySource.manual,
        ),
      ];
}
