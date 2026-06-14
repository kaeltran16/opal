import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'http_pal_service.dart';

/// [PalResponseCache] backed by [SharedPreferences] so cached insights/review
/// survive app relaunches (iOS terminates suspended apps, which is exactly the
/// "reopened the app and looked at last week again" case worth caching).
///
/// Entries carry a timestamp and expire after [ttl]; stale ones are pruned on
/// write so the cache can't grow without bound. An expired or unparseable hit is
/// treated as a miss, so the caller transparently refetches.
class PrefsPalCache extends PalResponseCache {
  PrefsPalCache(this._prefs, {this.ttl = const Duration(days: 30)});

  final SharedPreferences _prefs;
  final Duration ttl;

  static const _prefix = 'pal_cache:';

  @override
  Future<String?> get(String key) async {
    final raw = _prefs.getString('$_prefix$key');
    if (raw == null) return null;
    final entry = _decode(raw);
    if (entry == null || _isExpired(entry.t)) {
      await _prefs.remove('$_prefix$key');
      return null;
    }
    return entry.v;
  }

  @override
  Future<void> put(String key, String value) async {
    await _prefs.setString(
      '$_prefix$key',
      jsonEncode({'v': value, 't': DateTime.now().millisecondsSinceEpoch}),
    );
    await _evictStale();
  }

  // >= so a zero ttl means "don't cache" and an entry exactly at the ttl is stale.
  bool _isExpired(int storedAtMs) =>
      DateTime.now().millisecondsSinceEpoch - storedAtMs >= ttl.inMilliseconds;

  ({String v, int t})? _decode(String raw) {
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return (v: m['v'] as String, t: m['t'] as int);
    } catch (_) {
      return null;
    }
  }

  /// Drops expired (or corrupt) entries across the cache namespace.
  Future<void> _evictStale() async {
    for (final k in _prefs.getKeys().where((k) => k.startsWith(_prefix)).toList()) {
      final raw = _prefs.getString(k);
      final entry = raw == null ? null : _decode(raw);
      if (entry == null || _isExpired(entry.t)) await _prefs.remove(k);
    }
  }
}
