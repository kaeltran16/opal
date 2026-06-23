import 'enums.dart';

/// One mood check-in. [pleasantness] is the 0..1 position on the
/// unpleasant↔pleasant scale (the prototype's draggable orb); the descriptive
/// word ("Slightly pleasant") is derived, never stored. [tag] is an optional
/// one-word note.
class MoodCheckin {
  const MoodCheckin({
    required this.id,
    required this.timestamp,
    required this.pleasantness,
    required this.source,
    this.tag,
  });

  final String id;
  final DateTime timestamp;
  final double pleasantness;
  final String? tag;
  final EntrySource source;

  MoodCheckin copyWith({
    String? id,
    DateTime? timestamp,
    double? pleasantness,
    Object? tag = _sentinel,
    EntrySource? source,
  }) =>
      MoodCheckin(
        id: id ?? this.id,
        timestamp: timestamp ?? this.timestamp,
        pleasantness: pleasantness ?? this.pleasantness,
        tag: identical(tag, _sentinel) ? this.tag : tag as String?,
        source: source ?? this.source,
      );

  static const _sentinel = Object();

  @override
  bool operator ==(Object other) =>
      other is MoodCheckin &&
      other.id == id &&
      other.timestamp == timestamp &&
      other.pleasantness == pleasantness &&
      other.tag == tag &&
      other.source == source;

  @override
  int get hashCode => Object.hash(id, timestamp, pleasantness, tag, source);
}
