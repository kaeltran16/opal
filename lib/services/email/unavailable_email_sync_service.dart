import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../../models/models.dart';
import '../pal/http_pal_service.dart' show PalException;
import 'email_sync_service.dart';

/// Whether this platform can sync email at all.
///
/// False on web: IMAP needs a raw TCP socket, which browsers cannot open, and
/// the migration deliberately keeps the mailbox on-device rather than handing
/// credentials to a server. Single source of truth for both the provider wiring
/// and the screens' unavailable state — check this rather than `kIsWeb` at the
/// call site.
bool get isEmailSyncAvailable => !kIsWeb;

/// [EmailSyncService] for platforms that cannot sync email (web).
///
/// Every operation fails closed instead of pretending to work, so the screens
/// show an honest unavailable state and no mock import is ever mistaken for a
/// real receipt.
class UnavailableEmailSyncService implements EmailSyncService {
  UnavailableEmailSyncService();

  static const _reason =
      'Email sync is not available on web: connecting to your mailbox needs a '
      'native app.';

  final _controller = StreamController<SyncStatus>.broadcast();

  @override
  Stream<SyncStatus> get status => _controller.stream;

  @override
  bool get isConnected => false;

  @override
  EmailAccount? get account => null;

  @override
  Future<bool> testConnection(EmailAccount account, String appPassword) async =>
      false;

  @override
  Future<void> connect(EmailAccount account, String appPassword) async =>
      throw const PalException(_reason);

  @override
  Future<void> updateSenderFilters(List<String> filters) async {}

  @override
  Future<List<EmailImportItem>> syncNow() async =>
      throw const PalException(_reason);

  @override
  Future<void> disconnect() async {}

  @override
  void dispose() {
    _controller.close();
  }
}
