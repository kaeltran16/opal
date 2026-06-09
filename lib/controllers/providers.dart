import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/db/database.dart';
import '../data/repositories/repositories.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../theme/app_colors.dart';

part 'providers.g.dart';

// ---------------------------------------------------------------------------
// Database
// ---------------------------------------------------------------------------

/// The app's single [LoopDatabase]. Overridden in tests with an in-memory
/// `LoopDatabase.forTesting(NativeDatabase.memory())`. Closed on dispose.
@Riverpod(keepAlive: true)
LoopDatabase loopDatabase(Ref ref) {
  final db = LoopDatabase();
  ref.onDispose(db.close);
  return db;
}

// ---------------------------------------------------------------------------
// shared_preferences (injected at app start)
// ---------------------------------------------------------------------------

/// The loaded [SharedPreferences] instance. MUST be overridden in `main()`
/// (and in tests) with the awaited instance — it is async to obtain, so the
/// base provider throws to surface a missing override early.
@Riverpod(keepAlive: true)
SharedPreferences sharedPreferences(Ref ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden with the awaited instance',
  );
}

// ---------------------------------------------------------------------------
// Repositories
// ---------------------------------------------------------------------------

@Riverpod(keepAlive: true)
EntryRepository entryRepository(Ref ref) =>
    EntryRepository(ref.watch(loopDatabaseProvider));

@Riverpod(keepAlive: true)
GoalsRepository goalsRepository(Ref ref) =>
    GoalsRepository(ref.watch(loopDatabaseProvider));

@Riverpod(keepAlive: true)
RitualRepository ritualRepository(Ref ref) =>
    RitualRepository(ref.watch(loopDatabaseProvider));

@Riverpod(keepAlive: true)
RoutineRepository routineRepository(Ref ref) =>
    RoutineRepository(ref.watch(loopDatabaseProvider));

@Riverpod(keepAlive: true)
WorkoutRepository workoutRepository(Ref ref) =>
    WorkoutRepository(ref.watch(loopDatabaseProvider));

/// The exercise catalog (name-ascending), streamed from [RoutineRepository].
/// Powers the Exercise Library (U11); U12/U13 reuse the same source.
@riverpod
Stream<List<Exercise>> exercises(Ref ref) =>
    ref.watch(routineRepositoryProvider).watchExercises();

@Riverpod(keepAlive: true)
SettingsRepository settingsRepository(Ref ref) =>
    SettingsRepository(ref.watch(sharedPreferencesProvider));

// ---------------------------------------------------------------------------
// Services (default to mocks/no-ops; real impls swap in via override later)
// ---------------------------------------------------------------------------

@Riverpod(keepAlive: true)
PalService palService(Ref ref) => MockPalService();

@Riverpod(keepAlive: true)
HealthService healthService(Ref ref) => MockHealthService();

@Riverpod(keepAlive: true)
EmailSyncService emailSyncService(Ref ref) {
  final service = MockEmailSyncService();
  ref.onDispose(service.dispose);
  return service;
}

@Riverpod(keepAlive: true)
NotificationService notificationService(Ref ref) =>
    const NoopNotificationService();

@Riverpod(keepAlive: true)
HapticsService hapticsService(Ref ref) => const PlatformHapticsService();

// ---------------------------------------------------------------------------
// Theme settings (brightness + accent), persisted via SettingsRepository.
// Replaces the setState-driven state that lived in _LoopAppState.
// ---------------------------------------------------------------------------

/// Immutable view of the user's theme preferences.
@immutable
class AppSettings {
  const AppSettings({required this.brightness, required this.accent});

  final Brightness brightness;
  final AppAccent accent;

  AppSettings copyWith({Brightness? brightness, AppAccent? accent}) =>
      AppSettings(
        brightness: brightness ?? this.brightness,
        accent: accent ?? this.accent,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettings &&
          other.brightness == brightness &&
          other.accent == accent;

  @override
  int get hashCode => Object.hash(brightness, accent);
}

/// Holds and persists the theme (brightness + accent). Reads initial values
/// from [SettingsRepository]; every setter writes back so the selection
/// survives a restart.
@Riverpod(keepAlive: true)
class AppSettingsController extends _$AppSettingsController {
  @override
  AppSettings build() {
    final repo = ref.watch(settingsRepositoryProvider);
    return AppSettings(brightness: repo.brightness, accent: repo.accent);
  }

  Future<void> setBrightness(Brightness brightness) async {
    await ref.read(settingsRepositoryProvider).setBrightness(brightness);
    state = state.copyWith(brightness: brightness);
  }

  Future<void> setAccent(AppAccent accent) async {
    await ref.read(settingsRepositoryProvider).setAccent(accent);
    state = state.copyWith(accent: accent);
  }
}
