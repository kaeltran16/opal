import 'package:flutter_test/flutter_test.dart';
import 'package:opal/models/models.dart';
import 'package:opal/services/email/unavailable_email_sync_service.dart';
import 'package:opal/services/pal/http_pal_service.dart' show PalException;

const _account = EmailAccount(
  address: 'me@gmail.com',
  provider: Provider.gmail,
  appPasswordRef: '',
  senderFilters: [],
);

void main() {
  late UnavailableEmailSyncService service;

  setUp(() => service = UnavailableEmailSyncService());
  tearDown(() => service.dispose());

  test('reports no connection and no account', () {
    expect(service.isConnected, isFalse);
    expect(service.account, isNull);
  });

  test('fails closed rather than pretending a connection works', () async {
    expect(await service.testConnection(_account, 'pw'), isFalse);
    expect(service.connect(_account, 'pw'), throwsA(isA<PalException>()));
  });

  test('syncNow throws instead of returning fake imports', () {
    // the point of this impl: no mock receipt can be mistaken for a real one
    expect(service.syncNow(), throwsA(isA<PalException>()));
  });

  test('disconnect and updateSenderFilters are harmless no-ops', () async {
    await service.disconnect();
    await service.updateSenderFilters(['grab.com']);
    expect(service.isConnected, isFalse);
  });

  test('email sync is available off the web', () {
    // this suite runs on the Dart VM, so the native answer is the one asserted
    expect(isEmailSyncAvailable, isTrue);
  });
}
