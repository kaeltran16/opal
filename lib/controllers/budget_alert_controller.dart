import 'package:clock/clock.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../analysis/spend_alerts.dart';
import '../data/repositories/repositories.dart';
import '../models/models.dart';
import '../services/notifications/notification_service.dart';
import '../util/dates.dart';
import 'providers.dart';

part 'budget_alert_controller.g.dart';

/// Fires an over-budget alert when a spending entry pushes the day's total spend
/// over [Goals.dailyBudget].
///
/// Event-driven (no startup scheduling): the entry-add flow calls
/// [checkAfterSpend] after persisting a money entry. The alert is gated on the
/// `budgetAlerts` toggle and deduplicated to at most once per calendar day via
/// [SettingsRepository.budgetAlertDate], so only the threshold-crossing entry
/// alerts — later over-budget entries the same day stay quiet.
///
/// Scope: the single boundary every money entry the *user* logs flows through is
/// the New Entry sheet, which calls this after `insert`. Other insert paths
/// (Pal chat actions, email import) don't trigger it by design.
@Riverpod(keepAlive: true)
class BudgetAlertController extends _$BudgetAlertController {
  @override
  void build() {}

  /// Today's spend just changed — alert if it crossed the daily budget and we
  /// haven't already alerted today.
  Future<void> checkAfterSpend() async {
    final settings = ref.read(settingsRepositoryProvider);
    if (!settings.budgetAlerts) return;

    final now = clock.now();
    final today = _formatDate(now);
    if (settings.budgetAlertDate == today) return; // already alerted today

    final goals = await ref.read(goalsRepositoryProvider).get();
    final budget = goals.dailyBudget;
    if (budget <= 0) return; // no meaningful budget to cross

    final entries = await ref.read(entryRepositoryProvider).getToday(now);
    final spent = entries
        .where((e) => e.type == EntryType.money && (e.amount ?? 0) < 0)
        .fold<double>(0, (sum, e) => sum + e.amount!.abs());
    if (spent <= budget) return; // still within budget

    await _notifyOnce(
      NotificationRequest(
        id: NotificationIds.budgetAlert,
        title: 'Over budget',
        body: "You've passed today's spending budget.",
        scheduledAt: now,
      ),
      () => settings.setBudgetAlertDate(today),
    );
  }

  /// Delivers [request], then marks its cadence window handled via [markSent].
  ///
  /// Order matters: a transient delivery failure leaves the key unset so the
  /// next check retries, instead of silently suppressing the rest of the
  /// window. Never throws — the entry-add flow awaits this.
  Future<void> _notifyOnce(
    NotificationRequest request,
    Future<void> Function() markSent,
  ) async {
    try {
      await ref.read(notificationServiceProvider).schedule(request);
      await markSent();
    } catch (_) {
      // delivery failed; the cadence key stays unset so the next check retries.
    }
  }

  /// The periodic (not per-entry) budget signals, checked once at startup by
  /// [NotificationReconcileController]: how this week's spending pace compares
  /// with last week's, and the steepest month-over-month category rise.
  ///
  /// Each carries its own cadence key, so a quiet week and a quiet month stay
  /// quiet independently. Both are gated on the same `budgetAlerts` toggle as
  /// [checkAfterSpend] — one switch for "tell me about my budget".
  Future<void> checkPeriodic() async {
    final settings = ref.read(settingsRepositoryProvider);
    if (!settings.budgetAlerts) return;

    final now = clock.now();
    // Start-of-last-month is always at least 28 days back, so this window
    // covers the 14 days velocity needs and both months a spike compares.
    final entries = await ref.read(entryRepositoryProvider).getEntriesInRange(
          DateTime(now.year, now.month - 1),
          DateTime(now.year, now.month + 1),
        );

    await _alertVelocity(settings, entries, now);
    await _alertSpike(settings, entries, now);
  }

  /// Spending pace, at most once per week.
  ///
  /// Only acceleration is worth interrupting for: "you spent less than last
  /// week" is good news, and good news does not need a notification. The
  /// detector still reports both directions for any surface that wants them.
  Future<void> _alertVelocity(
    SettingsRepository settings,
    List<Entry> entries,
    DateTime now,
  ) async {
    final weekKey = _formatDate(startOfWeek(now));
    if (settings.velocityAlertWeek == weekKey) return;

    final velocity = detectVelocityChange(entries, now: now);
    if (velocity == null || !velocity.isAccelerating) return;

    final percent = (velocity.changeFraction * 100).round();
    await _notifyOnce(
      NotificationRequest(
        id: NotificationIds.spendVelocity,
        title: 'Spending is picking up',
        body: "You've spent $percent% more this week than last.",
        scheduledAt: now,
      ),
      () => settings.setVelocityAlertWeek(weekKey),
    );
  }

  /// The steepest category rise, at most once per month.
  ///
  /// One notification, not one per category — a month where several categories
  /// rose should still be a single interruption.
  Future<void> _alertSpike(
    SettingsRepository settings,
    List<Entry> entries,
    DateTime now,
  ) async {
    final monthKey = _formatMonth(now);
    if (settings.spikeAlertMonth == monthKey) return;

    final spikes = detectCategorySpikes(entries, now: now);
    if (spikes.isEmpty) return;

    final top = spikes.first;
    final percent = (top.changeFraction * 100).round();
    await _notifyOnce(
      NotificationRequest(
        id: NotificationIds.categorySpike,
        title: '${top.category} is up this month',
        body: "You've spent $percent% more on ${top.category} "
            'than you did last month.',
        scheduledAt: now,
      ),
      () => settings.setSpikeAlertMonth(monthKey),
    );
  }

  static String _formatDate(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  static String _formatMonth(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';
}
