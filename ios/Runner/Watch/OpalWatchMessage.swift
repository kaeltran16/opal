//
//  OpalWatchMessage.swift
//  Runner, OpalWatch
//
//  Wire format of the WatchConnectivity link. Compiled into both Runner and
//  OpalWatch (the way OpalWorkoutAttributes is shared with OpalWidgets) so the
//  two ends can't drift. A message is a `[String: Any]` carrying a `type`; a
//  reply carries either a `type` or an `error`. The phone answers in Dart, so
//  `WatchKeys` in lib/services/watch/watch_channel.dart spells the same keys.
//

enum OpalWatchMessage {
  static let typeKey = "type"
  static let errorKey = "error"

  /// Watch -> phone: `text` is what the user said. The reply is a `result`.
  static let log = "log"
  static let textKey = "text"

  /// Watch -> phone: `undo` is the token a `result` carried. The reply is `undone`.
  static let undo = "undo"
  static let undoKey = "undo"

  /// Phone -> Watch, display-ready. A logged item has `title`, `item` and maybe
  /// `amount` + `unit`, `detail` + `value` + `fraction` (spending against the
  /// budget) or `detail` + `bars` (a meal's confidence). An answer has `reply`.
  /// `undo` is there whenever the turn changed something.
  static let result = "result"
  static let undone = "undone"
  static let titleKey = "title"
  static let itemKey = "item"
  static let amountKey = "amount"
  static let unitKey = "unit"
  static let detailKey = "detail"
  static let valueKey = "value"
  static let fractionKey = "fraction"
  static let barsKey = "bars"
  static let replyKey = "reply"
}
