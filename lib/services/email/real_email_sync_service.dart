import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/models.dart';
import '../pal/device_token_store.dart';
import '../pal/http_pal_service.dart' show TokenProvider, PalException;
import 'email_sync_service.dart';

/// Real [EmailSyncService] (U24): talks to the proxy's `/v1/email/*` routes,
/// which run a live IMAP scan and model-extract receipts.
///
/// Pull model — the app-password is held in the device keychain (via
/// [TokenSecureStore]) and sent per sync; the server stores nothing. The account
/// metadata (minus password) is persisted in [SharedPreferences] so
/// [isConnected] survives a restart. Interface-compatible with
/// `MockEmailSyncService`, so screens are unchanged.
///
/// The staged [SyncStatus] sequence is emitted around the single round-trip so
/// the dashboard choreography matches the mock.
class RealEmailSyncService implements EmailSyncService {
  RealEmailSyncService({
    required String baseUrl,
    required http.Client httpClient,
    required this.tokens,
    required this.secure,
    required this.prefs,
    this.stageDelay = const Duration(milliseconds: 300),
    this.timeout = const Duration(seconds: 45),
  })  : _base = Uri.parse(baseUrl),
        _http = httpClient {
    _account = _loadAccount();
  }

  static const _accountKey = 'email.account';
  static const _passwordKey = 'email.appPassword';

  final Uri _base;
  final http.Client _http;
  final TokenProvider tokens;
  final TokenSecureStore secure;
  final SharedPreferences prefs;
  final Duration stageDelay;
  final Duration timeout;

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
    try {
      final json = await _post('/v1/email/test', _creds(account, appPassword));
      return json['ok'] == true;
    } on PalException {
      // a probe: surface "couldn't connect" rather than throwing
      return false;
    }
  }

  @override
  Future<void> connect(EmailAccount account, String appPassword) async {
    await secure.write(_passwordKey, appPassword);
    final connected = account.copyWith(appPasswordRef: _passwordKey);
    _account = connected;
    await prefs.setString(_accountKey, jsonEncode(connected.toJson()));
  }

  @override
  Future<void> updateSenderFilters(List<String> filters) async {
    final account = _account;
    if (account == null) return;
    final updated = account.copyWith(senderFilters: filters);
    _account = updated;
    await prefs.setString(_accountKey, jsonEncode(updated.toJson()));
  }

  @override
  Future<List<EmailImportItem>> syncNow() async {
    final account = _account;
    final appPassword = await secure.read(_passwordKey);
    if (account == null || appPassword == null) {
      throw const PalException('no connected email account');
    }

    _controller.add(SyncStatus.scanning);
    try {
      final body = {
        ..._creds(account, appPassword),
        'senderFilters': account.senderFilters,
        'since': account.lastSyncedAt?.millisecondsSinceEpoch,
      };
      final json = await _post('/v1/email/sync', body);

      _controller.add(SyncStatus.filtering);
      await Future<void>.delayed(stageDelay);
      _controller.add(SyncStatus.categorizing);
      await Future<void>.delayed(stageDelay);

      final items = ((json['items'] as List?) ?? const [])
          .cast<Map<String, Object?>>()
          .map(_itemFromJson)
          .toList();

      final synced = account.copyWith(lastSyncedAt: DateTime.now());
      _account = synced;
      await prefs.setString(_accountKey, jsonEncode(synced.toJson()));

      _controller.add(SyncStatus.upToDate);
      return items;
    } catch (e) {
      _controller.add(SyncStatus.error);
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    await secure.delete(_passwordKey);
    await prefs.remove(_accountKey);
    _account = null;
    _controller.add(SyncStatus.idle);
  }

  /// Releases the status stream. Call when the owning provider disposes.
  @override
  void dispose() {
    _controller.close();
  }

  EmailAccount? _loadAccount() {
    final raw = prefs.getString(_accountKey);
    if (raw == null) return null;
    try {
      return EmailAccount.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } catch (_) {
      return null; // corrupt/stale shape → treat as disconnected
    }
  }

  Map<String, Object?> _creds(EmailAccount account, String appPassword) => {
        'host': account.imapHost,
        'port': account.imapPort,
        'address': account.address,
        'appPassword': appPassword,
      };

  EmailImportItem _itemFromJson(Map<String, Object?> json) => EmailImportItem(
        id: json['id']! as String,
        merchant: json['merchant']! as String,
        amount: (json['amount']! as num).toDouble(),
        receivedAt: DateTime.parse(json['receivedAt']! as String),
        category: json['category'] as String?,
      );

  // Bearer-authed POST with one 401 retry (re-register), mirroring HttpPalService.
  Future<Map<String, dynamic>> _post(String path, Map<String, Object?> body) async {
    Future<http.Response> send() async {
      final token = await tokens.token();
      return _http
          .post(
            _base.replace(path: path),
            headers: {
              'content-type': 'application/json',
              'authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);
    }

    http.Response res;
    try {
      res = await send();
      if (res.statusCode == 401) {
        await tokens.clear();
        res = await send();
      }
    } on TimeoutException {
      throw const PalException('request timed out');
    } catch (e) {
      throw PalException('network error: $e');
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw PalException('proxy returned ${res.statusCode}');
    }
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }
}
