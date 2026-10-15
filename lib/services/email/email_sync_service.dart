import '../../models/models.dart';

/// The email/IMAP receipt-import seam (screens 16–18, U20).
///
/// Defined in U03 so the Email Sync screens can build entirely against the
/// staged [SyncStatus] stream + fake imports. `NativeEmailSyncService` emits the
/// same stream so the UI choreography is unchanged. [SyncStatus] already exists
/// in `lib/models/enums.dart`.

/// One receipt parsed from an inbox during a sync (becomes an [Entry] on import).
class EmailImportItem {
  const EmailImportItem({
    required this.id,
    required this.merchant,
    required this.amount,
    required this.receivedAt,
    this.category,
    this.orderRef,
    this.isNew = true,
  });

  /// Stable id (email message id in the real impl).
  final String id;
  final String merchant;

  /// Negative = expense.
  final double amount;
  final DateTime receivedAt;
  final String? category;

  /// The order number the email states (`2610ABC`), or null when it states
  /// none. An order confirmation and its delivered notice share it.
  final String? orderRef;

  /// Drives the "NEW" badge fade on the dashboard.
  final bool isNew;

  /// What makes two imports the same purchase, stored as the entry's
  /// `sourceRef`: the merchant and order number when the email states one,
  /// so a later email about the same order matches across syncs; else the
  /// message id.
  String get dedupRef {
    final order = orderRef;
    if (order == null) return id;
    return 'order:${merchant.trim().toLowerCase()}:${order.toLowerCase()}';
  }

  /// Materialise this import as a money [Entry] (`source: email`).
  Entry toEntry() => Entry(
        id: '',
        timestamp: receivedAt,
        type: EntryType.money,
        title: merchant,
        amount: amount,
        category: category,
        source: EntrySource.email,
        sourceRef: dedupRef,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmailImportItem &&
          other.id == id &&
          other.merchant == merchant &&
          other.amount == amount &&
          other.receivedAt == receivedAt &&
          other.category == category &&
          other.orderRef == orderRef &&
          other.isNew == isNew;

  @override
  int get hashCode =>
      Object.hash(id, merchant, amount, receivedAt, category, orderRef, isNew);
}

/// IMAP receipt-import service.
abstract interface class EmailSyncService {
  /// The live sync-job status (drives the dashboard status line/progress).
  Stream<SyncStatus> get status;

  /// Whether an account is currently connected.
  bool get isConnected;

  /// The connected account, or null.
  EmailAccount? get account;

  /// Test/connect credentials; returns true on success.
  Future<bool> testConnection(EmailAccount account, String appPassword);

  /// Persist the account (credentials via secure storage in the real impl).
  Future<void> connect(EmailAccount account, String appPassword);

  /// Replace the connected account's sender allowlist (persisted). No-op when
  /// no account is connected. Takes effect on the next [syncNow] — no reconnect.
  Future<void> updateSenderFilters(List<String> filters);

  /// Run a sync now; resolves with the items found (also emitted via [status]).
  Future<List<EmailImportItem>> syncNow();

  /// Remove the connected account.
  Future<void> disconnect();

  /// Releases the status stream. Called when the owning provider disposes.
  void dispose();
}
