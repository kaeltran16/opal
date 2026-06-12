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
///
/// An assistant turn may have applied [actions] (auto-applied mutations the user
/// can reverse); [undone] flips true once they have been reversed.
class PalMessage {
  const PalMessage({
    required this.role,
    required this.text,
    required this.timestamp,
    this.actions = const [],
    this.undone = false,
  });

  final PalRole role;
  final String text;
  final DateTime timestamp;

  /// Mutations this turn applied (empty for user messages and plain replies).
  final List<PalAction> actions;

  /// True once [actions] have been reversed via undo.
  final bool undone;

  PalMessage copyWith({
    PalRole? role,
    String? text,
    DateTime? timestamp,
    List<PalAction>? actions,
    bool? undone,
  }) =>
      PalMessage(
        role: role ?? this.role,
        text: text ?? this.text,
        timestamp: timestamp ?? this.timestamp,
        actions: actions ?? this.actions,
        undone: undone ?? this.undone,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PalMessage &&
          other.role == role &&
          other.text == text &&
          other.timestamp == timestamp &&
          other.undone == undone &&
          _listEquals(other.actions, actions);

  @override
  int get hashCode =>
      Object.hash(role, text, timestamp, undone, Object.hashAll(actions));
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// A mutation Pal performed from chat, decoded from the `/chat` `actions` wire.
/// Auto-applied client-side and reversible via undo. Unknown wire kinds decode
/// to null and are skipped, so a newer server never breaks an older client.
sealed class PalAction {
  const PalAction();
}

/// Which daily goal a [SetGoalAction] changes.
enum GoalTarget { dailyBudget, dailyMoveMinutes, dailyRitualTarget }

/// Log a timeline [Entry]. Money carries a signed [amount] (negative = expense),
/// move carries [durationMinutes]; rituals carry neither.
class LogEntryAction extends PalAction {
  const LogEntryAction({
    required this.type,
    required this.title,
    this.amount,
    this.durationMinutes,
    this.category,
    this.note,
  });

  final EntryType type;
  final String title;
  final double? amount;
  final int? durationMinutes;
  final String? category;
  final String? note;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LogEntryAction &&
          other.type == type &&
          other.title == title &&
          other.amount == amount &&
          other.durationMinutes == durationMinutes &&
          other.category == category &&
          other.note == note;

  @override
  int get hashCode =>
      Object.hash(type, title, amount, durationMinutes, category, note);
}

/// Build and save a workout routine for [goal]. Fulfilled client-side by calling
/// [PalService.generateRoutine] with the local exercise catalog, then persisting.
class CreateRoutineAction extends PalAction {
  const CreateRoutineAction({required this.goal, this.name});

  final String goal;
  final String? name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateRoutineAction && other.goal == goal && other.name == name;

  @override
  int get hashCode => Object.hash(goal, name);
}

/// Change one daily goal to [value].
class SetGoalAction extends PalAction {
  const SetGoalAction({required this.target, required this.value});

  final GoalTarget target;
  final num value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SetGoalAction && other.target == target && other.value == value;

  @override
  int get hashCode => Object.hash(target, value);
}

/// A chat turn's result: the assistant [reply] plus any [actions] it applied.
class PalChatResult {
  const PalChatResult({required this.reply, this.actions = const []});

  final String reply;
  final List<PalAction> actions;
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

/// The time window a structured insights request covers. [day] feeds the Today
/// "Pal noticed" card; [week]/[month] feed the Weekly/Monthly Review screens.
enum InsightRange { day, week, month }

/// A qualitative "Win" row in the Weekly Review (handoff screen 17). The icon is
/// derived on the client from [colorToken] — the model only chooses the metric.
class InsightWin {
  const InsightWin({
    required this.colorToken,
    required this.title,
    required this.sub,
  });

  /// 'money' | 'move' | 'rituals' — drives the row's accent and icon.
  final String colorToken;
  final String title;
  final String sub;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InsightWin &&
          other.colorToken == colorToken &&
          other.title == title &&
          other.sub == sub;

  @override
  int get hashCode => Object.hash(colorToken, title, sub);
}

/// A qualitative "Pattern" Pal found, used by the Weekly + Monthly Reviews.
class InsightPattern {
  const InsightPattern({
    required this.colorToken,
    required this.title,
    required this.detail,
  });

  /// 'money' | 'move' | 'rituals' — drives the accent bar / icon.
  final String colorToken;
  final String title;
  final String detail;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InsightPattern &&
          other.colorToken == colorToken &&
          other.title == title &&
          other.detail == detail;

  @override
  int get hashCode => Object.hash(colorToken, title, detail);
}

/// Structured, Pal-found insights for a window (the `/insights` seam). Each
/// surface reads the fields it needs: Today uses [headline]; Weekly uses
/// [headline] + [lede] (hero), [wins], [patterns], and [suggestion]; Monthly
/// uses [patterns]. Fields are nullable/empty when the range doesn't fill them.
class PalInsights {
  const PalInsights({
    this.headline,
    this.lede,
    this.suggestion,
    this.wins = const [],
    this.patterns = const [],
  });

  /// One warm lead observation (Today card + Weekly hero headline).
  final String? headline;

  /// A one-sentence sub-headline for the Weekly hero.
  final String? lede;

  /// One concrete thing to try (Weekly "One thing to try" card).
  final String? suggestion;

  final List<InsightWin> wins;
  final List<InsightPattern> patterns;

  /// True when there is nothing qualitative to show — the surfaces render their
  /// encouraging empty state instead.
  bool get isEmpty =>
      (headline == null || headline!.isEmpty) &&
      (suggestion == null || suggestion!.isEmpty) &&
      wins.isEmpty &&
      patterns.isEmpty;
}

/// The Pal AI interface. All methods are async to model network latency.
abstract interface class PalService {
  /// `/chat`: continue a conversation given prior [history] and the new
  /// [message]; returns the assistant's reply plus any mutations it applied.
  Future<PalChatResult> chat(List<PalMessage> history, String message);

  /// `/parse`: turn a natural-language [text] into structured entry fields.
  Future<ParsedEntryDraft> parse(String text);

  /// `/review`: a monthly narrative summary for [month] (U18).
  Future<String> review(DateTime month);

  /// `/insights`: structured Pal-found insights (wins/patterns/headline) for the
  /// given [range]. Powers the Today "Pal noticed" card and the Review screens.
  Future<PalInsights> insights(InsightRange range);

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
