//
//  OpalWatchMessage.swift
//  Runner, OpalWatch
//
//  Wire format of the WatchConnectivity link. Compiled into both Runner and
//  OpalWatch (the way OpalWorkoutAttributes is shared with OpalWidgets) so the
//  two ends can't drift. A message is a `[String: Any]` carrying a `type`; a
//  reply carries either a `type` or an `error`. The phone answers in Dart, so
//  `WatchKeys` in lib/services/watch/watch_channel.dart spells the same keys,
//  workout commands and phases included.
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

  /// Watch -> phone: a workout `command`, the `setId` the Watch showed, and on
  /// Complete set / Finish what the Watch measured. The reply, and every push
  /// from the phone, is a `workout` snapshot.
  static let workout = "workout"
  static let commandKey = "command"
  static let distanceKmKey = "distanceKm"
  static let heartRateKey = "heartRate"
  static let kcalKey = "kcal"

  /// Phone -> Watch: end the Watch's workout. The reply has `heartRate` and `kcal`.
  static let workoutEnd = "workoutEnd"

  /// A snapshot. `session` (start, epoch ms) and `rev` order them; the rest is
  /// display-ready. `restEndsAt` is epoch ms, `restTotal` seconds.
  static let sessionKey = "session"
  static let revKey = "rev"
  static let phaseKey = "phase"
  static let setIdKey = "setId"
  static let timedKey = "timed"
  static let setLabelKey = "setLabel"
  static let exerciseKey = "exercise"
  static let plannedKey = "planned"
  static let bestKey = "best"
  static let aheadKey = "ahead"
  static let restEndsAtKey = "restEndsAt"
  static let restTotalKey = "restTotal"
  static let nextKey = "next"
  static let progressKey = "progress"
  static let canSkipKey = "canSkip"
  static let loggedKey = "logged"

  static let phaseSet = "set"
  static let phaseRest = "rest"
  static let phaseDone = "done"
  static let phaseEnded = "ended"
  static let phaseNone = "none"

  /// The snapshot for a phone with no workout running.
  static let noWorkout: [String: Any] = [typeKey: workout, phaseKey: phaseNone]
}

/// The Watch's workout commands; the raw values are the wire's `command`.
enum OpalWorkoutCommand: String {
  case state
  case complete
  case skipRest
  case addRest
  case addSet
  case skipExercise
  case finish
}
