//
//  OpalWidgetSyncBridge.swift
//  Runner
//
//  Thin bridge for the `opal/widget_sync` MethodChannel. The Dart side POSTs the
//  rings snapshot to the proxy itself (it owns the device token); all this needs
//  to do is nudge WidgetKit to re-fetch immediately on `reload`. `reloadAllTimelines`
//  needs no entitlement, so it works on a free Apple team (no App Group required).
//  AppDelegate registers it once the Flutter engine is up.
//

import Flutter
import Foundation
import WidgetKit

enum OpalWidgetSyncBridge {
  /// Name of the MethodChannel; must match `HttpWidgetSyncService` in Dart.
  static let channelName = "opal/widget_sync"

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "reload":
        WidgetCenter.shared.reloadAllTimelines()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
