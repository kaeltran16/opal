/// Domain enums mirroring the ExpensePal SwiftData handoff.
///
/// Each enum carries a stable [wire] string so that U02 (drift persistence)
/// and any future JSON layer can serialize/deserialize without depending on
/// Dart's `.name`/`.index` (which is brittle across reordering). Use
/// `Enum.fromWire(...)` to parse and `value.wire` to write.
library;

/// The three trackers a single [Entry] can belong to.
enum EntryType {
  money('money'),
  move('move'),
  rituals('rituals');

  const EntryType(this.wire);

  /// Stable serialization token (matches the handoff's `.money | .move | .rituals`).
  final String wire;

  static EntryType fromWire(String wire) =>
      values.firstWhere((e) => e.wire == wire);
}

/// Where an [Entry] originated.
enum EntrySource {
  manual('manual'),
  email('email'),
  health('health'),
  nlParsed('nlParsed');

  const EntrySource(this.wire);

  final String wire;

  static EntrySource fromWire(String wire) =>
      values.firstWhere((e) => e.wire == wire);
}

/// Classification of a [Routine] (drives default muscle/grouping).
enum RoutineTag {
  upper('upper'),
  lower('lower'),
  full('full'),
  cardio('cardio'),
  custom('custom');

  const RoutineTag(this.wire);

  final String wire;

  static RoutineTag fromWire(String wire) =>
      values.firstWhere((e) => e.wire == wire);
}

/// How often a [Ritual] is expected to recur.
enum Cadence {
  daily('daily'),
  weekdays('weekdays'),
  weekends('weekends'),
  weekly('weekly'),
  custom('custom');

  const Cadence(this.wire);

  final String wire;

  static Cadence fromWire(String wire) =>
      values.firstWhere((e) => e.wire == wire);
}

/// Email provider for an [EmailAccount].
enum Provider {
  gmail('gmail'),
  outlook('outlook'),
  other('other');

  const Provider(this.wire);

  final String wire;

  static Provider fromWire(String wire) =>
      values.firstWhere((e) => e.wire == wire);
}

/// Staged status of an email sync job (drives the dashboard status line).
enum SyncStatus {
  idle('idle'),
  scanning('scanning'),
  filtering('filtering'),
  categorizing('categorizing'),
  upToDate('upToDate'),
  error('error');

  const SyncStatus(this.wire);

  final String wire;

  static SyncStatus fromWire(String wire) =>
      values.firstWhere((e) => e.wire == wire);
}
