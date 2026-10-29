//
//  OpalWatchMessage.swift
//  Runner, OpalWatch
//
//  Wire format of the WatchConnectivity link. Compiled into both Runner and
//  OpalWatch (the way OpalWorkoutAttributes is shared with OpalWidgets) so the
//  two ends can't drift. A message is a `[String: Any]` carrying a `type`; a
//  reply carries either a `type` or an `error`.
//

enum OpalWatchMessage {
  static let typeKey = "type"
  static let errorKey = "error"

  /// Watch -> phone; the phone answers `pong`. Proves the link end to end.
  static let ping = "ping"
  static let pong = "pong"
}
