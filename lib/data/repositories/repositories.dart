/// Barrel export for the plain-Dart repositories (U02).
///
/// Each is constructed with a [LoopDatabase] instance and assigns UUIDs on
/// insert. No Riverpod here — U03 wires these into providers.
library;

export 'budget_envelope_repository.dart';
export 'entry_repository.dart';
export 'goals_repository.dart';
export 'pal_note_repository.dart';
export 'ritual_repository.dart';
export 'routine_repository.dart';
export 'settings_repository.dart';
export 'weekly_plan_repository.dart';
export 'workout_repository.dart';
