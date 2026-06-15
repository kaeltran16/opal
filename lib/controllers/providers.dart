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
import '../util/dates.dart';
import '../util/format.dart' show Currency;

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

// Live collection streams watched by view-model providers so an edit to a
// *secondary* table re-emits even when the provider's primary `await for`
// stream is unchanged (e.g. editing a ritual routine refreshes Today, which is
// otherwise driven by the entries stream). Mirrors [goalsStream].

/// Live ritual routines (Today / Rituals).
@riverpod
Stream<List<RitualRoutine>> ritualRoutinesStream(Ref ref) =>
    ref.watch(ritualRepositoryProvider).watchRoutines();

/// Live workout routines (Move / Weekly plan).
@riverpod
Stream<List<Routine>> workoutRoutinesStream(Ref ref) =>
    ref.watch(routineRepositoryProvider).watchRoutines();

/// Live workout history, most-recent first (Move / Weekly plan).
@riverpod
Stream<List<Workout>> workoutsStream(Ref ref) =>
    ref.watch(workoutRepositoryProvider).watchWorkouts();

/// All entries, any type (Move's non-workout move entries + kcal).
@riverpod
Stream<List<Entry>> allEntriesStream(Ref ref) =>
    ref.watch(entryRepositoryProvider).watchAll();

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
  if (_palBaseUrl.isEmpty) {
    return MockPalService(
        currency: () => ref.read(appSettingsControllerProvider).currency);
  }

  final httpClient = _HttpClientHolder.instance;
  final entries = ref.watch(entryRepositoryProvider);
  final goals = ref.watch(goalsRepositoryProvider);
  final workouts = ref.watch(workoutRepositoryProvider);
  final routines = ref.watch(routineRepositoryProvider);
  final ritualRoutines = ref.watch(ritualRepositoryProvider);
  final settings = ref.watch(settingsRepositoryProvider);

  final tokens = TokenProvider(
    token: () => _deviceTokens(httpClient).token(),
    clear: () => _deviceTokens(httpClient).clear(),
  );

  // current move streak from a 60-day lookback (longer than any window) — the
  // streak helper needs history before the window to count back correctly.
  Future<int> moveStreak(DateTime now) async {
    final today = DateTime(now.year, now.month, now.day);
    final lookback = await entries.getEntriesInRange(
      today.subtract(const Duration(days: 60)),
      today.add(const Duration(days: 1)),
    );
    return moveStreakDays(lookback, now: now);
  }

  final context = PalContextSource(
    chat: () async {
      final now = DateTime.now();
      final today = await entries.watchToday(now).first;
      final week = await entries
          .watchEntriesInRange(
            startOfWeek(now),
            startOfDay(now).add(const Duration(days: 1)),
          )
          .first;
      return buildChatContext(
        userName: settings.displayName,
        goals: await goals.get(),
        todayEntries: today,
        weekEntries: week,
        moveStreakDays: await moveStreak(now),
        routineCount: (await ritualRoutines.getAll()).length,
      );
    },
    review: (anchor, range) async {
      final now = DateTime.now();
      final (DateTime start, DateTime end, DateTime prevStart, int periodDays) =
          switch (range) {
        ReviewRange.week => (
            anchor,
            anchor.add(const Duration(days: 7)),
            anchor.subtract(const Duration(days: 7)),
            7,
          ),
        ReviewRange.month => (
            DateTime(anchor.year, anchor.month),
            DateTime(anchor.year, anchor.month + 1),
            DateTime(anchor.year, anchor.month - 1),
            DateTime(anchor.year, anchor.month + 1, 0).day,
          ),
      };
      final periodEntries = await entries.watchEntriesInRange(start, end).first;
      final prevEntries = await entries.getEntriesInRange(prevStart, start);

      var spent = 0.0;
      var movedKcal = 0;
      var kept = 0;
      String topCat = '—';
      final byCat = <String, double>{};
      for (final e in periodEntries) {
        switch (e.type) {
          case EntryType.money:
            if ((e.amount ?? 0) < 0) {
              spent += e.amount!.abs();
              final c = e.category ?? 'Other';
              byCat[c] = (byCat[c] ?? 0) + e.amount!.abs();
            }
          case EntryType.move:
            movedKcal += e.calories ?? 0;
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

      // deltas vs the previous period; null when there's nothing to compare to.
      var prevSpent = 0.0;
      var prevMovedKcal = 0;
      for (final e in prevEntries) {
        if (e.type == EntryType.money && (e.amount ?? 0) < 0) {
          prevSpent += e.amount!.abs();
        } else if (e.type == EntryType.move) {
          prevMovedKcal += e.calories ?? 0;
        }
      }
      int? pctChange(num current, num prev) =>
          prev == 0 ? null : (((current - prev) / prev) * 100).round();
      final hasPrev = prevEntries.isNotEmpty;

      final g = await goals.get();
      final routineCount = (await ritualRoutines.getAll()).length;
      return buildReviewContext(
        range: range,
        spent: spent,
        spentDeltaPct: hasPrev ? pctChange(spent, prevSpent) : null,
        kcalMoved: movedKcal,
        movedDeltaPct: hasPrev ? pctChange(movedKcal, prevMovedKcal) : null,
        activeDays: periodEntries.map((e) => e.timestamp.day).toSet().length,
        ritualsKept: kept,
        ritualsTarget: effectiveDailyRitualTarget(routineCount, g) * periodDays,
        streakDays: await moveStreak(now),
        topCategory: topCat,
        topCategoryPct: topPct,
      );
    },
    insights: (range) async {
      final now = DateTime.now();
      final today = startOfDay(now);
      final weekStart = startOfWeek(now);
      final (DateTime start, DateTime end, int periodDays) = switch (range) {
        InsightRange.day => (today, today.add(const Duration(days: 1)), 1),
        InsightRange.week => (weekStart, weekStart.add(const Duration(days: 7)), 7),
        InsightRange.month => (
            DateTime(now.year, now.month),
            DateTime(now.year, now.month + 1),
            DateTime(now.year, now.month + 1, 0).day,
          ),
      };
      final windowEntries = await entries.watchEntriesInRange(start, end).first;
      // streak needs a longer lookback than the window itself
      final lookback = await entries.getEntriesInRange(
        today.subtract(const Duration(days: 60)),
        today.add(const Duration(days: 1)),
      );
      return buildInsightsContext(
        range: range,
        entries: windowEntries,
        goals: await goals.get(),
        periodDays: periodDays,
        streakDays: moveStreakDays(lookback, now: now),
        routineCount: (await ritualRoutines.getAll()).length,
      );
    },
    suggest: (another, excludeRoutineId) async {
      final recent = await workouts.watchWorkouts().first;
      final all = await routines.getAll();
      final catalog = await routines.getAllExercises();
      // drop the rejected routine client-side (the model can only pick from this
      // list), unless that would empty it — then keep all so a single-routine
      // user still gets a pick.
      final candidates = excludeRoutineId == null
          ? all
          : all.where((r) => r.id != excludeRoutineId).toList();
      return buildSuggestContext(
        recentWorkouts: recent.take(5).toList(),
        dayOfWeek: kWeekdays[DateTime.now().weekday - 1],
        availableRoutines: candidates.isEmpty ? all : candidates,
        exercisesById: {for (final e in catalog) e.id: e},
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
    // period-stable replies (insights, review) are cached client-side, keyed by
    // their request context, so a closed week/month doesn't re-bill an LLM call.
    cache: PrefsPalCache(ref.watch(sharedPreferencesProvider)),
    timeout: const Duration(seconds: 30),
  );
}

/// Real [HttpHealthService] when `PAL_BASE_URL` is set; [MockHealthService]
/// otherwise (tests, backend-less preview). Shares the proxy's http client +
/// device-token store with [palService]. Drives [HealthSyncController].
@Riverpod(keepAlive: true)
HealthService healthService(Ref ref) {
  if (_palBaseUrl.isEmpty) return const MockHealthService();

  final httpClient = _HttpClientHolder.instance;
  final tokens = TokenProvider(
    token: () => _deviceTokens(httpClient).token(),
    clear: () => _deviceTokens(httpClient).clear(),
  );
  return HttpHealthService(
    baseUrl: _palBaseUrl,
    httpClient: httpClient,
    tokens: tokens,
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

/// Pushes today's progress to the iOS home-screen rings widget. The app POSTs
/// the snapshot to the proxy (`/v1/widget/snapshot`) and the widget fetches it
/// over HTTP — App-Group sharing isn't available on a free Apple team. No-op off
/// iOS or when `PAL_BASE_URL` is unset. Driven by [WidgetSyncController].
@Riverpod(keepAlive: true)
WidgetSyncService widgetSyncService(Ref ref) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS || _palBaseUrl.isEmpty) {
    return const NoopWidgetSyncService();
  }
  final httpClient = _HttpClientHolder.instance;
  final tokens = TokenProvider(
    token: () => _deviceTokens(httpClient).token(),
    clear: () => _deviceTokens(httpClient).clear(),
  );
  return HttpWidgetSyncService(
    baseUrl: _palBaseUrl,
    httpClient: httpClient,
    tokens: tokens,
  );
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
  const AppSettings({
    required this.brightness,
    required this.accent,
    required this.currency,
  });

  final Brightness brightness;
  final AppAccent accent;
  final Currency currency;

  AppSettings copyWith({
    Brightness? brightness,
    AppAccent? accent,
    Currency? currency,
  }) =>
      AppSettings(
        brightness: brightness ?? this.brightness,
        accent: accent ?? this.accent,
        currency: currency ?? this.currency,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettings &&
          other.brightness == brightness &&
          other.accent == accent &&
          other.currency == currency;

  @override
  int get hashCode => Object.hash(brightness, accent, currency);
}

/// Holds and persists the theme (brightness + accent). Reads initial values
/// from [SettingsRepository]; every setter writes back so the selection
/// survives a restart.
@Riverpod(keepAlive: true)
class AppSettingsController extends _$AppSettingsController {
  @override
  AppSettings build() {
    final repo = ref.watch(settingsRepositoryProvider);
    return AppSettings(
      brightness: repo.brightness,
      accent: repo.accent,
      currency: repo.currency,
    );
  }

  Future<void> setBrightness(Brightness brightness) async {
    await ref.read(settingsRepositoryProvider).setBrightness(brightness);
    state = state.copyWith(brightness: brightness);
  }

  Future<void> setAccent(AppAccent accent) async {
    await ref.read(settingsRepositoryProvider).setAccent(accent);
    state = state.copyWith(accent: accent);
  }

  Future<void> setCurrency(Currency currency) async {
    await ref.read(settingsRepositoryProvider).setCurrency(currency);
    state = state.copyWith(currency: currency);
  }
}
