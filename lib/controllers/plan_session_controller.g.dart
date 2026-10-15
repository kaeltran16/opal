// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plan_session_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// What the user did with today's plan this app session: Today's card and
/// timeline, and You's Pal suggests, settle the same proposals here, so one
/// approved or put off on either screen is gone from both.
///
/// Kept alive so it outlives either screen. Not persisted, as Today's own
/// session never was.

@ProviderFor(PlanSessionController)
const planSessionControllerProvider = PlanSessionControllerProvider._();

/// What the user did with today's plan this app session: Today's card and
/// timeline, and You's Pal suggests, settle the same proposals here, so one
/// approved or put off on either screen is gone from both.
///
/// Kept alive so it outlives either screen. Not persisted, as Today's own
/// session never was.
final class PlanSessionControllerProvider
    extends $NotifierProvider<PlanSessionController, PlanSession> {
  /// What the user did with today's plan this app session: Today's card and
  /// timeline, and You's Pal suggests, settle the same proposals here, so one
  /// approved or put off on either screen is gone from both.
  ///
  /// Kept alive so it outlives either screen. Not persisted, as Today's own
  /// session never was.
  const PlanSessionControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'planSessionControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$planSessionControllerHash();

  @$internal
  @override
  PlanSessionController create() => PlanSessionController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PlanSession value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PlanSession>(value),
    );
  }
}

String _$planSessionControllerHash() =>
    r'e74e6aeb1cf325af04ac748fc048b4d2717ec04f';

/// What the user did with today's plan this app session: Today's card and
/// timeline, and You's Pal suggests, settle the same proposals here, so one
/// approved or put off on either screen is gone from both.
///
/// Kept alive so it outlives either screen. Not persisted, as Today's own
/// session never was.

abstract class _$PlanSessionController extends $Notifier<PlanSession> {
  PlanSession build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<PlanSession, PlanSession>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PlanSession, PlanSession>,
              PlanSession,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
