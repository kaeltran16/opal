import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/services/services.dart';

void main() {
  test('palServiceProvider defaults to MockPalService when PAL_BASE_URL is unset', () {
    // Tests run without --dart-define, so the gate must fall back to the mock.
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final service = container.read(palServiceProvider);

    expect(service, isA<MockPalService>());
  });
}
