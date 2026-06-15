// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'budget_alert_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

@ProviderFor(BudgetAlertController)
const budgetAlertControllerProvider = BudgetAlertControllerProvider._();

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
final class BudgetAlertControllerProvider
    extends $NotifierProvider<BudgetAlertController, void> {
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
  const BudgetAlertControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'budgetAlertControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$budgetAlertControllerHash();

  @$internal
  @override
  BudgetAlertController create() => BudgetAlertController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$budgetAlertControllerHash() =>
    r'd4c44619372412a8fc5a05fad6ce35cddd8a0f94';

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

abstract class _$BudgetAlertController extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  void runBuild() {
    build();
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    element.handleValue(ref, null);
  }
}
