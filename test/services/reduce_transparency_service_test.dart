import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/services/accessibility/reduce_transparency_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('opal/accessibility');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  // simulates the native side calling into dart.
  Future<void> nativeSends(String method, Object? arguments) {
    return messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall(method, arguments),
      ),
      (_) {},
    );
  }

  test('noop emits false once', () async {
    expect(await const NoopReduceTransparencyService().watch().toList(), [
      false,
    ]);
  });

  test('emits the initial value, then native changes', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'isReduceTransparencyEnabled');
      return false;
    });
    final values = <bool>[];
    final sub = const MethodChannelReduceTransparencyService().watch().listen(
      values.add,
    );
    await pumpEventQueue();

    await nativeSends('reduceTransparencyChanged', true);
    await nativeSends('reduceTransparencyChanged', false);
    await pumpEventQueue();
    await sub.cancel();

    expect(values, [false, true, false]);
  });

  test('falls back to false when the bridge is missing', () async {
    final values = await const MethodChannelReduceTransparencyService()
        .watch()
        .first;
    expect(values, false);
  });

  test('falls back to false when the bridge throws', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'boom');
    });
    expect(
      await const MethodChannelReduceTransparencyService().watch().first,
      false,
    );
  });
}
