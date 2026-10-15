import 'package:flutter/material.dart' show Brightness;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/data/repositories/settings_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults: dark brightness, onboarding incomplete', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = SettingsRepository(await SharedPreferences.getInstance());
    expect(repo.brightness, Brightness.dark);
    expect(repo.onboardingComplete, isFalse);
  });

  test('a saved light reads light and a saved dark reads dark', () async {
    SharedPreferences.setMockInitialValues({'settings.brightness': 'light'});
    expect(SettingsRepository(await SharedPreferences.getInstance()).brightness,
        Brightness.light);

    SharedPreferences.setMockInitialValues({'settings.brightness': 'dark'});
    expect(SettingsRepository(await SharedPreferences.getInstance()).brightness,
        Brightness.dark);
  });

  test('persists brightness / onboarding across reloads', () async {
    SharedPreferences.setMockInitialValues({});

    // First "session": write values.
    final repo = SettingsRepository(await SharedPreferences.getInstance());
    await repo.setBrightness(Brightness.light);
    await repo.setOnboardingComplete(true);

    // Simulate a restart: a fresh instance over the same backing store.
    final reloaded =
        SettingsRepository(await SharedPreferences.getInstance());
    expect(reloaded.brightness, Brightness.light);
    expect(reloaded.onboardingComplete, isTrue);
  });

  test('display name defaults to empty and persists trimmed', () async {
    SharedPreferences.setMockInitialValues({});

    final repo = SettingsRepository(await SharedPreferences.getInstance());
    expect(repo.displayName, '');

    await repo.setDisplayName('  Mira  ');

    final reloaded =
        SettingsRepository(await SharedPreferences.getInstance());
    expect(reloaded.displayName, 'Mira');
  });

  test('email sync prefs default to 15-min / notify off / auto-categorize on',
      () async {
    SharedPreferences.setMockInitialValues({});
    final repo = SettingsRepository(await SharedPreferences.getInstance());
    expect(repo.syncCadence, SyncCadence.every15min);
    expect(repo.importNotifications, isFalse);
    expect(repo.autoCategorize, isTrue);
  });

  test('email sync prefs persist across reloads', () async {
    SharedPreferences.setMockInitialValues({});

    final repo = SettingsRepository(await SharedPreferences.getInstance());
    await repo.setSyncCadence(SyncCadence.hourly);
    await repo.setImportNotifications(true);
    await repo.setAutoCategorize(false);

    final reloaded =
        SettingsRepository(await SharedPreferences.getInstance());
    expect(reloaded.syncCadence, SyncCadence.hourly);
    expect(reloaded.importNotifications, isTrue);
    expect(reloaded.autoCategorize, isFalse);
  });

  test('SyncCadence persists by minutes and maps back', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = SettingsRepository(await SharedPreferences.getInstance());

    await repo.setSyncCadence(SyncCadence.manual);
    expect(repo.syncCadence, SyncCadence.manual);
    expect(repo.syncCadence.minutes, 0);

    // An unknown stored minute count falls back to the default.
    expect(SyncCadence.fromMinutes(999), SyncCadence.every15min);
  });

  test('dismissed findings union with the stored set and read back', () async {
    SharedPreferences.setMockInitialValues({
      'settings.pal.dismissedFindings': ['corr:money-move:-'],
    });
    final repo = SettingsRepository(await SharedPreferences.getInstance());
    expect(repo.dismissedFindings, {'corr:money-move:-'});

    await repo
        .addDismissedFindings(['money:no-spend-streak', 'corr:money-move:-']);

    final reloaded =
        SettingsRepository(await SharedPreferences.getInstance());
    expect(reloaded.dismissedFindings,
        {'corr:money-move:-', 'money:no-spend-streak'});
  });

  test('dismissed findings default to empty', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = SettingsRepository(await SharedPreferences.getInstance());
    expect(repo.dismissedFindings, isEmpty);
  });

  group("today's plan", () {
    final day = DateTime(2026, 10, 4, 23, 58);

    test("round-trips the day's settled map", () async {
      SharedPreferences.setMockInitialValues({});
      final repo = SettingsRepository(await SharedPreferences.getInstance());
      expect(repo.planSettled(day), isEmpty);

      await repo.setPlanSettled(day, {'mood': true, 'proposal:rent': false});

      final reloaded = SettingsRepository(await SharedPreferences.getInstance());
      expect(reloaded.planSettled(DateTime(2026, 10, 4)),
          {'mood': true, 'proposal:rent': false});
    });

    test('another day reads empty', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = SettingsRepository(await SharedPreferences.getInstance());
      await repo.setPlanSettled(day, {'mood': true});

      expect(repo.planSettled(DateTime(2026, 10, 5, 0, 1)), isEmpty);
      expect(repo.planSettled(DateTime(2026, 10, 3, 12)), isEmpty);
    });

    test('a value that does not parse reads empty', () async {
      for (final corrupt in [
        'not json',
        '[]',
        '{"day":"2026-10-04"}',
        '{"day":"2026-10-04","settled":{"mood":"yes"}}',
      ]) {
        SharedPreferences.setMockInitialValues({'settings.today.planSettled': corrupt});
        final repo = SettingsRepository(await SharedPreferences.getInstance());
        expect(repo.planSettled(day), isEmpty, reason: corrupt);
      }
    });
  });
}
