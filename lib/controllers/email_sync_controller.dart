import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/repositories/settings_repository.dart';
import '../models/models.dart';
import '../services/services.dart';
import 'providers.dart';

part 'email_sync_controller.g.dart';

/// Result of a Test-connection attempt on the Setup screen. Drives the
/// idle/testing/success/error states of the test button.
enum TestState { idle, testing, success, error }

/// Streams the live [SyncStatus] from the email service. The dashboard's status
/// line + progress bar read this so the staged sequence (scanning → filtering →
/// categorizing → upToDate) is driven entirely by the service, not the UI.
///
/// Seeds [SyncStatus.idle] before the service's first emission so the stream is
/// never empty (the mock only emits on [EmailSyncService.syncNow]/disconnect).
@riverpod
Stream<SyncStatus> syncStatus(Ref ref) async* {
  final service = ref.watch(emailSyncServiceProvider);
  yield SyncStatus.idle;
  yield* service.status;
}

/// The Setup form's view model: the connection test lifecycle. The screen owns
/// the text controllers; this owns the async test + whether Save is unlocked
/// (Save is gated on a successful test, per the spec).
@immutable
class EmailSetupState {
  const EmailSetupState({this.test = TestState.idle});

  final TestState test;

  /// Save is only allowed once a test has succeeded.
  bool get canSave => test == TestState.success;

  EmailSetupState copyWith({TestState? test}) =>
      EmailSetupState(test: test ?? this.test);
}

/// Drives the Setup screen's Test-connection + Save. Delegates to
/// [EmailSyncService]; holds no credentials itself (the screen passes them in).
@riverpod
class EmailSetupController extends _$EmailSetupController {
  @override
  EmailSetupState build() => const EmailSetupState();

  /// Runs [EmailSyncService.testConnection]; flips to success/error so the
  /// button can show its state and Save can unlock.
  Future<void> testConnection(EmailAccount account, String appPassword) async {
    if (state.test == TestState.testing) return;
    state = state.copyWith(test: TestState.testing);
    try {
      final ok = await ref
          .read(emailSyncServiceProvider)
          .testConnection(account, appPassword);
      state = state.copyWith(test: ok ? TestState.success : TestState.error);
    } catch (_) {
      // any failure (network, secure storage) lands on the error state so the
      // button doesn't stick on "testing" forever
      state = state.copyWith(test: TestState.error);
    }
  }

  /// Persists the account (only meaningful after a successful test). Returns the
  /// connected account so the caller can navigate to the dashboard.
  Future<void> save(EmailAccount account, String appPassword) async {
    await ref.read(emailSyncServiceProvider).connect(account, appPassword);
    // the singleton service's identity doesn't change on connect, so mounted
    // watchers won't re-read the now-connected account on their own. mirror
    // disconnect (which replaces dashboard state) by forcing a rebuild.
    ref.invalidate(emailDashboardControllerProvider);
  }

  /// Re-edits invalidate a prior pass; reset so Save re-locks until re-tested.
  void markDirty() {
    if (state.test != TestState.idle) {
      state = const EmailSetupState();
    }
  }
}

/// The Dashboard's view model: the connected account + the imports surfaced by
/// the last sync, plus a [isSyncing] flag derived from the status stream. The
/// recent-imports NEW-badge fade is timed by the screen; this just supplies the
/// items and the connection identity.
@immutable
class EmailDashboardState {
  const EmailDashboardState({
    this.account,
    this.imports = const [],
    this.lastSyncAt,
    this.importsThisMonth = 0,
    this.importsAllTime = 0,
    this.syncCadence = SyncCadence.every15min,
    this.importNotifications = false,
    this.autoCategorize = true,
  });

  final EmailAccount? account;
  final List<EmailImportItem> imports;
  final DateTime? lastSyncAt;

  /// Count of email-sourced entries received in the current calendar month.
  final int importsThisMonth;

  /// Count of all email-sourced entries ever imported.
  final int importsAllTime;

  // Persisted sync preferences (mirrored from [SettingsRepository]).
  final SyncCadence syncCadence;
  final bool importNotifications;
  final bool autoCategorize;

  bool get isConnected => account != null;

  EmailDashboardState copyWith({
    EmailAccount? account,
    List<EmailImportItem>? imports,
    DateTime? lastSyncAt,
    int? importsThisMonth,
    int? importsAllTime,
    SyncCadence? syncCadence,
    bool? importNotifications,
    bool? autoCategorize,
  }) =>
      EmailDashboardState(
        // null-coalescing means copyWith can't clear account back to null;
        // disconnect must replace state wholesale (see disconnect()).
        account: account ?? this.account,
        imports: imports ?? this.imports,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        importsThisMonth: importsThisMonth ?? this.importsThisMonth,
        importsAllTime: importsAllTime ?? this.importsAllTime,
        syncCadence: syncCadence ?? this.syncCadence,
        importNotifications: importNotifications ?? this.importNotifications,
        autoCategorize: autoCategorize ?? this.autoCategorize,
      );
}

/// Owns the Dashboard: reads the connected account, runs Sync-now (which the
/// service stages over [syncStatusProvider]) and surfaces the returned imports,
/// and disconnects. All timing lives in the service.
@riverpod
class EmailDashboardController extends _$EmailDashboardController {
  @override
  EmailDashboardState build() {
    final service = ref.watch(emailSyncServiceProvider);
    final settings = ref.watch(settingsRepositoryProvider);
    // Prefs are synchronous (SharedPreferences); counts need a DB query, so we
    // seed zero and refresh them asynchronously below.
    unawaited(_refreshCounts());
    return EmailDashboardState(
      account: service.account,
      lastSyncAt: service.account?.lastSyncedAt,
      syncCadence: settings.syncCadence,
      importNotifications: settings.importNotifications,
      autoCategorize: settings.autoCategorize,
    );
  }

  /// Recomputes import-count stats from email-sourced [Entry]s: "all time" is
  /// every email entry; "this month" is those received in the current calendar
  /// month. There is no subscription/recurring model anymore, so no recurring
  /// count is derived here.
  Future<void> _refreshCounts() async {
    final entries = await ref.read(entryRepositoryProvider).getAll();
    // build() kicks this off unawaited; the dashboard may be disposed (user
    // navigates away) before the query returns, so don't touch state if so.
    if (!ref.mounted) return;
    final emailEntries =
        entries.where((e) => e.source == EntrySource.email).toList();
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);
    final thisMonth = emailEntries
        .where((e) => !e.timestamp.isBefore(monthStart))
        .length;
    state = state.copyWith(
      importsAllTime: emailEntries.length,
      importsThisMonth: thisMonth,
    );
  }

  Future<void> setSyncCadence(SyncCadence cadence) async {
    await ref.read(settingsRepositoryProvider).setSyncCadence(cadence);
    state = state.copyWith(syncCadence: cadence);
  }

  Future<void> setImportNotifications(bool enabled) async {
    await ref.read(settingsRepositoryProvider).setImportNotifications(enabled);
    state = state.copyWith(importNotifications: enabled);
  }

  Future<void> setAutoCategorize(bool enabled) async {
    await ref.read(settingsRepositoryProvider).setAutoCategorize(enabled);
    state = state.copyWith(autoCategorize: enabled);
  }

  /// Updates the connected account's sender allowlist. Persisted on the account
  /// by the service and re-sent on the next [syncNow] — no reconnect needed.
  Future<void> setSenderFilters(List<String> filters) async {
    final service = ref.read(emailSyncServiceProvider);
    await service.updateSenderFilters(filters);
    state = state.copyWith(account: service.account);
  }

  /// Runs a sync; the staged [SyncStatus] is emitted via the service's stream
  /// (read through [syncStatusProvider]). On completion the returned imports are
  /// materialised as timeline [Entry]s (deduped by `sourceRef` so re-syncs don't
  /// double-import), the imports list updates, and the last-sync time advances.
  Future<void> syncNow() async {
    try {
      final items = await ref.read(emailSyncServiceProvider).syncNow();
      await _persistImports(items);
      final service = ref.read(emailSyncServiceProvider);
      state = state.copyWith(
        imports: items,
        account: service.account,
        lastSyncAt: DateTime.now(),
      );
      await _refreshCounts();
      await ref.read(hapticsServiceProvider).success(); // sync complete
    } catch (_) {
      // the service already emits SyncStatus.error (surfaced via the status
      // stream); swallow so the future doesn't reject unhandled in the UI
    }
  }

  /// Writes each import as a money [Entry] (`source: email`), skipping any whose
  /// message-id was already imported. This is the "push structured entries back"
  /// step — without it, synced receipts never reach Today/Spending.
  Future<void> _persistImports(List<EmailImportItem> items) async {
    final entries = ref.read(entryRepositoryProvider);
    for (final item in items) {
      if (await entries.existsBySourceRef(item.id)) continue;
      await entries.insert(item.toEntry());
    }
  }

  /// Removes the account (service emits [SyncStatus.idle]) and clears state.
  Future<void> disconnect() async {
    await ref.read(emailSyncServiceProvider).disconnect();
    state = const EmailDashboardState();
  }
}
