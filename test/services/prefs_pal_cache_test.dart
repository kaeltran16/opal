import 'package:flutter_test/flutter_test.dart';
import 'package:opal/services/pal/prefs_pal_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<PrefsPalCache> cache({Duration ttl = const Duration(days: 30)}) async =>
      PrefsPalCache(await SharedPreferences.getInstance(), ttl: ttl);

  test('round-trips a stored value', () async {
    final c = await cache();
    await c.put('k', 'reply');
    expect(await c.get('k'), 'reply');
  });

  test('misses for an unknown key', () async {
    expect(await (await cache()).get('absent'), isNull);
  });

  test('treats an expired entry as a miss and removes it', () async {
    final prefs = await SharedPreferences.getInstance();
    final c = PrefsPalCache(prefs, ttl: Duration.zero); // everything is instantly stale
    await c.put('k', 'reply');
    expect(await c.get('k'), isNull);
    // the stale entry was pruned, not just hidden
    expect(prefs.getKeys().where((k) => k.contains('k')), isEmpty);
  });

  test('does not collide with non-cache keys when evicting', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('unrelated', 'keep me');
    final c = PrefsPalCache(prefs, ttl: Duration.zero);
    await c.put('k', 'reply'); // triggers eviction of stale cache entries
    expect(prefs.getString('unrelated'), 'keep me');
  });
}
