import '../../models/models.dart';

/// The Pal AI seam: chat, NL parse, monthly review, and workout suggestion.
///
/// Defined in U03 so every later consumer (U12 Start-Workout, U16 Chat, U18
/// Monthly Review, U07 "Type it" parse) codes against a stable interface. The
/// mock returns canned on-brand strings with fake latency; the real
/// `HttpPalService` (U23) swaps in via a Riverpod provider override with zero
/// screen changes. The return DTOs below are the locked SF-3 contract.

/// Formats a money [magnitude] for a "Logged $X" confirmation: whole amounts
/// drop the cents (12 → "12"), fractional amounts keep two places (12.5 →
/// "12.50"). Shared by every Pal surface so confirmations read identically.
String formatLoggedAmount(double magnitude) =>
    magnitude % 1 == 0 ? magnitude.toStringAsFixed(0) : magnitude.toStringAsFixed(2);

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
enum GoalTarget { dailyBudget, dailyMoveKcal, dailyRitualTarget }

/// Log a timeline [Entry]. Money carries a signed [amount] (negative = expense),
/// move carries [durationMinutes]; rituals carry neither.
class LogEntryAction extends PalAction {
  const LogEntryAction({
    required this.type,
    required this.title,
    this.amount,
    this.durationMinutes,
    this.calories,
    this.category,
    this.note,
  });

  final EntryType type;
  final String title;
  final double? amount;
  final int? durationMinutes;
  final int? calories;
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
          other.calories == calories &&
          other.category == category &&
          other.note == note;

  @override
  int get hashCode =>
      Object.hash(type, title, amount, durationMinutes, calories, category, note);
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

/// The period a `/review` narrative covers: a calendar [week] (anchor + 7 days)
/// for the Weekly Review, or the calendar [month] of the anchor for the Monthly
/// Review. Decouples the review window from its anchor date.
enum ReviewRange { week, month }

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

/// A cross-pillar action Pal proposes on the Pal Home hub for the user to
/// approve (the "Needs you" list). Presentation is data-driven: [colorToken]
/// picks the pillar accent and [icon]/[approveIcon] are SF-symbol names rendered
/// through the safe icon map. [action] drives approve behavior — `'close_out'`
/// navigates to the Evening Close-Out flow; any other value (or null) flips the
/// card to its optimistic "done" confirmation.
class PalProposal {
  const PalProposal({
    required this.id,
    required this.tag,
    required this.colorToken,
    required this.icon,
    required this.title,
    required this.body,
    required this.approveLabel,
    required this.approveIcon,
    required this.doneLabel,
    this.action,
  });

  final String id;
  final String tag;
  final String colorToken; // 'money' | 'move' | 'rituals'
  final String icon;
  final String title;
  final String body;
  final String approveLabel;
  final String approveIcon;
  final String doneLabel;
  final String? action;

  bool get navigatesToCloseOut => action == 'close_out';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PalProposal &&
          other.id == id &&
          other.tag == tag &&
          other.colorToken == colorToken &&
          other.icon == icon &&
          other.title == title &&
          other.body == body &&
          other.approveLabel == approveLabel &&
          other.approveIcon == approveIcon &&
          other.doneLabel == doneLabel &&
          other.action == action;

  @override
  int get hashCode => Object.hash(id, tag, colorToken, icon, title, body,
      approveLabel, approveIcon, doneLabel, action);
}

/// A background task Pal handles automatically, shown in the "On autopilot"
/// list with a toggle. [enabled] is the server-side default.
class PalAutopilotItem {
  const PalAutopilotItem({
    required this.id,
    required this.colorToken,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
  });

  final String id;
  final String colorToken;
  final String icon;
  final String title;
  final String subtitle;
  final bool enabled;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PalAutopilotItem &&
          other.id == id &&
          other.colorToken == colorToken &&
          other.icon == icon &&
          other.title == title &&
          other.subtitle == subtitle &&
          other.enabled == enabled;

  @override
  int get hashCode =>
      Object.hash(id, colorToken, icon, title, subtitle, enabled);
}

/// One durable fact the user told Pal (the `/v1/memory` facts list). Deletable
/// per item in "What Pal remembers".
class PalFact {
  const PalFact({required this.id, required this.text});

  final String id;
  final String text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PalFact && other.id == id && other.text == text;

  @override
  int get hashCode => Object.hash(id, text);
}

/// Pal's persistent memory: user-authored [facts] + derived [patterns]
/// (the `/v1/memory` payload). Patterns reuse [InsightPattern].
class PalMemoryDigest {
  const PalMemoryDigest({this.facts = const [], this.patterns = const []});

  final List<PalFact> facts;
  final List<InsightPattern> patterns;

  bool get isEmpty => facts.isEmpty && patterns.isEmpty;
}

/// The Pal Home hub payload (the `/agenda` seam): the proposals to approve, the
/// autopilot delegation list, and the current workout [streakDays] shown in the
/// hero. Fields default empty so a partial/older server payload degrades to
/// empty sections rather than an error.
class PalAgenda {
  const PalAgenda({
    this.proposals = const [],
    this.autopilot = const [],
    this.streakDays = 0,
  });

  final List<PalProposal> proposals;
  final List<PalAutopilotItem> autopilot;
  final int streakDays;

  bool get isEmpty => proposals.isEmpty && autopilot.isEmpty;
}

/// A structured quick-log payload attached to a concrete suggestion chip. When
/// Pal is offline, the composer writes this as a local [Entry] instead of
/// hanging; the New Entry sheet uses it to pre-fill the form. Open-prompt /
/// goal chips carry none (null). Money [amount] is pre-signed (negative =
/// expense), mirroring [Entry.amount].
class StarterEntry {
  const StarterEntry({
    required this.type,
    required this.title,
    this.amount,
    this.category,
    this.durationMinutes,
  });

  final EntryType type;
  final String title;
  final double? amount;
  final String? category;
  final int? durationMinutes;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StarterEntry &&
          other.type == type &&
          other.title == title &&
          other.amount == amount &&
          other.category == category &&
          other.durationMinutes == durationMinutes;

  @override
  int get hashCode => Object.hash(type, title, amount, category, durationMinutes);
}

/// Which surface a [PalSuggestion] set is generated for. Tunes the server prompt
/// and selects the context the client sends.
enum SuggestionSurface { composer, newEntry, routineGoal }

/// One Pal-generated quick-pick chip (the `/suggestions` seam). [label] is both
/// the display text and the action text (chat message or routine goal). [icon]
/// is an SF-symbol name derived server-side from the model's kind; [colorToken]
/// is the pillar accent. [entry] is the optional structured quick-log used by
/// the composer (offline fallback) and New Entry (form prefill).
class PalSuggestion {
  const PalSuggestion({
    required this.label,
    required this.icon,
    required this.colorToken,
    this.entry,
  });

  final String label;
  final String icon;
  final String colorToken;
  final StarterEntry? entry;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PalSuggestion &&
          other.label == label &&
          other.icon == icon &&
          other.colorToken == colorToken &&
          other.entry == entry;

  @override
  int get hashCode => Object.hash(label, icon, colorToken, entry);
}

/// The Pal AI interface. All methods are async to model network latency.
abstract interface class PalService {
  /// `/chat`: continue a conversation given prior [history] and the new
  /// [message]; returns the assistant's reply plus any mutations it applied.
  Future<PalChatResult> chat(List<PalMessage> history, String message);

  /// `/parse`: turn a natural-language [text] into structured entry fields.
  Future<ParsedEntryDraft> parse(String text);

  /// `/review`: a narrative summary for the period [range] (week or month)
  /// containing [anchor] (U18).
  Future<String> review(DateTime anchor, ReviewRange range);

  /// `/insights`: structured Pal-found insights (wins/patterns/headline) for the
  /// given [range]. Powers the Today "Pal noticed" card and the Review screens.
  Future<PalInsights> insights(InsightRange range);

  /// Suggest a workout for the Start-Workout picker (U12). [another] true asks
  /// for a different pick than the last; [excludeRoutineId] is the routine just
  /// shown, dropped from the candidate list so "another" doesn't repeat it.
  Future<WorkoutSuggestion> suggestWorkout({
    bool another = false,
    String? excludeRoutineId,
  });

  /// A short post-workout note for the summary/detail screens (U14/U15).
  Future<String> postWorkoutNote(Workout workout);

  /// `/routine`: build an ordered routine from a free-text [goal], drawing only
  /// from the [available] exercise catalog. Powers the Routine Generator.
  Future<GeneratedRoutineDraft> generateRoutine(
    String goal,
    List<Exercise> available,
  );

  /// `/agenda`: the Pal Home hub payload — cross-pillar [PalProposal]s to
  /// approve, the autopilot delegation list, and the workout streak. Drives the
  /// agentic Pal Home screen.
  Future<PalAgenda> agenda();

  /// `/v1/suggestions`: Pal-generated, context-aware quick-pick chips for the
  /// given [surface]. Drives the composer starters, New Entry quick-picks, and
  /// Routine Generator goal chips.
  Future<List<PalSuggestion>> suggestions(SuggestionSurface surface);

  /// `/v1/memory`: Pal's current persistent memory for this device.
  Future<PalMemoryDigest> memory();

  /// `POST /v1/memory/refresh`: re-derive patterns from recent data; returns the
  /// updated digest.
  Future<PalMemoryDigest> refreshMemory();

  /// `DELETE /v1/memory/facts/:id`: forget one fact; returns the updated digest.
  Future<PalMemoryDigest> deleteFact(String id);

  /// `DELETE /v1/memory`: wipe all memory; returns the (empty) digest.
  Future<PalMemoryDigest> clearMemory();
}
