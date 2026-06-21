import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/controllers/email_sync_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/data/db/database.dart';
import 'package:opal/models/models.dart';
import 'package:opal/services/services.dart';

const _account = EmailAccount(
  address: 'me@gmail.com',
  provider: Provider.gmail,
  appPasswordRef: '',
);

void main() {
  // Regression (P2 #1): connect() goes through EmailSetupController.save(), a
  // different controller than disconnect. The singleton service's identity
  // doesn't change on connect, so a watcher mounted across the connect event
  // (e.g. the You-tab Integrations row) kept reading isConnected == false until
  // the provider was disposed. save() must invalidate the dashboard provider so
  // mounted watchers rebuild and read the now-connected account.
  test('save() refreshes the dashboard so a mounted watcher sees isConnected',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = LoopDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        loopDatabaseProvider.overrideWithValue(db),
        // the real mock: account is null until connect() mutates it.
        emailSyncServiceProvider.overrideWithValue(
          MockEmailSyncService(stageDelay: Duration.zero),
        ),
      ],
    );
    addTearDown(container.dispose);

    // mount a watcher of the dashboard before connecting, mirroring the
    // long-lived Integrations row.
    container.listen(emailDashboardControllerProvider, (_, _) {});
    expect(
      container.read(emailDashboardControllerProvider).isConnected,
      isFalse,
    );

    await container
        .read(emailSetupControllerProvider.notifier)
        .save(_account, 'abcd efgh ijkl mnop');

    // the invalidation rebuilds the dashboard, which re-reads the connected
    // account from the service.
    expect(
      container.read(emailDashboardControllerProvider).isConnected,
      isTrue,
    );
    expect(
      container.read(emailDashboardControllerProvider).account?.address,
      'me@gmail.com',
    );
  });
}
