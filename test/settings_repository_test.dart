import 'package:flutter/material.dart' show Brightness;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opal/data/repositories/settings_repository.dart';
import 'package:opal/theme/app_colors.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults: blue accent, light brightness, onboarding incomplete',
      () async {
    SharedPreferences.setMockInitialValues({});
    final repo = SettingsRepository(await SharedPreferences.getInstance());
    expect(repo.accent, AppAccent.blue);
    expect(repo.brightness, Brightness.light);
    expect(repo.onboardingComplete, isFalse);
  });

  test('persists accent / brightness / onboarding across reloads', () async {
    SharedPreferences.setMockInitialValues({});

    // First "session": write values.
    final repo = SettingsRepository(await SharedPreferences.getInstance());
    await repo.setAccent(AppAccent.teal);
    await repo.setBrightness(Brightness.dark);
    await repo.setOnboardingComplete(true);

    // Simulate a restart: a fresh instance over the same backing store.
    final reloaded =
        SettingsRepository(await SharedPreferences.getInstance());
    expect(reloaded.accent, AppAccent.teal);
    expect(reloaded.brightness, Brightness.dark);
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
}
