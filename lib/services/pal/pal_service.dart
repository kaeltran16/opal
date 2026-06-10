import '../../models/models.dart';

/// The Pal AI seam: chat, NL parse, monthly review, and workout suggestion.
///
/// Defined in U03 so every later consumer (U12 Start-Workout, U16 Chat, U18
/// Monthly Review, U07 "Type it" parse) codes against a stable interface. The
/// mock returns canned on-brand strings with fake latency; the real
/// `HttpPalService` (U23) swaps in via a Riverpod provider override with zero
/// screen changes. The return DTOs below are the locked SF-3 contract.

/// Author of a [PalMessage] in the Ask-Pal chat.
enum PalRole { user, assistant }

/// A single chat message (mirrors the handoff's chat bubble model).
class PalMessage {
  const PalMessage({
    required this.role,
    required this.text,
    required this.timestamp,
  });

  final PalRole role;
  final String text;
  final DateTime timestamp;

  PalMessage copyWith({PalRole? role, String? text, DateTime? timestamp}) =>
      PalMessage(
        role: role ?? this.role,
        text: text ?? this.text,
        timestamp: timestamp ?? this.timestamp,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PalMessage &&
          other.role == role &&
          other.text == text &&
          other.timestamp == timestamp;

  @override
  int get hashCode => Object.hash(role, text, timestamp);
}

/// Structured fields parsed from a natural-language entry (the `/parse` seam).
///
/// Returned by [PalService.parse] to pre-fill the New Entry form (U07/U16).
/// All fields are optional — the form fills what's present and leaves the rest
/// for the user.
class ParsedEntryDraft {
  const ParsedEntryDraft({
    required this.type,
    this.title,
    this.amount,
    this.category,
    this.durationMinutes,
    this.note,
  });

  final EntryType type;
  final String? title;

  /// Negative = expense, positive = income (money only).
  final double? amount;
  final String? category;
  final int? durationMinutes;
  final String? note;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ParsedEntryDraft &&
          other.type == type &&
          other.title == title &&
          other.amount == amount &&
          other.category == category &&
          other.durationMinutes == durationMinutes &&
          other.note == note;

  @override
  int get hashCode =>
      Object.hash(type, title, amount, category, durationMinutes, note);
}

/// A suggested workout for the Start-Workout "Pal's pick" card (U12).
class WorkoutSuggestion {
  const WorkoutSuggestion({
    required this.title,
    required this.rationale,
    this.routineId,
    this.estimatedMinutes,
    this.focus,
  });

  /// Display name, e.g. "Push Day A".
  final String title;

  /// One-line on-brand reason ("You're fresh and it's been 3 days since push").
  final String rationale;

  /// FK to a seeded/saved [Routine.id] when the pick maps to one. Nullable.
  final String? routineId;
  final int? estimatedMinutes;

  /// Muscle/group focus label, e.g. "Push".
  final String? focus;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutSuggestion &&
          other.title == title &&
          other.rationale == rationale &&
          other.routineId == routineId &&
          other.estimatedMinutes == estimatedMinutes &&
          other.focus == focus;

  @override
  int get hashCode =>
      Object.hash(title, rationale, routineId, estimatedMinutes, focus);
}

/// One generated set in a [GeneratedRoutineDraft] exercise. Strength sets carry
/// [reps] (+ optional [weightKg]); cardio sets carry [durationMinutes].
class GeneratedSetDraft {
  const GeneratedSetDraft({this.reps, this.weightKg, this.durationMinutes});

  final int? reps;
  final double? weightKg;
  final int? durationMinutes;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeneratedSetDraft &&
          other.reps == reps &&
          other.weightKg == weightKg &&
          other.durationMinutes == durationMinutes;

  @override
  int get hashCode => Object.hash(reps, weightKg, durationMinutes);
}

/// One exercise (by catalog [exerciseId]) plus its generated [sets].
class GeneratedExerciseDraft {
  const GeneratedExerciseDraft({required this.exerciseId, required this.sets});

  final String exerciseId;
  final List<GeneratedSetDraft> sets;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeneratedExerciseDraft &&
          other.exerciseId == exerciseId &&
          _setsEqual(other.sets, sets);

  @override
  int get hashCode => Object.hash(exerciseId, Object.hashAll(sets));
}

bool _setsEqual(List<GeneratedSetDraft> a, List<GeneratedSetDraft> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// An AI-generated routine returned by [PalService.generateRoutine] for the
/// Routine Generator screen (the `/routine` seam). The screen reviews it and,
/// on save, persists a real [Routine] via the repository.
class GeneratedRoutineDraft {
  const GeneratedRoutineDraft({
    required this.name,
    required this.tag,
    required this.exercises,
    this.estimatedMinutes,
    this.rationale,
  });

  final String name;
  final RoutineTag tag;
  final List<GeneratedExerciseDraft> exercises;
  final int? estimatedMinutes;

  /// One-sentence explanation of the design ("compound → isolation").
  final String? rationale;
}

/// The Pal AI interface. All methods are async to model network latency.
abstract interface class PalService {
  /// `/chat`: continue a conversation given prior [history] and the new
  /// [message]; returns the assistant's reply text.
  Future<String> chat(List<PalMessage> history, String message);

  /// `/parse`: turn a natural-language [text] into structured entry fields.
  Future<ParsedEntryDraft> parse(String text);

  /// `/review`: a monthly narrative summary for [month] (U18).
  Future<String> review(DateTime month);

  /// Suggest a workout for the Start-Workout picker (U12). [another] true asks
  /// for a different pick than the last.
  Future<WorkoutSuggestion> suggestWorkout({bool another = false});

  /// A short post-workout note for the summary/detail screens (U14/U15).
  Future<String> postWorkoutNote(Workout workout);

  /// `/routine`: build an ordered routine from a free-text [goal], drawing only
  /// from the [available] exercise catalog. Powers the Routine Generator.
  Future<GeneratedRoutineDraft> generateRoutine(
    String goal,
    List<Exercise> available,
  );
}
