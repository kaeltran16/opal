import 'enums.dart';

/// A single logged item on the unified timeline — money, movement, or a ritual.
///
/// Mirrors the handoff's `@Model class Entry`. SwiftData `UUID` → [String] [id]
/// (callers supply the id; the model never self-generates), `Date` → [DateTime],
/// and all SwiftData optionals → nullable Dart fields.
class Entry {
  const Entry({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.title,
    this.detail,
    this.amount,
    this.duration,
    this.calories,
    this.distance,
    this.category,
    this.ritualId,
    this.note,
    required this.source,
    this.sourceRef,
    this.workoutId,
  });

  /// UUID supplied by the caller (never self-generated). Non-null.
  final String id;
  final DateTime timestamp;
  final EntryType type;
  final String title;

  /// Free-form secondary line (e.g. "Coffee · cortado"). Nullable.
  final String? detail;

  /// Money only. Negative = expense, positive = income. Nullable.
  final double? amount;

  /// Move / rituals minutes. Nullable.
  final int? duration;

  /// Move only, kilocalories. Nullable.
  final int? calories;

  /// Move only, kilometres. Nullable.
  final double? distance;

  /// Money only, category label. Nullable.
  final String? category;

  /// Rituals only, FK to [Ritual.id]. Nullable.
  final String? ritualId;

  final String? note;
  final EntrySource source;

  /// External reference (emailMessageId, healthWorkoutUUID, …). Nullable.
  final String? sourceRef;

  /// FK to [Workout.id] when this is a strength-session move entry. Nullable.
  final String? workoutId;

  /// True when this entry represents an expense (money, amount < 0).
  bool get isExpense => type == EntryType.money && (amount ?? 0) < 0;

  /// True when this entry represents income (money, amount > 0).
  bool get isIncome => type == EntryType.money && (amount ?? 0) > 0;

  Entry copyWith({
    String? id,
    DateTime? timestamp,
    EntryType? type,
    String? title,
    String? detail,
    double? amount,
    int? duration,
    int? calories,
    double? distance,
    String? category,
    String? ritualId,
    String? note,
    EntrySource? source,
    String? sourceRef,
    String? workoutId,
  }) {
    return Entry(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      title: title ?? this.title,
      detail: detail ?? this.detail,
      amount: amount ?? this.amount,
      duration: duration ?? this.duration,
      calories: calories ?? this.calories,
      distance: distance ?? this.distance,
      category: category ?? this.category,
      ritualId: ritualId ?? this.ritualId,
      note: note ?? this.note,
      source: source ?? this.source,
      sourceRef: sourceRef ?? this.sourceRef,
      workoutId: workoutId ?? this.workoutId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Entry &&
          other.id == id &&
          other.timestamp == timestamp &&
          other.type == type &&
          other.title == title &&
          other.detail == detail &&
          other.amount == amount &&
          other.duration == duration &&
          other.calories == calories &&
          other.distance == distance &&
          other.category == category &&
          other.ritualId == ritualId &&
          other.note == note &&
          other.source == source &&
          other.sourceRef == sourceRef &&
          other.workoutId == workoutId;

  @override
  int get hashCode => Object.hash(
        id,
        timestamp,
        type,
        title,
        detail,
        amount,
        duration,
        calories,
        distance,
        category,
        ritualId,
        note,
        source,
        sourceRef,
        workoutId,
      );

  @override
  String toString() => 'Entry(id: $id, type: ${type.wire}, title: $title)';
}
