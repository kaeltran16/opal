import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Narrow secure-storage seam so the token store is unit-testable without a
/// platform channel.
abstract interface class TokenSecureStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Default [TokenSecureStore] backed by the platform keychain (in-memory on web).
class FlutterTokenSecureStore implements TokenSecureStore {
  const FlutterTokenSecureStore([this._storage = const FlutterSecureStorage()]);
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

  Future<String> token() async {
    final cached = await secure.read(_key);
    if (cached != null && cached.isNotEmpty) return cached;
    final fresh = await register(deviceId);
    await secure.write(_key, fresh);
    return fresh;
  }

  /// Drops the cached token so the next [token] call re-registers (used after a 401).
  Future<void> clear() => secure.delete(_key);
}
