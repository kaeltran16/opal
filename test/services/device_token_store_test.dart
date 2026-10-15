import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:opal/services/pal/device_token_store.dart';

class _FakeSecureStore implements TokenSecureStore {
  final Map<String, String> _m = {};
  @override
  Future<String?> read(String key) async => _m[key];
  @override
  Future<void> write(String key, String value) async => _m[key] = value;
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
}
