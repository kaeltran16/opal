import 'package:flutter/material.dart' show Brightness;
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/app_colors.dart' show AppAccent;

/// User preferences persisted across launches via `shared_preferences`.
///
/// Mirrors the handoff's `@AppStorage("accent")` / brightness toggle plus the
/// onboarding gate flag. This is the SwiftData-free settings store; theme state
/// that previously lived in `_LoopAppState` now reads/writes here (via the
/// Riverpod `appSettings` controller).
///
/// Keys are stable strings so a future schema change can migrate cleanly.
class SettingsRepository {
  SettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _kAccent = 'settings.accent';
  static const _kBrightness = 'settings.brightness';
  static const _kOnboardingComplete = 'settings.onboardingComplete';
  static const _kRitualReminders = 'settings.ritualReminders';
  static const _kBudgetAlerts = 'settings.budgetAlerts';
  static const _kDisplayName = 'settings.displayName';

  // --- Accent -------------------------------------------------------------

  /// Persisted accent, defaulting to [AppAccent.blue] when unset/unknown.
  AppAccent get accent {
    final name = _prefs.getString(_kAccent);
    if (name == null) return AppAccent.blue;
    return AppAccent.values.firstWhere(
      (a) => a.name == name,
      orElse: () => AppAccent.blue,
    );
  }

  Future<void> setAccent(AppAccent accent) =>
      _prefs.setString(_kAccent, accent.name);

  // --- Brightness ---------------------------------------------------------

  /// Persisted brightness, defaulting to [Brightness.light] when unset.
  Brightness get brightness {
    final v = _prefs.getString(_kBrightness);
    return v == 'dark' ? Brightness.dark : Brightness.light;
  }

  Future<void> setBrightness(Brightness brightness) => _prefs.setString(
        _kBrightness,
        brightness == Brightness.dark ? 'dark' : 'light',
      );

  // --- Onboarding gate ----------------------------------------------------

  /// Whether the first-run onboarding flow has been completed (U17 gate).
  bool get onboardingComplete => _prefs.getBool(_kOnboardingComplete) ?? false;

  Future<void> setOnboardingComplete(bool complete) =>
      _prefs.setBool(_kOnboardingComplete, complete);

  // --- Profile ------------------------------------------------------------

  /// The user's display name, captured during onboarding. Empty when unset.
  String get displayName => _prefs.getString(_kDisplayName) ?? '';

  Future<void> setDisplayName(String name) =>
      _prefs.setString(_kDisplayName, name.trim());

  // --- Notification preferences -------------------------------------------

  /// Daily ritual reminder nudges. Defaults on.
  bool get ritualReminders => _prefs.getBool(_kRitualReminders) ?? true;

  Future<void> setRitualReminders(bool enabled) =>
      _prefs.setBool(_kRitualReminders, enabled);

  /// Over-budget alerts. Defaults on.
  bool get budgetAlerts => _prefs.getBool(_kBudgetAlerts) ?? true;

  Future<void> setBudgetAlerts(bool enabled) =>
      _prefs.setBool(_kBudgetAlerts, enabled);
}
