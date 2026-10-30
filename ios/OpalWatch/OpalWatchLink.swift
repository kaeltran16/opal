//
//  OpalWatchLink.swift
//  OpalWatch
//
//  Watch end of the WatchConnectivity link. Sends what the user said to the
//  phone, which logs it through Pal and answers with display-ready text, and
//  publishes the screen to show. Nothing is queued: with the iPhone out of
//  reach the log is dropped and the words stay on screen for Try again.
//
//  It is the one WCSession delegate, so workout traffic (snapshots the phone
//  pushes, its request to end the workout) passes through to OpalWatchWorkout,
//  which sends its commands with `transmit`.
//

import Foundation
import WatchConnectivity

/// What the phone said about a log. Every field is display-ready.
struct PalReply {
  let title: String?
  let item: String?
  let amount: String?
  let unit: String?
  let detail: String?
  let value: String?
  let fraction: Double?
  let bars: Int?
  let reply: String?
  /// Opaque; sent back as is to undo the turn.
  let undoToken: Any?

  init(_ map: [String: Any]) {
    title = map[OpalWatchMessage.titleKey] as? String
    item = map[OpalWatchMessage.itemKey] as? String
    amount = map[OpalWatchMessage.amountKey] as? String
    unit = map[OpalWatchMessage.unitKey] as? String
    detail = map[OpalWatchMessage.detailKey] as? String
    value = map[OpalWatchMessage.valueKey] as? String
    fraction = (map[OpalWatchMessage.fractionKey] as? NSNumber)?.doubleValue
    bars = (map[OpalWatchMessage.barsKey] as? NSNumber)?.intValue
    reply = map[OpalWatchMessage.replyKey] as? String
    undoToken = map[OpalWatchMessage.undoKey]
  }
}

/// How a message to the phone went.
enum PhoneOutcome {
  case reply([String: Any])
  case failed(String)
}

enum PalScreen {
  case ready
  case sending(text: String)
  case result(text: String, reply: PalReply)
  case undone(text: String, reply: PalReply)
  case failed(text: String, reason: String)
}

final class OpalWatchLink: NSObject, ObservableObject, WCSessionDelegate {
  @Published private(set) var screen = PalScreen.ready
  @Published private(set) var undoing = false
  /// Why the last Undo didn't go through; shown under the Undo button.
  @Published private(set) var undoError: String?

  private static let outOfReach = "Your iPhone is out of reach"
  private static let tooSlow = "Your iPhone took too long"

  /// Bumped on every new screen, so a late reply can't replace a newer one.
  private var generation = 0

  let workout = OpalWatchWorkout()

  override init() {
    super.init()
    workout.transmit = { [weak self] message, done in self?.transmit(message, done: done) }
    WCSession.default.delegate = self
    WCSession.default.activate()
  }

  func log(_ text: String) {
    let words = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !words.isEmpty else { return }
    show(.sending(text: words))
    send([OpalWatchMessage.typeKey: OpalWatchMessage.log, OpalWatchMessage.textKey: words]) {
      [weak self] outcome in
      switch outcome {
      case .reply(let map):
        self?.show(.result(text: words, reply: PalReply(map)))
      case .failed(let reason):
        self?.show(.failed(text: words, reason: reason))
      }
    }
  }

  func retry() {
    if case .failed(let text, _) = screen { log(text) }
  }

  func undo() {
    guard case .result(let text, let reply) = screen, let token = reply.undoToken, !undoing
    else { return }
    undoing = true
    undoError = nil
    send([OpalWatchMessage.typeKey: OpalWatchMessage.undo, OpalWatchMessage.undoKey: token]) {
      [weak self] outcome in
      guard let self else { return }
      self.undoing = false
      switch outcome {
      case .reply:
        self.show(.undone(text: text, reply: reply))
      case .failed(let reason):
        self.undoError = reason
      }
    }
  }

  func reset() {
    show(.ready)
  }

  private func show(_ next: PalScreen) {
    generation += 1
    screen = next
    undoing = false
    undoError = nil
  }

  /// Sends [message] and calls [done] on main, unless the screen moved on.
  private func send(_ message: [String: Any], done: @escaping (PhoneOutcome) -> Void) {
    let sentFor = generation
    transmit(message) { [weak self] outcome in
      guard let self, self.generation == sentFor else { return }
      done(outcome)
    }
  }

  /// Sends [message] to the phone and calls [done] on main with its reply.
  func transmit(_ message: [String: Any], done: @escaping (PhoneOutcome) -> Void) {
    let deliver: (PhoneOutcome) -> Void = { outcome in
      DispatchQueue.main.async { done(outcome) }
    }
    WCSession.default.sendMessage(
      message,
      replyHandler: { reply in
        if let error = reply[OpalWatchMessage.errorKey] as? String {
          deliver(.failed(error))
        } else {
          deliver(.reply(reply))
        }
      },
      errorHandler: { error in
        deliver(.failed(Self.reason(for: error)))
      })
  }

  private static func reason(for error: Error) -> String {
    switch (error as? WCError)?.code {
    case .notReachable:
      return outOfReach
    case .messageReplyTimedOut:
      return tooSlow
    default:
      return error.localizedDescription
    }
  }

  func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    if let error {
      NSLog("OpalWatchLink: activation failed — \(error.localizedDescription)")
    }
  }

  // MARK: - workout traffic from the phone

  func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    receiveSnapshot(message)
  }

  func session(
    _ session: WCSession,
    didReceiveMessage message: [String: Any],
    replyHandler: @escaping ([String: Any]) -> Void
  ) {
    guard message[OpalWatchMessage.typeKey] as? String == OpalWatchMessage.workoutEnd else {
      replyHandler([OpalWatchMessage.errorKey: "unknown message"])
      return
    }
    DispatchQueue.main.async { [weak self] in
      replyHandler(self?.workout.endFromPhone() ?? [:])
    }
  }

  func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
    receiveSnapshot(applicationContext)
  }

  private func receiveSnapshot(_ message: [String: Any]) {
    guard message[OpalWatchMessage.typeKey] as? String == OpalWatchMessage.workout else { return }
    DispatchQueue.main.async { [weak self] in
      self?.workout.receive(message)
    }
  }
}
