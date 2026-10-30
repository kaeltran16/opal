//
//  OpalWatchApp.swift
//  OpalWatch
//
//  Pal logging on the Watch: say something, the iPhone logs it through Pal,
//  and the result comes back with Undo. Screens are in OpalWatchViews.
//
//  During a workout started on the iPhone the app shows the workout remote
//  instead (OpalWatchWorkout, OpalWatchWorkoutViews). The phone opens it with
//  HKHealthStore.startWatchApp, which arrives here as a workout configuration.
//

import HealthKit
import SwiftUI
import WatchKit

@main
struct OpalWatchApp: App {
  @WKApplicationDelegateAdaptor private var delegate: OpalWatchAppDelegate

  var body: some Scene {
    WindowGroup {
      RootView(link: delegate.link, workout: delegate.link.workout)
    }
  }
}

/// Owns the link, so a workout start that launches the app finds it in place.
final class OpalWatchAppDelegate: NSObject, WKApplicationDelegate {
  let link = OpalWatchLink()

  func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
    link.workout.start(workoutConfiguration)
  }
}

private struct RootView: View {
  let link: OpalWatchLink
  @ObservedObject var workout: OpalWatchWorkout

  var body: some View {
    if workout.active {
      WorkoutView(workout: workout)
    } else {
      PalView(link: link)
    }
  }
}
