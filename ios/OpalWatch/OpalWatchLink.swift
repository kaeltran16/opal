//
//  OpalWatchLink.swift
//  OpalWatch
//
//  Watch end of the WatchConnectivity link. Activates the session on init and
//  pings the phone (OpalWatchSession answers), publishing the outcome for the
//  home screen.
//

import Foundation
import WatchConnectivity

final class OpalWatchLink: NSObject, ObservableObject, WCSessionDelegate {
  @Published private(set) var status = "Not pinged yet"

  override init() {
    super.init()
    WCSession.default.delegate = self
    WCSession.default.activate()
  }

  func ping() {
    status = "Pinging…"
    let sentAt = Date()
    WCSession.default.sendMessage(
      [OpalWatchMessage.typeKey: OpalWatchMessage.ping],
      replyHandler: { [weak self] reply in
        let ms = Int(Date().timeIntervalSince(sentAt) * 1000)
        if reply[OpalWatchMessage.typeKey] as? String == OpalWatchMessage.pong {
          self?.publish("iPhone replied in \(ms) ms")
        } else {
          self?.publish("Unexpected reply: \(reply)")
        }
      },
      errorHandler: { [weak self] error in
        self?.publish("No reply: \(error.localizedDescription)")
      })
  }

  func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    if let error {
      publish("Link failed: \(error.localizedDescription)")
    }
  }

  // WCSession calls back on a background queue; @Published must change on main
  private func publish(_ text: String) {
    DispatchQueue.main.async { self.status = text }
  }
}
