import 'enums.dart';

/// A passive observation in the Pal inbox — "a quiet inbox, not an anxious one".
class PalNote {
  const PalNote({
    required this.id,
    required this.createdAt,
    required this.kind,
    required this.category,
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.unread = true,
  });

  /// Caller-supplied id.
  final String id;
  final DateTime createdAt;
  final NoteKind kind;

  /// Drives the category color dot (money / move / rituals).
  final EntryType category;

  /// SF Symbol name.
  final String icon;
  final String title;
  final String body;

  /// Optional action pill label (deep-links / seeds Pal). Null = no action.
  final String? actionLabel;
  final bool unread;

  PalNote copyWith({
    String? id,
    DateTime? createdAt,
    NoteKind? kind,
    EntryType? category,
    String? icon,
    String? title,
    String? body,
    String? actionLabel,
    bool? unread,
  }) =>
      PalNote(
        id: id ?? this.id,
        createdAt: createdAt ?? this.createdAt,
        kind: kind ?? this.kind,
        category: category ?? this.category,
        icon: icon ?? this.icon,
        title: title ?? this.title,
        body: body ?? this.body,
        actionLabel: actionLabel ?? this.actionLabel,
        unread: unread ?? this.unread,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PalNote &&
          other.id == id &&
          other.createdAt == createdAt &&
          other.kind == kind &&
          other.category == category &&
          other.icon == icon &&
          other.title == title &&
          other.body == body &&
          other.actionLabel == actionLabel &&
          other.unread == unread;

  @override
  int get hashCode => Object.hash(
        id,
        createdAt,
        kind,
        category,
        icon,
        title,
        body,
        actionLabel,
        unread,
      );

  @override
  String toString() => 'PalNote(id: $id, kind: ${kind.wire}, title: $title)';
}
