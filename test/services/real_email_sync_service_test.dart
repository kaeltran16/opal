import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:opal/models/models.dart';
import 'package:opal/services/pal/device_token_store.dart';
import 'package:opal/services/pal/http_pal_service.dart' show TokenProvider, PalException;
import 'package:opal/services/email/real_email_sync_service.dart';

class _MemSecure implements TokenSecureStore {
  final _m = <String, String>{};
  @override
  Future<String?> read(String key) async => _m[key];
  @override
  Future<void> write(String key, String value) async => _m[key] = value;
  @override
  Future<void> delete(String key) async => _m.remove(key);
}

const _account = EmailAccount(
  address: 'me@gmail.com',
  provider: Provider.gmail,
  appPasswordRef: '',
  senderFilters: ['amazon.com'],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MemSecure secure;
  late SharedPreferences prefs;

  setUp(() async {
    secure = _MemSecure();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  TokenProvider tokens() => TokenProvider(token: () async => 'tok', clear: () async {});

  RealEmailSyncService build(MockClient client) => RealEmailSyncService(
        baseUrl: 'https://pal.test',
        httpClient: client,
        tokens: tokens(),
        secure: secure,
        prefs: prefs,
        stageDelay: Duration.zero,
      );

  test('testConnection posts creds to /v1/email/test and returns ok', () async {
    late http.Request seen;
    final service = build(MockClient((req) async {
      seen = req;
      return http.Response(jsonEncode({'ok': true}), 200);
    }));

    final ok = await service.testConnection(_account, 'app pass word');

    expect(ok, isTrue);
    expect(seen.url.path, '/v1/email/test');
    expect(jsonDecode(seen.body)['appPassword'], 'app pass word');
    expect(jsonDecode(seen.body)['host'], 'imap.gmail.com');
  });

  test('testConnection returns false on a transport failure (does not throw)', () async {
    final service = build(MockClient((req) async => http.Response('nope', 500)));
    expect(await service.testConnection(_account, 'pw'), isFalse);
  });

  test('connect persists the account + password; survives a new instance', () async {
    final service = build(MockClient((req) async => http.Response(jsonEncode({'ok': true}), 200)));
    await service.connect(_account, 'secretpw');

    expect(service.isConnected, isTrue);
    expect(await secure.read('email.appPassword'), 'secretpw');

    // a fresh instance reading the same prefs/secure is still connected
    final reopened = build(MockClient((req) async => http.Response('{}', 200)));
    expect(reopened.isConnected, isTrue);
    expect(reopened.account?.address, 'me@gmail.com');
  });

  test('syncNow maps items, sends since, and emits the staged status sequence', () async {
    final service = build(MockClient((req) async {
      expect(req.url.path, '/v1/email/sync');
      final body = jsonDecode(req.body) as Map<String, Object?>;
      expect(body['senderFilters'], ['amazon.com']);
      expect(body['since'], isNull); // first sync
      return http.Response(
        jsonEncode({
          'items': [
            {
              'id': 'msg-1',
              'merchant': 'Amazon',
              'amount': -42.99,
              'receivedAt': '2026-06-09T10:00:00.000Z',
              'category': 'Shopping',
            }
          ]
        }),
        200,
      );
    }));
    await service.connect(_account, 'pw');

    final staged = expectLater(
      service.status,
      emitsInOrder([
        SyncStatus.scanning,
        SyncStatus.filtering,
        SyncStatus.categorizing,
        SyncStatus.upToDate,
      ]),
    );

    final items = await service.syncNow();

    expect(items, hasLength(1));
    expect(items.first.merchant, 'Amazon');
    expect(items.first.amount, -42.99);
    expect(items.first.receivedAt, DateTime.parse('2026-06-09T10:00:00.000Z'));
    expect(service.account?.lastSyncedAt, isNotNull); // advanced
    await staged;
  });

  test('syncNow tolerates an extra truncated field in the response', () async {
    final service = build(MockClient((req) async => http.Response(
          jsonEncode({
            'items': [
              {
                'id': 'msg-1',
                'merchant': 'Amazon',
                'amount': -42.99,
                'receivedAt': '2026-06-09T10:00:00.000Z',
                'category': 'Shopping',
              }
            ],
            'truncated': true,
          }),
          200,
        )));
    await service.connect(_account, 'pw');

    final items = await service.syncNow();
    expect(items, hasLength(1));
    expect(items.first.merchant, 'Amazon');
  });

  test('syncNow sends the prior lastSyncedAt as since on a subsequent sync', () async {
    final synced = _account.copyWith(lastSyncedAt: DateTime(2026, 6, 1));
    await prefs.setString('email.account', jsonEncode(synced.toJson()));
    await secure.write('email.appPassword', 'pw');

    late Map<String, Object?> body;
    final service = build(MockClient((req) async {
      body = jsonDecode(req.body) as Map<String, Object?>;
      return http.Response(jsonEncode({'items': <Object>[]}), 200);
    }));

    await service.syncNow();
    expect(body['since'], DateTime(2026, 6, 1).millisecondsSinceEpoch);
  });

  test('syncNow without a connected account throws', () async {
    final service = build(MockClient((req) async => http.Response('{}', 200)));
    expect(service.syncNow, throwsA(isA<PalException>()));
  });

  test('syncNow emits error and rethrows on a non-2xx', () async {
    final service = build(MockClient((req) async => http.Response('rejected', 422)));
    await service.connect(_account, 'pw');

    final staged = expectLater(
      service.status,
      emitsInOrder([SyncStatus.scanning, SyncStatus.error]),
    );

    await expectLater(service.syncNow(), throwsA(isA<PalException>()));
    await staged;
  });

  test('disconnect clears the account, password, and emits idle', () async {
    final service = build(MockClient((req) async => http.Response(jsonEncode({'ok': true}), 200)));
    await service.connect(_account, 'pw');

    final emittedIdle = expectLater(service.status, emits(SyncStatus.idle));

    await service.disconnect();

    expect(service.isConnected, isFalse);
    expect(await secure.read('email.appPassword'), isNull);
    expect(prefs.getString('email.account'), isNull);
    await emittedIdle;
  });
}
