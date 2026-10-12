// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'autopilot_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The user's autopilot switches for this app session, as overrides of each
/// item's server default by item id.
///
/// Kept alive so a switch survives leaving and reopening Autopilot. Not
/// persisted: there is no server endpoint yet, so a switch cannot stop the
/// task, and a stored value would claim more than it does.

@ProviderFor(AutopilotSwitches)
const autopilotSwitchesProvider = AutopilotSwitchesProvider._();

/// The user's autopilot switches for this app session, as overrides of each
/// item's server default by item id.
///
/// Kept alive so a switch survives leaving and reopening Autopilot. Not
/// persisted: there is no server endpoint yet, so a switch cannot stop the
/// task, and a stored value would claim more than it does.
final class AutopilotSwitchesProvider
    extends $NotifierProvider<AutopilotSwitches, Map<String, bool>> {
  /// The user's autopilot switches for this app session, as overrides of each
  /// item's server default by item id.
  ///
  /// Kept alive so a switch survives leaving and reopening Autopilot. Not
  /// persisted: there is no server endpoint yet, so a switch cannot stop the
  /// task, and a stored value would claim more than it does.
  const AutopilotSwitchesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'autopilotSwitchesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$autopilotSwitchesHash();

  @$internal
  @override
  AutopilotSwitches create() => AutopilotSwitches();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, bool> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, bool>>(value),
    );
  }
}

String _$autopilotSwitchesHash() => r'f3455e789e1aaf55c041604ce854043c62127d30';

/// The user's autopilot switches for this app session, as overrides of each
/// item's server default by item id.
///
/// Kept alive so a switch survives leaving and reopening Autopilot. Not
/// persisted: there is no server endpoint yet, so a switch cannot stop the
/// task, and a stored value would claim more than it does.

abstract class _$AutopilotSwitches extends $Notifier<Map<String, bool>> {
  Map<String, bool> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<Map<String, bool>, Map<String, bool>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Map<String, bool>, Map<String, bool>>,
              Map<String, bool>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
