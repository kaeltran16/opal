// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'autopilot_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The Autopilot switches, which are the stored notification settings: Spend
/// nudge is `budgetAlerts` and Routine reminders is `ritualReminders`.
///
/// Autopilot and Notifications both switch through here, so the two screens
/// and You's count can never disagree.

@ProviderFor(Automations)
const automationsProvider = AutomationsProvider._();

/// The Autopilot switches, which are the stored notification settings: Spend
/// nudge is `budgetAlerts` and Routine reminders is `ritualReminders`.
///
/// Autopilot and Notifications both switch through here, so the two screens
/// and You's count can never disagree.
final class AutomationsProvider
    extends $NotifierProvider<Automations, Map<Automation, bool>> {
  /// The Autopilot switches, which are the stored notification settings: Spend
  /// nudge is `budgetAlerts` and Routine reminders is `ritualReminders`.
  ///
  /// Autopilot and Notifications both switch through here, so the two screens
  /// and You's count can never disagree.
  const AutomationsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'automationsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$automationsHash();

  @$internal
  @override
  Automations create() => Automations();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<Automation, bool> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<Automation, bool>>(value),
    );
  }
}

String _$automationsHash() => r'e16934147dfe1f2cfa380f6f17f57cf3de9d6f7a';

/// The Autopilot switches, which are the stored notification settings: Spend
/// nudge is `budgetAlerts` and Routine reminders is `ritualReminders`.
///
/// Autopilot and Notifications both switch through here, so the two screens
/// and You's count can never disagree.

abstract class _$Automations extends $Notifier<Map<Automation, bool>> {
  Map<Automation, bool> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<Map<Automation, bool>, Map<Automation, bool>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Map<Automation, bool>, Map<Automation, bool>>,
              Map<Automation, bool>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
