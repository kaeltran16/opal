//
//  OpalWidgetSyncBridge.swift
//  Runner
//
//  Receives today's progress from Flutter over the `opal/widget_sync`
//  MethodChannel, writes it to the shared App Group (via RingsSnapshot), and
//  asks WidgetKit to reload the rings widget. Mirrors OpalLiveActivityBridge:
//  AppDelegate registers it once the Flutter engine is up.
//

import Flutter
import Foundation
import WidgetKit

enum OpalWidgetSyncBridge {
  /// Name of the MethodChannel; must match `MethodChannelWidgetSyncService` in Dart.
  static let channelName = "opal/widget_sync"

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "sync":
        guard let a = call.arguments as? [String: Any] else {
          result(FlutterError(code: "bad_args", message: "expected a map", details: nil))
          return
        }
        RingsSnapshot(
          moneyRing: a["moneyRing"] as? Double ?? 0,
          moveRing: a["moveRing"] as? Double ?? 0,
          ritualsRing: a["ritualsRing"] as? Double ?? 0,
          moneySpent: a["moneySpent"] as? Double ?? 0,
          dailyBudget: a["dailyBudget"] as? Double ?? 0,
          moveMinutes: a["moveMinutes"] as? Int ?? 0,
          dailyMoveMinutes: a["dailyMoveMinutes"] as? Int ?? 0,
          ritualsDone: a["ritualsDone"] as? Int ?? 0,
          dailyRitualTarget: a["dailyRitualTarget"] as? Int ?? 0
        ).save()
        WidgetCenter.shared.reloadAllTimelines()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
