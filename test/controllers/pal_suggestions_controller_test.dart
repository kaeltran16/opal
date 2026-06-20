import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opal/controllers/pal_suggestions_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/services/pal/http_pal_service.dart';
import 'package:opal/services/pal/pal_service.dart';

class _ThrowingPal implements PalService {
  @override
  Future<List<PalSuggestion>> suggestions(SuggestionSurface s) async =>
      throw const PalException('down');
  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _OkPal implements PalService {
  @override
  Future<List<PalSuggestion>> suggestions(SuggestionSurface s) async =>
      const [PalSuggestion(label: 'x', icon: 'sparkles', colorToken: 'accent')];
  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  test('returns [] when the service throws', () async {
    final c = ProviderContainer(overrides: [palServiceProvider.overrideWithValue(_ThrowingPal())]);
    addTearDown(c.dispose);
    final out = await c.read(palSuggestionsProvider(SuggestionSurface.composer).future);
    expect(out, isEmpty);
  });

  test('returns the service list on success', () async {
    final c = ProviderContainer(overrides: [palServiceProvider.overrideWithValue(_OkPal())]);
    addTearDown(c.dispose);
    final out = await c.read(palSuggestionsProvider(SuggestionSurface.newEntry).future);
    expect(out, hasLength(1));
  });
}
