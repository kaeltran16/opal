import 'enums.dart';

/// A recurring daily/weekly habit the user tracks.
///
/// Mirrors the handoff's `@Model class Ritual`. SwiftData `Date?` →
/// nullable [DateTime] [reminderTime]; `icon` holds an SF Symbol name
/// (resolved via `lib/widgets/app_icon.dart` on Flutter).
class Ritual {
  const Ritual({
    required this.id,
    required this.title,
    required this.icon,
    this.cadence = Cadence.daily,
    this.reminderTime,
    this.order = 0,
    this.streak = 0,
  });

  /// Caller-supplied id (never self-generated).
  final String id;
  final String title;

  /// SF Symbol name, e.g. "book.closed.fill".
  final String icon;
  final Cadence cadence;

  /// Optional time-of-day reminder. Nullable.
  final DateTime? reminderTime;

  /// Display/sort order (0-based).
  final int order;

  /// Current consecutive-completion streak in days.
  final int streak;

  Ritual copyWith({
    String? id,
    String? title,
    String? icon,
    Cadence? cadence,
    DateTime? reminderTime,
    int? order,
    int? streak,
  }) {
    return Ritual(
      id: id ?? this.id,
      title: title ?? this.title,
      icon: icon ?? this.icon,
      cadence: cadence ?? this.cadence,
      reminderTime: reminderTime ?? this.reminderTime,
      order: order ?? this.order,
      streak: streak ?? this.streak,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Ritual &&
          other.id == id &&
          other.title == title &&
          other.icon == icon &&
          other.cadence == cadence &&
          other.reminderTime == reminderTime &&
          other.order == order &&
          other.streak == streak;

  @override
  int get hashCode =>
      Object.hash(id, title, icon, cadence, reminderTime, order, streak);

  @override
  String toString() =>
      'Ritual(id: $id, title: $title, cadence: ${cadence.wire}, streak: $streak)';
}
