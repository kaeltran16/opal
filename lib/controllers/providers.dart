import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

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
PalNoteRepository palNoteRepository(Ref ref) =>
    PalNoteRepository(ref.watch(loopDatabaseProvider));

@Riverpod(keepAlive: true)
RoutineRepository routineRepository(Ref ref) =>
    RoutineRepository(ref.watch(loopDatabaseProvider));

@Riverpod(keepAlive: true)
WorkoutRepository workoutRepository(Ref ref) =>
    WorkoutRepository(ref.watch(loopDatabaseProvider));

@Riverpod(keepAlive: true)
WeeklyPlanRepository weeklyPlanRepository(Ref ref) =>
    WeeklyPlanRepository(ref.watch(loopDatabaseProvider));

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

/// Compile-time backend config. `--dart-define=PAL_BASE_URL=...` swaps in the
/// real proxy; unset (tests, backend-less preview) keeps the mock.
const _palBaseUrl = String.fromEnvironment('PAL_BASE_URL');
const _palProvisioningKey = String.fromEnvironment('PAL_PROVISIONING_KEY');

// Single shared http client + device-token store for the real Pal proxy. Kept
// module-level (not providers) since they hold no Riverpod state and the gate
// below is the only consumer.
class _HttpClientHolder {
  static final http.Client instance = http.Client();
}

DeviceTokenStore? _deviceTokensCache;
DeviceTokenStore _deviceTokens(http.Client client) {
  return _deviceTokensCache ??= DeviceTokenStore(
    secure: const FlutterTokenSecureStore(),
    deviceId: const Uuid().v4(),
    register: (deviceId) async {
      final res = await client.post(
        Uri.parse('$_palBaseUrl/v1/register'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'provisioningKey': _palProvisioningKey, 'deviceId': deviceId}),
      );
      if (res.statusCode != 200) {
        throw PalException('register failed (${res.statusCode})');
      }
      return (jsonDecode(res.body) as Map<String, dynamic>)['token'] as String;
    },
  );
}

@Riverpod(keepAlive: true)
PalService palService(Ref ref) {
  if (_palBaseUrl.isEmpty) return MockPalService();

  final httpClient = _HttpClientHolder.instance;
  final entries = ref.watch(entryRepositoryProvider);
  final goals = ref.watch(goalsRepositoryProvider);
  final workouts = ref.watch(workoutRepositoryProvider);
  final routines = ref.watch(routineRepositoryProvider);

  final tokens = TokenProvider(
    token: () => _deviceTokens(httpClient).token(),
    clear: () => _deviceTokens(httpClient).clear(),
  );

  final context = PalContextSource(
    chat: () async {
      final now = DateTime.now();
      final today = await entries.watchToday(now).first;
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final week = await entries
          .watchEntriesInRange(
            DateTime(weekStart.year, weekStart.month, weekStart.day),
            DateTime(now.year, now.month, now.day).add(const Duration(days: 1)),
          )
          .first;
      return buildChatContext(
        userName: 'there',
        goals: await goals.get(),
        todayEntries: today,
        weekEntries: week,
        moveStreakDays: 0, // streak source wired in U18 reuse; 0 until then
      );
    },
    review: (month) async {
      final start = DateTime(month.year, month.month);
      final end = DateTime(month.year, month.month + 1);
      final monthEntries = await entries.watchEntriesInRange(start, end).first;
      var spent = 0.0;
      var movedMin = 0;
      var kept = 0;
      String topCat = '—';
      final byCat = <String, double>{};
      for (final e in monthEntries) {
        switch (e.type) {
          case EntryType.money:
            if ((e.amount ?? 0) < 0) {
              spent += e.amount!.abs();
              final c = e.category ?? 'Other';
              byCat[c] = (byCat[c] ?? 0) + e.amount!.abs();
            }
          case EntryType.move:
            movedMin += e.duration ?? 0;
          case EntryType.rituals:
            kept += 1;
        }
      }
      var topVal = 0.0;
      byCat.forEach((k, v) {
        if (v > topVal) {
          topVal = v;
          topCat = k;
        }
      });
      final topPct = spent == 0 ? 0 : ((topVal / spent) * 100).round();
      final g = await goals.get();
      return buildReviewContext(
        spent: spent,
        spentDeltaPct: 0,
        hoursMoved: (movedMin / 60).round(),
        movedDeltaPct: 0,
        activeDays: monthEntries.map((e) => e.timestamp.day).toSet().length,
        ritualsKept: kept,
        ritualsTarget: g.dailyRitualTarget * 30,
        streakDays: 0,
        topCategory: topCat,
        topCategoryPct: topPct,
        discoveredPattern: 'steady tracking this month',
      );
    },
    suggest: (another) async {
      final recent = await workouts.watchWorkouts().first;
      final all = await routines.getAll();
      const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      return buildSuggestContext(
        recentWorkouts: recent.take(5).toList(),
        dayOfWeek: days[DateTime.now().weekday - 1],
        availableRoutines: all,
      );
    },
    postWorkout: (workout) async {
      final priors = (await workouts.watchWorkouts().first)
          .where((w) => w.routineId == workout.routineId && w.id != workout.id)
          .toList();
      double? lastVol;
      int? daysAgo;
      if (priors.isNotEmpty) {
        priors.sort((a, b) => b.startedAt.compareTo(a.startedAt));
        lastVol = priors.first.totalVolumeKg;
        daysAgo = DateTime.now().difference(priors.first.startedAt).inDays;
      }
      return buildPostWorkoutContext(
        workout: workout,
        lastSessionVolumeKg: lastVol,
        daysAgoLastSession: daysAgo,
      );
    },
    resolveRoutineTitle: (id) async => (await routines.getById(id))?.name,
  );

  return HttpPalService(
    baseUrl: _palBaseUrl,
    httpClient: httpClient,
    tokens: tokens,
    context: context,
    timeout: kIsWeb ? const Duration(seconds: 8) : const Duration(seconds: 30),
  );
}

/// Real IMAP-backed sync (U24) when `PAL_BASE_URL` is set; [MockEmailSyncService]
/// otherwise (tests, backend-less preview). Shares the proxy's http client +
/// device-token store with [palService].
@Riverpod(keepAlive: true)
EmailSyncService emailSyncService(Ref ref) {
  if (_palBaseUrl.isEmpty) {
    final service = MockEmailSyncService();
    ref.onDispose(service.dispose);
    return service;
  }

  final httpClient = _HttpClientHolder.instance;
  final tokens = TokenProvider(
    token: () => _deviceTokens(httpClient).token(),
    clear: () => _deviceTokens(httpClient).clear(),
  );
  final service = RealEmailSyncService(
    baseUrl: _palBaseUrl,
    httpClient: httpClient,
    tokens: tokens,
    secure: const FlutterTokenSecureStore(),
    prefs: ref.watch(sharedPreferencesProvider),
  );
  ref.onDispose(service.dispose);
  return service;
}

/// Real `flutter_local_notifications` on iOS (U27); no-op elsewhere. Requires
/// the timezone DB to be initialized in `main()` before any [schedule] call.
@Riverpod(keepAlive: true)
NotificationService notificationService(Ref ref) {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    return LocalNotificationService();
  }
  return const NoopNotificationService();
}

@Riverpod(keepAlive: true)
HapticsService hapticsService(Ref ref) => const PlatformHapticsService();

/// Live Activity / Dynamic Island for the active workout (U25). The real impl
/// talks to the native `opal/live_activity` MethodChannel; until the OpalWidgets
/// extension + AppDelegate bridge are added in Xcode (see
/// `docs/ios-native-setup.md`) the channel is absent and every call no-ops
/// gracefully. No-op on web/tests/desktop.
@Riverpod(keepAlive: true)
LiveActivityService liveActivityService(Ref ref) {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    return const MethodChannelLiveActivityService();
  }
  return const NoopLiveActivityService();
}

/// Pushes today's progress to the iOS home-screen rings widget over the native
/// `opal/widget_sync` MethodChannel; no-op off iOS. Driven by
/// [WidgetSyncController]. Until the OpalWidgets extension + AppDelegate bridge
/// are wired in Xcode the channel is absent and every call no-ops gracefully.
@Riverpod(keepAlive: true)
WidgetSyncService widgetSyncService(Ref ref) {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    return const MethodChannelWidgetSyncService();
  }
  return const NoopWidgetSyncService();
}

/// Siri Shortcuts / AppIntents donation + deep-link stream (U26). The real impl
/// talks to the native `opal/intents` MethodChannel, registered once the Intents
/// Swift files are added to the Runner target in Xcode; no-op elsewhere.
@Riverpod(keepAlive: true)
SiriShortcutsService siriShortcutsService(Ref ref) {
  final service = createSiriShortcutsService();
  ref.onDispose(service.dispose);
  return service;
}

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
