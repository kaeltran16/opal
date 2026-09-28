import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/controllers/providers.dart';
import 'package:opal/controllers/today_brief_controller.dart';
import 'package:opal/screens/today/today_logic.dart';
import 'package:opal/services/pal/pal_service.dart';

/// Plays back one scripted response per `insights` call: a [PalInsights] is
/// returned, anything else is thrown.
class _ScriptedPal implements PalService {
  _ScriptedPal(this.script);

  final List<Object> script;
  final ranges = <InsightRange>[];

  @override
  Future<PalInsights> insights(InsightRange range) async {
    ranges.add(range);
    final next = script.removeAt(0);
    if (next is PalInsights) return next;
    throw next;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProviderContainer _container(_ScriptedPal pal) {
  final c = ProviderContainer(overrides: [
    palServiceProvider.overrideWithValue(pal),
  ]);
  addTearDown(c.dispose);
  // hold a listener so the auto-dispose provider survives between reads.
  c.listen(todayBriefProvider, (_, _) {});
  return c;
}

void main() {
  test('build loads the trimmed day headline', () async {
    final pal = _ScriptedPal([const PalInsights(headline: '  Steady start. ')]);
    final c = _container(pal);

    expect(await c.read(todayBriefProvider.future), 'Steady start.');
    expect(pal.ranges, [InsightRange.day]);
  });

  test('a failed refresh keeps the last good headline', () async {
    final pal = _ScriptedPal([
      const PalInsights(headline: 'Steady start.'),
      Exception('unreachable'),
    ]);
    final c = _container(pal);
    await c.read(todayBriefProvider.future);

    await c.read(todayBriefProvider.notifier).refresh();

    final state = c.read(todayBriefProvider);
    expect(state, const AsyncData<String?>('Steady start.'));
    expect(briefMode(state), BriefMode.brief);
  });

  test('an empty refresh keeps the last good headline', () async {
    final pal = _ScriptedPal([
      const PalInsights(headline: 'Steady start.'),
      const PalInsights(headline: '   '),
    ]);
    final c = _container(pal);
    await c.read(todayBriefProvider.future);

    await c.read(todayBriefProvider.notifier).refresh();

    expect(c.read(todayBriefProvider), const AsyncData<String?>('Steady start.'));
  });

  test('a successful refresh replaces the headline', () async {
    final pal = _ScriptedPal([
      const PalInsights(headline: 'Steady start.'),
      const PalInsights(headline: 'Good close.'),
    ]);
    final c = _container(pal);
    await c.read(todayBriefProvider.future);

    await c.read(todayBriefProvider.notifier).refresh();

    expect(c.read(todayBriefProvider), const AsyncData<String?>('Good close.'));
  });

  test('a failed rebuild after invalidate keeps the last good headline', () async {
    final pal = _ScriptedPal([
      const PalInsights(headline: 'Steady start.'),
      Exception('unreachable'),
    ]);
    final c = _container(pal);
    await c.read(todayBriefProvider.future);

    c.invalidate(todayBriefProvider);

    expect(await c.read(todayBriefProvider.future), 'Steady start.');
    expect(pal.ranges, hasLength(2));
  });

  test('a first-load failure gives data null, not an error', () async {
    final pal = _ScriptedPal([Exception('unreachable')]);
    final c = _container(pal);

    expect(await c.read(todayBriefProvider.future), isNull);
    final state = c.read(todayBriefProvider);
    expect(state, const AsyncData<String?>(null));
    expect(briefMode(state), BriefMode.fallback);
  });
}
