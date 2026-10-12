import 'package:flutter/material.dart' show Brightness, TimeOfDay;
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/notifications/notification_service.dart'
    show kDefaultReminderTime;
import '../../util/format.dart' show Currency;

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
/// Holds the brightness toggle plus the onboarding gate flag. This is the
/// SwiftData-free settings store; theme state
/// that previously lived in `_LoopAppState` now reads/writes here (via the
/// Riverpod `appSettings` controller).
///
/// Keys are stable strings so a future schema change can migrate cleanly.
class SettingsRepository {
  SettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _kBrightness = 'settings.brightness';
  static const _kCurrency = 'settings.currency';
  static const _kOnboardingComplete = 'settings.onboardingComplete';
  static const _kRitualReminders = 'settings.ritualReminders';
  static const _kReminderTime = 'settings.reminderTimeMinutes';
  static const _kBudgetAlerts = 'settings.budgetAlerts';
  static const _kBudgetAlertDate = 'settings.budgetAlertDate';
  static const _kVelocityAlertWeek = 'settings.velocityAlertWeek';
  static const _kSpikeAlertMonth = 'settings.spikeAlertMonth';
  static const _kDisplayName = 'settings.displayName';
  static const _kSyncCadence = 'settings.email.syncCadenceMinutes';
  static const _kImportNotifications = 'settings.email.importNotifications';
  static const _kAutoCategorize = 'settings.email.autoCategorize';
  static const _kDismissedFindings = 'settings.pal.dismissedFindings';

  // --- Brightness ---------------------------------------------------------

  /// Persisted brightness, defaulting to [Brightness.dark] when unset.
  Brightness get brightness {
    final v = _prefs.getString(_kBrightness);
    return v == 'light' ? Brightness.light : Brightness.dark;
  }

  Future<void> setBrightness(Brightness brightness) => _prefs.setString(
        _kBrightness,
        brightness == Brightness.dark ? 'dark' : 'light',
      );

  // --- Currency -----------------------------------------------------------

  /// Persisted display currency, defaulting to [Currency.usd] when unset.
  Currency get currency => Currency.fromCode(_prefs.getString(_kCurrency));

  Future<void> setCurrency(Currency currency) =>
      _prefs.setString(_kCurrency, currency.code);

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

  /// Time of day for the daily ritual reminder. Stored as minutes-since-
  /// midnight (matching the int-minutes style used by [syncCadence]); defaults
  /// to [kDefaultReminderTime] (09:00) when unset.
  TimeOfDay get reminderTime {
    final minutes = _prefs.getInt(_kReminderTime);
    if (minutes == null) return kDefaultReminderTime;
    return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  }

  Future<void> setReminderTime(TimeOfDay time) =>
      _prefs.setInt(_kReminderTime, time.hour * 60 + time.minute);

  /// Over-budget alerts. Defaults on.
  bool get budgetAlerts => _prefs.getBool(_kBudgetAlerts) ?? true;

  Future<void> setBudgetAlerts(bool enabled) =>
      _prefs.setBool(_kBudgetAlerts, enabled);

  /// Last calendar day ('YYYY-MM-DD') an over-budget alert fired, or null if
  /// never. Used to dedup the alert to at most once per day. Stored here (not
  /// derived from entries) so the dedup survives without scanning notifications.
  String? get budgetAlertDate => _prefs.getString(_kBudgetAlertDate);

  Future<void> setBudgetAlertDate(String date) =>
      _prefs.setString(_kBudgetAlertDate, date);

  /// Week-start date ('YYYY-MM-DD') of the last spending-pace alert, or null if
  /// never. The pace compares two 7-day windows, so re-firing inside the same
  /// week would just restate the same comparison.
  String? get velocityAlertWeek => _prefs.getString(_kVelocityAlertWeek);

  Future<void> setVelocityAlertWeek(String weekStart) =>
      _prefs.setString(_kVelocityAlertWeek, weekStart);

  /// Month ('YYYY-MM') of the last category-spike alert, or null if never. The
  /// spike is a month-over-month comparison, so once a month is the natural
  /// cadence.
  String? get spikeAlertMonth => _prefs.getString(_kSpikeAlertMonth);

  Future<void> setSpikeAlertMonth(String month) =>
      _prefs.setString(_kSpikeAlertMonth, month);

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

  // --- Pal findings -------------------------------------------------------

  /// Ids of the Pal findings the user dismissed. An id encodes the claim, so a
  /// changed finding is a new id and shows again.
  Set<String> get dismissedFindings =>
      (_prefs.getStringList(_kDismissedFindings) ?? const []).toSet();

  /// Adds [ids] to the dismissed set, keeping the ones already there.
  Future<void> addDismissedFindings(Iterable<String> ids) =>
      _prefs.setStringList(
          _kDismissedFindings, {...dismissedFindings, ...ids}.toList());
}
