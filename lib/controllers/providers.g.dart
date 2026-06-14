// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app's single [LoopDatabase]. Overridden in tests with an in-memory
/// `LoopDatabase.forTesting(NativeDatabase.memory())`. Closed on dispose.

@ProviderFor(loopDatabase)
const loopDatabaseProvider = LoopDatabaseProvider._();

/// The app's single [LoopDatabase]. Overridden in tests with an in-memory
/// `LoopDatabase.forTesting(NativeDatabase.memory())`. Closed on dispose.

final class LoopDatabaseProvider
    extends $FunctionalProvider<LoopDatabase, LoopDatabase, LoopDatabase>
    with $Provider<LoopDatabase> {
  /// The app's single [LoopDatabase]. Overridden in tests with an in-memory
  /// `LoopDatabase.forTesting(NativeDatabase.memory())`. Closed on dispose.
  const LoopDatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'loopDatabaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$loopDatabaseHash();

  @$internal
  @override
  $ProviderElement<LoopDatabase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LoopDatabase create(Ref ref) {
    return loopDatabase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LoopDatabase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LoopDatabase>(value),
    );
  }
}

String _$loopDatabaseHash() => r'066ef642ee12ee3456bfca74a263b337e7280156';

/// The loaded [SharedPreferences] instance. MUST be overridden in `main()`
/// (and in tests) with the awaited instance — it is async to obtain, so the
/// base provider throws to surface a missing override early.

@ProviderFor(sharedPreferences)
const sharedPreferencesProvider = SharedPreferencesProvider._();

/// The loaded [SharedPreferences] instance. MUST be overridden in `main()`
/// (and in tests) with the awaited instance — it is async to obtain, so the
/// base provider throws to surface a missing override early.

final class SharedPreferencesProvider
    extends
        $FunctionalProvider<
          SharedPreferences,
          SharedPreferences,
          SharedPreferences
        >
    with $Provider<SharedPreferences> {
  /// The loaded [SharedPreferences] instance. MUST be overridden in `main()`
  /// (and in tests) with the awaited instance — it is async to obtain, so the
  /// base provider throws to surface a missing override early.
  const SharedPreferencesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sharedPreferencesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sharedPreferencesHash();

  @$internal
  @override
  $ProviderElement<SharedPreferences> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SharedPreferences create(Ref ref) {
    return sharedPreferences(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SharedPreferences value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SharedPreferences>(value),
    );
  }
}

String _$sharedPreferencesHash() => r'f1d9e859e6fd019f71b246bec414c31ab2fd5d25';

@ProviderFor(entryRepository)
const entryRepositoryProvider = EntryRepositoryProvider._();

final class EntryRepositoryProvider
    extends
        $FunctionalProvider<EntryRepository, EntryRepository, EntryRepository>
    with $Provider<EntryRepository> {
  const EntryRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'entryRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$entryRepositoryHash();

  @$internal
  @override
  $ProviderElement<EntryRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  EntryRepository create(Ref ref) {
    return entryRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EntryRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EntryRepository>(value),
    );
  }
}

String _$entryRepositoryHash() => r'35f1a7edc0a3567fa7739914c92341ce40fc38ac';

@ProviderFor(goalsRepository)
const goalsRepositoryProvider = GoalsRepositoryProvider._();

final class GoalsRepositoryProvider
    extends
        $FunctionalProvider<GoalsRepository, GoalsRepository, GoalsRepository>
    with $Provider<GoalsRepository> {
  const GoalsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'goalsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$goalsRepositoryHash();

  @$internal
  @override
  $ProviderElement<GoalsRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GoalsRepository create(Ref ref) {
    return goalsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GoalsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GoalsRepository>(value),
    );
  }
}

String _$goalsRepositoryHash() => r'4d7de92c0d5af97ffd2b1904ba8c4f3bef35ebe4';

@ProviderFor(ritualRepository)
const ritualRepositoryProvider = RitualRepositoryProvider._();

final class RitualRepositoryProvider
    extends
        $FunctionalProvider<
          RitualRepository,
          RitualRepository,
          RitualRepository
        >
    with $Provider<RitualRepository> {
  const RitualRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ritualRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ritualRepositoryHash();

  @$internal
  @override
  $ProviderElement<RitualRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RitualRepository create(Ref ref) {
    return ritualRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RitualRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RitualRepository>(value),
    );
  }
}

String _$ritualRepositoryHash() => r'685506845c2fa6d11959055d9a75617fc88c0c7e';

@ProviderFor(palNoteRepository)
const palNoteRepositoryProvider = PalNoteRepositoryProvider._();

final class PalNoteRepositoryProvider
    extends
        $FunctionalProvider<
          PalNoteRepository,
          PalNoteRepository,
          PalNoteRepository
        >
    with $Provider<PalNoteRepository> {
  const PalNoteRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'palNoteRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$palNoteRepositoryHash();

  @$internal
  @override
  $ProviderElement<PalNoteRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PalNoteRepository create(Ref ref) {
    return palNoteRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PalNoteRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PalNoteRepository>(value),
    );
  }
}

String _$palNoteRepositoryHash() => r'f7c9c696e41eab9b1c9c6f09ade16e3cb7e18478';

@ProviderFor(routineRepository)
const routineRepositoryProvider = RoutineRepositoryProvider._();

final class RoutineRepositoryProvider
    extends
        $FunctionalProvider<
          RoutineRepository,
          RoutineRepository,
          RoutineRepository
        >
    with $Provider<RoutineRepository> {
  const RoutineRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'routineRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$routineRepositoryHash();

  @$internal
  @override
  $ProviderElement<RoutineRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RoutineRepository create(Ref ref) {
    return routineRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RoutineRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RoutineRepository>(value),
    );
  }
}

String _$routineRepositoryHash() => r'01a5ccef9945eab7d79620645f76bcdc65e7c02e';

@ProviderFor(workoutRepository)
const workoutRepositoryProvider = WorkoutRepositoryProvider._();

final class WorkoutRepositoryProvider
    extends
        $FunctionalProvider<
          WorkoutRepository,
          WorkoutRepository,
          WorkoutRepository
        >
    with $Provider<WorkoutRepository> {
  const WorkoutRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workoutRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workoutRepositoryHash();

  @$internal
  @override
  $ProviderElement<WorkoutRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  WorkoutRepository create(Ref ref) {
    return workoutRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WorkoutRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WorkoutRepository>(value),
    );
  }
}

String _$workoutRepositoryHash() => r'c97103f9acf7574b8a484ef162d790c62a8850c9';

@ProviderFor(weeklyPlanRepository)
const weeklyPlanRepositoryProvider = WeeklyPlanRepositoryProvider._();

final class WeeklyPlanRepositoryProvider
    extends
        $FunctionalProvider<
          WeeklyPlanRepository,
          WeeklyPlanRepository,
          WeeklyPlanRepository
        >
    with $Provider<WeeklyPlanRepository> {
  const WeeklyPlanRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'weeklyPlanRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$weeklyPlanRepositoryHash();

  @$internal
  @override
  $ProviderElement<WeeklyPlanRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  WeeklyPlanRepository create(Ref ref) {
    return weeklyPlanRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WeeklyPlanRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WeeklyPlanRepository>(value),
    );
  }
}

String _$weeklyPlanRepositoryHash() =>
    r'c3738b6eac4779275e5171feaf67aa8e78bf391b';

/// The exercise catalog (name-ascending), streamed from [RoutineRepository].
/// Powers the Exercise Library (U11); U12/U13 reuse the same source.

@ProviderFor(exercises)
const exercisesProvider = ExercisesProvider._();

/// The exercise catalog (name-ascending), streamed from [RoutineRepository].
/// Powers the Exercise Library (U11); U12/U13 reuse the same source.

final class ExercisesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Exercise>>,
          List<Exercise>,
          Stream<List<Exercise>>
        >
    with $FutureModifier<List<Exercise>>, $StreamProvider<List<Exercise>> {
  /// The exercise catalog (name-ascending), streamed from [RoutineRepository].
  /// Powers the Exercise Library (U11); U12/U13 reuse the same source.
  const ExercisesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'exercisesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$exercisesHash();

  @$internal
  @override
  $StreamProviderElement<List<Exercise>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Exercise>> create(Ref ref) {
    return exercises(ref);
  }
}

String _$exercisesHash() => r'ee2f8f9130f459ff475ccb109de3daa27b5b38b3';

@ProviderFor(settingsRepository)
const settingsRepositoryProvider = SettingsRepositoryProvider._();

final class SettingsRepositoryProvider
    extends
        $FunctionalProvider<
          SettingsRepository,
          SettingsRepository,
          SettingsRepository
        >
    with $Provider<SettingsRepository> {
  const SettingsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'settingsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$settingsRepositoryHash();

  @$internal
  @override
  $ProviderElement<SettingsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SettingsRepository create(Ref ref) {
    return settingsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SettingsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SettingsRepository>(value),
    );
  }
}

String _$settingsRepositoryHash() =>
    r'cb57457244062d3bd9be73a1a3ee43a55e76dd3d';

@ProviderFor(palService)
const palServiceProvider = PalServiceProvider._();

final class PalServiceProvider
    extends $FunctionalProvider<PalService, PalService, PalService>
    with $Provider<PalService> {
  const PalServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'palServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$palServiceHash();

  @$internal
  @override
  $ProviderElement<PalService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PalService create(Ref ref) {
    return palService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PalService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PalService>(value),
    );
  }
}

String _$palServiceHash() => r'ec8860a15a191ff535fd0eb0e7ac52828ced2fb6';

/// Real [HttpHealthService] when `PAL_BASE_URL` is set; [MockHealthService]
/// otherwise (tests, backend-less preview). Shares the proxy's http client +
/// device-token store with [palService]. Drives [HealthSyncController].

@ProviderFor(healthService)
const healthServiceProvider = HealthServiceProvider._();

/// Real [HttpHealthService] when `PAL_BASE_URL` is set; [MockHealthService]
/// otherwise (tests, backend-less preview). Shares the proxy's http client +
/// device-token store with [palService]. Drives [HealthSyncController].

final class HealthServiceProvider
    extends $FunctionalProvider<HealthService, HealthService, HealthService>
    with $Provider<HealthService> {
  /// Real [HttpHealthService] when `PAL_BASE_URL` is set; [MockHealthService]
  /// otherwise (tests, backend-less preview). Shares the proxy's http client +
  /// device-token store with [palService]. Drives [HealthSyncController].
  const HealthServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'healthServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$healthServiceHash();

  @$internal
  @override
  $ProviderElement<HealthService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  HealthService create(Ref ref) {
    return healthService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HealthService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HealthService>(value),
    );
  }
}

String _$healthServiceHash() => r'06754b758929c0ec6678354ee640ade2d04654e7';

/// Real IMAP-backed sync (U24) when `PAL_BASE_URL` is set; [MockEmailSyncService]
/// otherwise (tests, backend-less preview). Shares the proxy's http client +
/// device-token store with [palService].

@ProviderFor(emailSyncService)
const emailSyncServiceProvider = EmailSyncServiceProvider._();

/// Real IMAP-backed sync (U24) when `PAL_BASE_URL` is set; [MockEmailSyncService]
/// otherwise (tests, backend-less preview). Shares the proxy's http client +
/// device-token store with [palService].

final class EmailSyncServiceProvider
    extends
        $FunctionalProvider<
          EmailSyncService,
          EmailSyncService,
          EmailSyncService
        >
    with $Provider<EmailSyncService> {
  /// Real IMAP-backed sync (U24) when `PAL_BASE_URL` is set; [MockEmailSyncService]
  /// otherwise (tests, backend-less preview). Shares the proxy's http client +
  /// device-token store with [palService].
  const EmailSyncServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'emailSyncServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$emailSyncServiceHash();

  @$internal
  @override
  $ProviderElement<EmailSyncService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  EmailSyncService create(Ref ref) {
    return emailSyncService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EmailSyncService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EmailSyncService>(value),
    );
  }
}

String _$emailSyncServiceHash() => r'e7031bbc411bd2af7fd24f4e49ac479cec7f82df';

/// Real `flutter_local_notifications` on iOS (U27); no-op elsewhere. Requires
/// the timezone DB to be initialized in `main()` before any [schedule] call.

@ProviderFor(notificationService)
const notificationServiceProvider = NotificationServiceProvider._();

/// Real `flutter_local_notifications` on iOS (U27); no-op elsewhere. Requires
/// the timezone DB to be initialized in `main()` before any [schedule] call.

final class NotificationServiceProvider
    extends
        $FunctionalProvider<
          NotificationService,
          NotificationService,
          NotificationService
        >
    with $Provider<NotificationService> {
  /// Real `flutter_local_notifications` on iOS (U27); no-op elsewhere. Requires
  /// the timezone DB to be initialized in `main()` before any [schedule] call.
  const NotificationServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationServiceHash();

  @$internal
  @override
  $ProviderElement<NotificationService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NotificationService create(Ref ref) {
    return notificationService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NotificationService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NotificationService>(value),
    );
  }
}

String _$notificationServiceHash() =>
    r'9598a87c3cf64950f40027e83fcdbd0bdaee3d91';

@ProviderFor(hapticsService)
const hapticsServiceProvider = HapticsServiceProvider._();

final class HapticsServiceProvider
    extends $FunctionalProvider<HapticsService, HapticsService, HapticsService>
    with $Provider<HapticsService> {
  const HapticsServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'hapticsServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$hapticsServiceHash();

  @$internal
  @override
  $ProviderElement<HapticsService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  HapticsService create(Ref ref) {
    return hapticsService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HapticsService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HapticsService>(value),
    );
  }
}

String _$hapticsServiceHash() => r'9804f50173cd1effd98eda0576aa018ccaf3c973';

/// Live Activity / Dynamic Island for the active workout (U25). The real impl
/// talks to the native `opal/live_activity` MethodChannel; until the OpalWidgets
/// extension + AppDelegate bridge are added in Xcode (see
/// `docs/ios-native-setup.md`) the channel is absent and every call no-ops
/// gracefully. No-op on web/tests/desktop.

@ProviderFor(liveActivityService)
const liveActivityServiceProvider = LiveActivityServiceProvider._();

/// Live Activity / Dynamic Island for the active workout (U25). The real impl
/// talks to the native `opal/live_activity` MethodChannel; until the OpalWidgets
/// extension + AppDelegate bridge are added in Xcode (see
/// `docs/ios-native-setup.md`) the channel is absent and every call no-ops
/// gracefully. No-op on web/tests/desktop.

final class LiveActivityServiceProvider
    extends
        $FunctionalProvider<
          LiveActivityService,
          LiveActivityService,
          LiveActivityService
        >
    with $Provider<LiveActivityService> {
  /// Live Activity / Dynamic Island for the active workout (U25). The real impl
  /// talks to the native `opal/live_activity` MethodChannel; until the OpalWidgets
  /// extension + AppDelegate bridge are added in Xcode (see
  /// `docs/ios-native-setup.md`) the channel is absent and every call no-ops
  /// gracefully. No-op on web/tests/desktop.
  const LiveActivityServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'liveActivityServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$liveActivityServiceHash();

  @$internal
  @override
  $ProviderElement<LiveActivityService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  LiveActivityService create(Ref ref) {
    return liveActivityService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LiveActivityService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LiveActivityService>(value),
    );
  }
}

String _$liveActivityServiceHash() =>
    r'da56177b00efd0d4c58d9386832c921d706e55b0';

/// Pushes today's progress to the iOS home-screen rings widget. The app POSTs
/// the snapshot to the proxy (`/v1/widget/snapshot`) and the widget fetches it
/// over HTTP — App-Group sharing isn't available on a free Apple team. No-op off
/// iOS or when `PAL_BASE_URL` is unset. Driven by [WidgetSyncController].

@ProviderFor(widgetSyncService)
const widgetSyncServiceProvider = WidgetSyncServiceProvider._();

/// Pushes today's progress to the iOS home-screen rings widget. The app POSTs
/// the snapshot to the proxy (`/v1/widget/snapshot`) and the widget fetches it
/// over HTTP — App-Group sharing isn't available on a free Apple team. No-op off
/// iOS or when `PAL_BASE_URL` is unset. Driven by [WidgetSyncController].

final class WidgetSyncServiceProvider
    extends
        $FunctionalProvider<
          WidgetSyncService,
          WidgetSyncService,
          WidgetSyncService
        >
    with $Provider<WidgetSyncService> {
  /// Pushes today's progress to the iOS home-screen rings widget. The app POSTs
  /// the snapshot to the proxy (`/v1/widget/snapshot`) and the widget fetches it
  /// over HTTP — App-Group sharing isn't available on a free Apple team. No-op off
  /// iOS or when `PAL_BASE_URL` is unset. Driven by [WidgetSyncController].
  const WidgetSyncServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'widgetSyncServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$widgetSyncServiceHash();

  @$internal
  @override
  $ProviderElement<WidgetSyncService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  WidgetSyncService create(Ref ref) {
    return widgetSyncService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WidgetSyncService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WidgetSyncService>(value),
    );
  }
}

String _$widgetSyncServiceHash() => r'7d166e9bef81801efe8948ec280372fa019d2e5b';

/// Siri Shortcuts / AppIntents donation + deep-link stream (U26). The real impl
/// talks to the native `opal/intents` MethodChannel, registered once the Intents
/// Swift files are added to the Runner target in Xcode; no-op elsewhere.

@ProviderFor(siriShortcutsService)
const siriShortcutsServiceProvider = SiriShortcutsServiceProvider._();

/// Siri Shortcuts / AppIntents donation + deep-link stream (U26). The real impl
/// talks to the native `opal/intents` MethodChannel, registered once the Intents
/// Swift files are added to the Runner target in Xcode; no-op elsewhere.

final class SiriShortcutsServiceProvider
    extends
        $FunctionalProvider<
          SiriShortcutsService,
          SiriShortcutsService,
          SiriShortcutsService
        >
    with $Provider<SiriShortcutsService> {
  /// Siri Shortcuts / AppIntents donation + deep-link stream (U26). The real impl
  /// talks to the native `opal/intents` MethodChannel, registered once the Intents
  /// Swift files are added to the Runner target in Xcode; no-op elsewhere.
  const SiriShortcutsServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'siriShortcutsServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$siriShortcutsServiceHash();

  @$internal
  @override
  $ProviderElement<SiriShortcutsService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SiriShortcutsService create(Ref ref) {
    return siriShortcutsService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SiriShortcutsService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SiriShortcutsService>(value),
    );
  }
}

String _$siriShortcutsServiceHash() =>
    r'b33f6ecb8781e6a3b00582f6ee1c85b4029cd6d5';

/// Holds and persists the theme (brightness + accent). Reads initial values
/// from [SettingsRepository]; every setter writes back so the selection
/// survives a restart.

@ProviderFor(AppSettingsController)
const appSettingsControllerProvider = AppSettingsControllerProvider._();

/// Holds and persists the theme (brightness + accent). Reads initial values
/// from [SettingsRepository]; every setter writes back so the selection
/// survives a restart.
final class AppSettingsControllerProvider
    extends $NotifierProvider<AppSettingsController, AppSettings> {
  /// Holds and persists the theme (brightness + accent). Reads initial values
  /// from [SettingsRepository]; every setter writes back so the selection
  /// survives a restart.
  const AppSettingsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appSettingsControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appSettingsControllerHash();

  @$internal
  @override
  AppSettingsController create() => AppSettingsController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppSettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppSettings>(value),
    );
  }
}

String _$appSettingsControllerHash() =>
    r'99e319ee07b126a29740e64f1240ab9e716af825';

/// Holds and persists the theme (brightness + accent). Reads initial values
/// from [SettingsRepository]; every setter writes back so the selection
/// survives a restart.

abstract class _$AppSettingsController extends $Notifier<AppSettings> {
  AppSettings build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AppSettings, AppSettings>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AppSettings, AppSettings>,
              AppSettings,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
