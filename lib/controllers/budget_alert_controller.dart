import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/models.dart';
import '../services/notifications/notification_service.dart';
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

    final now = DateTime.now();
    final today = _formatDate(now);
    if (settings.budgetAlertDate == today) return; // already alerted today

    final goals = await ref.read(goalsRepositoryProvider).get();
    final budget = goals.dailyBudget;
    if (budget <= 0) return; // no meaningful budget to cross

    final entries =
        await ref.read(entryRepositoryProvider).watchToday(now).first;
    final spent = entries
        .where((e) => e.type == EntryType.money && (e.amount ?? 0) < 0)
        .fold<double>(0, (sum, e) => sum + e.amount!.abs());
    if (spent <= budget) return; // still within budget

    await settings.setBudgetAlertDate(today);
    await ref.read(notificationServiceProvider).schedule(
          NotificationRequest(
            id: NotificationIds.budgetAlert,
            title: 'Over budget',
            body: "You've passed today's spending budget.",
            scheduledAt: now,
          ),
        );
  }

  static String _formatDate(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }
}
