import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/controllers/recap_controller.dart';
import 'package:opal/services/pal/pal_service.dart';

/// Records refreshMemory calls; everything else routes through noSuchMethod so
/// the fake doesn't have to implement the full PalService surface.
class _RecordingPal implements PalService {
  int refreshCount = 0;
  bool shouldThrow = false;

  @override
  Future<PalMemoryDigest> refreshMemory() async {
    refreshCount++;
    if (shouldThrow) throw Exception('boom');
    return const PalMemoryDigest();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('recapMemoryRefresh triggers a single memory refresh', () async {
    final pal = _RecordingPal();
    final container = ProviderContainer(overrides: [palServiceProvider.overrideWithValue(pal)]);
    addTearDown(container.dispose);

    await container.read(recapMemoryRefreshProvider.future);
    expect(pal.refreshCount, 1);
  });

  test('a thrown refresh is swallowed and never propagates', () async {
    final pal = _RecordingPal()..shouldThrow = true;
    final container = ProviderContainer(overrides: [palServiceProvider.overrideWithValue(pal)]);
    addTearDown(container.dispose);

    // completes normally despite refreshMemory throwing — memory never blocks recap.
    await container.read(recapMemoryRefreshProvider.future);
    expect(pal.refreshCount, 1);
  });
}
