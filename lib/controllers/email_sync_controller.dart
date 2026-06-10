import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

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
    final ok =
        await ref.read(emailSyncServiceProvider).testConnection(account, appPassword);
    state = state.copyWith(test: ok ? TestState.success : TestState.error);
  }

  /// Persists the account (only meaningful after a successful test). Returns the
  /// connected account so the caller can navigate to the dashboard.
  Future<void> save(EmailAccount account, String appPassword) async {
    await ref.read(emailSyncServiceProvider).connect(account, appPassword);
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
  });

  final EmailAccount? account;
  final List<EmailImportItem> imports;
  final DateTime? lastSyncAt;

  bool get isConnected => account != null;

  EmailDashboardState copyWith({
    EmailAccount? account,
    List<EmailImportItem>? imports,
    DateTime? lastSyncAt,
  }) =>
      EmailDashboardState(
        account: account ?? this.account,
        imports: imports ?? this.imports,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
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
    return EmailDashboardState(
      account: service.account,
      lastSyncAt: service.account?.lastSyncedAt,
    );
  }

  /// Runs a sync; the staged [SyncStatus] is emitted via the service's stream
  /// (read through [syncStatusProvider]). On completion, the returned imports
  /// replace the list and the last-sync time advances.
  Future<void> syncNow() async {
    final items = await ref.read(emailSyncServiceProvider).syncNow();
    final service = ref.read(emailSyncServiceProvider);
    state = state.copyWith(
      imports: items,
      account: service.account,
      lastSyncAt: DateTime.now(),
    );
    await ref.read(hapticsServiceProvider).success(); // sync complete
  }

  /// Removes the account (service emits [SyncStatus.idle]) and clears state.
  Future<void> disconnect() async {
    await ref.read(emailSyncServiceProvider).disconnect();
    state = const EmailDashboardState();
  }
}
