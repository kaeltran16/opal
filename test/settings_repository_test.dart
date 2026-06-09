import 'package:flutter/material.dart' show Brightness;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:loop/data/repositories/settings_repository.dart';
import 'package:loop/theme/app_colors.dart';

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
}
