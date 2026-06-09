/// Barrel export for the plain-Dart repositories (U02).
///
/// Each is constructed with a [LoopDatabase] instance and assigns UUIDs on
/// insert. No Riverpod here — U03 wires these into providers.
library;

export 'entry_repository.dart';
export 'goals_repository.dart';
export 'ritual_repository.dart';
export 'routine_repository.dart';
export 'workout_repository.dart';
