//
//  OpalWatchSession.swift
//  Runner
//
//  Phone end of the WatchConnectivity link. AppDelegate activates it at launch,
//  so a `sendMessage` from the Watch that wakes the app in the background finds
//  its delegate already in place. Logs, undos and workout commands go to
//  OpalWatchRelay, which answers them in Dart.
//
//  During a workout Dart also calls out through the relay's channel: start the
//  Watch app's workout, push it a snapshot, and end it for its numbers.
//

import Flutter
import Foundation
import HealthKit
import WatchConnectivity

final class OpalWatchSession: NSObject, WCSessionDelegate {
  static let shared = OpalWatchSession()

  private static let handledTypes: Set<String> = [
    OpalWatchMessage.log, OpalWatchMessage.undo, OpalWatchMessage.workout,
  ]

  // apple recommends one long-lived store per app; this one only launches the
  // Watch app, it reads and writes nothing
  private let healthStore = HKHealthStore()

  private override init() {
    super.init()
  }

  func activate() {
    // false on iPad, which can't pair a Watch
    guard WCSession.isSupported() else { return }
    WCSession.default.delegate = self
    WCSession.default.activate()
  }

  func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    if let error {
      NSLog("OpalWatchSession: activation failed — \(error.localizedDescription)")
    }
  }

  func sessionDidBecomeInactive(_ session: WCSession) {}

  // the user switched to another Watch; activate again to talk to it
  func sessionDidDeactivate(_ session: WCSession) {
    session.activate()
  }

  func session(
    _ session: WCSession,
    didReceiveMessage message: [String: Any],
    replyHandler: @escaping ([String: Any]) -> Void
  ) {
    let type = message[OpalWatchMessage.typeKey] as? String
    guard let type, Self.handledTypes.contains(type) else {
      replyHandler([OpalWatchMessage.errorKey: "unknown message type: \(type ?? "none")"])
      return
    }
    // WatchConnectivity calls back on a background queue; Flutter channels and
    // the relay's state live on main
    DispatchQueue.main.async {
      OpalWatchRelay.shared.forward(message, reply: replyHandler)
    }
  }

  // MARK: - workout calls from Dart

  /// `startWorkout`, `pushWorkout` and `endWorkout` on `opal/watch`; the Dart
  /// end is `ChannelWatchWorkoutService`. None of them fails: without a Watch
  /// they do nothing.
  func handleWorkoutCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "startWorkout":
      let cardio = (call.arguments as? [String: Any])?["cardio"] as? Bool ?? false
      startWorkout(cardio: cardio, result: result)
    case "pushWorkout":
      if let snapshot = call.arguments as? [String: Any] {
        push(snapshot)
      }
      result(nil)
    case "endWorkout":
      endWorkout(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private var watchReady: Bool {
    guard WCSession.isSupported() else { return false }
    let session = WCSession.default
    return session.activationState == .activated && session.isPaired
      && session.isWatchAppInstalled
  }

  /// Opens the Watch app with an HKWorkoutSession of this kind; it asks the
  /// phone for the session's state once it runs.
  private func startWorkout(cardio: Bool, result: @escaping FlutterResult) {
    guard watchReady, HKHealthStore.isHealthDataAvailable() else { return result(nil) }
    let configuration = HKWorkoutConfiguration()
    configuration.activityType = cardio ? .running : .traditionalStrengthTraining
    configuration.locationType = .indoor
    healthStore.startWatchApp(with: configuration) { _, error in
      if let error {
        NSLog("OpalWatchSession: startWatchApp failed — \(error.localizedDescription)")
      }
      DispatchQueue.main.async { result(nil) }
    }
  }

  /// The latest snapshot always goes into the application context, so a Watch
  /// app that wasn't running finds it; a reachable one also gets it at once.
  private func push(_ snapshot: [String: Any]) {
    guard watchReady else { return }
    let session = WCSession.default
    do {
      try session.updateApplicationContext(snapshot)
    } catch {
      NSLog("OpalWatchSession: application context failed — \(error.localizedDescription)")
    }
    guard session.isReachable else { return }
    session.sendMessage(snapshot, replyHandler: nil) { error in
      NSLog("OpalWatchSession: push failed — \(error.localizedDescription)")
    }
  }

  /// Ends the Watch's workout and answers with what it measured, or nil when
  /// the Watch can't be reached. Dart stops waiting after a few seconds.
  private func endWorkout(result: @escaping FlutterResult) {
    guard watchReady, WCSession.default.isReachable else { return result(nil) }
    WCSession.default.sendMessage(
      [OpalWatchMessage.typeKey: OpalWatchMessage.workoutEnd],
      replyHandler: { reply in
        DispatchQueue.main.async { result(reply) }
      },
      errorHandler: { error in
        NSLog("OpalWatchSession: workoutEnd failed — \(error.localizedDescription)")
        DispatchQueue.main.async { result(nil) }
      })
  }
}
