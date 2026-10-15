import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:opal/models/models.dart';
import 'package:opal/services/pal/device_token_store.dart';
import 'package:opal/services/pal/http_pal_service.dart'
    show TokenProvider, PalException;
import 'package:opal/services/email/mailbox_client.dart';
import 'package:opal/services/email/native_email_sync_service.dart';
import 'package:opal/services/email/receipt_filters.dart';

class _MemSecure implements TokenSecureStore {
  final _m = <String, String>{};
  @override
  Future<String?> read(String key) async => _m[key];
  @override
  Future<void> write(String key, String value) async => _m[key] = value;
  @override
  Future<void> delete(String key) async => _m.remove(key);
}

class _FakeMailbox implements MailboxClient {
  _FakeMailbox({this.emails = const [], this.onVerify});

  List<RawEmail> emails;
  void Function()? onVerify;

  ImapCreds? verifiedWith;
  ImapCreds? fetchedWith;
  DateTime? fetchedSince;
  int? fetchedMax;

  @override
  Future<void> verify(ImapCreds creds) async {
    verifiedWith = creds;
    onVerify?.call();
  }

  @override
  Future<List<RawEmail>> fetchSince(
    ImapCreds creds,
    DateTime since,
    int max,
  ) async {
    fetchedWith = creds;
    fetchedSince = since;
    fetchedMax = max;
    return emails;
  }
}

RawEmail _email({
  required String id,
  String from = 'no-reply@grab.com',
  String fromName = 'Grab',
  String subject = 'Your GrabFood order',
  String text = 'Total 45,000d',
  DateTime? date,
}) =>
    RawEmail(
      messageId: id,
      from: from,
      fromName: fromName,
      subject: subject,
      date: date ?? DateTime.utc(2026, 1, 6, 11, 27),
      text: text,
    );

Map<String, Object?> _item(String id, {String merchant = 'GrabFood'}) => {
      'id': id,
      'merchant': merchant,
      'amount': -45000,
      'receivedAt': '2026-01-06T11:27:00.000Z',
      'category': 'Food & Drink',
    };

const _account = EmailAccount(
  address: 'me@gmail.com',
  provider: Provider.gmail,
  appPasswordRef: '',
  senderFilters: [],
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

  TokenProvider tokens() =>
      TokenProvider(token: () async => 'tok', clear: () async {});

  NativeEmailSyncService build(
    MockClient client,
    MailboxClient mailbox,
  ) =>
      NativeEmailSyncService(
        baseUrl: 'https://pal.test',
        httpClient: client,
        mailbox: mailbox,
        tokens: tokens(),
        secure: secure,
        prefs: prefs,
        stageDelay: Duration.zero,
      );

  MockClient okClient(List<http.Request> seen, {List<Object?>? items}) =>
      MockClient((req) async {
        seen.add(req);
        final candidates =
            (jsonDecode(req.body)['candidates'] as List).cast<Map>();
        return http.Response(
          jsonEncode({
            'items': items ??
                candidates.map((c) => _item(c['id'] as String)).toList(),
          }),
          200,
        );
      });

  Future<NativeEmailSyncService> connected(
    MockClient client,
    MailboxClient mailbox, {
    EmailAccount account = _account,
  }) async {
    final service = build(client, mailbox);
    await service.connect(account, 'app pass word');
    return service;
  }

  group('testConnection', () {
    test('verifies over IMAP and never touches the network', () async {
      final mailbox = _FakeMailbox();
      var httpCalls = 0;
      final service = build(MockClient((req) async {
        httpCalls++;
        return http.Response('{}', 200);
      }), mailbox);

      expect(await service.testConnection(_account, 'app pass word'), isTrue);
      expect(mailbox.verifiedWith?.appPassword, 'app pass word');
      expect(mailbox.verifiedWith?.host, 'imap.gmail.com');
      expect(httpCalls, 0, reason: 'credentials must never leave the device');
    });

    test('returns false on a bad login rather than throwing', () async {
      final mailbox = _FakeMailbox(
        onVerify: () => throw const ImapAuthException('nope'),
      );
      final service = build(MockClient((_) async => http.Response('{}', 200)),
          mailbox);
      expect(await service.testConnection(_account, 'pw'), isFalse);
    });

    test('returns false when the mailbox is unreachable', () async {
      final mailbox = _FakeMailbox(
        onVerify: () => throw const MailboxException('no route'),
      );
      final service = build(MockClient((_) async => http.Response('{}', 200)),
          mailbox);
      expect(await service.testConnection(_account, 'pw'), isFalse);
    });
  });

  group('syncNow', () {
    test('throws when no account is connected', () async {
      final service = build(
        MockClient((_) async => http.Response('{}', 200)),
        _FakeMailbox(),
      );
      expect(service.syncNow(), throwsA(isA<PalException>()));
    });

    test('sends the app password to IMAP only, never to the worker', () async {
      final seen = <http.Request>[];
      final mailbox = _FakeMailbox(emails: [_email(id: 'm1')]);
      final service = await connected(okClient(seen), mailbox);

      await service.syncNow();

      expect(mailbox.fetchedWith?.appPassword, 'app pass word');
      expect(seen, hasLength(1));
      expect(seen.single.body, isNot(contains('app pass word')));
      expect(seen.single.url.path, '/v1/email/extract');
      expect(seen.single.headers['authorization'], 'Bearer tok');
    });

    test('redacts PII and bounds the body before sending', () async {
      final seen = <http.Request>[];
      final mailbox = _FakeMailbox(emails: [
        _email(
          id: 'm1',
          subject: 'Receipt for user@example.com',
          text: 'Paid 4111111111111111 total 45,000d${'x' * kMaxBodyChars}',
        ),
      ]);
      final service = await connected(okClient(seen), mailbox);

      await service.syncNow();

      final sent = (jsonDecode(seen.single.body)['candidates'] as List).single
          as Map<String, Object?>;
      expect(sent['subject'], 'Receipt for [email]');
      expect(sent['text'], isNot(contains('4111111111111111')));
      expect(sent['text'], contains('[card]'));
      expect((sent['text']! as String).length, kMaxBodyChars);
      expect(sent['envelopeDate'], '2026-01-06T11:27:00.000Z');
    });

    test('sends the device UTC offset at the envelope instant', () async {
      final seen = <http.Request>[];
      final mailbox = _FakeMailbox(emails: [_email(id: 'm1')]);
      final service = await connected(okClient(seen), mailbox);

      await service.syncNow();

      final sent = (jsonDecode(seen.single.body)['candidates'] as List).single
          as Map<String, Object?>;
      final envelope = DateTime.parse(sent['envelopeDate']! as String);
      expect(
        sent['utcOffsetMinutes'],
        envelope.toLocal().timeZoneOffset.inMinutes,
      );
    });

    test('drops repeated message ids before extraction', () async {
      final seen = <http.Request>[];
      final mailbox = _FakeMailbox(emails: [
        _email(id: 'dupe'),
        _email(id: 'dupe'),
        _email(id: 'other'),
      ]);
      final service = await connected(okClient(seen), mailbox);

      await service.syncNow();

      final sentIds = (jsonDecode(seen.single.body)['candidates'] as List)
          .map((c) => (c as Map)['id'])
          .toList();
      expect(sentIds, ['dupe', 'other']);
    });

    test('drops obvious non-receipts before the paid call', () async {
      final seen = <http.Request>[];
      final mailbox = _FakeMailbox(emails: [
        _email(id: 'promo', subject: '50% off', text: 'unsubscribe here'),
        _email(id: 'real'),
      ]);
      final service = await connected(okClient(seen), mailbox);

      await service.syncNow();

      final sentIds = (jsonDecode(seen.single.body)['candidates'] as List)
          .map((c) => (c as Map)['id'])
          .toList();
      expect(sentIds, ['real']);
    });

    test('applies the sender allowlist', () async {
      final seen = <http.Request>[];
      final mailbox = _FakeMailbox(emails: [
        _email(id: 'grab'),
        _email(id: 'other', from: 'news@shopee.vn', fromName: 'Shopee'),
      ]);
      final service = await connected(
        okClient(seen),
        mailbox,
        account: _account.copyWith(senderFilters: ['grab.com']),
      );

      await service.syncNow();

      final sentIds = (jsonDecode(seen.single.body)['candidates'] as List)
          .map((c) => (c as Map)['id'])
          .toList();
      expect(sentIds, ['grab']);
    });

    test('makes no request and returns nothing when all mail is filtered out',
        () async {
      var calls = 0;
      final mailbox = _FakeMailbox(emails: [
        _email(id: 'promo', subject: 'Sale ends today', text: 'unsubscribe'),
      ]);
      final service = await connected(MockClient((req) async {
        calls++;
        return http.Response('{}', 200);
      }), mailbox);

      expect(await service.syncNow(), isEmpty);
      expect(calls, 0);
    });

    test('splits more than one batch across requests, capped at kBatchSize',
        () async {
      final seen = <http.Request>[];
      final mailbox = _FakeMailbox(
        emails: List.generate(kBatchSize + 3, (i) => _email(id: 'm$i')),
      );
      final service = await connected(okClient(seen), mailbox);

      final items = await service.syncNow();

      expect(seen, hasLength(2));
      for (final req in seen) {
        final batch = jsonDecode(req.body)['candidates'] as List;
        expect(batch.length, lessThanOrEqualTo(kBatchSize));
      }
      expect(items, hasLength(kBatchSize + 3));
    });

    test('keeps import order matching scan order across batches', () async {
      final mailbox = _FakeMailbox(
        emails: List.generate(kBatchSize + 2, (i) => _email(id: 'm$i')),
      );
      final service = await connected(okClient(<http.Request>[]), mailbox);

      final items = await service.syncNow();

      expect(
        items.map((i) => i.id).toList(),
        List.generate(kBatchSize + 2, (i) => 'm$i'),
      );
    });

    test('one failed batch does not discard the others', () async {
      final mailbox = _FakeMailbox(
        emails: List.generate(kBatchSize + 2, (i) => _email(id: 'm$i')),
      );
      final service = await connected(MockClient((req) async {
        final candidates =
            (jsonDecode(req.body)['candidates'] as List).cast<Map>();
        // fail whichever request carries the first email of the second batch
        if (candidates.any((c) => c['id'] == 'm$kBatchSize')) {
          return http.Response('upstream boom', 502);
        }
        return http.Response(
          jsonEncode({
            'items':
                candidates.map((c) => _item(c['id'] as String)).toList(),
          }),
          200,
        );
      }), mailbox);

      final items = await service.syncNow();

      expect(items, hasLength(kBatchSize));
      expect(items.map((i) => i.id), isNot(contains('m$kBatchSize')));
    });

    test('emits the staged status sequence', () async {
      final mailbox = _FakeMailbox(emails: [_email(id: 'm1')]);
      final service = await connected(okClient(<http.Request>[]), mailbox);
      final seen = <SyncStatus>[];
      service.status.listen(seen.add);

      await service.syncNow();
      await Future<void>.delayed(Duration.zero);

      expect(seen, [
        SyncStatus.scanning,
        SyncStatus.filtering,
        SyncStatus.categorizing,
        SyncStatus.upToDate,
      ]);
    });

    test('emits error and rethrows when the mailbox fails', () async {
      // a transport failure surfaces rather than being swallowed
      final service = await connected(
        okClient(<http.Request>[]),
        _ThrowingMailbox(),
      );
      final seen = <SyncStatus>[];
      service.status.listen(seen.add);

      await expectLater(service.syncNow(), throwsA(isA<MailboxException>()));
      await Future<void>.delayed(Duration.zero);
      expect(seen.last, SyncStatus.error);
    });

    test('scans since the last sync, or a 7 day window on first run', () async {
      final mailbox = _FakeMailbox(emails: [_email(id: 'm1')]);
      final service = await connected(okClient(<http.Request>[]), mailbox);

      await service.syncNow();
      final firstRun = mailbox.fetchedSince!;
      expect(
        DateTime.now().difference(firstRun).inDays,
        7,
        reason: 'first run falls back to the server default window',
      );
      expect(mailbox.fetchedMax, kMaxScan);

      // the cursor advances, so the next scan starts from the last sync
      await service.syncNow();
      expect(mailbox.fetchedSince!.isAfter(firstRun), isTrue);
    });

    test('advances the persisted cursor so a restart resumes', () async {
      final mailbox = _FakeMailbox(emails: [_email(id: 'm1')]);
      final service = await connected(okClient(<http.Request>[]), mailbox);

      await service.syncNow();

      expect(service.account?.lastSyncedAt, isNotNull);
      final reloaded = build(okClient(<http.Request>[]), mailbox);
      expect(reloaded.isConnected, isTrue);
      expect(reloaded.account?.lastSyncedAt, isNotNull);
    });
  });

  group('account lifecycle', () {
    test('disconnect clears the password and the persisted account', () async {
      final mailbox = _FakeMailbox();
      final service = await connected(okClient(<http.Request>[]), mailbox);
      expect(service.isConnected, isTrue);

      await service.disconnect();

      expect(service.isConnected, isFalse);
      expect(await secure.read('email.appPassword'), isNull);
      expect(build(okClient(<http.Request>[]), mailbox).isConnected, isFalse);
    });

    test('updateSenderFilters persists and survives a rebuild', () async {
      final mailbox = _FakeMailbox();
      final service = await connected(okClient(<http.Request>[]), mailbox);

      await service.updateSenderFilters(['shopee.vn']);

      expect(
        build(okClient(<http.Request>[]), mailbox).account?.senderFilters,
        ['shopee.vn'],
      );
    });
  });
}

class _ThrowingMailbox implements MailboxClient {
  @override
  Future<void> verify(ImapCreds creds) async {}

  @override
  Future<List<RawEmail>> fetchSince(
    ImapCreds creds,
    DateTime since,
    int max,
  ) async =>
      throw const MailboxException('no route to host');
}
