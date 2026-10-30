//
//  OpalWatchRelay.swift
//  Runner
//
//  Hands a Watch log, undo or workout command to Dart over the `opal/watch`
//  MethodChannel and sends Dart's reply back to the Watch; the Dart end is
//  `bindWatchChannel`. Dart's own workout calls on the channel (start the
//  Watch workout, push a snapshot, end it) go on to OpalWatchSession.
//
//  Which engine: the app's own while it exists, so only one engine opens the
//  database. When a message wakes the app with no scene (so no app engine), a
//  headless engine runs the `watchMain` entrypoint and is stopped once Dart
//  says it is idle. If the app opens meanwhile, the headless engine finishes
//  what it has and the app engine is told to refresh after each write.
//  Workout commands go to the app engine only: the session lives in its
//  memory, so without one there is no workout to drive.
//
//  Timing: iOS gives a woken app a short, unpromised stretch, so the relay
//  holds a background task while anything is in flight and answers the Watch
//  itself if Dart is too slow. Every reply goes to the Watch once.
//

import Flutter
import UIKit

final class OpalWatchRelay {
  static let shared = OpalWatchRelay()

  static let channelName = "opal/watch"

  /// Dart entrypoint in lib/main.dart.
  private static let headlessEntrypoint = "watchMain"

  /// Dart caps the chat at 15 s; this is the relay's own cap, still inside the
  /// roughly 30 s iOS tends to give a woken app.
  private static let replyDeadline: TimeInterval = 25

  private static let tooSlow = "Your iPhone took too long"
  private static let phoneFailed = "Something went wrong on your iPhone"

  typealias Reply = ([String: Any]) -> Void

  private struct Request {
    let id = UUID()
    let message: [String: Any]
    let receivedAt = Date()
  }

  /// One Dart end of the channel. [busy] counts requests handed to it that
  /// Dart hasn't answered, queued ones included.
  private final class Endpoint {
    let channel: FlutterMethodChannel
    let attachedAt = Date()
    var ready = false
    var queued: [Request] = []
    var busy = 0

    init(channel: FlutterMethodChannel) {
      self.channel = channel
    }
  }

  private var app: Endpoint?
  private var headless: (engine: FlutterEngine, endpoint: Endpoint)?
  private var waiting: [UUID: Reply] = [:]
  private var backgroundTask = UIBackgroundTaskIdentifier.invalid
  private var sceneObserver: NSObjectProtocol?

  private init() {
    // the app engine belongs to the scene and goes when the scene does
    sceneObserver = NotificationCenter.default.addObserver(
      forName: UIScene.didDisconnectNotification, object: nil, queue: .main
    ) { [weak self] _ in
      self?.detachApp()
    }
  }

  /// Called once the app's own engine is up; Dart says `ready` when it binds.
  func attachApp(_ messenger: FlutterBinaryMessenger) {
    app = attach(messenger)
  }

  /// Main thread only, like every method here.
  func forward(_ message: [String: Any], reply: @escaping Reply) {
    if message[OpalWatchMessage.typeKey] as? String == OpalWatchMessage.workout, app == nil {
      reply(OpalWatchMessage.noWorkout)
      return
    }
    holdBackgroundTime()
    let request = Request(message: message)
    waiting[request.id] = reply
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.replyDeadline) { [weak self] in
      self?.finish(request.id, with: [OpalWatchMessage.errorKey: Self.tooSlow])
    }
    guard let endpoint = app ?? startHeadless() else {
      finish(request.id, with: [OpalWatchMessage.errorKey: Self.phoneFailed])
      return
    }
    hand(request, to: endpoint)
  }

  // MARK: - endpoints

  private func attach(_ messenger: FlutterBinaryMessenger) -> Endpoint {
    let endpoint = Endpoint(
      channel: FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger))
    endpoint.channel.setMethodCallHandler { [weak self, weak endpoint] call, result in
      guard let self, let endpoint else { return result(nil) }
      switch call.method {
      case "ready":
        self.ready(endpoint)
      case "idle":
        self.stopHeadlessIfIdle(endpoint)
      case "startWorkout", "pushWorkout", "endWorkout":
        return OpalWatchSession.shared.handleWorkoutCall(call, result: result)
      default:
        return result(FlutterMethodNotImplemented)
      }
      result(nil)
    }
    return endpoint
  }

  private func ready(_ endpoint: Endpoint) {
    endpoint.ready = true
    let ms = Int(Date().timeIntervalSince(endpoint.attachedAt) * 1000)
    NSLog("OpalWatchRelay: Dart ready \(ms) ms after attach")
    let queued = endpoint.queued
    endpoint.queued = []
    queued.forEach { send($0, to: endpoint) }
  }

  private func detachApp() {
    guard let gone = app else { return }
    app = nil
    // requests Dart never got go to a headless engine; sent ones hit the deadline
    for request in gone.queued where waiting[request.id] != nil {
      guard let endpoint = startHeadless() else {
        finish(request.id, with: [OpalWatchMessage.errorKey: Self.phoneFailed])
        continue
      }
      hand(request, to: endpoint)
    }
  }

  private func startHeadless() -> Endpoint? {
    if let headless { return headless.endpoint }
    let engine = FlutterEngine(name: "opal.watch", project: nil, allowHeadlessExecution: true)
    guard engine.run(withEntrypoint: Self.headlessEntrypoint) else {
      NSLog("OpalWatchRelay: the headless engine failed to start")
      return nil
    }
    GeneratedPluginRegistrant.register(with: engine)
    OpalWidgetSyncBridge.register(with: engine.binaryMessenger)
    let endpoint = attach(engine.binaryMessenger)
    headless = (engine, endpoint)
    return endpoint
  }

  private func stopHeadlessIfIdle(_ endpoint: Endpoint) {
    guard let headless, headless.endpoint === endpoint, endpoint.busy == 0 else { return }
    stopHeadless()
    releaseIfIdle()
  }

  private func stopHeadless() {
    headless?.engine.destroyContext()
    headless = nil
  }

  // MARK: - requests

  private func hand(_ request: Request, to endpoint: Endpoint) {
    endpoint.busy += 1
    if endpoint.ready {
      send(request, to: endpoint)
    } else {
      endpoint.queued.append(request)
    }
  }

  private func send(_ request: Request, to endpoint: Endpoint) {
    let method = request.message[OpalWatchMessage.typeKey] as? String ?? ""
    endpoint.channel.invokeMethod(method, arguments: request.message) { [weak self] result in
      guard let self else { return }
      endpoint.busy -= 1
      let ms = Int(Date().timeIntervalSince(request.receivedAt) * 1000)
      NSLog("OpalWatchRelay: \(method) answered by Dart in \(ms) ms")
      guard let reply = result as? [String: Any] else {
        NSLog("OpalWatchRelay: %@ got no reply map: %@", method, String(describing: result))
        self.finish(request.id, with: [OpalWatchMessage.errorKey: Self.phoneFailed])
        return
      }
      // the app engine's drift streams don't see the other connection's write
      if endpoint !== self.app, reply[OpalWatchMessage.errorKey] == nil, let app = self.app,
        app.ready
      {
        app.channel.invokeMethod("changed", arguments: nil)
      }
      self.finish(request.id, with: reply)
    }
  }

  private func finish(_ id: UUID, with reply: [String: Any]) {
    guard let watchReply = waiting.removeValue(forKey: id) else { return }
    watchReply(reply)
    releaseIfIdle()
  }

  // MARK: - background time

  private func holdBackgroundTime() {
    guard backgroundTask == .invalid else { return }
    backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Opal Watch log") {
      [weak self] in
      self?.expire()
    }
  }

  private func releaseIfIdle() {
    guard waiting.isEmpty, headless == nil, backgroundTask != .invalid else { return }
    UIApplication.shared.endBackgroundTask(backgroundTask)
    backgroundTask = .invalid
  }

  // iOS is about to suspend the app: answer everyone now and stop the engine
  private func expire() {
    NSLog("OpalWatchRelay: background time ran out with \(waiting.count) waiting")
    for id in Array(waiting.keys) {
      finish(id, with: [OpalWatchMessage.errorKey: Self.tooSlow])
    }
    stopHeadless()
    if backgroundTask != .invalid {
      UIApplication.shared.endBackgroundTask(backgroundTask)
      backgroundTask = .invalid
    }
  }
}
