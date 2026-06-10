import 'enums.dart';

/// One ordered step inside a [RitualRoutine] (e.g. "Glass of water").
///
/// [id] is stable so a step's completion can be recorded as a ritual-type
/// `Entry` (`Entry.ritualId == step.id`) — the single source of truth for
/// "what got done today", shared with the Today rings.
class RitualStep {
  const RitualStep({
    required this.id,
    required this.title,
    required this.note,
    required this.icon,
  });

  /// Caller-supplied stable id (seed convention: `"<routineId>-step-<index>"`).
  final String id;
  final String title;
  final String note;

  /// SF Symbol name, resolved via `lib/widgets/app_icon.dart`.
  final String icon;

  RitualStep copyWith({String? id, String? title, String? note, String? icon}) =>
      RitualStep(
        id: id ?? this.id,
        title: title ?? this.title,
        note: note ?? this.note,
        icon: icon ?? this.icon,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RitualStep &&
          other.id == id &&
          other.title == title &&
          other.note == note &&
          other.icon == icon;

  @override
  int get hashCode => Object.hash(id, title, note, icon);

  @override
  String toString() => 'RitualStep(id: $id, title: $title)';
}

/// A time-of-day routine (Morning / Midday / Evening) — an ordered list of
/// [steps]. Replaces the flat `Ritual`: the Rituals tab, guided Player, and
/// Evening Close-Out all read routines, and step completion writes a ritual
/// `Entry` so the Today rituals ring stays in sync.
class RitualRoutine {
  const RitualRoutine({
    required this.id,
    required this.name,
    required this.time,
    required this.tone,
    required this.icon,
    required this.blurb,
    this.streak = 0,
    this.order = 0,
    this.steps = const [],
  });

  /// Caller-supplied id (`"morning" | "midday" | "evening"` or a custom UUID).
  final String id;
  final String name;

  /// Human display time, e.g. "7:00 AM".
  final String time;
  final RitualTone tone;

  /// SF Symbol name for the routine glyph.
  final String icon;

  /// Short subtitle, e.g. "Ease into the day".
  final String blurb;

  /// Current consecutive-completion streak in days.
  final int streak;

  /// Display/sort order (0-based).
  final int order;

  /// Ordered steps.
  final List<RitualStep> steps;

  /// Key for `AppColors.forType(...)` — the tracker hue this routine borrows.
  String get colorKey => tone.colorKey;

  RitualRoutine copyWith({
    String? id,
    String? name,
    String? time,
    RitualTone? tone,
    String? icon,
    String? blurb,
    int? streak,
    int? order,
    List<RitualStep>? steps,
  }) =>
      RitualRoutine(
        id: id ?? this.id,
        name: name ?? this.name,
        time: time ?? this.time,
        tone: tone ?? this.tone,
        icon: icon ?? this.icon,
        blurb: blurb ?? this.blurb,
        streak: streak ?? this.streak,
        order: order ?? this.order,
        steps: steps ?? this.steps,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RitualRoutine &&
          other.id == id &&
          other.name == name &&
          other.time == time &&
          other.tone == tone &&
          other.icon == icon &&
          other.blurb == blurb &&
          other.streak == streak &&
          other.order == order &&
          _listEquals(other.steps, steps);

  @override
  int get hashCode => Object.hash(
        id,
        name,
        time,
        tone,
        icon,
        blurb,
        streak,
        order,
        Object.hashAll(steps),
      );

  @override
  String toString() =>
      'RitualRoutine(id: $id, name: $name, steps: ${steps.length})';
}

bool _listEquals(List<RitualStep> a, List<RitualStep> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
