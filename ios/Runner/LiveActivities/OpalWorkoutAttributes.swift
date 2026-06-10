//
//  OpalWorkoutAttributes.swift
//  Opal — U25 Live Activities / Dynamic Island
//
//  Shared ActivityKit attributes describing the live workout session that the
//  Dynamic Island / Live Activity mirrors (see WorkoutSessionController on the
//  Flutter side). This file MUST belong to BOTH targets:
//    - the app target (Runner)        — so OpalLiveActivityBridge can start it
//    - the widget extension (OpalWidgets) — so the SwiftUI views can render it
//  Add it to both in Xcode's File Inspector → Target Membership.
//

import ActivityKit
import Foundation

/// Attributes for a live workout session Live Activity.
///
/// `static` fields are fixed for the lifetime of the activity (set once at
/// `start`); the nested `ContentState` carries everything that changes while
/// the workout runs and is pushed via `update`.
@available(iOS 16.1, *)
struct OpalWorkoutActivityAttributes: ActivityAttributes {
  public typealias ContentState = OpalWorkoutContentState

  /// Routine id — baked into the deep-link target `opal://session/<routineId>`
  /// so a tap on the island routes to the matching active session.
  let routineId: String

  /// Display name of the routine, shown on the lock-screen banner.
  let routineName: String

  /// Wall-clock start of the workout (epoch). The SwiftUI views derive the
  /// live-ticking elapsed timer from this via `Text(timerInterval:)`, so the
  /// clock advances on-device without per-second push updates.
  let startedAt: Date
}

/// Mutable content of a workout Live Activity. Mirror of the Dart `update`
/// arguments in `MethodChannelLiveActivityService`.
@available(iOS 16.1, *)
struct OpalWorkoutContentState: Codable, Hashable {
  /// Whole seconds elapsed at the moment of the last update. Informational —
  /// the displayed timer ticks from `startedAt`; this lets the views reconcile
  /// after a long background gap if needed.
  var elapsedSeconds: Int

  /// Name of the exercise currently in focus, or `nil` if unknown / between
  /// exercises.
  var currentExercise: String?

  /// Number of sets logged so far this session, or `nil` if not tracked.
  var completedSets: Int?

  /// Seconds left on the rest countdown. When non-`nil` (and > 0) the island
  /// shows a rest timer; `nil`/0 means "not resting" → show the elapsed timer.
  var restRemainingSeconds: Int?
}
