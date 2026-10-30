//
//  OpalWatchSession.swift
//  Runner
//
//  Phone end of the WatchConnectivity link. AppDelegate activates it at launch,
//  so a `sendMessage` from the Watch that wakes the app in the background finds
//  its delegate already in place. Logs and undos go to OpalWatchRelay, which
//  answers them in Dart.
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
    guard type == OpalWatchMessage.log || type == OpalWatchMessage.undo else {
      replyHandler([OpalWatchMessage.errorKey: "unknown message type: \(type ?? "none")"])
      return
    }
    // WatchConnectivity calls back on a background queue; Flutter channels and
    // the relay's state live on main
    DispatchQueue.main.async {
      OpalWatchRelay.shared.forward(message, reply: replyHandler)
    }
  }
}
