//
//  OpalLiveActivityBridge.swift
//  Opal — U25 Live Activities / Dynamic Island
//
//  Flutter <-> ActivityKit bridge for the `opal/live_activity` MethodChannel.
//
//  Belongs to the APP target (Runner) only — the widget extension never starts
//  activities, it only renders them.
//
//  Orchestrator wiring (see U25 Integration notes for the exact code):
//    1. In AppDelegate.didFinishLaunchingWithOptions, after the engine exists,
//       resolve the FlutterBinaryMessenger and call:
//           OpalLiveActivityBridge.register(with: messenger)
//    2. Register the `opal` URL scheme in Info.plist (CFBundleURLTypes) and set
//       `NSSupportsLiveActivities = true` on the app target.
//    3. Handle the incoming `opal://session/<routineId>` deep link in
//       AppDelegate (application(_:open:options:)) and forward the routineId to
//       Flutter (e.g. over a second MethodChannel) so GoRouter can `go` to
//       `/session/<routineId>`.
//
//  The live-ticking timer is rendered on-device by SwiftUI `Text(timerInterval:)`
//  from `attributes.startedAt`, so `update` is only invoked when the *content*
//  (exercise / sets / rest) changes — NOT every second.
//

import Foundation

#if canImport(ActivityKit)
import ActivityKit
#endif

#if canImport(Flutter)
import Flutter
#elseif canImport(FlutterMacOS)
import FlutterMacOS
#endif

/// Registers against `opal/live_activity` and maps channel calls onto
/// `Activity<OpalWorkoutActivityAttributes>`.
final class OpalLiveActivityBridge {
  static let channelName = "opal/live_activity"

  /// Strong reference so the channel + its handler outlive `register(with:)`.
  private static var shared: OpalLiveActivityBridge?

  private let channel: FlutterMethodChannel

  private init(channel: FlutterMethodChannel) {
    self.channel = channel
  }

  /// Wires the bridge to the given Flutter messenger. Call once at launch.
  @discardableResult
  static func register(with messenger: FlutterBinaryMessenger) -> OpalLiveActivityBridge {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    let bridge = OpalLiveActivityBridge(channel: channel)
    channel.setMethodCallHandler { call, result in
      bridge.handle(call, result: result)
    }
    shared = bridge
    return bridge
  }

  // MARK: - Dispatch

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "areEnabled":
      result(areActivitiesEnabled())
    case "start":
      start(call.arguments, result: result)
    case "update":
      update(call.arguments, result: result)
    case "end":
      end(call.arguments, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - areEnabled

  private func areActivitiesEnabled() -> Bool {
    if #available(iOS 16.1, *) {
      return ActivityAuthorizationInfo().areActivitiesEnabled
    }
    return false
  }

  // MARK: - start

  private func start(_ arguments: Any?, result: @escaping FlutterResult) {
    guard #available(iOS 16.1, *) else {
      result(nil)
      return
    }
    guard
      let args = arguments as? [String: Any],
      let routineId = args["routineId"] as? String,
      let routineName = args["routineName"] as? String
    else {
      result(argError("start"))
      return
    }

    guard ActivityAuthorizationInfo().areActivitiesEnabled else {
      result(nil)
      return
    }

    let startedAt: Date
    if let ms = args["startedAtMs"] as? NSNumber {
      startedAt = Date(timeIntervalSince1970: ms.doubleValue / 1000.0)
    } else {
      startedAt = Date()
    }

    let attributes = OpalWorkoutActivityAttributes(
      routineId: routineId,
      routineName: routineName,
      startedAt: startedAt
    )
    let initialState = OpalWorkoutContentState(
      elapsedSeconds: 0,
      currentExercise: nil,
      completedSets: 0,
      restRemainingSeconds: nil
    )

    do {
      let activity: Activity<OpalWorkoutActivityAttributes>
      if #available(iOS 16.2, *) {
        // No staleness deadline: the activity is driven locally and ended
        // explicitly on finish.
        let content = ActivityContent(state: initialState, staleDate: nil)
        activity = try Activity.request(
          attributes: attributes,
          content: content,
          pushType: nil
        )
      } else {
        // iOS 16.1 API: contentState only, no ActivityContent wrapper.
        activity = try Activity.request(
          attributes: attributes,
          contentState: initialState,
          pushType: nil
        )
      }
      result(activity.id)
    } catch {
      NSLog("OpalLiveActivity: start failed — \(error.localizedDescription)")
      result(nil)
    }
  }

  // MARK: - update

  private func update(_ arguments: Any?, result: @escaping FlutterResult) {
    guard #available(iOS 16.1, *) else {
      result(nil)
      return
    }
    guard
      let args = arguments as? [String: Any],
      let activityId = args["activityId"] as? String
    else {
      result(argError("update"))
      return
    }

    guard let activity = activity(for: activityId) else {
      // Stale / unknown id — nothing to do.
      result(nil)
      return
    }

    let state = OpalWorkoutContentState(
      elapsedSeconds: (args["elapsedSeconds"] as? NSNumber)?.intValue ?? 0,
      currentExercise: args["currentExercise"] as? String,
      completedSets: (args["completedSets"] as? NSNumber)?.intValue,
      restRemainingSeconds: (args["restRemainingSeconds"] as? NSNumber)?.intValue
    )

    Task {
      if #available(iOS 16.2, *) {
        await activity.update(ActivityContent(state: state, staleDate: nil))
      } else {
        await activity.update(using: state)
      }
      result(nil)
    }
  }

  // MARK: - end

  private func end(_ arguments: Any?, result: @escaping FlutterResult) {
    guard #available(iOS 16.1, *) else {
      result(nil)
      return
    }
    guard
      let args = arguments as? [String: Any],
      let activityId = args["activityId"] as? String,
      let activity = activity(for: activityId)
    else {
      // Unknown id is a no-op success.
      result(nil)
      return
    }

    Task {
      if #available(iOS 16.2, *) {
        await activity.end(
          ActivityContent(state: activity.content.state, staleDate: nil),
          dismissalPolicy: .immediate
        )
      } else {
        await activity.end(using: activity.contentState, dismissalPolicy: .immediate)
      }
      result(nil)
    }
  }

  // MARK: - Helpers

  @available(iOS 16.1, *)
  private func activity(for id: String) -> Activity<OpalWorkoutActivityAttributes>? {
    Activity<OpalWorkoutActivityAttributes>.activities.first { $0.id == id }
  }

  private func argError(_ method: String) -> FlutterError {
    FlutterError(
      code: "bad_args",
      message: "OpalLiveActivity.\(method): missing/invalid arguments",
      details: nil
    )
  }
}
