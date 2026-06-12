import 'dart:async';

import '../../models/models.dart';
import 'email_sync_service.dart';

/// In-memory [EmailSyncService] for Windows preview + tests.
///
/// Emits the staged [SyncStatus] sequence (scanning → filtering →
/// categorizing → upToDate) on [syncNow] so the U20 dashboard animation has a
/// real stream to drive off, and returns canned import items. Credentials are
/// kept in memory (no secure storage on web). The real IMAP worker (U24)
/// emits the same stream.
class MockEmailSyncService implements EmailSyncService {
  MockEmailSyncService({
    this.stageDelay = const Duration(milliseconds: 700),
  });

  /// Delay between staged status emissions.
  final Duration stageDelay;

  final _controller = StreamController<SyncStatus>.broadcast();
  EmailAccount? _account;

  @override
  Stream<SyncStatus> get status => _controller.stream;

  @override
  bool get isConnected => _account != null;

  @override
  EmailAccount? get account => _account;

  @override
  Future<bool> testConnection(EmailAccount account, String appPassword) async {
    await Future<void>.delayed(stageDelay);
    // Mock: any 16-char-ish password "succeeds".
    return appPassword.replaceAll(' ', '').length >= 8;
  }

  @override
  Future<void> connect(EmailAccount account, String appPassword) async {
    // the service owns the keychain reference; the screen no longer hardcodes it
    _account = account.copyWith(
      appPasswordRef: 'mock-keychain-ref',
      lastSyncedAt: DateTime.now(),
    );
  }

  @override
  Future<List<EmailImportItem>> syncNow() async {
    _controller.add(SyncStatus.scanning);
    await Future<void>.delayed(stageDelay);
    _controller.add(SyncStatus.filtering);
    await Future<void>.delayed(stageDelay);
    _controller.add(SyncStatus.categorizing);
    await Future<void>.delayed(stageDelay);

    final now = DateTime.now();
    final items = <EmailImportItem>[
      EmailImportItem(
        id: 'mock-email-1',
        merchant: 'Amazon',
        amount: -42.99,
        receivedAt: now.subtract(const Duration(hours: 2)),
        category: 'Shopping',
      ),
      EmailImportItem(
        id: 'mock-email-2',
        merchant: 'Uber',
        amount: -18.40,
        receivedAt: now.subtract(const Duration(hours: 5)),
        category: 'Transport',
      ),
    ];

    _account = _account?.copyWith(lastSyncedAt: now);
    _controller.add(SyncStatus.upToDate);
    return items;
  }

  @override
  Future<void> disconnect() async {
    _account = null;
    _controller.add(SyncStatus.idle);
  }

  /// Releases the status stream. Call when the owning provider disposes.
  @override
  void dispose() {
    _controller.close();
  }
}
