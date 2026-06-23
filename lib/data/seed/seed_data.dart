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
          title: 'Four Verve runs last week',
          body: "You spent \$23 at Verve over the past 7 days — 1.7× your usual "
              'pace. Dial back this week, or re-budget?',
          actionLabel: 'Ask Pal',
          unread: true,
        ),
        PalNote(
          id: 'seed-note-3',
          createdAt: _minutesAgo(60 * 26),
          kind: NoteKind.spotted,
          category: EntryType.move,
          icon: 'fork.knife',
          // no weekday in the copy: createdAt is relative (_minutesAgo) so the
          // inbox stamp owns "when"; a hardcoded day would drift against it.
          title: 'You skipped lunch',
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
          // no weekday/date in the copy (see seed-note-3): createdAt is relative
          // so the inbox stamp owns "when"; a hardcoded day/date would drift.
          title: 'Rent auto-pays this week',
          body: '\$2,400 from Chase ··0427. Balance looks fine — \$4,192 after.',
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

  /// The exercise catalog — reference data shipped to every build (36 across
  /// Push / Pull / Legs / Core / Cardio).
  ///
  /// Ships PR-less: PRs are user-derived, not catalog data. The demo user's
  /// records are overlaid separately via [demoExercisePrs] in the dev seed only.
  /// Icons reuse SF Symbols already present in the catalog.
  static List<Exercise> exercises() => const [
        // --- Push ---
        Exercise(
          id: 'bench',
          name: 'Barbell Bench Press',
          group: 'Push',
          muscle: 'Chest',
          icon: 'figure.strengthtraining.traditional',
          equipment: 'Barbell',
        ),
        Exercise(
          id: 'ohp',
          name: 'Overhead Press',
          group: 'Push',
          muscle: 'Shoulders',
          icon: 'figure.strengthtraining.traditional',
          equipment: 'Barbell',
        ),
        Exercise(
          id: 'incline-db',
          name: 'Incline DB Press',
          group: 'Push',
          muscle: 'Chest',
          icon: 'dumbbell.fill',
          equipment: 'Dumbbell',
        ),
        Exercise(
          id: 'flat-db-press',
          name: 'Flat DB Press',
          group: 'Push',
          muscle: 'Chest',
          icon: 'dumbbell.fill',
          equipment: 'Dumbbell',
        ),
        Exercise(
          id: 'cable-fly',
          name: 'Cable Fly',
          group: 'Push',
          muscle: 'Chest',
          icon: 'figure.strengthtraining.functional',
          equipment: 'Cable',
        ),
        Exercise(
          id: 'dips',
          name: 'Dips',
          group: 'Push',
          muscle: 'Chest',
          icon: 'figure.strengthtraining.functional',
          equipment: 'Bodyweight',
        ),
        Exercise(
          id: 'tricep-rope',
          name: 'Tricep Pushdown',
          group: 'Push',
          muscle: 'Triceps',
          icon: 'figure.strengthtraining.functional',
          equipment: 'Cable',
        ),
        Exercise(
          id: 'lateral-raise',
          name: 'Lateral Raise',
          group: 'Push',
          muscle: 'Shoulders',
          icon: 'dumbbell.fill',
          equipment: 'Dumbbell',
        ),

        // --- Pull ---
        Exercise(
          id: 'deadlift',
          name: 'Deadlift',
          group: 'Pull',
          muscle: 'Back',
          icon: 'figure.strengthtraining.traditional',
          equipment: 'Barbell',
        ),
        Exercise(
          id: 'pullup',
          name: 'Pull-up',
          group: 'Pull',
          muscle: 'Back',
          icon: 'figure.pullup',
          equipment: 'Bodyweight',
        ),
        Exercise(
          id: 'lat-pulldown',
          name: 'Lat Pulldown',
          group: 'Pull',
          muscle: 'Back',
          icon: 'figure.strengthtraining.functional',
          equipment: 'Cable',
        ),
        Exercise(
          id: 'barbell-row',
          name: 'Barbell Row',
          group: 'Pull',
          muscle: 'Back',
          icon: 'figure.strengthtraining.traditional',
          equipment: 'Barbell',
        ),
        Exercise(
          id: 'seated-cable-row',
          name: 'Seated Cable Row',
          group: 'Pull',
          muscle: 'Back',
          icon: 'figure.strengthtraining.functional',
          equipment: 'Cable',
        ),
        Exercise(
          id: 'face-pull',
          name: 'Face Pull',
          group: 'Pull',
          muscle: 'Rear Delts',
          icon: 'figure.strengthtraining.functional',
          equipment: 'Cable',
        ),
        Exercise(
          id: 'barbell-shrug',
          name: 'Barbell Shrug',
          group: 'Pull',
          muscle: 'Traps',
          icon: 'figure.strengthtraining.traditional',
          equipment: 'Barbell',
        ),
        Exercise(
          id: 'bicep-curl',
          name: 'Bicep Curl',
          group: 'Pull',
          muscle: 'Biceps',
          icon: 'dumbbell.fill',
          equipment: 'Dumbbell',
        ),
        Exercise(
          id: 'hammer-curl',
          name: 'Hammer Curl',
          group: 'Pull',
          muscle: 'Biceps',
          icon: 'dumbbell.fill',
          equipment: 'Dumbbell',
        ),

        // --- Legs ---
        Exercise(
          id: 'squat',
          name: 'Back Squat',
          group: 'Legs',
          muscle: 'Quads',
          icon: 'figure.strengthtraining.traditional',
          equipment: 'Barbell',
        ),
        Exercise(
          id: 'rdl',
          name: 'Romanian Deadlift',
          group: 'Legs',
          muscle: 'Hamstrings',
          icon: 'figure.strengthtraining.traditional',
          equipment: 'Barbell',
        ),
        Exercise(
          id: 'leg-press',
          name: 'Leg Press',
          group: 'Legs',
          muscle: 'Quads',
          icon: 'figure.strengthtraining.functional',
          equipment: 'Machine',
        ),
        Exercise(
          id: 'leg-extension',
          name: 'Leg Extension',
          group: 'Legs',
          muscle: 'Quads',
          icon: 'figure.strengthtraining.functional',
          equipment: 'Machine',
        ),
        Exercise(
          id: 'leg-curl',
          name: 'Leg Curl',
          group: 'Legs',
          muscle: 'Hamstrings',
          icon: 'figure.strengthtraining.functional',
          equipment: 'Machine',
        ),
        Exercise(
          id: 'hip-thrust',
          name: 'Hip Thrust',
          group: 'Legs',
          muscle: 'Glutes',
          icon: 'figure.strengthtraining.traditional',
          equipment: 'Barbell',
        ),
        Exercise(
          id: 'bulgarian-split-squat',
          name: 'Bulgarian Split Squat',
          group: 'Legs',
          muscle: 'Quads',
          icon: 'figure.walk',
          equipment: 'Dumbbell',
        ),
        Exercise(
          id: 'walking-lunge',
          name: 'Walking Lunge',
          group: 'Legs',
          muscle: 'Quads',
          icon: 'figure.walk',
          equipment: 'Dumbbell',
        ),
        Exercise(
          id: 'calf-raise',
          name: 'Standing Calf Raise',
          group: 'Legs',
          muscle: 'Calves',
          icon: 'figure.strengthtraining.functional',
          equipment: 'Machine',
        ),

        // --- Core ---
        Exercise(
          id: 'plank',
          name: 'Plank',
          group: 'Core',
          muscle: 'Core',
          icon: 'figure.core.training',
          equipment: 'Bodyweight',
        ),
        Exercise(
          id: 'hanging-leg',
          name: 'Hanging Leg Raise',
          group: 'Core',
          muscle: 'Abs',
          icon: 'figure.core.training',
          equipment: 'Bodyweight',
        ),
        Exercise(
          id: 'crunch',
          name: 'Crunch',
          group: 'Core',
          muscle: 'Abs',
          icon: 'figure.core.training',
          equipment: 'Bodyweight',
        ),
        Exercise(
          id: 'cable-crunch',
          name: 'Cable Crunch',
          group: 'Core',
          muscle: 'Abs',
          icon: 'figure.core.training',
          equipment: 'Cable',
        ),
        Exercise(
          id: 'russian-twist',
          name: 'Russian Twist',
          group: 'Core',
          muscle: 'Obliques',
          icon: 'figure.core.training',
          equipment: 'Bodyweight',
        ),
        Exercise(
          id: 'ab-wheel',
          name: 'Ab Wheel Rollout',
          group: 'Core',
          muscle: 'Core',
          icon: 'figure.core.training',
          equipment: 'Bodyweight',
        ),

        // --- Cardio ---
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

  /// The demo user's personal records, keyed by exercise id. Overlaid onto the
  /// (PR-less) reference catalog by the dev seed only — see [Seeder.seedDemoData].
  /// These are the baseline volumes PR detection compares against in a session.
  static Map<String, ExercisePR> demoExercisePrs() => const {
        'bench': ExercisePR(weightKg: 92.5, reps: 5),
        'ohp': ExercisePR(weightKg: 57.5, reps: 5),
        'incline-db': ExercisePR(weightKg: 32.5, reps: 8),
        'tricep-rope': ExercisePR(weightKg: 35, reps: 12),
        'lateral-raise': ExercisePR(weightKg: 12.5, reps: 12),
        'deadlift': ExercisePR(weightKg: 142.5, reps: 3),
        'pullup': ExercisePR(weightKg: 0, reps: 11),
        'barbell-row': ExercisePR(weightKg: 77.5, reps: 6),
        'face-pull': ExercisePR(weightKg: 30, reps: 15),
        'bicep-curl': ExercisePR(weightKg: 17.5, reps: 10),
        'squat': ExercisePR(weightKg: 115, reps: 5),
        'rdl': ExercisePR(weightKg: 95, reps: 8),
        'leg-press': ExercisePR(weightKg: 180, reps: 10),
        'calf-raise': ExercisePR(weightKg: 80, reps: 15),
        'walking-lunge': ExercisePR(weightKg: 20, reps: 12),
        'plank': ExercisePR(weightKg: 0, reps: 90),
        'hanging-leg': ExercisePR(weightKg: 0, reps: 12),
      };

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
        // Earliest entry — anchors "Tracking since" so tenure predates the
        // 11-day workout / 12-day routine streaks (otherwise it reads "0 days").
        Entry(
          id: 'seed-entry-first-run',
          timestamp: _daysAgoAt(14, 7, 20),
          type: EntryType.move,
          title: 'Run · first log',
          detail: '3.2 km · 17:40',
          duration: 18,
          calories: 198,
          distance: 3.2,
          source: EntrySource.health,
        ),
        // Backfill: a real 11-day move streak (today + the previous 10 days) so
        // the streak surfaces and the "11-day workout streak" copy is truthful.
        // Days 11-13 stay empty so the streak stops at 11 (the day-14 first-run
        // entry above only anchors "Tracking since").
        ...List<Entry>.generate(10, (i) {
          final daysAgo = i + 1; // 1..10
          final isRun = daysAgo.isEven;
          return Entry(
            id: 'seed-entry-streak-$daysAgo',
            timestamp: _daysAgoAt(daysAgo, 7, 30),
            type: EntryType.move,
            title: isRun ? 'Run · morning loop' : 'Walk · neighborhood',
            detail: isRun ? '4.6 km · 23:30' : '32 min',
            duration: isRun ? 23 : 32,
            calories: isRun ? 268 : 175,
            distance: isRun ? 4.6 : null,
            source: EntrySource.health,
          );
        }),
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
          category: 'Food & Drink',
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
          category: 'Food & Drink',
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
        // pending nutrition card: a food expense with no linked meal yet.
        Entry(
          id: 'seed-nutrition-pending',
          timestamp: _todayAt(20, 15),
          type: EntryType.money,
          title: 'Thai Basil',
          detail: 'DoorDash',
          amount: -24.80,
          category: 'Food & Drink',
          source: EntrySource.email,
        ),

        // --- Backfill: 29 days of money + ritual entries for correlation engine ---
        // Short nights attributed to daysAgo 0,3,6,9,12,15,19,24 — those days
        // carry higher spend (~$65–72) vs normal-night days (~$30–37).
        // Today (daysAgo=0) already has ~$85 in the entries above.
        ..._backfillMoneyAndRituals(),
      ];

  /// Four demo nutrition meals (design's m1–m4), anchored to today so the
  /// Nutrition landing always has content on first run.
  ///
  /// m2 links to the seeded Verve coffee expense; m3 links to the Tartine lunch
  /// expense — both already in [entries]. m1/m4 are home meals with no link.
  static List<NutritionMeal> nutritionMeals() => [
        NutritionMeal(
          id: 'seed-meal-m1',
          timestamp: _todayAt(7, 50),
          slot: 'Breakfast',
          name: 'Oats & banana',
          source: NutritionSource.home,
          icon: 'leaf.fill',
          confidence: NutritionConfidence.med,
          cal: const IntRange(290, 400),
          macros: macrosFromCal(const IntRange(290, 400)),
          tags: const ['fiber-rich'],
        ),
        NutritionMeal(
          id: 'seed-meal-m2',
          timestamp: _todayAt(8, 30),
          slot: 'Drink',
          name: 'Verve cortado',
          source: NutritionSource.takeout,
          icon: 'cup.and.saucer.fill',
          confidence: NutritionConfidence.low,
          cal: const IntRange(60, 120),
          macros: macrosFromCal(const IntRange(60, 120)),
          linkedEntryId: 'seed-entry-coffee',
        ),
        NutritionMeal(
          id: 'seed-meal-m3',
          timestamp: _todayAt(12, 40),
          slot: 'Lunch',
          name: 'Tartine sandwich',
          source: NutritionSource.takeout,
          icon: 'fork.knife',
          confidence: NutritionConfidence.med,
          cal: const IntRange(560, 820),
          macros: macrosFromCal(const IntRange(560, 820)),
          note: 'estimated from Tartine order',
          tags: const ['from expense', 'high-carb'],
          linkedEntryId: 'seed-entry-lunch',
        ),
        NutritionMeal(
          id: 'seed-meal-m4',
          timestamp: _todayAt(19, 10),
          slot: 'Dinner',
          name: 'Whole Foods bowl',
          source: NutritionSource.home,
          icon: 'basket.fill',
          confidence: NutritionConfidence.med,
          cal: const IntRange(480, 680),
          macros: macrosFromCal(const IntRange(480, 680)),
          tags: const ['groceries'],
          linkedEntryId: 'seed-entry-groceries',
        ),
      ];

  // ---------------------------------------------------------------------------
  // Backfill helpers (sleep/mood correlation window)
  // ---------------------------------------------------------------------------

  /// Generates 29 days of money + ritual entries (daysAgo 1..29) so the
  /// correlation engine has ≥21 paired days for Sleep×Spending and Mood×Ritual.
  ///
  /// Money amounts are calibrated against [sleepNights]: days whose night was
  /// short (daysAgo 1,4,7,10,13,16,20,25 → attributed to daysAgo 0,3,6,9,12,
  /// 15,19,24) carry higher spend ($64–72); all other days carry lower spend
  /// ($30–37). Today (daysAgo 0) is covered by the existing entries above.
  ///
  /// Ritual days (daysAgo 1,2,3,5,6,8,9,11,12,14,15,17,18,20,21,23,24,26,27)
  /// get 5 morning-step completions each; skipped days contribute nothing
  /// (the 0-fill in buildDailyVectors handles those).
  static List<Entry> _backfillMoneyAndRituals() {
    // spend per daysAgo 1..29; index 0 = daysAgo 1.
    // daysAgo 3,6,9,12,15,19,24 are "after short night" → higher spend.
    // daysAgo 0 (today) is handled by existing entries; not in this list.
    const spendByDaysAgo = <int, double>{
      1: 33.00,
      2: 35.00,
      3: 66.50, // after short night
      4: 36.00,
      5: 30.00,
      6: 71.00, // after short night
      7: 34.00,
      8: 37.00,
      9: 64.20, // after short night
      10: 31.00,
      11: 36.00,
      12: 68.80, // after short night
      13: 32.00,
      14: 34.00,
      15: 70.50, // after short night
      16: 33.00,
      17: 36.00,
      18: 30.00,
      19: 65.30, // after short night
      20: 34.00,
      21: 37.00,
      22: 31.00,
      23: 35.00,
      24: 72.00, // after short night
      25: 33.00,
      26: 36.00,
      27: 30.00,
      28: 35.00,
      29: 32.00,
    };

    // days with morning ritual completed (5 steps each).
    const ritualDays = {1, 2, 3, 5, 6, 8, 9, 11, 12, 14, 15, 17, 18, 20, 21, 23, 24, 26, 27};

    final entries = <Entry>[];
    for (final e in spendByDaysAgo.entries) {
      final d = e.key;
      entries.add(Entry(
        id: 'seed-spend-d$d',
        timestamp: _daysAgoAt(d, 12, 0),
        type: EntryType.money,
        title: 'Daily spend',
        detail: 'auto-seeded',
        amount: -e.value,
        category: 'Food & Drink',
        source: EntrySource.manual,
      ));
    }
    for (final d in ritualDays) {
      for (var step = 0; step < 5; step++) {
        entries.add(Entry(
          id: 'seed-ritual-d$d-s$step',
          timestamp: _daysAgoAt(d, 7, step * 5),
          type: EntryType.rituals,
          title: 'Morning step ${step + 1}',
          detail: 'Morning · step ${step + 1}',
          ritualId: 'morning-step-$step',
          source: EntrySource.manual,
        ));
      }
    }
    return entries;
  }

  // ---------------------------------------------------------------------------
  // Sleep nights — 30 nights; engineered so short nights precede high-spend days
  // ---------------------------------------------------------------------------

  /// 30 nights ending last night. [SleepNight.night] is the calendar date of
  /// the sleep session; [buildDailyVectors] attributes it to night+1 for
  /// same-day pairing with money. Short nights (asleepMinutes < 390) at
  /// daysAgo 4,7,10,13,16,20,25 are attributed to the higher-spend days.
  static List<SleepNight> sleepNights() {
    // (daysAgo, asleepMin, inBedMin, bedtime, wake, deep, rem, core, awake, wakes)
    const nights = <(int, int, int, String, String, int, int, int, int, int)>[
      // last night — prescribed (asleep 432, normal; today's high spend is an outlier
      // the correlation absorbs — estimated |r| still ~0.84 across 30 nights).
      (1, 432, 450, '23:32', '7:02', 64, 98, 270, 18, 2),
      // short nights — asleepMinutes < 390 (kShortNightMinutes = 390),
      // each attributed to a higher-spend day via night+1 mapping.
      (4, 355, 375, '0:18', '6:13', 48, 82, 225, 20, 3),
      (7, 342, 362, '0:42', '6:24', 44, 76, 222, 20, 3),
      (10, 368, 388, '23:55', '6:03', 52, 88, 228, 20, 2),
      (13, 348, 368, '0:30', '6:18', 46, 80, 222, 20, 3),
      (16, 362, 382, '0:12', '6:14', 50, 85, 227, 20, 3),
      (20, 350, 370, '0:38', '6:28', 45, 78, 227, 20, 3),
      (25, 375, 395, '23:48', '6:03', 55, 90, 230, 20, 2),
      // normal nights — asleepMinutes 415–468
      (2, 438, 455, '23:10', '6:48', 68, 102, 268, 17, 1),
      (3, 452, 468, '22:55', '6:47', 72, 108, 272, 16, 1),
      (5, 445, 462, '23:05', '6:50', 70, 105, 270, 17, 1),
      (6, 420, 438, '23:22', '6:42', 64, 98, 258, 18, 2),
      (8, 456, 472, '22:52', '6:48', 74, 110, 272, 16, 1),
      (9, 418, 436, '23:18', '6:36', 63, 96, 259, 18, 2),
      (11, 462, 478, '22:48', '6:50', 76, 112, 274, 16, 1),
      (12, 428, 445, '23:15', '6:43', 66, 100, 262, 17, 2),
      (14, 448, 465, '23:00', '6:48', 71, 107, 270, 17, 1),
      (15, 415, 433, '23:20', '6:35', 62, 95, 258, 18, 2),
      (17, 460, 476, '22:50', '6:50', 75, 111, 274, 16, 1),
      (18, 435, 452, '23:12', '6:47', 68, 103, 264, 17, 1),
      (19, 422, 440, '23:16', '6:38', 64, 97, 261, 18, 2),
      (21, 458, 474, '22:52', '6:50', 74, 110, 274, 16, 1),
      (22, 442, 458, '23:08', '6:50', 69, 105, 268, 17, 1),
      (23, 430, 448, '23:14', '6:44', 67, 101, 262, 17, 2),
      (24, 452, 468, '23:00', '6:52', 72, 108, 272, 16, 1),
      (26, 438, 455, '23:10', '6:48', 68, 102, 268, 17, 1),
      (27, 455, 470, '22:58', '6:53', 73, 109, 273, 16, 1),
      (28, 425, 442, '23:18', '6:43', 65, 99, 261, 17, 2),
      (29, 446, 463, '23:05', '6:51', 71, 107, 268, 17, 1),
      (30, 440, 457, '23:10', '6:50', 69, 104, 267, 17, 1),
    ];

    return [
      for (final (d, asleep, inBed, bed, wake, deep, rem, core, awake, wakes) in nights)
        SleepNight(
          id: 'seed-sleep-$d',
          night: _daysAgoAt(d, 0, 0),
          asleepMinutes: asleep,
          inBedMinutes: inBed,
          bedtime: bed,
          wake: wake,
          deepMinutes: deep,
          remMinutes: rem,
          coreMinutes: core,
          awakeMinutes: awake,
          wakes: wakes,
          source: EntrySource.health,
        ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Mood check-ins — calibrated against ritual days
  // ---------------------------------------------------------------------------

  /// One+ check-ins per day for 30 days. On ritual days (where morning steps
  /// were logged) pleasantness is higher (0.62–0.72); on skipped days it is
  /// lower (0.36–0.46). Today has three check-ins matching the prototype hero.
  static List<MoodCheckin> moodCheckins() {
    // ritual days: 0,1,2,3,5,6,8,9,11,12,14,15,17,18,20,21,23,24,26,27
    // skipped days: 4,7,10,13,16,19,22,25,28,29 — lower pleasantness entries below.

    // (daysAgo, hour, min, pleasantness, tag)
    final specs = <(int, int, int, double, String?)>[
      // today — three check-ins matching prototype hero (prescribed)
      (0, 8, 5, 0.46, 'Tired'),
      (0, 13, 40, 0.62, 'Calm'),
      (0, 21, 12, 0.70, 'Calm'),
      // prior days — one mid-day check-in each
      (1, 13, 15, 0.65, null),
      (2, 13, 20, 0.68, null),
      (3, 13, 10, 0.63, null),
      (4, 13, 30, 0.42, null), // skipped ritual
      (5, 13, 5, 0.66, null),
      (6, 13, 25, 0.71, null),
      (7, 13, 15, 0.38, null), // skipped
      (8, 13, 20, 0.67, null),
      (9, 13, 10, 0.64, null),
      (10, 13, 30, 0.44, null), // skipped
      (11, 13, 5, 0.69, null),
      (12, 13, 25, 0.65, null),
      (13, 13, 15, 0.40, null), // skipped
      (14, 13, 20, 0.70, null),
      (15, 13, 10, 0.63, null),
      (16, 13, 30, 0.43, null), // skipped
      (17, 13, 5, 0.68, null),
      (18, 13, 25, 0.66, null),
      (19, 13, 15, 0.37, null), // skipped
      (20, 13, 20, 0.72, null),
      (21, 13, 10, 0.65, null),
      (22, 13, 30, 0.45, null), // skipped
      (23, 13, 5, 0.67, null),
      (24, 13, 25, 0.70, null),
      (25, 13, 15, 0.41, null), // skipped
      (26, 13, 20, 0.64, null),
      (27, 13, 10, 0.69, null),
      (28, 13, 30, 0.46, null), // skipped
      (29, 13, 5, 0.39, null), // skipped
    ];

    final result = <MoodCheckin>[];
    for (var i = 0; i < specs.length; i++) {
      final (d, h, m, p, tag) = specs[i];
      result.add(MoodCheckin(
        id: 'seed-mood-$i',
        timestamp: _daysAgoAt(d, h, m),
        pleasantness: p,
        tag: tag,
        source: EntrySource.manual,
      ));
    }
    return result;
  }

  /// The seven default per-category budget envelopes, position-ordered. Their
  /// categories are the canonical [kSpendCategories]; seed money [entries] use
  /// those same names so every expense lands in an envelope and the month total
  /// matches Insights. Any category that doesn't match still counts toward the
  /// authoritative total via the Budgets "Uncategorized" row.
  static List<BudgetEnvelope> budgetEnvelopes() => const [
        BudgetEnvelope(
          id: 'env-food',
          category: 'Food & Drink',
          cap: 600,
          icon: 'cup.and.saucer.fill',
          colorToken: 'money',
          position: 0,
        ),
        BudgetEnvelope(
          id: 'env-grocer',
          category: 'Groceries',
          cap: 500,
          icon: 'basket.fill',
          colorToken: 'money',
          position: 1,
        ),
        BudgetEnvelope(
          id: 'env-bills',
          category: 'Bills & Utilities',
          cap: 670,
          icon: 'bolt.fill',
          colorToken: 'accent',
          position: 2,
        ),
        BudgetEnvelope(
          id: 'env-shop',
          category: 'Shopping',
          cap: 300,
          icon: 'bag.fill',
          colorToken: 'rituals',
          position: 3,
        ),
        BudgetEnvelope(
          id: 'env-transit',
          category: 'Transport',
          cap: 200,
          icon: 'car.fill',
          colorToken: 'move',
          position: 4,
        ),
        BudgetEnvelope(
          id: 'env-fun',
          category: 'Entertainment',
          cap: 180,
          icon: 'tv.fill',
          colorToken: 'rituals',
          position: 5,
        ),
        BudgetEnvelope(
          id: 'env-health',
          category: 'Health',
          cap: 150,
          icon: 'heart.fill',
          colorToken: 'move',
          position: 6,
        ),
      ];
}
