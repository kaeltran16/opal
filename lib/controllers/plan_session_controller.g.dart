// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plan_session_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// What the user did with today's plan: Today's card and timeline, and You's
/// Pal suggests, settle the same proposals here, so one approved or put off
/// on either screen is gone from both.
///
/// Approving a proposal performs it through the repositories, and Undo
/// reverses it the same way. Each settles or pops only after its write, so a
/// failed write leaves the plan as it was and throws for the screen to say so.
///
/// Kept alive so it outlives either screen. The settled map is saved for the
/// day, so a relaunch keeps the day's put-offs; the undo history is not, as
/// the toast that offers it is gone after a relaunch anyway.
///
/// A put-off proposal is also saved with its day, so Pal suggesting it again
/// leaves it out for [declineDays] days; bringing it back or undoing the
/// put-off that day forgets it.

@ProviderFor(PlanSessionController)
const planSessionControllerProvider = PlanSessionControllerProvider._();

/// What the user did with today's plan: Today's card and timeline, and You's
/// Pal suggests, settle the same proposals here, so one approved or put off
/// on either screen is gone from both.
///
/// Approving a proposal performs it through the repositories, and Undo
/// reverses it the same way. Each settles or pops only after its write, so a
/// failed write leaves the plan as it was and throws for the screen to say so.
///
/// Kept alive so it outlives either screen. The settled map is saved for the
/// day, so a relaunch keeps the day's put-offs; the undo history is not, as
/// the toast that offers it is gone after a relaunch anyway.
///
/// A put-off proposal is also saved with its day, so Pal suggesting it again
/// leaves it out for [declineDays] days; bringing it back or undoing the
/// put-off that day forgets it.
final class PlanSessionControllerProvider
    extends $NotifierProvider<PlanSessionController, PlanSession> {
  /// What the user did with today's plan: Today's card and timeline, and You's
  /// Pal suggests, settle the same proposals here, so one approved or put off
  /// on either screen is gone from both.
  ///
  /// Approving a proposal performs it through the repositories, and Undo
  /// reverses it the same way. Each settles or pops only after its write, so a
  /// failed write leaves the plan as it was and throws for the screen to say so.
  ///
  /// Kept alive so it outlives either screen. The settled map is saved for the
  /// day, so a relaunch keeps the day's put-offs; the undo history is not, as
  /// the toast that offers it is gone after a relaunch anyway.
  ///
  /// A put-off proposal is also saved with its day, so Pal suggesting it again
  /// leaves it out for [declineDays] days; bringing it back or undoing the
  /// put-off that day forgets it.
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
    r'098b8cd9f29e89f5659279d0a4955fcb2af105bb';

/// What the user did with today's plan: Today's card and timeline, and You's
/// Pal suggests, settle the same proposals here, so one approved or put off
/// on either screen is gone from both.
///
/// Approving a proposal performs it through the repositories, and Undo
/// reverses it the same way. Each settles or pops only after its write, so a
/// failed write leaves the plan as it was and throws for the screen to say so.
///
/// Kept alive so it outlives either screen. The settled map is saved for the
/// day, so a relaunch keeps the day's put-offs; the undo history is not, as
/// the toast that offers it is gone after a relaunch anyway.
///
/// A put-off proposal is also saved with its day, so Pal suggesting it again
/// leaves it out for [declineDays] days; bringing it back or undoing the
/// put-off that day forgets it.

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
