import 'package:flutter/material.dart' show Brightness;
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/app_colors.dart' show AppAccent;

/// How often the email sync runs in the background. Persisted by its [minutes]
/// so the stored value stays meaningful even if the option set changes.
enum SyncCadence {
  every15min(15, 'Every 15 min'),
  every30min(30, 'Every 30 min'),
  hourly(60, 'Hourly'),
  manual(0, 'Manual only');

  const SyncCadence(this.minutes, this.label);

  final int minutes;
  final String label;

  static SyncCadence fromMinutes(int minutes) => values.firstWhere(
        (c) => c.minutes == minutes,
        orElse: () => SyncCadence.every15min,
      );
}

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
  static const _kSyncCadence = 'settings.email.syncCadenceMinutes';
  static const _kImportNotifications = 'settings.email.importNotifications';
  static const _kAutoCategorize = 'settings.email.autoCategorize';

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

  /// The display name, or the app default ('You') when unset.
  String get displayNameOrDefault {
    final n = displayName.trim();
    return n.isEmpty ? 'You' : n;
  }

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

  // --- Email sync preferences ---------------------------------------------

  /// Background email-sync cadence. Defaults to [SyncCadence.every15min].
  SyncCadence get syncCadence {
    final minutes = _prefs.getInt(_kSyncCadence);
    if (minutes == null) return SyncCadence.every15min;
    return SyncCadence.fromMinutes(minutes);
  }

  Future<void> setSyncCadence(SyncCadence cadence) =>
      _prefs.setInt(_kSyncCadence, cadence.minutes);

  /// Notify when a new receipt is detected during sync. Defaults off.
  bool get importNotifications =>
      _prefs.getBool(_kImportNotifications) ?? false;

  Future<void> setImportNotifications(bool enabled) =>
      _prefs.setBool(_kImportNotifications, enabled);

  /// Let Pal auto-categorize imported receipts. Defaults on.
  bool get autoCategorize => _prefs.getBool(_kAutoCategorize) ?? true;

  Future<void> setAutoCategorize(bool enabled) =>
      _prefs.setBool(_kAutoCategorize, enabled);
}
