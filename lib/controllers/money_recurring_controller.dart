import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/models.dart';
import 'providers.dart';

part 'money_recurring_controller.g.dart';

/// "in N days" for an absolute [date], clamped to ≥ 0. Single source of truth
/// for the countdown math used by both Subscriptions and Bills.
int daysUntil(DateTime date, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final target = DateTime(date.year, date.month, date.day);
  final d = target.difference(today).inDays;
  return d < 0 ? 0 : d;
}

/// The computed Subscriptions block (handoff screen 18): the list (soonest
/// first) plus the monthly/yearly/next-up totals. All math lives here so the
/// screen only lays out and this stays unit-testable.
@immutable
class SubscriptionsState {
  const SubscriptionsState({
    required this.subs,
    required this.monthlyTotal,
  });

  /// Subscriptions sorted by [Subscription.nextChargeDate] ascending.
  final List<Subscription> subs;

  /// Sum of all monthly amounts.
  final double monthlyTotal;

  double get yearlyTotal => monthlyTotal * 12;

  /// The soonest-charging subscription, or null when empty.
  Subscription? get nextUp => subs.isEmpty ? null : subs.first;
}

SubscriptionsState buildSubscriptionsState(List<Subscription> subs) {
  final sorted = [...subs]
    ..sort((a, b) => a.nextChargeDate.compareTo(b.nextChargeDate));
  final total = sorted.fold<double>(0, (s, x) => s + x.amount);
  return SubscriptionsState(subs: sorted, monthlyTotal: total);
}

/// Streams the [SubscriptionsState]; re-emits whenever subscriptions change.
@riverpod
Stream<SubscriptionsState> subscriptions(Ref ref) {
  return ref
      .watch(subscriptionRepositoryProvider)
      .watchSubscriptions()
      .map(buildSubscriptionsState);
}

/// The computed Bills block (handoff screen 23): the list (soonest first), the
/// next-bill hero source, and the month total + auto-pay count.
@immutable
class BillsState {
  const BillsState({
    required this.bills,
    required this.monthTotal,
    required this.autoPayCount,
  });

  /// Bills sorted by [Bill.dueDate] ascending.
  final List<Bill> bills;

  /// Sum of all bill amounts ("Due this month").
  final double monthTotal;

  /// How many bills are on auto-pay.
  final int autoPayCount;

  /// The soonest-due bill (the hero), or null when empty.
  Bill? get next => bills.isEmpty ? null : bills.first;

  int get count => bills.length;
}

BillsState buildBillsState(List<Bill> bills) {
  final sorted = [...bills]..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  final total = sorted.fold<double>(0, (s, b) => s + b.amount);
  final auto = sorted.where((b) => b.autoPay).length;
  return BillsState(bills: sorted, monthTotal: total, autoPayCount: auto);
}

/// Streams the [BillsState]; re-emits whenever bills change.
@riverpod
Stream<BillsState> bills(Ref ref) {
  return ref.watch(billRepositoryProvider).watchBills().map(buildBillsState);
}
