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

  /// Helper: [minutesAgo] minutes back from now (for Pal-note timestamps).
  static DateTime _minutesAgo(int minutesAgo) =>
      DateTime.now().subtract(Duration(minutes: minutesAgo));

  /// The default daily targets (matches handoff / `Goals` defaults).
  static const Goals goals = Goals(
    dailyBudget: 85.0,
    dailyMoveKcal: 500,
    dailyRitualTarget: 5,
  );

  /// The three time-of-day ritual routines (Morning / Midday / Evening), each
  /// an ordered list of steps. Step ids follow `"<routineId>-step-<index>"` so
  /// a completed step can be recorded as a ritual `Entry` (`ritualId == step.id`)
  /// — the single source of truth shared with the Today rings.
  static List<RitualRoutine> ritualRoutines() => const [
        RitualRoutine(
          id: 'morning',
          name: 'Morning',
          time: '7:00 AM',
          tone: RitualTone.morning,
          icon: 'sunrise.fill',
          blurb: 'Ease into the day',
          streak: 12,
          order: 0,
          steps: [
            RitualStep(
              id: 'morning-step-0',
              title: 'Glass of water',
              note: 'Before coffee — rehydrate first thing.',
              icon: 'drop.fill',
            ),
            RitualStep(
              id: 'morning-step-1',
              title: 'Wash my face',
              note: 'Gentle cleanser, then a cold rinse to wake up.',
              icon: 'drop.fill',
            ),
            RitualStep(
              id: 'morning-step-2',
              title: 'Moisturize + SPF',
              note: "Don't skip the sunscreen, even indoors.",
              icon: 'sun.max.fill',
            ),
            RitualStep(
              id: 'morning-step-3',
              title: 'Meditate',
              note: 'Ten minutes. Eyes closed, follow the breath.',
              icon: 'sparkles',
            ),
            RitualStep(
              id: 'morning-step-4',
              title: 'Morning pages',
              note: 'Three pages, longhand, before any screens.',
              icon: 'book.closed.fill',
            ),
          ],
        ),
        RitualRoutine(
          id: 'midday',
          name: 'Midday reset',
          time: '1:00 PM',
          tone: RitualTone.midday,
          icon: 'sun.max.fill',
          blurb: 'Break the desk spell',
          streak: 5,
          order: 1,
          steps: [
            RitualStep(
              id: 'midday-step-0',
              title: 'Step outside',
              note: 'A ten-minute walk, no phone. Just move.',
              icon: 'figure.walk',
            ),
            RitualStep(
              id: 'midday-step-1',
              title: 'Stretch it out',
              note: 'Neck, shoulders, hips — undo the slouch.',
              icon: 'leaf.fill',
            ),
            RitualStep(
              id: 'midday-step-2',
              title: 'Inbox to zero',
              note: 'Reply, archive, or defer. Nothing lingers.',
              icon: 'tray.fill',
            ),
          ],
        ),
        RitualRoutine(
          id: 'evening',
          name: 'Evening wind-down',
          time: '9:30 PM',
          tone: RitualTone.evening,
          icon: 'moon.stars.fill',
          blurb: 'Close the day gently',
          streak: 8,
          order: 2,
          steps: [
            RitualStep(
              id: 'evening-step-0',
              title: 'Phone on the charger',
              note: 'Out of the bedroom. No screens past here.',
              icon: 'bolt.fill',
            ),
            RitualStep(
              id: 'evening-step-1',
              title: 'Skincare',
              note: 'Cleanse, serum, night cream.',
              icon: 'drop.fill',
            ),
            RitualStep(
              id: 'evening-step-2',
              title: 'Read',
              note: 'Twenty pages. Currently: Pachinko.',
              icon: 'books.vertical.fill',
            ),
            RitualStep(
              id: 'evening-step-3',
              title: 'Reflect',
              note: 'One honest line about today in the journal.',
              icon: 'character.book.closed.fill',
            ),
          ],
        ),
      ];

  /// Passive Pal-inbox observations (Pal Inbox screen).
  static List<PalNote> palNotes() => [
        PalNote(
          id: 'seed-note-1',
          createdAt: _minutesAgo(2),
          kind: NoteKind.nudge,
          category: EntryType.rituals,
          icon: 'moon.stars.fill',
          title: 'Evening close-out is open',
          body: "4 of 5 routines done. 5 min of reflection and you'll close the "
              'ring tonight.',
          actionLabel: 'Close out →',
          unread: true,
        ),
        PalNote(
          id: 'seed-note-2',
          createdAt: _minutesAgo(120),
          kind: NoteKind.spotted,
          category: EntryType.money,
          icon: 'cup.and.saucer.fill',
          title: 'Fourth Verve this week',
          body: "You've spent \$23 at Verve since Monday — 1.7× your usual "
              'pace. Dial back, or re-budget?',
          actionLabel: 'Ask Pal',
          unread: true,
        ),
        PalNote(
          id: 'seed-note-3',
          createdAt: _minutesAgo(60 * 26),
          kind: NoteKind.spotted,
          category: EntryType.move,
          icon: 'fork.knife',
          title: 'You skipped lunch Tuesday',
          body: 'No food logged between breakfast and 6pm — and you still ran '
              '4.8km after. Just noticed.',
          actionLabel: 'Log it',
          unread: false,
        ),
        PalNote(
          id: 'seed-note-4',
          createdAt: _minutesAgo(60 * 27),
          kind: NoteKind.win,
          category: EntryType.move,
          icon: 'flame.fill',
          title: '11-day workout streak',
          body: "Longest you've gone this year. Want to share or just keep it "
              'going quietly?',
          actionLabel: 'See streak',
          unread: false,
        ),
        PalNote(
          id: 'seed-note-5',
          createdAt: _minutesAgo(60 * 48),
          kind: NoteKind.pattern,
          category: EntryType.rituals,
          icon: 'sparkles',
          title: 'Morning pages → better days',
          body: 'Your workout score averages 73 min on days you write, 42 min on '
              'days you skip. Pattern over 6 weeks.',
          actionLabel: 'See pattern',
          unread: false,
        ),
        PalNote(
          id: 'seed-note-6',
          createdAt: _minutesAgo(60 * 72),
          kind: NoteKind.reminder,
          category: EntryType.money,
          icon: 'bell.fill',
          title: 'Rent auto-pays Monday',
          body: '\$2,400 from Chase ··0427 on Apr 28. Balance looks fine — '
              '\$4,192 after.',
          actionLabel: 'View bill',
          unread: false,
        ),
        PalNote(
          id: 'seed-note-7',
          createdAt: _minutesAgo(60 * 96),
          kind: NoteKind.recap,
          category: EntryType.rituals,
          icon: 'chart.bar.fill',
          title: 'Your weekly review is ready',
          body: "A steady week — under budget, 11-day streak, 6/7 morning "
              "pages. Let's look closer.",
          actionLabel: 'Open review →',
          unread: false,
        ),
        PalNote(
          id: 'seed-note-8',
          createdAt: _minutesAgo(60 * 120),
          kind: NoteKind.spotted,
          category: EntryType.move,
          icon: 'figure.run',
          title: 'Shorter runs after 9pm',
          body: 'Your last 3 late runs averaged 18 min vs your morning 28. '
              'Evening you is tireder than morning you.',
          actionLabel: null,
          unread: false,
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
          estMin: 55,
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
          estMin: 58,
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
          estMin: 62,
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
          estMin: 45,
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
          estMin: 30,
          distanceKm: 5.0,
          pace: '5:00 /km',
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

  /// The default weekly schedule (ISO weekday 1=Mon..7=Sun) referencing the
  /// seeded [routines]. Wed/Sun are Rest days (no row). Mirrors the layout the
  /// Weekly Plan screen previously hardcoded.
  static List<WeeklyPlanAssignment> weeklyPlan() => const [
        WeeklyPlanAssignment(weekday: 1, routineId: 'seed-routine-push-a'),
        WeeklyPlanAssignment(weekday: 2, routineId: 'seed-routine-pull-a'),
        WeeklyPlanAssignment(weekday: 4, routineId: 'seed-routine-legs'),
        WeeklyPlanAssignment(
            weekday: 5, routineId: 'seed-routine-treadmill-int'),
        WeeklyPlanAssignment(weekday: 6, routineId: 'seed-routine-upper-power'),
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
          id: 'seed-entry-step-morning-0',
          timestamp: _todayAt(6, 42),
          type: EntryType.rituals,
          title: 'Glass of water',
          detail: 'Morning · step 1',
          ritualId: 'morning-step-0',
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
          id: 'seed-entry-step-morning-1',
          timestamp: _todayAt(6, 48),
          type: EntryType.rituals,
          title: 'Wash my face',
          detail: 'Morning · step 2',
          ritualId: 'morning-step-1',
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
          id: 'seed-entry-step-morning-2',
          timestamp: _todayAt(6, 55),
          type: EntryType.rituals,
          title: 'Moisturize + SPF',
          detail: 'Morning · step 3',
          ritualId: 'morning-step-2',
          source: EntrySource.manual,
        ),
        Entry(
          id: 'seed-entry-strength',
          timestamp: _todayAt(17, 45),
          type: EntryType.move,
          title: 'Strength · push',
          detail: 'Push day · gym',
          duration: 42,
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
      ];
}
