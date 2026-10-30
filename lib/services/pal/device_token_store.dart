import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Narrow secure-storage seam so the token store is unit-testable without a
/// platform channel.
abstract interface class TokenSecureStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Default [TokenSecureStore] backed by the platform keychain (in-memory on web).
///
/// Readable after the first unlock, not only while unlocked: a Watch log wakes
/// the app in the background, usually with the phone locked in a pocket.
class FlutterTokenSecureStore implements TokenSecureStore {
  const FlutterTokenSecureStore([this._storage = FlutterTokenSecureStore._keychain]);

  static const _keychain = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Obtains a server device token, registering once and caching it in secure
/// storage. [register] performs the `POST /v1/register` round-trip.
class DeviceTokenStore {
  DeviceTokenStore({
    required this.secure,
    required this.deviceId,
    required this.register,
  });

  static const _key = 'pal_device_token';

  final TokenSecureStore secure;
  final String deviceId;
  final Future<String> Function(String deviceId) register;

  // first launch fires several Pal calls at once; they must share one register.
  Future<String>? _inFlight;

  // a keychain item keeps the accessibility it was written with, so a token
  // saved before the store's options changed is written again, once per launch
  bool _saved = false;

  Future<String> token() {
    final pending = _inFlight;
    if (pending != null) return pending;
    final next = _readOrRegister();
    _inFlight = next;
    next.whenComplete(() => _inFlight = null).ignore();
    return next;
  }

  Future<String> _readOrRegister() async {
    final cached = await secure.read(_key);
    if (cached != null && cached.isNotEmpty) {
      if (!_saved) await _resave(cached);
      return cached;
    }
    final fresh = await register(deviceId);
    await secure.write(_key, fresh);
    _saved = true;
    return fresh;
  }

  // the token was read, so a failed re-save must not fail the call; the next
  // call tries again
  Future<void> _resave(String token) async {
    try {
      await secure.write(_key, token);
      _saved = true;
    } catch (e) {
      debugPrint('DeviceTokenStore: re-saving the token failed: $e');
    }
  }

  /// Drops the cached token so the next [token] call re-registers (used after a 401).
  Future<void> clear() => secure.delete(_key);
}
