//
//  OpalRingsSnapshot.swift
//  Shared by Runner (writer) and OpalWidgets (reader) via the App Group.
//
//  The app's OpalWidgetSyncBridge calls `save()`; the widget's TimelineProvider
//  calls `load()`. The App Group id + UserDefaults keys live here once and are
//  compiled into BOTH targets (mirrors how OpalWorkoutAttributes is shared).
//

import Foundation

/// Shared App Group identifier — must match the entitlement on BOTH the Runner
/// app and the OpalWidgets extension.
let opalAppGroupId = "group.com.opal.opal"

/// Today's progress the rings widget renders. Pre-computed on the Flutter side
/// (the widget does no math), so a zeroed goal arrives as a 0 ring fraction.
struct RingsSnapshot {
  var moneyRing: Double
  var moveRing: Double
  var ritualsRing: Double
  var moneySpent: Double
  var dailyBudget: Double
  var moveMinutes: Int
  var dailyMoveMinutes: Int
  var ritualsDone: Int
  var dailyRitualTarget: Int

  /// Zeroed snapshot for "no data yet" (fresh install / unprovisioned group).
  static let empty = RingsSnapshot(
    moneyRing: 0, moveRing: 0, ritualsRing: 0,
    moneySpent: 0, dailyBudget: 0,
    moveMinutes: 0, dailyMoveMinutes: 0,
    ritualsDone: 0, dailyRitualTarget: 0)

  private enum Key {
    static let moneyRing = "moneyRing"
    static let moveRing = "moveRing"
    static let ritualsRing = "ritualsRing"
    static let moneySpent = "moneySpent"
    static let dailyBudget = "dailyBudget"
    static let moveMinutes = "moveMinutes"
    static let dailyMoveMinutes = "dailyMoveMinutes"
    static let ritualsDone = "ritualsDone"
    static let dailyRitualTarget = "dailyRitualTarget"
    static let hasData = "hasData"
  }

  private static var store: UserDefaults? { UserDefaults(suiteName: opalAppGroupId) }

  /// Persists to the shared group; no-op if the group is unavailable (e.g. an
  /// unprovisioned App Group), so a sync failure never crashes.
  func save() {
    guard let d = Self.store else { return }
    d.set(moneyRing, forKey: Key.moneyRing)
    d.set(moveRing, forKey: Key.moveRing)
    d.set(ritualsRing, forKey: Key.ritualsRing)
    d.set(moneySpent, forKey: Key.moneySpent)
    d.set(dailyBudget, forKey: Key.dailyBudget)
    d.set(moveMinutes, forKey: Key.moveMinutes)
    d.set(dailyMoveMinutes, forKey: Key.dailyMoveMinutes)
    d.set(ritualsDone, forKey: Key.ritualsDone)
    d.set(dailyRitualTarget, forKey: Key.dailyRitualTarget)
    d.set(true, forKey: Key.hasData)
  }

  /// Reads the latest snapshot, or `.empty` if nothing has been written yet.
  static func load() -> RingsSnapshot {
    guard let d = store, d.bool(forKey: Key.hasData) else { return .empty }
    return RingsSnapshot(
      moneyRing: d.double(forKey: Key.moneyRing),
      moveRing: d.double(forKey: Key.moveRing),
      ritualsRing: d.double(forKey: Key.ritualsRing),
      moneySpent: d.double(forKey: Key.moneySpent),
      dailyBudget: d.double(forKey: Key.dailyBudget),
      moveMinutes: d.integer(forKey: Key.moveMinutes),
      dailyMoveMinutes: d.integer(forKey: Key.dailyMoveMinutes),
      ritualsDone: d.integer(forKey: Key.ritualsDone),
      dailyRitualTarget: d.integer(forKey: Key.dailyRitualTarget))
  }
}
