import 'package:drift/drift.dart';

import '../../models/models.dart';
import 'database.dart';
import 'tables.dart' show GoalsTable;

/// Conversions between drift row classes and the `lib/models/` domain types.
///
/// Drift types never leak above the repository layer: repositories take/return
/// only domain models, using these mappers internally.

// ---------------------------------------------------------------------------
// Entry
// ---------------------------------------------------------------------------

extension EntryRowMapper on EntryRow {
  Entry toModel() => Entry(
        id: id,
        timestamp: timestamp,
        type: EntryType.fromWire(type),
        title: title,
        detail: detail,
        amount: amount,
        duration: duration,
        calories: calories,
        distance: distance,
        category: category,
        ritualId: ritualId,
        note: note,
        source: EntrySource.fromWire(source),
        sourceRef: sourceRef,
        workoutId: workoutId,
      );
}

extension EntryModelMapper on Entry {
  EntriesCompanion toCompanion() => EntriesCompanion(
        id: Value(id),
        timestamp: Value(timestamp),
        type: Value(type.wire),
        title: Value(title),
        detail: Value(detail),
        amount: Value(amount),
        duration: Value(duration),
        calories: Value(calories),
        distance: Value(distance),
        category: Value(category),
        ritualId: Value(ritualId),
        note: Value(note),
        source: Value(source.wire),
        sourceRef: Value(sourceRef),
        workoutId: Value(workoutId),
      );
}

// ---------------------------------------------------------------------------
// Exercise (ExercisePR flattened to two columns)
// ---------------------------------------------------------------------------

extension ExerciseRowMapper on ExerciseRow {
  Exercise toModel() => Exercise(
        id: id,
        name: name,
        group: group,
        muscle: muscle,
        icon: icon,
        equipment: equipment,
        pr: (prWeightKg != null && prReps != null)
            ? ExercisePR(weightKg: prWeightKg!, reps: prReps!)
            : null,
      );
}

extension ExerciseModelMapper on Exercise {
  ExercisesCompanion toCompanion() => ExercisesCompanion(
        id: Value(id),
        name: Value(name),
        group: Value(group),
        muscle: Value(muscle),
        icon: Value(icon),
        equipment: Value(equipment),
        prWeightKg: Value(pr?.weightKg),
        prReps: Value(pr?.reps),
      );
}

// ---------------------------------------------------------------------------
// Workout + SetLog
// ---------------------------------------------------------------------------

extension SetLogRowMapper on SetLogRow {
  SetLog toModel() => SetLog(
        id: id,
        exerciseId: exerciseId,
        weightKg: weightKg,
        reps: reps,
        done: done,
        isPR: isPR,
      );
}

extension SetLogModelMapper on SetLog {
  SetLogsCompanion toCompanion(String workoutId, int position) =>
      SetLogsCompanion(
        id: Value(id),
        workoutId: Value(workoutId),
        exerciseId: Value(exerciseId),
        weightKg: Value(weightKg),
        reps: Value(reps),
        done: Value(done),
        isPR: Value(isPR),
        position: Value(position),
      );
}

extension WorkoutModelMapper on Workout {
  WorkoutsCompanion toCompanion() => WorkoutsCompanion(
        id: Value(id),
        routineId: Value(routineId),
        name: Value(name),
        startedAt: Value(startedAt),
        endedAt: Value(endedAt),
      );
}

/// Builds a [Workout] domain object from its row + already-loaded child sets.
Workout workoutFromRow(WorkoutRow row, List<SetLog> sets) => Workout(
      id: row.id,
      routineId: row.routineId,
      name: row.name,
      startedAt: row.startedAt,
      endedAt: row.endedAt,
      sets: sets,
    );

// ---------------------------------------------------------------------------
// Routine + RoutineExercise
// ---------------------------------------------------------------------------

extension RoutineExerciseRowMapper on RoutineExerciseRow {
  RoutineExercise toModel() => RoutineExercise(
        id: id,
        exerciseId: exerciseId,
        order: position,
        targetSets: targetSets,
        targetReps: targetReps,
        targetWeightKg: targetWeightKg,
      );
}

extension RoutineExerciseModelMapper on RoutineExercise {
  RoutineExercisesCompanion toCompanion(String routineId) =>
      RoutineExercisesCompanion(
        id: Value(id),
        routineId: Value(routineId),
        exerciseId: Value(exerciseId),
        position: Value(order),
        targetSets: Value(targetSets),
        targetReps: Value(targetReps),
        targetWeightKg: Value(targetWeightKg),
      );
}

extension RoutineModelMapper on Routine {
  RoutinesCompanion toCompanion() => RoutinesCompanion(
        id: Value(id),
        name: Value(name),
        tag: Value(tag.wire),
        restSeconds: Value(restSeconds),
        warmupReminder: Value(warmupReminder),
        autoProgress: Value(autoProgress),
        estMin: Value(estMin),
        distanceKm: Value(distanceKm),
        pace: Value(pace),
      );
}

/// Builds a [Routine] from its row + already-loaded child exercise slots.
Routine routineFromRow(RoutineRow row, List<RoutineExercise> exercises) =>
    Routine(
      id: row.id,
      name: row.name,
      tag: RoutineTag.fromWire(row.tag),
      exercises: exercises,
      restSeconds: row.restSeconds,
      warmupReminder: row.warmupReminder,
      autoProgress: row.autoProgress,
      estMin: row.estMin,
      distanceKm: row.distanceKm,
      pace: row.pace,
    );

// ---------------------------------------------------------------------------
// RitualRoutine + RitualStep
// ---------------------------------------------------------------------------

extension RitualStepRowMapper on RitualStepRow {
  RitualStep toModel() => RitualStep(
        id: id,
        title: title,
        note: note,
        icon: icon,
      );
}

extension RitualStepModelMapper on RitualStep {
  RitualStepsCompanion toCompanion(String routineId, int position) =>
      RitualStepsCompanion(
        id: Value(id),
        routineId: Value(routineId),
        title: Value(title),
        note: Value(note),
        icon: Value(icon),
        position: Value(position),
      );
}

extension RitualRoutineModelMapper on RitualRoutine {
  RitualRoutinesCompanion toCompanion() => RitualRoutinesCompanion(
        id: Value(id),
        name: Value(name),
        time: Value(time),
        tone: Value(tone.wire),
        icon: Value(icon),
        blurb: Value(blurb),
        streak: Value(streak),
        position: Value(order),
      );
}

/// Builds a [RitualRoutine] from its row + already-loaded ordered steps.
RitualRoutine ritualRoutineFromRow(
  RitualRoutineRow row,
  List<RitualStep> steps,
) =>
    RitualRoutine(
      id: row.id,
      name: row.name,
      time: row.time,
      tone: RitualTone.fromWire(row.tone),
      icon: row.icon,
      blurb: row.blurb,
      streak: row.streak,
      order: row.position,
      steps: steps,
    );

// ---------------------------------------------------------------------------
// PalNote
// ---------------------------------------------------------------------------

extension PalNoteRowMapper on PalNoteRow {
  PalNote toModel() => PalNote(
        id: id,
        createdAt: createdAt,
        kind: NoteKind.fromWire(kind),
        category: EntryType.fromWire(category),
        icon: icon,
        title: title,
        body: body,
        actionLabel: actionLabel,
        unread: unread,
      );
}

extension PalNoteModelMapper on PalNote {
  PalNotesCompanion toCompanion() => PalNotesCompanion(
        id: Value(id),
        createdAt: Value(createdAt),
        kind: Value(kind.wire),
        category: Value(category.wire),
        icon: Value(icon),
        title: Value(title),
        body: Value(body),
        actionLabel: Value(actionLabel),
        unread: Value(unread),
      );
}

// ---------------------------------------------------------------------------
// WeeklyPlanAssignment (weekday -> routineId)
// ---------------------------------------------------------------------------

extension WeeklyPlanDayRowMapper on WeeklyPlanDayRow {
  WeeklyPlanAssignment toModel() =>
      WeeklyPlanAssignment(weekday: weekday, routineId: routineId);
}

extension WeeklyPlanAssignmentModelMapper on WeeklyPlanAssignment {
  WeeklyPlanDaysCompanion toCompanion() => WeeklyPlanDaysCompanion(
        weekday: Value(weekday),
        routineId: Value(routineId),
      );
}

// ---------------------------------------------------------------------------
// BudgetEnvelope
// ---------------------------------------------------------------------------

extension BudgetEnvelopeRowMapper on BudgetEnvelopeRow {
  BudgetEnvelope toModel() => BudgetEnvelope(
        id: id,
        category: category,
        cap: cap,
        icon: icon,
        colorToken: colorToken,
        position: position,
      );
}

extension BudgetEnvelopeModelMapper on BudgetEnvelope {
  BudgetEnvelopesCompanion toCompanion() => BudgetEnvelopesCompanion(
        id: Value(id),
        category: Value(category),
        cap: Value(cap),
        icon: Value(icon),
        colorToken: Value(colorToken),
        position: Value(position),
      );
}

// ---------------------------------------------------------------------------
// Goals (single row)
// ---------------------------------------------------------------------------

extension GoalsRowMapper on GoalsRow {
  Goals toModel() => Goals(
        dailyBudget: dailyBudget,
        dailyMoveKcal: dailyMoveKcal,
        dailyRitualTarget: dailyRitualTarget,
      );
}

extension GoalsModelMapper on Goals {
  GoalsTableCompanion toCompanion() => GoalsTableCompanion(
        id: const Value(GoalsTable.singletonId),
        dailyBudget: Value(dailyBudget),
        dailyMoveKcal: Value(dailyMoveKcal),
        dailyRitualTarget: Value(dailyRitualTarget),
      );
}
