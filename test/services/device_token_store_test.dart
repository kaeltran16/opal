import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:opal/services/pal/device_token_store.dart';

class _FakeSecureStore implements TokenSecureStore {
  _FakeSecureStore({this.writeFails = false});

  final bool writeFails;
  final Map<String, String> _m = {};
  int writes = 0;

  @override
  Future<String?> read(String key) async => _m[key];
  @override
  Future<void> write(String key, String value) async {
    writes++;
    if (writeFails) throw StateError('keychain locked');
    _m[key] = value;
  }
  @override
  Future<void> delete(String key) async => _m.remove(key);
}

void main() {
  test('registers once, then reuses the cached token', () async {
    var registerCalls = 0;
    final store = DeviceTokenStore(
      secure: _FakeSecureStore(),
      deviceId: 'device-fixed',
      register: (deviceId) async {
        registerCalls++;
        return 'token-$deviceId';
      },
    );

    final first = await store.token();
    final second = await store.token();

    expect(first, 'token-device-fixed');
    expect(second, 'token-device-fixed');
    expect(registerCalls, 1);
  });

  test('clear forces a re-register on next token()', () async {
    var registerCalls = 0;
    final store = DeviceTokenStore(
      secure: _FakeSecureStore(),
      deviceId: 'd',
      register: (_) async {
        registerCalls++;
        return 'tok$registerCalls';
      },
    );

    await store.token();
    await store.clear();
    final after = await store.token();

    expect(after, 'tok2');
    expect(registerCalls, 2);
  });

  test('concurrent token() calls share one in-flight register', () async {
    var registerCalls = 0;
    final gate = Completer<String>();
    final store = DeviceTokenStore(
      secure: _FakeSecureStore(),
      deviceId: 'd',
      register: (_) {
        registerCalls++;
        return gate.future;
      },
    );

    final a = store.token();
    final b = store.token();
    gate.complete('tok');

    expect(await Future.wait([a, b]), ['tok', 'tok']);
    expect(registerCalls, 1);
  });

  test('a failed register is not cached; the next call retries', () async {
    var registerCalls = 0;
    final store = DeviceTokenStore(
      secure: _FakeSecureStore(),
      deviceId: 'd',
      register: (_) async {
        registerCalls++;
        if (registerCalls == 1) throw StateError('500');
        return 'tok';
      },
    );

    await expectLater(store.token(), throwsStateError);
    expect(await store.token(), 'tok');
    expect(registerCalls, 2);
  });

  group('keychain accessibility', () {
    DeviceTokenStore storeOn(_FakeSecureStore secure) => DeviceTokenStore(
          secure: secure,
          deviceId: 'd',
          register: (_) async => 'fresh',
        );

    test('a token saved by an earlier launch is saved again once', () async {
      final secure = _FakeSecureStore().._m['pal_device_token'] = 'old';
      final store = storeOn(secure);

      expect(await store.token(), 'old');
      expect(await store.token(), 'old');

      expect(secure.writes, 1);
    });

    test('a freshly registered token is saved once, not again on reuse', () async {
      final secure = _FakeSecureStore();
      final store = storeOn(secure);

      expect(await store.token(), 'fresh');
      expect(await store.token(), 'fresh');

      expect(secure.writes, 1);
    });

    test('a failed re-save still returns the token and is retried', () async {
      final secure = _FakeSecureStore(writeFails: true).._m['pal_device_token'] = 'old';
      final store = storeOn(secure);

      expect(await store.token(), 'old');
      expect(await store.token(), 'old');

      expect(secure.writes, 2);
    });
  });
}
