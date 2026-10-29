//
//  OpalWatchSession.swift
//  Runner
//
//  Phone end of the WatchConnectivity link. AppDelegate activates it at launch,
//  so a `sendMessage` from the Watch that wakes the app in the background finds
//  its delegate already in place. For now it only answers `ping`.
//

import Foundation
import WatchConnectivity

final class OpalWatchSession: NSObject, WCSessionDelegate {
  static let shared = OpalWatchSession()

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
    if type == OpalWatchMessage.ping {
      replyHandler([OpalWatchMessage.typeKey: OpalWatchMessage.pong])
    } else {
      replyHandler([OpalWatchMessage.errorKey: "unknown message type: \(type ?? "none")"])
    }
  }
}
