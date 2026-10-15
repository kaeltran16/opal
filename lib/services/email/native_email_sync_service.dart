import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/models.dart';
import '../pal/device_token_store.dart';
import '../pal/http_pal_service.dart' show TokenProvider, PalException;
import 'email_sync_service.dart';
import 'mailbox_client.dart';
import 'receipt_filters.dart';

/// Native [EmailSyncService] (migration phase 4B): IMAP runs on-device and only
/// sanitized receipt candidates reach the Worker.
///
/// Replaces the retired server-side IMAP scan. The app password is read
/// from the keychain per sync and handed to the [MailboxClient] only — it is
/// never sent to the Worker, which in turn never returns the OpenRouter key.
/// Account metadata (minus password) lives in [SharedPreferences] so
/// [isConnected] survives a restart.
///
/// Interface-compatible with the mock and the HTTP implementation, so the email
/// screens are unchanged.
class NativeEmailSyncService implements EmailSyncService {
  NativeEmailSyncService({
    required String baseUrl,
    required http.Client httpClient,
    required this.mailbox,
    required this.tokens,
    required this.secure,
    required this.prefs,
    this.stageDelay = const Duration(milliseconds: 300),
    this.timeout = const Duration(seconds: 45),
    this.maxScan = kMaxScan,
  })  : _base = Uri.parse(baseUrl),
        _http = httpClient {
    _account = _loadAccount();
  }

  static const _accountKey = 'email.account';
  static const _passwordKey = 'email.appPassword';

  /// Scan window when no sync has happened yet. Matches the server default the
  /// old `/v1/email/sync` route applied.
  static const _defaultWindow = Duration(days: 7);

  /// Extraction requests in flight. Bounds Worker load while staying inside the
  /// whole-sync timeout; mirrors the server's EXTRACT_CONCURRENCY.
  static const _extractConcurrency = 4;

  final Uri _base;
  final http.Client _http;
  final MailboxClient mailbox;
  final TokenProvider tokens;
  final TokenSecureStore secure;
  final SharedPreferences prefs;
  final Duration stageDelay;
  final Duration timeout;
  final int maxScan;

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
      await mailbox.verify(_creds(account, appPassword));
      return true;
    } on ImapAuthException {
      return false;
    } on MailboxException {
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
      final since =
          account.lastSyncedAt ?? clock.now().subtract(_defaultWindow);
      final emails = await mailbox.fetchSince(
        _creds(account, appPassword),
        since,
        maxScan,
      );

      _controller.add(SyncStatus.filtering);
      await Future<void>.delayed(stageDelay);
      final candidates = _sanitize(emails, account.senderFilters);

      _controller.add(SyncStatus.categorizing);
      await Future<void>.delayed(stageDelay);
      final items = await _extractAll(candidates);

      final synced = account.copyWith(lastSyncedAt: clock.now());
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

  @override
  void dispose() {
    _controller.close();
  }

  /// Applies the sender allowlist, drops repeated Message-IDs, drops obvious
  /// non-receipts, then redacts and bounds what survives.
  ///
  /// Dedup happens before the non-receipt gate so a repeated id is never
  /// evaluated twice, and both happen before extraction so nothing needless
  /// reaches the paid call.
  List<Map<String, Object?>> _sanitize(
    List<RawEmail> emails,
    List<String> senderFilters,
  ) {
    final seen = <String>{};
    return filterBySender(
      emails,
      senderFilters,
      from: (e) => e.from,
      fromName: (e) => e.fromName,
    )
        .where((e) => seen.add(e.messageId))
        .where((e) => !isLikelyNonReceipt(subject: e.subject, text: e.text))
        .map((e) => <String, Object?>{
              'id': boundText(e.messageId, kMaxIdChars),
              'from': boundText(e.from, kMaxFromChars),
              'subject': boundText(redactPii(e.subject), kMaxSubjectChars),
              'text': boundText(redactPii(e.text), kMaxBodyChars),
              'envelopeDate': e.date.toUtc().toIso8601String(),
              // receipt bodies carry local wall-clock times; the offset at the
              // envelope instant lets the worker map them to UTC across DST.
              'utcOffsetMinutes': e.date.toLocal().timeZoneOffset.inMinutes,
            })
        .toList();
  }

  /// Extracts every batch, tolerating per-batch failure.
  ///
  /// One failed batch loses only its own candidates — the rest still import
  /// (the server's Bug A fix, kept client-side now that the loop lives here).
  Future<List<EmailImportItem>> _extractAll(
    List<Map<String, Object?>> candidates,
  ) async {
    if (candidates.isEmpty) return const [];

    final batches = <List<Map<String, Object?>>>[];
    for (var i = 0; i < candidates.length; i += kBatchSize) {
      batches.add(candidates.sublist(
        i,
        i + kBatchSize > candidates.length ? candidates.length : i + kBatchSize,
      ));
    }

    // results are held per batch index so import order follows scan order
    // regardless of which request completes first.
    final perBatch = List<List<EmailImportItem>>.filled(
      batches.length,
      const [],
    );
    var next = 0;
    Future<void> work() async {
      while (next < batches.length) {
        final index = next++;
        try {
          perBatch[index] = await _extractBatch(batches[index]);
        } on PalException {
          // isolated: this batch's candidates are skipped, the others stand
        }
      }
    }

    final workers = batches.length < _extractConcurrency
        ? batches.length
        : _extractConcurrency;
    await Future.wait(List.generate(workers, (_) => work()));

    return perBatch.expand((b) => b).toList();
  }

  Future<List<EmailImportItem>> _extractBatch(
    List<Map<String, Object?>> batch,
  ) async {
    final json = await _post('/v1/email/extract', {'candidates': batch});
    // the sender comes from the fetched email, never from the model's reply.
    final domains = {
      for (final c in batch)
        c['id']! as String: senderDomain(c['from']! as String),
    };
    return ((json['items'] as List?) ?? const [])
        .cast<Map<String, Object?>>()
        .map((item) => _itemFromJson(item, domains[item['id']]))
        .toList();
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

  ImapCreds _creds(EmailAccount account, String appPassword) => ImapCreds(
        host: account.imapHost,
        port: account.imapPort,
        address: account.address,
        appPassword: appPassword,
      );

  EmailImportItem _itemFromJson(
    Map<String, Object?> json,
    String? senderDomain,
  ) =>
      EmailImportItem(
        id: json['id']! as String,
        merchant: json['merchant']! as String,
        amount: (json['amount']! as num).toDouble(),
        receivedAt: DateTime.parse(json['receivedAt']! as String),
        category: json['category'] as String?,
        orderRef: json['orderRef'] as String?,
        senderDomain: senderDomain,
      );

  // Bearer-authed POST with one 401 retry (re-register), mirroring HttpPalService.
  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, Object?> body,
  ) async {
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
